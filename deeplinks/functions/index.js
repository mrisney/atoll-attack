// functions/index.js
const functions = require('firebase-functions');
const admin     = require('firebase-admin');

admin.initializeApp();

exports.inviteRedirect = functions.https.onRequest(async (req, res) => {
  try {
    // Extract code from path: e.g. /i/ISLAND-X7B2
    const segments = req.path.split('/');
    const code = segments[segments.length - 1];

    // Fetch invite doc from Firestore
    const snap = await admin.firestore().collection('invites').doc(code).get();
    if (!snap.exists) {
      return res.status(404).send('Invite not found or expired');
    }

    const data = snap.data();
    // Assuming expiresAt is a Firestore Timestamp
    if (data.expiresAt.toMillis() < Date.now()) {
      return res.status(410).send('Invite has expired');
    }

    // Deep-link into your app
    const appLink = `https://links.atoll-attack.com/join?code=${encodeURIComponent(code)}`;

    // Fallback to store if app not installed
    const ua = req.get('User-Agent') || '';
    const storeLink = /iPhone|iPad|iPod/.test(ua)
      ? 'https://apps.apple.com/app/id123456789'
      : 'https://play.google.com/store/apps/details?id=com.risney.atollattack';

    // Redirect
    res.format({
      'application/json': () => res.redirect(302, appLink),
      'text/html': () => {
        res.send(`
          <html>
            <head>
              <meta http-equiv="refresh" content="0; url=${appLink}" />
            </head>
            <body>
              <p>Opening app… if nothing happens, <a href="${storeLink}">get the app</a>.</p>
            </body>
          </html>
        `);
      },
      'default': () => res.redirect(302, appLink)
    });

  } catch (err) {
    console.error('Error in inviteRedirect:', err);
    res.status(500).send('Server error');
  }
});
