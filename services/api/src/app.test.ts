import { describe, expect, it } from "vitest";

import { buildApp } from "./app.js";
import type { AppConfig } from "./config.js";
import type { IdentityVerifier } from "./auth/identityVerifier.js";
import {
  GoogleDesktopOAuthBrokerError,
  type GoogleDesktopOAuthBroker,
  type GoogleDesktopTokenRequest,
} from "./oauth/googleDesktopOAuthBroker.js";
import type {
  DriveBinding,
  DriveBindingRepository,
  UpsertDriveBinding,
} from "./repositories/driveBindingRepository.js";

const config: AppConfig = {
  databaseUrl: "postgresql://unused",
  googleAllowedClientIds: ["test-client"],
  googleDesktopClientId: null,
  googleDesktopClientSecret: null,
  userKeyHmacSecret: "a-secure-test-secret-with-more-than-32-characters",
  logLevel: "silent",
  nodeEnv: "test",
  port: 3000,
};

class FakeIdentityVerifier implements IdentityVerifier {
  async verify(idToken: string) {
    if (!idToken.startsWith("valid:")) {
      throw new Error("invalid token");
    }
    return { subject: idToken.slice("valid:".length) };
  }
}

class MemoryDriveBindingRepository implements DriveBindingRepository {
  private readonly records = new Map<string, DriveBinding>();

  async findByAccountKey(accountKey: string) {
    return this.records.get(accountKey) ?? null;
  }

  async upsert(input: UpsertDriveBinding) {
    const current = this.records.get(input.accountKey);
    const now = new Date("2026-07-27T00:00:00.000Z");
    const record: DriveBinding = {
      ...input,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
    };
    this.records.set(input.accountKey, record);
    return record;
  }

  async deleteByAccountKey(accountKey: string) {
    this.records.delete(accountKey);
  }
}

class FakeGoogleDesktopOAuthBroker implements GoogleDesktopOAuthBroker {
  readonly configured = true;
  readonly requests: GoogleDesktopTokenRequest[] = [];

  async requestToken(input: GoogleDesktopTokenRequest) {
    this.requests.push(input);
    return {
      accessToken: "access-token",
      refreshToken:
        input.grantType === "authorization_code" ? "refresh-token" : null,
      idToken: input.grantType === "authorization_code" ? "id-token" : null,
      expiresIn: 3600,
    };
  }
}

async function createTestApp(
  googleDesktopOAuthBroker?: GoogleDesktopOAuthBroker,
) {
  return buildApp({
    config,
    repository: new MemoryDriveBindingRepository(),
    identityVerifier: new FakeIdentityVerifier(),
    googleDesktopOAuthBroker,
    logger: false,
  });
}

