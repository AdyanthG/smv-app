"use strict";

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// Push-notification functions (social triggers + scheduled engagement/FOMO).
Object.assign(exports, require("./notifications"));

/**
 * Full account-deletion cleanup.
 *
 * Fires when a user is removed from Firebase Auth (the app calls
 * `currentUser.delete()`). Runs with admin privileges, so it can remove data
 * the client can't reach: reciprocal follow edges, comments the user left on
 * other people's posts, and all Storage files.
 *
 * Ordering matters: reciprocal follow cleanup reads the user's
 * following/followers subcollections, so it must run BEFORE the user document
 * is recursively deleted.
 */
exports.cleanupDeletedUser = functions
  .runWith({ timeoutSeconds: 300, memory: "512MB" })
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;
    const userRef = db.collection("users").doc(uid);
    console.log(`[cleanupDeletedUser] starting cleanup for ${uid}`);

    // 1) Reciprocal follow cleanup — decrement counts and remove the mirror docs
    //    on the other side of every follow edge. Read BEFORE deleting the user.
    try {
      const following = await userRef.collection("following").get();
      await Promise.all(
        following.docs.map(async (d) => {
          const target = db.collection("users").doc(d.id);
          await target.collection("followers").doc(uid).delete().catch(() => {});
          await target.update({ followerCount: FieldValue.increment(-1) }).catch(() => {});
        })
      );

      const followers = await userRef.collection("followers").get();
      await Promise.all(
        followers.docs.map(async (d) => {
          const follower = db.collection("users").doc(d.id);
          await follower.collection("following").doc(uid).delete().catch(() => {});
          await follower.update({ followingCount: FieldValue.increment(-1) }).catch(() => {});
        })
      );
    } catch (e) {
      console.error("[cleanupDeletedUser] follow cleanup failed", e);
    }

    // 2) Delete the user's scans.
    try {
      await deleteQuery(db.collection("scans").where("userId", "==", uid));
    } catch (e) {
      console.error("[cleanupDeletedUser] scan cleanup failed", e);
    }

    // 3) Delete the user's posts (recursive removes their likes/comments).
    try {
      const posts = await db.collection("posts").where("authorId", "==", uid).get();
      await Promise.all(posts.docs.map((d) => db.recursiveDelete(d.ref)));
    } catch (e) {
      console.error("[cleanupDeletedUser] post cleanup failed", e);
    }

    // 4) Delete comments the user wrote on OTHER people's posts, decrementing
    //    each parent post's commentCount.
    try {
      const comments = await db
        .collectionGroup("comments")
        .where("authorId", "==", uid)
        .get();
      await Promise.all(
        comments.docs.map(async (d) => {
          const postRef = d.ref.parent.parent;
          await d.ref.delete().catch(() => {});
          if (postRef) {
            await postRef.update({ commentCount: FieldValue.increment(-1) }).catch(() => {});
          }
        })
      );
    } catch (e) {
      console.error("[cleanupDeletedUser] comment cleanup failed", e);
    }

    // 5) Delete the user document and every remaining subcollection
    //    (saved, blocked, following, followers, …).
    try {
      await db.recursiveDelete(userRef);
    } catch (e) {
      console.error("[cleanupDeletedUser] user doc cleanup failed", e);
    }

    // 6) Delete Storage files: all scan images and the profile photo.
    try {
      const bucket = admin.storage().bucket();
      await bucket.deleteFiles({ prefix: `scans/${uid}/` });
      await bucket.deleteFiles({ prefix: `profiles/${uid}/` });
    } catch (e) {
      console.error("[cleanupDeletedUser] storage cleanup failed", e);
    }

    console.log(`[cleanupDeletedUser] finished cleanup for ${uid}`);
  });

/**
 * Delete every document matched by a query, in batches (Firestore caps batches
 * at 500 writes).
 */
async function deleteQuery(query) {
  const snap = await query.get();
  const batchSize = 400;
  for (let i = 0; i < snap.docs.length; i += batchSize) {
    const batch = db.batch();
    snap.docs.slice(i, i + batchSize).forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}
