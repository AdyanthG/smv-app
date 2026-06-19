"use strict";

// ─────────────────────────────────────────────────────────────────────────
// Sign in with Apple — token revocation (App Store requirement).
//
// Apple requires that apps offering Sign in with Apple AND account deletion
// revoke the user's tokens on deletion. Flow:
//   1. Client writes the short-lived authorization code to appleAuthCodes/{uid}.
//   2. exchangeAppleAuthCode trades it for a long-lived refresh token (stored
//      on the user doc) — must happen promptly (codes expire in ~5 min).
//   3. On account deletion, cleanupDeletedUser calls revokeAppleToken().
//
// Configure these in functions/.env (see .env.example):
//   APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_CLIENT_ID (bundle id), APPLE_PRIVATE_KEY
// ─────────────────────────────────────────────────────────────────────────

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const jwt = require("jsonwebtoken");

const db = admin.firestore();

const TEAM_ID = process.env.APPLE_TEAM_ID;
const KEY_ID = process.env.APPLE_KEY_ID;
const CLIENT_ID = process.env.APPLE_CLIENT_ID; // app bundle id, e.g. com.adyanth.SMV
const PRIVATE_KEY = (process.env.APPLE_PRIVATE_KEY || "").replace(/\\n/g, "\n");

const isConfigured = () => Boolean(TEAM_ID && KEY_ID && CLIENT_ID && PRIVATE_KEY);

/** Apple client secret: a short-lived ES256 JWT signed with the .p8 key. */
function makeClientSecret() {
  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    { iss: TEAM_ID, iat: now, exp: now + 3600, aud: "https://appleid.apple.com", sub: CLIENT_ID },
    PRIVATE_KEY,
    { algorithm: "ES256", keyid: KEY_ID }
  );
}

async function applePost(endpoint, params) {
  return fetch(`https://appleid.apple.com/auth/${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(params).toString(),
  });
}

// Exchange the authorization code for a refresh token, store it, drop the code.
exports.exchangeAppleAuthCode = functions.firestore
  .document("appleAuthCodes/{uid}")
  .onCreate(async (snap, ctx) => {
    const uid = ctx.params.uid;
    const code = snap.data() && snap.data().code;
    if (!isConfigured() || !code) {
      await snap.ref.delete().catch(() => {});
      return;
    }
    try {
      const res = await applePost("token", {
        grant_type: "authorization_code",
        code,
        client_id: CLIENT_ID,
        client_secret: makeClientSecret(),
      });
      const body = await res.json();
      if (body.refresh_token) {
        await db.collection("users").doc(uid).set(
          { appleRefreshToken: body.refresh_token }, { merge: true });
      } else {
        console.error("[exchangeAppleAuthCode]", JSON.stringify(body).slice(0, 200));
      }
    } catch (e) {
      console.error("[exchangeAppleAuthCode]", e.message);
    }
    // Never retain the auth code.
    await snap.ref.delete().catch(() => {});
  });

/** Revoke a user's Apple refresh token (called on account deletion). */
async function revokeAppleToken(refreshToken) {
  if (!isConfigured() || !refreshToken) return;
  try {
    await applePost("revoke", {
      client_id: CLIENT_ID,
      client_secret: makeClientSecret(),
      token: refreshToken,
      token_type_hint: "refresh_token",
    });
  } catch (e) {
    console.error("[revokeAppleToken]", e.message);
  }
}

exports.revokeAppleToken = revokeAppleToken;
