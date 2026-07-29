import { describe, expect, it } from "vitest";

import {
  GoogleDesktopOAuthBrokerError,
  RailwayGoogleDesktopOAuthBroker,
} from "./googleDesktopOAuthBroker.js";

describe("RailwayGoogleDesktopOAuthBroker", () => {
  it("exchanges PKCE codes with the secret kept on the API side", async () => {
    let postedBody = "";
    const broker = new RailwayGoogleDesktopOAuthBroker(
      "desktop-client-id",
      "railway-only-secret",
      async (_input, init) => {
        postedBody = init?.body?.toString() ?? "";
        return new Response(
          JSON.stringify({
            access_token: "access-token",
            refresh_token: "refresh-token",
            id_token: "id-token",
            expires_in: 3600,
          }),
          {
            status: 200,
            headers: { "content-type": "application/json" },
          },
        );
      },
    );

    const token = await broker.requestToken({
      grantType: "authorization_code",
      authorizationCode: "authorization-code",
      codeVerifier: "v".repeat(64),
      redirectUri: "http://127.0.0.1:49152",
    });

    const fields = new URLSearchParams(postedBody);
    expect(fields.get("client_id")).toBe("desktop-client-id");
    expect(fields.get("client_secret")).toBe("railway-only-secret");
    expect(fields.get("code")).toBe("authorization-code");
    expect(fields.get("code_verifier")).toBe("v".repeat(64));
    expect(fields.get("redirect_uri")).toBe("http://127.0.0.1:49152");
    expect(token).toEqual({
      accessToken: "access-token",
      refreshToken: "refresh-token",
      idToken: "id-token",
      expiresIn: 3600,
    });
  });

  it("maps Google failures without echoing request credentials", async () => {
    const broker = new RailwayGoogleDesktopOAuthBroker(
      "desktop-client-id",
      "railway-only-secret",
      async () =>
        new Response(
          JSON.stringify({
            error: "invalid_grant",
            error_description: "Authorization code expired.",
          }),
          {
            status: 400,
            headers: { "content-type": "application/json" },
          },
        ),
    );

    await expect(
      broker.requestToken({
        grantType: "refresh_token",
        refreshToken: "refresh-token",
      }),
    ).rejects.toMatchObject<GoogleDesktopOAuthBrokerError>({
      statusCode: 400,
      code: "invalid_grant",
      description: "Authorization code expired.",
    });
  });
});
