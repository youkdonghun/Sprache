import { describe, expect, it } from "vitest";

import { buildApp } from "./app.js";
import type { AppConfig } from "./config.js";
import type { IdentityVerifier } from "./auth/identityVerifier.js";
import type {
  DriveBinding,
  DriveBindingRepository,
  UpsertDriveBinding,
} from "./repositories/driveBindingRepository.js";

const config: AppConfig = {
  databaseUrl: "postgresql://unused",
  googleAllowedClientIds: ["test-client"],
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

async function createTestApp() {
  return buildApp({
    config,
    repository: new MemoryDriveBindingRepository(),
    identityVerifier: new FakeIdentityVerifier(),
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
    });
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

