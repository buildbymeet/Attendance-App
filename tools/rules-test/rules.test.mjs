import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, writeBatch, serverTimestamp, Timestamp, collection, addDoc, getDocs, query, where, deleteDoc } from 'firebase/firestore';
import fs from 'fs';

const env = await initializeTestEnvironment({ projectId: 'demo-att', firestore: { rules: fs.readFileSync(new URL('../../firestore.rules', import.meta.url).pathname + '', 'utf8'), host: '127.0.0.1', port: 8080 } });
const ist = new Date(Date.now() + 330 * 60000);
const key = (d) => d.toISOString().slice(0, 10);
const today = key(ist);
const yest = key(new Date(ist.getTime() - 86400000));
let pass = 0, fail = 0;
const t = async (name, p) => { try { await p; pass++; console.log('ok   ', name); } catch (e) { fail++; console.log('FAIL ', name, String(e.message).slice(0, 200)); } };

await env.withSecurityRulesDisabled(async (c) => {
  const d = c.firestore();
  await setDoc(doc(d, 'users/A'), { role: 'admin', accountStatus: 'active', fullName: 'Admin', phone: '9999999999' });
  await setDoc(doc(d, 'users/U1'), { role: 'employee', accountStatus: 'active', fullName: 'One', phone: '9876543210', username: 'one', email: 'one@x.com' });
  await setDoc(doc(d, 'users/U2'), { role: 'employee', accountStatus: 'active', fullName: 'Two', phone: '9876543211', username: 'two', email: 'two@x.com' });
  await setDoc(doc(d, 'users/U3'), { role: 'employee', accountStatus: 'inactive', fullName: 'Three', phone: '9876543212', username: 'three', email: 'three@x.com' });
  await setDoc(doc(d, 'usernames/one'), { uid: 'U1' });
});
const A = env.authenticatedContext('A', { email: 'a@x.com' }).firestore();
const U1 = env.authenticatedContext('U1', { email: 'one@x.com' }).firestore();
const U2 = env.authenticatedContext('U2', { email: 'two@x.com' }).firestore();
const U3 = env.authenticatedContext('U3', { email: 'three@x.com' }).firestore();
const N = env.authenticatedContext('N1', { email: 'New@x.com' }).firestore();
const anon = env.unauthenticatedContext().firestore();
const img = 'x'.repeat(2000);

// ---- signup
const prof = (o = {}) => ({ fullName: 'New Person', username: 'newp', email: 'new@x.com', phone: '9123456789', role: 'employee', accountStatus: 'active', department: '', employeeCode: '', createdAt: serverTimestamp(), ...o });
const signup = async (db, uid, p) => { const b = writeBatch(db); b.set(doc(db, 'usernames/' + p.username), { uid }); b.set(doc(db, 'users/' + uid), p); return b.commit(); };
await t('signup as employee ok', assertSucceeds(signup(N, 'N1', prof())));
await t('signup as admin denied', assertFails(signup(env.authenticatedContext('N2', { email: 'new@x.com' }).firestore(), 'N2', prof({ role: 'admin', username: 'sneaky' }))));
await t('signup duplicate username denied', assertFails(signup(env.authenticatedContext('N3', { email: 'new@x.com' }).firestore(), 'N3', prof({ username: 'one' }))));
await t('signup bad phone denied', assertFails(signup(env.authenticatedContext('N4', { email: 'new@x.com' }).firestore(), 'N4', prof({ username: 'badphone', phone: '1234567890' }))));
await t('employee cannot change own role', assertFails(updateDoc(doc(U1, 'users/U1'), { role: 'admin' })));
await t('employee can edit own name', assertSucceeds(updateDoc(doc(U1, 'users/U1'), { fullName: 'One Two' })));
await t('employee cannot read other profile', assertFails(getDoc(doc(U1, 'users/U2'))));
await t('admin reads employees', assertSucceeds(getDocs(query(collection(A, 'users'), where('role', '==', 'employee')))));
await t('admin deactivates employee', assertSucceeds(updateDoc(doc(A, 'users/U2'), { accountStatus: 'inactive' })));
await t('admin cannot promote', assertFails(updateDoc(doc(A, 'users/U1'), { role: 'admin' })));
await env.withSecurityRulesDisabled(async (c) => updateDoc(doc(c.firestore(), 'users/U2'), { accountStatus: 'active' }));

