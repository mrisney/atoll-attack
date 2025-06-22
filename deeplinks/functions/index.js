// functions/index.js
// Combined Cloud Functions for Atoll Attack game session management

const functions = require('firebase-functions');
const admin     = require('firebase-admin');
const { onSchedule } = require('firebase-functions/v2/scheduler');

admin.initializeApp();
const db = admin.firestore();

// 1️⃣ Redirect invite endpoint
//    - Validates game code and expiration
//    - Redirects to deep link URI
exports.inviteRedirect = functions.https.onRequest(async (req, res) => {
  try {
    const segments = req.path.split('/');
    const code = segments[segments.length - 1];

    const snap = await db.collection('games').doc(code).get();
    if (!snap.exists) {
      return res.status(404).send('Invalid invite code');
    }

    const data = snap.data();
    if (data.expiresAt.toDate() < new Date()) {
      return res.status(410).send('Invite has expired');
    }

    return res.redirect(302, `atollattack://join?code=${encodeURIComponent(code)}`);
  } catch (err) {
    console.error('Error in inviteRedirect:', err);
    return res.status(500).send('Server error');
  }
});

// 2️⃣ Callable: createRoom
//    - Generates a unique game code
//    - Initializes Firestore document under games/{code}
exports.createRoom = functions.https.onCall(async (data, ctx) => {
  const playerId = ctx.auth?.uid;
  if (!playerId) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be signed in');
  }

  const code = `ISL-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
  const gameRef = db.collection('games').doc(code);

  await gameRef.set({
    state:     'waiting',
    players:   [playerId],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    ),
    settings:  data.settings || {}
  });

  return { code };
});

// 3️⃣ Scheduled expiration of stale rooms
//    - Runs daily to mark 'waiting' rooms older than 7 days as 'expired'
exports.expireOldRooms = onSchedule('every 24 hours', async (event) => {
  const cutoff = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
  );

  const staleSnap = await db
    .collection('games')
    .where('state', '==', 'waiting')
    .where('createdAt', '<', cutoff)
    .get();

  const batch = db.batch();
  staleSnap.docs.forEach(doc => batch.update(doc.ref, { state: 'expired' }));
  return batch.commit();
});
