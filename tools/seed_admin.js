#!/usr/bin/env node
/**
 * Creates (or repairs) the single fixed Admin account and default settings.
 * Credentials come from environment variables – they are never stored in the app.
 *
 *   cd tools && npm install
 *   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json   # Firebase console > Project settings > Service accounts
 *   export ADMIN_EMAIL=admin@yourcompany.com
 *   export ADMIN_PASSWORD='a-strong-password'
 *   export ADMIN_NAME='Administrator'            # optional
 *   node seed_admin.js
 */
const admin = require('firebase-admin');

const email = (process.env.ADMIN_EMAIL || '').trim().toLowerCase();
const password = process.env.ADMIN_PASSWORD || '';
const name = process.env.ADMIN_NAME || 'Administrator';
if (!email || password.length < 8) {
  console.error('Set ADMIN_EMAIL and ADMIN_PASSWORD (min 8 chars).');
  process.exit(1);
}

admin.initializeApp();
(async () => {
  let user;
  try {
    user = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(user.uid, { password, disabled: false });
    console.log('Updated existing auth user', user.uid);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    user = await admin.auth().createUser({ email, password, displayName: name, emailVerified: true });
    console.log('Created auth user', user.uid);
  }
  const db = admin.firestore();
  await db.doc(`users/${user.uid}`).set(
    {
      fullName: name,
      username: 'admin',
      email,
      phone: '',
      role: 'admin',
      accountStatus: 'active',
      department: '',
      employeeCode: 'ADMIN',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  const s = db.doc('settings/app');
  if (!(await s.get()).exists) {
    await s.set({ shiftStart: '09:30', graceMinutes: 15, fullDayHours: 8, halfDayHours: 4, weeklyOffs: [7], company: 'My Company' });
  }
  console.log('Admin ready:', email);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