// ---- check in
const ci = async (db, uid, id, over = {}) => {
  const b = writeBatch(db);
  b.set(doc(db, 'selfies/' + id + '_in'), { userId: uid, data: img, createdAt: serverTimestamp() });
  b.set(doc(db, 'attendance/' + id), { userId: uid, userName: 'x', empCode: 'E', date: today, attendanceType: 'selfie', status: 'checked_in', checkInTime: serverTimestamp(), checkInSelfieId: id + '_in', checkInLat: 12.9, checkInLng: 77.5, checkInAccuracy: 5, checkInAddress: '', checkInDevice: 'android', corrected: false, createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...over });
  return b.commit();
};
await t('checkin for another day id denied', assertFails(ci(U1, 'U1', 'U1_' + yest, { date: yest })));
await t('checkin with client time denied', assertFails(ci(U2, 'U2', 'U2_' + today, { checkInTime: Timestamp.fromDate(new Date(Date.now() - 3600000)) })));
await t('checkin for someone else denied', assertFails(ci(U1, 'U2', 'U2_' + today)));
await t('inactive user checkin denied', assertFails(ci(U3, 'U3', 'U3_' + today)));
await t('checkin ok', assertSucceeds(ci(U1, 'U1', 'U1_' + today)));
await t('duplicate checkin denied', assertFails(ci(U1, 'U1', 'U1_' + today)));
await t('own attendance readable', assertSucceeds(getDoc(doc(U1, 'attendance/U1_' + today))));
await t('other user cannot read', assertFails(getDoc(doc(U2, 'attendance/U1_' + today))));
await t('nonexistent own doc readable (for existence check)', assertSucceeds(getDoc(doc(U2, 'attendance/U2_' + today))));
await t('own selfie readable', assertSucceeds(getDoc(doc(U1, 'selfies/U1_' + today + '_in'))));
await t('other selfie denied', assertFails(getDoc(doc(U2, 'selfies/U1_' + today + '_in'))));
await t('list own attendance', assertSucceeds(getDocs(query(collection(U1, 'attendance'), where('userId', '==', 'U1')))));
await t('list all attendance denied', assertFails(getDocs(collection(U1, 'attendance'))));

// ---- check out
const co = async (db, uid, id, over = {}) => {
  const b = writeBatch(db);
  b.set(doc(db, 'selfies/' + id + '_out'), { userId: uid, data: img, createdAt: serverTimestamp() });
  b.update(doc(db, 'attendance/' + id), { checkOutTime: serverTimestamp(), checkOutSelfieId: id + '_out', checkOutLat: 12.9, checkOutLng: 77.5, checkOutAccuracy: 4, checkOutAddress: '', checkOutDevice: 'a', status: 'completed', updatedAt: serverTimestamp(), ...over });
  return b.commit();
};
await t('checkout tampering other field denied', assertFails(co(U1, 'U1', 'U1_' + today, { checkInTime: Timestamp.fromDate(new Date(Date.now() - 36000000)) })));
await t('checkout with client time denied', assertFails(co(U1, 'U1', 'U1_' + today, { checkOutTime: Timestamp.fromDate(new Date()) })));
await t('checkout ok', assertSucceeds(co(U1, 'U1', 'U1_' + today)));
await t('second checkout denied', assertFails(co(U1, 'U1', 'U1_' + today)));
await t('employee cannot edit times', assertFails(updateDoc(doc(U1, 'attendance/U1_' + today), { checkInTime: Timestamp.fromDate(new Date(0)) })));
await t('employee cannot delete attendance', assertFails(deleteDoc(doc(U1, 'attendance/U1_' + today))));