describe("Sprache API", () => {
  it("reports health without authentication", async () => {
    const app = await createTestApp();
    const response = await app.inject({ method: "GET", url: "/health" });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({
      status: "ok",
      service: "sprache-api",
      desktopOAuthBroker: "not_configured",
    });
    await app.close();
  });

  it("serves public OAuth branding pages without authentication", async () => {
    const app = await createTestApp();
    const homepage = await app.inject({ method: "GET", url: "/" });
    const privacy = await app.inject({ method: "GET", url: "/privacy" });
    const terms = await app.inject({ method: "GET", url: "/terms" });

    expect(homepage.statusCode).toBe(200);
    expect(homepage.headers["content-type"]).toContain("text/html");
    expect(homepage.headers["content-security-policy"]).toContain(
      "frame-ancestors 'none'",
    );
    expect(homepage.body).toContain("<h1>Sprache</h1>");
    expect(homepage.body).toContain("Google 연결은 선택 사항");
    expect(homepage.body).toContain('href="/privacy"');
    expect(homepage.body).toContain('href="/terms"');

    expect(privacy.statusCode).toBe(200);
    expect(privacy.body).toContain("Sprache 개인정보처리방침");
    expect(privacy.body).toContain("<code>drive.file</code>");
    expect(privacy.body).toContain("Railway DB에는 이메일");
    expect(privacy.body).toContain("Google API Services User Data Policy");
    expect(privacy.body).toContain("Google 계정 연결 관리");

    expect(terms.statusCode).toBe(200);
    expect(terms.body).toContain("Sprache 서비스 이용약관");
    await app.close();
  });

  it("keeps legacy public document paths available", async () => {
    const app = await createTestApp();
    const homepage = await app.inject({
      method: "GET",
      url: "/app-homepage.html",
    });
    const privacy = await app.inject({
      method: "GET",
      url: "/privacy-policy.html",
    });

    expect(homepage.statusCode).toBe(200);
    expect(homepage.body).toContain("<h1>Sprache</h1>");
    expect(privacy.statusCode).toBe(200);
    expect(privacy.body).toContain("개인정보처리방침");
    await app.close();
  });

  it("brokers desktop authorization and refresh tokens without caching them", async () => {
    const broker = new FakeGoogleDesktopOAuthBroker();
    const app = await createTestApp(broker);

    const authorization = await app.inject({
      method: "POST",
      url: "/v1/oauth/google/desktop/token",
      payload: {
        grantType: "authorization_code",
        authorizationCode: "authorization-code",
        codeVerifier: "v".repeat(64),
        redirectUri: "http://127.0.0.1:49152",
      },
    });
    const refresh = await app.inject({
      method: "POST",
      url: "/v1/oauth/google/desktop/token",
      payload: {
        grantType: "refresh_token",
        refreshToken: "refresh-token",
      },
    });

    expect(authorization.statusCode).toBe(200);
    expect(authorization.headers["cache-control"]).toBe("no-store");
    expect(authorization.headers.pragma).toBe("no-cache");
    expect(authorization.json()).toEqual({
      accessToken: "access-token",
      refreshToken: "refresh-token",
      idToken: "id-token",
      expiresIn: 3600,
    });
    expect(refresh.statusCode).toBe(200);
    expect(broker.requests).toHaveLength(2);
    expect(broker.requests[0]).toMatchObject({
      grantType: "authorization_code",
      redirectUri: "http://127.0.0.1:49152",
    });
    expect(broker.requests[1]).toEqual({
      grantType: "refresh_token",
      refreshToken: "refresh-token",
    });
    await app.close();
  });

  it("rejects unsafe callbacks and reports a missing Railway broker", async () => {
    const configured = await createTestApp(new FakeGoogleDesktopOAuthBroker());
    const unsafe = await configured.inject({
      method: "POST",
      url: "/v1/oauth/google/desktop/token",
      payload: {
        grantType: "authorization_code",
        authorizationCode: "authorization-code",
        codeVerifier: "v".repeat(64),
        redirectUri: "https://attacker.example/callback",
      },
    });
    expect(unsafe.statusCode).toBe(400);
    expect(unsafe.json().error).toBe("invalid_request");
    await configured.close();

    const unavailable = await createTestApp();
    const missing = await unavailable.inject({
      method: "POST",
      url: "/v1/oauth/google/desktop/token",
      payload: {
        grantType: "refresh_token",
        refreshToken: "refresh-token",
      },
    });
    expect(missing.statusCode).toBe(503);
    expect(missing.json().error).toBe("oauth_broker_not_configured");
    await unavailable.close();
  });

  it("rejects malformed desktop token JSON without caching it", async () => {
    const app = await createTestApp(new FakeGoogleDesktopOAuthBroker());
    const response = await app.inject({
      method: "POST",
      url: "/v1/oauth/google/desktop/token",
      headers: { "content-type": "application/json" },
      payload: '{"grantType":',
    });

    expect(response.statusCode).toBe(400);
    expect(response.headers["cache-control"]).toBe("no-store");
    expect(response.headers.pragma).toBe("no-cache");
    expect(response.json()).toEqual({
      error: "invalid_request",
      message: "Request body must be valid JSON",
    });
    await app.close();
  });

  it("returns a bounded Google OAuth error without token material", async () => {
    const failingBroker: GoogleDesktopOAuthBroker = {
      configured: true,
      async requestToken() {
        throw new GoogleDesktopOAuthBrokerError(
          400,
          "invalid_grant",
          "Authorization code expired.",
        );
      },
    };
    const app = await createTestApp(failingBroker);
    const response = await app.inject({
      method: "POST",
      url: "/v1/oauth/google/desktop/token",
      payload: {
        grantType: "refresh_token",
        refreshToken: "do-not-return-this-token",
      },
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toEqual({
      error: "invalid_grant",
      message: "Google OAuth token request failed",
      description: "Authorization code expired.",
    });
    expect(response.body).not.toContain("do-not-return-this-token");
    await app.close();
  });

  it("rejects missing and invalid ID tokens", async () => {
    const app = await createTestApp();
    const missing = await app.inject({
      method: "GET",
      url: "/v1/me/drive-root",
    });
    const invalid = await app.inject({
      method: "GET",
      url: "/v1/me/drive-root",
      headers: { authorization: "Bearer invalid" },
    });

    expect(missing.statusCode).toBe(401);
    expect(invalid.statusCode).toBe(401);
    await app.close();
  });

  it("stores, reads, and removes only the current account binding", async () => {
    const app = await createTestApp();
    const headers = { authorization: "Bearer valid:user-a" };
    const folderId = "folder_1234567890";

    const stored = await app.inject({
      method: "PUT",
      url: "/v1/me/drive-root",
      headers,
      payload: {
        folderId,
        folderName: "Language Data",
        schemaVersion: 1,
      },
    });
    expect(stored.statusCode).toBe(200);
    expect(stored.json().binding.folderId).toBe(folderId);

    const current = await app.inject({
      method: "GET",
      url: "/v1/me/drive-root",
      headers,
    });
    expect(current.json().binding.folderName).toBe("Language Data");

    const otherAccount = await app.inject({
      method: "GET",
      url: "/v1/me/drive-root",
      headers: { authorization: "Bearer valid:user-b" },
    });
    expect(otherAccount.json()).toEqual({ binding: null });

    const removed = await app.inject({
      method: "DELETE",
      url: "/v1/me/drive-root",
      headers,
    });
    expect(removed.statusCode).toBe(204);

    const afterDelete = await app.inject({
      method: "GET",
      url: "/v1/me/drive-root",
      headers,
    });
    expect(afterDelete.json()).toEqual({ binding: null });
    await app.close();
  });

  it("rejects invalid Drive folder IDs", async () => {
    const app = await createTestApp();
    const response = await app.inject({
      method: "PUT",
      url: "/v1/me/drive-root",
      headers: { authorization: "Bearer valid:user-a" },
      payload: {
        folderId: "../bad",
        schemaVersion: 1,
      },
    });

    expect(response.statusCode).toBe(400);
    expect(response.json().error).toBe("invalid_request");
    await app.close();
  });
});
