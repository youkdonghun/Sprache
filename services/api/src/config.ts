import { z } from "zod";

const optionalCredential = z.preprocess(
  (value) =>
    typeof value === "string" && value.trim().length === 0 ? undefined : value,
  z.string().trim().min(1).optional(),
);

const envSchema = z
  .object({
    DATABASE_URL: z.string().min(1),
    GOOGLE_ALLOWED_CLIENT_IDS: z.string().min(1),
    GOOGLE_DESKTOP_CLIENT_ID: optionalCredential,
    GOOGLE_DESKTOP_CLIENT_SECRET: optionalCredential,
    USER_KEY_HMAC_SECRET: z.string().min(32),
    LOG_LEVEL: z
      .enum(["fatal", "error", "warn", "info", "debug", "trace", "silent"])
      .default("info"),
    NODE_ENV: z
      .enum(["development", "test", "production"])
      .default("development"),
    PORT: z.coerce.number().int().min(1).max(65_535).default(3000),
  })
  .superRefine((value, context) => {
    if (
      Boolean(value.GOOGLE_DESKTOP_CLIENT_ID) !==
      Boolean(value.GOOGLE_DESKTOP_CLIENT_SECRET)
    ) {
      context.addIssue({
        code: "custom",
        path: ["GOOGLE_DESKTOP_CLIENT_SECRET"],
        message:
          "GOOGLE_DESKTOP_CLIENT_ID and GOOGLE_DESKTOP_CLIENT_SECRET must be configured together",
      });
    }
  });

export type AppConfig = {
  databaseUrl: string;
  googleAllowedClientIds: string[];
  googleDesktopClientId: string | null;
  googleDesktopClientSecret: string | null;
  userKeyHmacSecret: string;
  logLevel: z.infer<typeof envSchema>["LOG_LEVEL"];
  nodeEnv: z.infer<typeof envSchema>["NODE_ENV"];
  port: number;
};

export function loadConfig(environment: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = envSchema.parse(environment);
  const googleAllowedClientIds = parsed.GOOGLE_ALLOWED_CLIENT_IDS.split(",")
    .map((value) => value.trim())
    .filter(Boolean);

  if (googleAllowedClientIds.length === 0) {
    throw new Error("GOOGLE_ALLOWED_CLIENT_IDS must contain at least one client ID");
  }

  return {
    databaseUrl: parsed.DATABASE_URL,
    googleAllowedClientIds,
    googleDesktopClientId: parsed.GOOGLE_DESKTOP_CLIENT_ID ?? null,
    googleDesktopClientSecret: parsed.GOOGLE_DESKTOP_CLIENT_SECRET ?? null,
    userKeyHmacSecret: parsed.USER_KEY_HMAC_SECRET,
    logLevel: parsed.LOG_LEVEL,
    nodeEnv: parsed.NODE_ENV,
    port: parsed.PORT,
  };
}
