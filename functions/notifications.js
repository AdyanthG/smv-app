"use strict";

// ─────────────────────────────────────────────────────────────────────────
// SMV push-notification system (Firebase Cloud Messaging).
//
// A mix of Firestore-triggered (social) and scheduled (engagement/FOMO)
// notifications. Delivery to iOS devices requires an APNs auth key uploaded
// to Firebase (needs the Apple Developer membership). Until then these run and
// no-op safely; they start delivering the moment APNs is configured.
//
// All sends respect the user's `notificationsEnabled` flag and require a
// stored `fcmToken`. Invalid tokens are pruned automatically.
// ─────────────────────────────────────────────────────────────────────────

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const TZ = "America/New_York";
const RUNTIME = { timeoutSeconds: 300, memory: "512MB" };

// ── Time helpers (EST/EDT) ──
const estHour = (d = new Date()) =>
  parseInt(new Intl.DateTimeFormat("en-US", { timeZone: TZ, hour: "numeric", hour12: false }).format(d), 10);
const estDateStr = (d = new Date()) =>
  new Intl.DateTimeFormat("en-CA", { timeZone: TZ }).format(d); // YYYY-MM-DD
const daysSince = (date) => Math.floor((Date.now() - date.getTime()) / 86_400_000);

// ── Core sender ──
async function sendToUser(uid, { title, body, data = {}, logInApp = false }) {
  try {
    const snap = await db.collection("users").doc(uid).get();
    const u = snap.data();
    if (!u || !u.fcmToken) return false;
    if (u.notificationsEnabled === false) return false;

    await admin.messaging().send({
      token: u.fcmToken,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });

    // Mirror personal notifications into an in-app feed (with deep-link ids).
    if (logInApp) {
      const entry = {
        title, body, type: data.type || "general", read: false,
        createdAt: FieldValue.serverTimestamp(),
      };
      if (data.postId) entry.postId = data.postId;
      if (data.userId) entry.userId = data.userId;
      if (data.tab) entry.tab = data.tab;
      await db.collection("users").doc(uid).collection("notifications").add(entry);
    }
    return true;
  } catch (e) {
    if (e.code === "messaging/registration-token-not-registered" ||
        e.code === "messaging/invalid-registration-token") {
      await db.collection("users").doc(uid).update({ fcmToken: FieldValue.delete() }).catch(() => {});
    } else {
      console.error(`[sendToUser:${uid}]`, e.message);
    }
    return false;
  }
}

/** Fan a payload-builder out across all eligible users (small/medium scale). */
async function broadcast(buildPayload, { limit = 5000 } = {}) {
  const snap = await db.collection("users").limit(limit).get();
  let sent = 0;
  await Promise.all(snap.docs.map(async (doc) => {
    const u = doc.data();
    if (!u.fcmToken || u.notificationsEnabled === false) return;
    const payload = buildPayload(doc.id, u);
    if (!payload) return;
    if (await sendToUser(doc.id, payload)) sent++;
  }));
  return sent;
}

const displayName = (u) => (u && u.displayName) || "Someone";

// ═══════════════════════════════════════════════════════════════════════
// SOCIAL — Firestore-triggered
// ═══════════════════════════════════════════════════════════════════════

// New follower → notify the followed user.
exports.onNewFollower = functions.firestore
  .document("users/{userId}/followers/{followerId}")
  .onCreate(async (_snap, ctx) => {
    const { userId, followerId } = ctx.params;
    if (userId === followerId) return;
    const follower = (await db.collection("users").doc(followerId).get()).data();
    await sendToUser(userId, {
      title: "New follower ✨",
      body: `${displayName(follower)} started following you.`,
      data: { type: "follow", userId: followerId },
      logInApp: true,
    });
  });

// Post liked → notify the author (skip self-likes).
exports.onPostLiked = functions.firestore
  .document("posts/{postId}/likes/{likeUserId}")
  .onCreate(async (_snap, ctx) => {
    const { postId, likeUserId } = ctx.params;
    const post = (await db.collection("posts").doc(postId).get()).data();
    if (!post || post.authorId === likeUserId) return;
    const liker = (await db.collection("users").doc(likeUserId).get()).data();
    await sendToUser(post.authorId, {
      title: "New like ❤️",
      body: `${displayName(liker)} liked your post.`,
      data: { type: "like", postId },
      logInApp: true,
    });
  });

// Comment → notify the post author (skip self-comments).
exports.onPostComment = functions.firestore
  .document("posts/{postId}/comments/{commentId}")
  .onCreate(async (snap, ctx) => {
    const { postId } = ctx.params;
    const comment = snap.data();
    const post = (await db.collection("posts").doc(postId).get()).data();
    if (!post || !comment || post.authorId === comment.authorId) return;
    const preview = (comment.body || "").slice(0, 80);
    await sendToUser(post.authorId, {
      title: `${comment.authorName || "Someone"} commented 💬`,
      body: preview,
      data: { type: "comment", postId },
      logInApp: true,
    });
  });

