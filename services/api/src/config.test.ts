import { describe, expect, it } from "vitest";

import { loadConfig } from "./config.js";

const baseEnvironment = {
  DATABASE_URL: "postgresql://unused",
  GOOGLE_ALLOWED_CLIENT_IDS: "desktop-client,android-client",
  USER_KEY_HMAC_SECRET: "a-secure-test-secret-with-more-than-32-characters",
  NODE_ENV: "test",
};

describe("API configuration", () => {
  it("allows the desktop OAuth broker to be explicitly unconfigured", () => {
    const config = loadConfig({
      ...baseEnvironment,
      GOOGLE_DESKTOP_CLIENT_ID: "",
      GOOGLE_DESKTOP_CLIENT_SECRET: "",
    });

    expect(config.googleDesktopClientId).toBeNull();
    expect(config.googleDesktopClientSecret).toBeNull();
  });

  it("requires the desktop client ID and secret as one Railway pair", () => {
    expect(() =>
      loadConfig({
        ...baseEnvironment,
        GOOGLE_DESKTOP_CLIENT_ID: "desktop-client",
      }),
    ).toThrow(/must be configured together/);
  });
});