// ---- manual request
const rq = (db, uid, over = {}) => addDoc(collection(db, 'requests'), { userId: uid, userName: 'x', type: 'manual', date: yest, endDate: yest, requestedCheckIn: Timestamp.fromDate(new Date(Date.now() - 30 * 3600000)), requestedCheckOut: Timestamp.fromDate(new Date(Date.now() - 22 * 3600000)), reason: 'forgot to punch', notes: '', status: 'pending', adminComment: '', used: false, createdAt: serverTimestamp(), ...over });
await t('request ok', assertSucceeds(rq(U2, 'U2')));
await t('request pre-approved denied', assertFails(rq(U2, 'U2', { status: 'approved' })));
await t('request future date denied', assertFails(rq(U2, 'U2', { date: key(new Date(ist.getTime() + 5 * 86400000)), endDate: key(new Date(ist.getTime() + 5 * 86400000)) })));
await t('leave future ok', assertSucceeds(addDoc(collection(U2, 'requests'), { userId: 'U2', userName: 'x', type: 'leave', date: key(new Date(ist.getTime() + 5 * 86400000)), endDate: key(new Date(ist.getTime() + 6 * 86400000)), reason: 'family event', notes: '', status: 'pending', adminComment: '', used: false, createdAt: serverTimestamp() })));
const rid = (await rq(U2, 'U2')).id;
await t('employee self-approve denied', assertFails(updateDoc(doc(U2, 'requests/' + rid), { status: 'approved', approvedBy: 'U2', approvedAt: serverTimestamp(), adminComment: '', approvedByName: 'x' })));
await t('other employee cannot read request', assertFails(getDoc(doc(U1, 'requests/' + rid))));
// complete before approval
const manual = async (db, uid, rid, date, withOut = true) => {
  const id = uid + '_' + date;
  const b = writeBatch(db);
  b.set(doc(db, 'selfies/' + id + '_in'), { userId: uid, data: img, createdAt: serverTimestamp() });
  const r = (await getDoc(doc(db, 'requests/' + rid))).data();
  b.set(doc(db, 'attendance/' + id), { userId: uid, userName: 'x', empCode: 'E', date, attendanceType: 'manual', status: 'completed', requestId: rid, checkInTime: r.requestedCheckIn, checkInSelfieId: id + '_in', checkInLat: 1, checkInLng: 2, checkInAccuracy: 3, checkInAddress: '', checkInDevice: 'a', ...(withOut ? { checkOutTime: r.requestedCheckOut } : {}), corrected: false, createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
  b.update(doc(db, 'requests/' + rid), { used: true, attendanceId: id });
  return b.commit();
};
await t('manual before approval denied', assertFails(manual(U2, 'U2', rid, yest)));
await t('admin approve ok', (async () => {
  const b = writeBatch(A);
  b.update(doc(A, 'requests/' + rid), { status: 'approved', adminComment: 'ok', approvedBy: 'A', approvedByName: 'Admin', approvedAt: serverTimestamp() });
  b.set(doc(collection(A, 'auditLogs')), { actorId: 'A', actorName: 'Admin', action: 'request_approved', entityType: 'request', entityId: rid, oldValue: null, newValue: null, timestamp: serverTimestamp() });
  await assertSucceeds(b.commit());
})());
await t('admin re-decide denied', assertFails(updateDoc(doc(A, 'requests/' + rid), { status: 'rejected', adminComment: 'x', approvedBy: 'A', approvedByName: 'Admin', approvedAt: serverTimestamp() })));
await t('other user cannot use approved request', assertFails(manual(U1, 'U1', rid, yest)));
await t('manual attendance after approval ok', assertSucceeds(manual(U2, 'U2', rid, yest)));
await t('manual request reuse denied', assertFails(updateDoc(doc(U2, 'requests/' + rid), { used: true, attendanceId: 'U2_' + yest })));
await t('audit log tamper denied', assertFails(updateDoc(doc(A, 'auditLogs/x'), { action: 'y' })));
await t('employee cannot write audit', assertFails(addDoc(collection(U1, 'auditLogs'), { actorId: 'U1', timestamp: serverTimestamp() })));
await t('admin corrects attendance', assertSucceeds(updateDoc(doc(A, 'attendance/U1_' + today), { checkInTime: Timestamp.fromDate(new Date()), corrected: true })));
await t('admin query by date range', assertSucceeds(getDocs(query(collection(A, 'attendance'), where('date', '>=', yest), where('date', '<=', today)))));
await t('employee cannot write holiday', assertFails(addDoc(collection(U1, 'holidays'), { name: 'x', date: today })));
await t('admin writes holiday', assertSucceeds(addDoc(collection(A, 'holidays'), { name: 'x', date: today })));
await t('employee reads holidays', assertSucceeds(getDocs(collection(U1, 'holidays'))));
await t('anon denied', assertFails(getDocs(collection(anon, 'holidays'))));
await t('employee cancels pending request', assertSucceeds((async () => { const r = await rq(U1, 'U1'); await deleteDoc(doc(U1, 'requests/' + r.id)); })()));

console.log(`\n${pass} passed, ${fail} failed`);
await env.cleanup();
process.exit(fail ? 1 : 0);
