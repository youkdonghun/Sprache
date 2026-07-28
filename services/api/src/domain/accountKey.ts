import { createHmac } from "node:crypto";

export function createAccountKey(googleSubject: string, secret: string): string {
  if (googleSubject.length === 0) {
    throw new Error("Google subject must not be empty");
  }
  if (secret.length < 32) {
    throw new Error("HMAC secret must contain at least 32 characters");
  }

  return createHmac("sha256", secret).update(googleSubject, "utf8").digest("hex");
}

