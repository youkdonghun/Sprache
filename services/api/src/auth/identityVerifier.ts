import { OAuth2Client } from "google-auth-library";

export type VerifiedIdentity = {
  subject: string;
};

export interface IdentityVerifier {
  verify(idToken: string): Promise<VerifiedIdentity>;
}

export class GoogleIdentityVerifier implements IdentityVerifier {
  private readonly client = new OAuth2Client();

  constructor(private readonly allowedClientIds: string[]) {}

  async verify(idToken: string): Promise<VerifiedIdentity> {
    const ticket = await this.client.verifyIdToken({
      idToken,
      audience: this.allowedClientIds,
    });
    const payload = ticket.getPayload();
    if (!payload?.sub) {
      throw new Error("Google token is missing a subject");
    }
    return { subject: payload.sub };
  }
}

