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
  isGoogleDesktopOAuthBrokerError,
  RailwayGoogleDesktopOAuthBroker,
  UnavailableGoogleDesktopOAuthBroker,
  type GoogleDesktopOAuthBroker,
} from "./oauth/googleDesktopOAuthBroker.js";
import {
  PrismaDriveBindingRepository,
  type DriveBinding,
  type DriveBindingRepository,
} from "./repositories/driveBindingRepository.js";
import {
  appHomepageHtml,
  privacyPolicyHtml,
  termsOfServiceHtml,
} from "./publicPages.js";

type BuildAppOptions = {
  config: AppConfig;
  repository?: DriveBindingRepository;
  identityVerifier?: IdentityVerifier;
  googleDesktopOAuthBroker?: GoogleDesktopOAuthBroker;
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

const loopbackRedirectSchema = z
  .string()
  .max(128)
  .refine((value) => {
    try {
      const uri = new URL(value);
      return (
        uri.protocol === "http:" &&
        uri.hostname === "127.0.0.1" &&
        uri.port.length > 0 &&
        uri.username.length === 0 &&
        uri.password.length === 0 &&
        (uri.pathname === "/" || uri.pathname.length === 0) &&
        uri.search.length === 0 &&
        uri.hash.length === 0
      );
    } catch {
      return false;
    }
  }, "redirectUri must be a pathless 127.0.0.1 loopback URL with a dynamic port");

const desktopTokenBodySchema = z.discriminatedUnion("grantType", [
  z.object({
    grantType: z.literal("authorization_code"),
    authorizationCode: z.string().min(1).max(4096),
    codeVerifier: z
      .string()
      .min(43)
      .max(128)
      .regex(/^[A-Za-z0-9\-._~]+$/),
    redirectUri: loopbackRedirectSchema,
  }),
  z.object({
    grantType: z.literal("refresh_token"),
    refreshToken: z.string().min(1).max(4096),
  }),
]);

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
                "*.authorizationCode",
                "*.codeVerifier",
                "req.body.authorizationCode",
                "req.body.codeVerifier",
                "req.body.refreshToken",
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
  const googleDesktopOAuthBroker =
    options.googleDesktopOAuthBroker ??
    (options.config.googleDesktopClientId &&
    options.config.googleDesktopClientSecret
      ? new RailwayGoogleDesktopOAuthBroker(
          options.config.googleDesktopClientId,
          options.config.googleDesktopClientSecret,
        )
      : new UnavailableGoogleDesktopOAuthBroker());

  await app.register(cors, {
    origin: false,
  });
  await app.register(helmet);
  await app.register(rateLimit, {
    max: 120,
    timeWindow: "1 minute",
  });

  const publicPageHeaders = {
    "cache-control": "public, max-age=300",
    "content-security-policy":
      "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
    "referrer-policy": "no-referrer",
  };
  const sendPublicPage = (reply: FastifyReply, html: string) =>
    reply
      .headers(publicPageHeaders)
      .type("text/html; charset=utf-8")
      .send(html);

  app.get("/", async (_request, reply) =>
    sendPublicPage(reply, appHomepageHtml),
  );
  app.get("/app-homepage.html", async (_request, reply) =>
    sendPublicPage(reply, appHomepageHtml),
  );
  app.get("/privacy", async (_request, reply) =>
    sendPublicPage(reply, privacyPolicyHtml),
  );
  app.get("/privacy-policy.html", async (_request, reply) =>
    sendPublicPage(reply, privacyPolicyHtml),
  );
  app.get("/terms", async (_request, reply) =>
    sendPublicPage(reply, termsOfServiceHtml),
  );

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
    desktopOAuthBroker: googleDesktopOAuthBroker.configured
      ? "ready"
      : "not_configured",
  }));

  app.post(
    "/v1/oauth/google/desktop/token",
    {
      config: {
        rateLimit: {
          max: 20,
          timeWindow: "1 minute",
        },
      },
    },
    async (request, reply) => {
      reply
        .header("cache-control", "no-store")
        .header("pragma", "no-cache");

      if (!googleDesktopOAuthBroker.configured) {
        return reply.code(503).send({
          error: "oauth_broker_not_configured",
          message: "Desktop Google OAuth is not configured on Railway",
        });
      }

      const input = desktopTokenBodySchema.parse(request.body);
      try {
        const token = await googleDesktopOAuthBroker.requestToken(input);
        return reply.code(200).send(token);
      } catch (error) {
        if (isGoogleDesktopOAuthBrokerError(error)) {
          return reply.code(error.statusCode).send({
            error: error.code,
            message: "Google OAuth token request failed",
            description: error.description,
          });
        }
        throw error;
      }
    },
  );

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
    const isDesktopTokenRequest =
      request.method === "POST" &&
      request.url === "/v1/oauth/google/desktop/token";
    if (isDesktopTokenRequest) {
      reply
        .header("cache-control", "no-store")
        .header("pragma", "no-cache");
    }

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

    const errorCode =
      typeof error === "object" && error !== null && "code" in error
        ? (error as { code?: unknown }).code
        : null;
    if (errorCode === "FST_ERR_CTP_INVALID_JSON_BODY") {
      return reply.code(400).send({
        error: "invalid_request",
        message: "Request body must be valid JSON",
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
