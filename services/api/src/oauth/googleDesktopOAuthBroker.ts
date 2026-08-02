import { z } from "zod";

export type GoogleDesktopTokenRequest =
  | {
      grantType: "authorization_code";
      authorizationCode: string;
      codeVerifier: string;
      redirectUri: string;
    }
  | {
      grantType: "refresh_token";
      refreshToken: string;
    };

export type GoogleDesktopTokenResponse = {
  accessToken: string;
  refreshToken: string | null;
  idToken: string | null;
  expiresIn: number;
};

export interface GoogleDesktopOAuthBroker {
  readonly configured: boolean;

  requestToken(
    input: GoogleDesktopTokenRequest,
  ): Promise<GoogleDesktopTokenResponse>;
}

const googleDesktopOAuthBrokerErrorBrand = Symbol.for(
  "@sprache/api/GoogleDesktopOAuthBrokerError",
);
const googleDesktopOAuthErrorCodePattern = /^[a-z][a-z0-9_]{0,127}$/;

export class GoogleDesktopOAuthBrokerError extends Error {
  readonly [googleDesktopOAuthBrokerErrorBrand] = true;

  constructor(
    readonly statusCode: number,
    readonly code: string,
    readonly description: string | null = null,
  ) {
    super(description ? `${code}: ${description}` : code);
    this.name = "GoogleDesktopOAuthBrokerError";
  }
}

export function isGoogleDesktopOAuthBrokerError(
  value: unknown,
): value is GoogleDesktopOAuthBrokerError {
  if (typeof value !== "object" || value === null) return false;
  const candidate = value as Record<PropertyKey, unknown>;
  return (
    candidate[googleDesktopOAuthBrokerErrorBrand] === true &&
    candidate.name === "GoogleDesktopOAuthBrokerError" &&
    typeof candidate.statusCode === "number" &&
    Number.isInteger(candidate.statusCode) &&
    candidate.statusCode >= 400 &&
    candidate.statusCode <= 599 &&
    typeof candidate.code === "string" &&
    googleDesktopOAuthErrorCodePattern.test(candidate.code) &&
    (candidate.description === null ||
      (typeof candidate.description === "string" &&
        candidate.description.length <= 320))
  );
}

const googleTokenSchema = z.object({
  access_token: z.string().min(1),
  refresh_token: z.string().min(1).optional(),
  id_token: z.string().min(1).optional(),
  expires_in: z.coerce.number().int().positive(),
});

const googleErrorSchema = z.object({
  error: z.string().min(1).optional(),
  error_description: z.string().optional(),
});

export class RailwayGoogleDesktopOAuthBroker
  implements GoogleDesktopOAuthBroker
{
  readonly configured = true;

  constructor(
    private readonly clientId: string,
    private readonly clientSecret: string,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async requestToken(
    input: GoogleDesktopTokenRequest,
  ): Promise<GoogleDesktopTokenResponse> {
    const body = new URLSearchParams({
      client_id: this.clientId,
      client_secret: this.clientSecret,
      grant_type: input.grantType,
    });
    if (input.grantType === "authorization_code") {
      body.set("code", input.authorizationCode);
      body.set("code_verifier", input.codeVerifier);
      body.set("redirect_uri", input.redirectUri);
    } else {
      body.set("refresh_token", input.refreshToken);
    }

    let response: Response;
    try {
      response = await this.fetchImpl("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: {
          "content-type": "application/x-www-form-urlencoded",
        },
        body,
        signal: AbortSignal.timeout(15_000),
      });
    } catch {
      throw new GoogleDesktopOAuthBrokerError(
        502,
        "oauth_broker_upstream_failed",
        "Google token endpoint is temporarily unavailable.",
      );
    }

    const rawBody = await response.text();
    let decoded: unknown;
    try {
      decoded = JSON.parse(rawBody);
    } catch {
      throw new GoogleDesktopOAuthBrokerError(
        502,
        "oauth_broker_invalid_response",
        "Google token endpoint returned an invalid response.",
      );
    }

    if (!response.ok) {
      const parsed = googleErrorSchema.safeParse(decoded);
      const code = parsed.success
        ? (parsed.data.error ?? "google_oauth_failed")
        : "google_oauth_failed";
      const description = parsed.success
        ? sanitizeDescription(parsed.data.error_description)
        : null;
      throw new GoogleDesktopOAuthBrokerError(
        normalizeUpstreamStatus(response.status),
        code,
        description,
      );
    }

    const token = googleTokenSchema.safeParse(decoded);
    if (!token.success) {
      throw new GoogleDesktopOAuthBrokerError(
        502,
        "oauth_broker_invalid_response",
        "Google token response is missing required fields.",
      );
    }
    return {
      accessToken: token.data.access_token,
      refreshToken: token.data.refresh_token ?? null,
      idToken: token.data.id_token ?? null,
      expiresIn: token.data.expires_in,
    };
  }
}

export class UnavailableGoogleDesktopOAuthBroker
  implements GoogleDesktopOAuthBroker
{
  readonly configured = false;

  async requestToken(): Promise<GoogleDesktopTokenResponse> {
    throw new GoogleDesktopOAuthBrokerError(
      503,
      "oauth_broker_not_configured",
      "Railway desktop OAuth broker credentials are not configured.",
    );
  }
}

function normalizeUpstreamStatus(statusCode: number): number {
  if (statusCode >= 400 && statusCode < 500) {
    return statusCode;
  }
  return 502;
}

function sanitizeDescription(value: string | undefined): string | null {
  if (!value) return null;
  const normalized = value.trim().replace(/\s+/g, " ");
  return normalized.length <= 320
    ? normalized
    : `${normalized.slice(0, 317)}...`;
}