// Vote recorded → milestone nudge to the winner on round-number win counts.
exports.onVoteRecorded = functions.firestore
  .document("votes/{voteId}")
  .onCreate(async (snap) => {
    const vote = snap.data();
    if (!vote || !vote.winnerId) return;
    const winner = (await db.collection("users").doc(vote.winnerId).get()).data();
    const wins = (winner && winner.voteWins) || 0;
    const milestones = [10, 25, 50, 100, 250, 500, 1000];
    if (milestones.includes(wins)) {
      await sendToUser(vote.winnerId, {
        title: `${wins} vote wins 🏆`,
        body: `People keep picking you. See your spot on the Most Voted board.`,
        data: { type: "vote_milestone", tab: "leaderboard" },
        logInApp: true,
      });
    }
  });

// ═══════════════════════════════════════════════════════════════════════
// ENGAGEMENT / FOMO — Scheduled
// ═══════════════════════════════════════════════════════════════════════

// Daily scan reminder (6pm EST) → only users who haven't scanned today.
exports.dailyScanReminder = functions.runWith(RUNTIME).pubsub
  .schedule("every day 18:00").timeZone(TZ)
  .onRun(async () => {
    const today = estDateStr();
    const sent = await broadcast((uid, u) => {
      const last = u.lastScanAt && u.lastScanAt.toDate ? u.lastScanAt.toDate() : null;
      if (last && estDateStr(last) === today) return null; // already scanned
      return {
        title: "Daily scan time 📸",
        body: "Is your glow-up working? Take today's scan and find out.",
        data: { type: "daily_scan", tab: "scan" },
      };
    });
    console.log(`[dailyScanReminder] sent ${sent}`);
  });

// The BeReal-style surprise drop — fires once per day at a date-seeded random
// hour (11am–9pm EST). Runs hourly and self-guards against double-sending.
exports.smvDrop = functions.runWith(RUNTIME).pubsub
  .schedule("every 60 minutes")
  .onRun(async () => {
    const now = new Date();
    const today = estDateStr(now);
    // Deterministic "random" target hour per day (11..21).
    const seed = parseInt(today.replace(/-/g, ""), 10);
    const targetHour = 11 + (seed * 7) % 11;
    if (estHour(now) !== targetHour) return;

    const metaRef = db.collection("meta").doc("smvDrop");
    const meta = (await metaRef.get()).data() || {};
    if (meta.lastSent === today) return; // already dropped today
    await metaRef.set({ lastSent: today }, { merge: true });

    const sent = await broadcast(() => ({
      title: "⚡ It's SMV o'clock",
      body: "Everyone's scanning right now. Drop a scan and see where you land today.",
      data: { type: "smv_drop", tab: "scan" },
    }));
    console.log(`[smvDrop] hour ${targetHour} sent ${sent}`);
  });

// Streak saver (8pm EST) → users with a live streak who haven't scanned today.
exports.streakReminder = functions.runWith(RUNTIME).pubsub
  .schedule("every day 20:00").timeZone(TZ)
  .onRun(async () => {
    const today = estDateStr();
    const sent = await broadcast((uid, u) => {
      const streak = u.streak || 0;
      if (streak < 2) return null;
      const last = u.lastScanAt && u.lastScanAt.toDate ? u.lastScanAt.toDate() : null;
      if (last && estDateStr(last) === today) return null; // safe already
      return {
        title: `🔥 ${streak}-day streak ending`,
        body: `Don't lose your ${streak}-day streak — scan before midnight.`,
        data: { type: "streak", tab: "scan" },
      };
    });
    console.log(`[streakReminder] sent ${sent}`);
  });

// Dormant re-engagement (5pm EST) → users last seen 5–6 days ago (fires once).
exports.dormantReengagement = functions.runWith(RUNTIME).pubsub
  .schedule("every day 17:00").timeZone(TZ)
  .onRun(async () => {
    const sent = await broadcast((uid, u) => {
      const last = u.lastScanAt && u.lastScanAt.toDate ? u.lastScanAt.toDate() : null;
      if (!last) return null;
      const days = daysSince(last);
      if (days < 5 || days > 6) return null;
      return {
        title: "Your face misses you 👀",
        body: `It's been ${days} days. See how your SMV is holding up.`,
        data: { type: "dormant", tab: "scan" },
      };
    });
    console.log(`[dormantReengagement] sent ${sent}`);
  });

// Weekly vote recap (Mondays 12pm EST) → "you were rated X times this week".
exports.weeklyVoteRecap = functions.runWith(RUNTIME).pubsub
  .schedule("every monday 12:00").timeZone(TZ)
  .onRun(async () => {
    const weekAgo = new Date(Date.now() - 7 * 86_400_000);
    const votes = await db.collection("votes")
      .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(weekAgo)).get();

    const received = {}; // uid -> {times, wins}
    votes.forEach((d) => {
      const v = d.data();
      for (const id of [v.winnerId, v.loserId]) {
        if (!id) continue;
        received[id] = received[id] || { times: 0, wins: 0 };
        received[id].times++;
      }
      if (v.winnerId) received[v.winnerId].wins++;
    });

    let sent = 0;
    await Promise.all(Object.entries(received).map(async ([uid, r]) => {
      if (r.times < 1) return;
      const ok = await sendToUser(uid, {
        title: "Your week in votes 👀",
        body: `You were rated ${r.times} ${r.times === 1 ? "time" : "times"} this week — ${r.wins} in your favor. See where you stand.`,
        data: { type: "vote_recap", tab: "leaderboard" },
        logInApp: true,
      });
      if (ok) sent++;
    }));
    console.log(`[weeklyVoteRecap] sent ${sent}`);
  });
