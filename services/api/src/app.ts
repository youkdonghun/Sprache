import { PrismaClient } from "@prisma/client";
import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import Fastify, {
  type FastifyInstance,
  type FastifyReply,
  type FastifyRequest,
} from "fastify";
import { z } from "zod";

import {
  GoogleIdentityVerifier,
  type IdentityVerifier,
} from "./auth/identityVerifier.js";
import type { AppConfig } from "./config.js";
import { createAccountKey } from "./domain/accountKey.js";
import {
  PrismaDriveBindingRepository,
  type DriveBinding,
  type DriveBindingRepository,
} from "./repositories/driveBindingRepository.js";

type BuildAppOptions = {
  config: AppConfig;
  repository?: DriveBindingRepository;
  identityVerifier?: IdentityVerifier;
  logger?: boolean;
};

type AuthenticatedRequest = FastifyRequest & {
  accountKey?: string;
};

const driveRootBodySchema = z.object({
  folderId: z.string().regex(/^[A-Za-z0-9_-]{10,256}$/),
  folderName: z.string().trim().min(1).max(256).nullable().default(null),
  schemaVersion: z.number().int().min(1).max(10_000).default(1),
});

function serializeBinding(binding: DriveBinding) {
  return {
    folderId: binding.appRootFolderId,
    folderName: binding.appRootFolderName,
    schemaVersion: binding.schemaVersion,
    createdAt: binding.createdAt.toISOString(),
    updatedAt: binding.updatedAt.toISOString(),
  };
}

export async function buildApp(options: BuildAppOptions): Promise<FastifyInstance> {
  const app = Fastify({
    logger:
      options.logger === false
        ? false
        : {
            level: options.config.logLevel,
            redact: {
              paths: [
                "req.headers.authorization",
                "headers.authorization",
                "*.idToken",
                "*.accessToken",
                "*.refreshToken",
              ],
              censor: "[REDACTED]",
            },
          },
  });

  let prisma: PrismaClient | undefined;
  const repository =
    options.repository ??
    (() => {
      prisma = new PrismaClient({
        datasourceUrl: options.config.databaseUrl,
      });
      return new PrismaDriveBindingRepository(prisma);
    })();
  const identityVerifier =
    options.identityVerifier ??
    new GoogleIdentityVerifier(options.config.googleAllowedClientIds);

  await app.register(cors, {
    origin: false,
  });
  await app.register(helmet);
  await app.register(rateLimit, {
    max: 120,
    timeWindow: "1 minute",
  });

  async function authenticate(
    request: AuthenticatedRequest,
    reply: FastifyReply,
  ): Promise<void> {
    const authorization = request.headers.authorization;
    if (!authorization?.startsWith("Bearer ")) {
      await reply.code(401).send({
        error: "unauthorized",
        message: "Bearer ID token is required",
      });
      return;
    }

    const idToken = authorization.slice("Bearer ".length).trim();
    if (idToken.length === 0) {
      await reply.code(401).send({
        error: "unauthorized",
        message: "Bearer ID token is required",
      });
      return;
    }

    try {
      const identity = await identityVerifier.verify(idToken);
      request.accountKey = createAccountKey(
        identity.subject,
        options.config.userKeyHmacSecret,
      );
    } catch {
      await reply.code(401).send({
        error: "unauthorized",
        message: "Google ID token is invalid or expired",
      });
    }
  }

  app.get("/health", async () => ({
    status: "ok",
    service: "sprache-api",
  }));

  app.post(
    "/v1/auth/verify",
    { preHandler: authenticate },
    async (request: AuthenticatedRequest, reply) => {
      if (!request.accountKey) {
        return reply;
      }
      const binding = await repository.findByAccountKey(request.accountKey);
      return {
        authenticated: true,
        driveConnected: binding !== null,
      };
    },
  );

  app.get(
    "/v1/me/drive-root",
    { preHandler: authenticate },
    async (request: AuthenticatedRequest, reply) => {
      if (!request.accountKey) {
        return reply;
      }
      const binding = await repository.findByAccountKey(request.accountKey);
      return {
        binding: binding ? serializeBinding(binding) : null,
      };
    },
  );

  app.put(
    "/v1/me/drive-root",
    { preHandler: authenticate },
    async (request: AuthenticatedRequest, reply) => {
      if (!request.accountKey) {
        return reply;
      }
      const input = driveRootBodySchema.parse(request.body);
      const binding = await repository.upsert({
        accountKey: request.accountKey,
        appRootFolderId: input.folderId,
        appRootFolderName: input.folderName,
        schemaVersion: input.schemaVersion,
      });
      return reply.code(200).send({
        binding: serializeBinding(binding),
      });
    },
  );

  app.delete(
    "/v1/me/drive-root",
    { preHandler: authenticate },
    async (request: AuthenticatedRequest, reply) => {
      if (!request.accountKey) {
        return reply;
      }
      await repository.deleteByAccountKey(request.accountKey);
      return reply.code(204).send();
    },
  );

  app.setErrorHandler((error, request, reply) => {
    if (error instanceof z.ZodError) {
      return reply.code(400).send({
        error: "invalid_request",
        message: "Request validation failed",
        issues: error.issues.map((issue) => ({
          path: issue.path.join("."),
          message: issue.message,
        })),
      });
    }

    request.log.error({ error }, "Unhandled API error");
    return reply.code(500).send({
      error: "internal_error",
      message: "An unexpected error occurred",
    });
  });

  if (prisma) {
    app.addHook("onClose", async () => {
      await prisma?.$disconnect();
    });
  }

  return app;
}
