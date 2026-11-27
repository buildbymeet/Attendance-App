import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'capture.dart';
import 'ist.dart';
import 'models.dart';

final db = FirebaseFirestore.instance;
final auth = FirebaseAuth.instance;
FieldValue get serverNow => FieldValue.serverTimestamp();

String friendlyError(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'Wrong email or password';
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'weak-password':
        return 'Password is too weak (min 8 characters)';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'network-request-failed':
        return 'No internet connection';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'requires-recent-login':
        return 'Please log in again and retry';
    }
    return e.message ?? e.code;
  }
  if (e is FirebaseException) {
    if (e.code == 'permission-denied') {
      return 'Not allowed. This action was rejected by the server (check your device clock, account status or whether it was already done).';
    }
    if (e.code == 'unavailable') return 'No internet connection';
    return e.message ?? e.code;
  }
  final s = e.toString();
  return s.startsWith('Exception: ') ? s.substring(11) : s;
}

class Repo {
  // ---------------- Auth ----------------
  static Future<Emp> loadProfile(String uid) async {
    final d = await db.doc('users/$uid').get();
    if (!d.exists) throw 'Account profile not found. Contact your administrator.';
    return Emp(d.id, d.data()!);
  }

  static Future<void> login(String email, String password, {required bool admin}) async {
    final c = await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    try {
      final p = await loadProfile(c.user!.uid);
      if (!p.active) throw 'Your account has been deactivated. Contact your administrator.';
      if (admin && !p.isAdmin) throw 'This is not an administrator account.';
      if (!admin && p.isAdmin) throw 'Administrators must use the Admin Login page.';
    } catch (_) {
      await auth.signOut();
      rethrow;
    }
  }

  static Future<bool> usernameFree(String u) async => !(await db.doc('usernames/$u').get()).exists;

  static Future<void> signUp({
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required String password,
  }) async {
    final uname = username.trim().toLowerCase();
    final cred = await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = cred.user!;
    try {
      if (!await usernameFree(uname)) throw 'Username "$uname" is already taken';
      final b = db.batch();
      b.set(db.doc('usernames/$uname'), {'uid': user.uid});
      b.set(db.doc('users/${user.uid}'), {
        'fullName': fullName.trim(),
        'username': uname,
        'email': email.trim().toLowerCase(),
        'phone': phone,
        'role': 'employee',
        'accountStatus': 'active',
        'department': '',
        'employeeCode': '',
        'createdAt': serverNow,
      });
      await b.commit();
    } catch (e) {
      try {
        await user.delete();
      } catch (_) {
        await auth.signOut();
      }
      rethrow;
    }
  }

  static Future<void> resetPassword(String email) => auth.sendPasswordResetEmail(email: email.trim());

  static Future<void> changePassword(String current, String next) async {
    final u = auth.currentUser!;
    await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: current));
    await u.updatePassword(next);
  }

  // ---------------- Streams ----------------
  static List<T> _map<T>(QuerySnapshot<Map<String, dynamic>> s, T Function(String, Map<String, dynamic>) f) =>
      s.docs.map((d) => f(d.id, d.data())).toList();

  static Stream<AppSettings> settings() => db.doc('settings/app').snapshots().map(
      (d) => d.exists ? AppSettings.fromMap(d.data()!) : const AppSettings());
  static Stream<List<Hol>> holidays() => db.collection('holidays').snapshots().map((s) => _map(s, Hol.new));
  static Stream<List<Att>> attendanceOf(String uid) =>
      db.collection('attendance').where('userId', isEqualTo: uid).snapshots().map((s) => _map(s, Att.new));
  static Stream<List<Req>> requestsOf(String uid) =>
      db.collection('requests').where('userId', isEqualTo: uid).snapshots().map((s) => _map(s, Req.new));
  static Stream<List<Emp>> employees() =>
      db.collection('users').where('role', isEqualTo: 'employee').snapshots().map((s) => _map(s, Emp.new));
  static Stream<List<Req>> allRequests() =>
      db.collection('requests').orderBy('createdAt', descending: true).limit(500).snapshots().map((s) => _map(s, Req.new));
  static Stream<List<Att>> attendanceOn(String date) =>
      db.collection('attendance').where('date', isEqualTo: date).snapshots().map((s) => _map(s, Att.new));

  static Future<List<Att>> fetchAttendance(String from, String to) async {
    final s = await db
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: from)
        .where('date', isLessThanOrEqualTo: to)
        .get();
    return _map(s, Att.new);
  }

  static Future<Att?> attendanceFor(String uid, String date) async {
    final d = await db.doc('attendance/${uid}_$date').get();
    return d.exists ? Att(d.id, d.data()!) : null;
  }

  static Future<Uint8List?> selfie(String? id) async {
    if (id == null || id.isEmpty) return null;
    final d = await db.doc('selfies/$id').get();
    final b = d.data()?['data'];
    return b is String ? base64Decode(b) : null;
  }

  // ---------------- Punching ----------------
  static Map<String, dynamic> _loc(String p, Capture c) => {
        '${p}Lat': c.lat,
        '${p}Lng': c.lng,
        '${p}Accuracy': c.accuracy,
        '${p}Address': c.address ?? '',
        '${p}Device': c.device,
      };

  static void _putSelfie(WriteBatch b, String id, String uid, Capture c) =>
      b.set(db.doc('selfies/$id'), {'userId': uid, 'data': c.selfieBase64, 'createdAt': serverNow});

  static Future<void> checkIn(Emp me, Capture c) async {
    final id = '${me.id}_${istDateKey()}';
    if ((await db.doc('attendance/$id').get()).exists) throw 'You have already checked in today';
    final b = db.batch();
    _putSelfie(b, '${id}_in', me.id, c);
    b.set(db.doc('attendance/$id'), {
      'userId': me.id,
      'userName': me.fullName,
      'empCode': me.code,
      'date': istDateKey(),
      'attendanceType': 'selfie',
      'status': 'checked_in',
      'checkInTime': serverNow,
      'checkInSelfieId': '${id}_in',
      ..._loc('checkIn', c),
      'corrected': false,
      'createdAt': serverNow,
      'updatedAt': serverNow,
    });
    await b.commit();
  }

  static Future<void> checkOut(Emp me, Att a, Capture c) async {
    final b = db.batch();
    _putSelfie(b, '${a.id}_out', me.id, c);
    b.update(db.doc('attendance/${a.id}'), {
      'checkOutTime': serverNow,
      'checkOutSelfieId': '${a.id}_out',
      ..._loc('checkOut', c),
      'status': 'completed',
      'updatedAt': serverNow,
    });
    await b.commit();
  }

  // ---------------- Manual requests ----------------
  static Future<void> submitRequest(Emp me, Map<String, dynamic> fields) =>
      db.collection('requests').add({
        'userId': me.id,
        'userName': me.fullName,
        'status': 'pending',
        'adminComment': '',
        'used': false,
        'createdAt': serverNow,
        ...fields,
      });

  static Future<void> cancelRequest(Req r) => db.doc('requests/${r.id}').delete();

  /// Employee creates the attendance entry that an admin approved.
  static Future<void> completeManual(Emp me, Req r, Capture c, Att? existing) async {
    final id = '${me.id}_${r.date}';
    final b = db.batch();
    if (existing == null) {
      _putSelfie(b, '${id}_in', me.id, c);
      b.set(db.doc('attendance/$id'), {
        'userId': me.id,
        'userName': me.fullName,
        'empCode': me.code,
        'date': r.date,
        'attendanceType': 'manual',
        'status': r.reqOut != null ? 'completed' : 'checked_in',
        'requestId': r.id,
        'checkInTime': Timestamp.fromDate(r.reqIn!),
        'checkInSelfieId': '${id}_in',
        ..._loc('checkIn', c),
        if (r.reqOut != null) 'checkOutTime': Timestamp.fromDate(r.reqOut!),
        if (r.reqOut != null) 'checkOutSelfieId': '${id}_in',
        if (r.reqOut != null) ..._loc('checkOut', c),
        'corrected': false,
        'createdAt': serverNow,
        'updatedAt': serverNow,
      });
    } else {
      _putSelfie(b, '${id}_out', me.id, c);
      b.update(db.doc('attendance/$id'), {
        'checkOutTime': Timestamp.fromDate(r.reqOut!),
        'checkOutSelfieId': '${id}_out',
        ..._loc('checkOut', c),
        'status': 'completed',
        'requestId': r.id,
        'updatedAt': serverNow,
      });
    }
    b.update(db.doc('requests/${r.id}'), {'used': true, 'attendanceId': id});
    await b.commit();
  }

  // ---------------- Admin ----------------
  static Map<String, dynamic> _audit(Emp admin, String action, String type, String id, Object? oldV, Object? newV) => {
        'actorId': admin.id,
        'actorName': admin.fullName,
        'action': action,
        'entityType': type,
        'entityId': id,
        'oldValue': oldV,
        'newValue': newV,
        'timestamp': serverNow,
      };

  static void _log(WriteBatch b, Emp admin, String action, String type, String id, Object? o, Object? n) =>
      b.set(db.collection('auditLogs').doc(), _audit(admin, action, type, id, o, n));

  static Future<void> decideRequest(Emp admin, Req r, bool approve, String comment) async {
    final b = db.batch();
    b.update(db.doc('requests/${r.id}'), {
      'status': approve ? 'approved' : 'rejected',
      'adminComment': comment.trim(),
      'approvedBy': admin.id,
      'approvedByName': admin.fullName,
      'approvedAt': serverNow,
    });
    _log(b, admin, approve ? 'request_approved' : 'request_rejected', 'request', r.id,
        {'status': 'pending'}, {'status': approve ? 'approved' : 'rejected', 'comment': comment.trim(), 'employee': r.userName, 'date': r.date});
    await b.commit();
  }

  static Future<void> updateEmployee(Emp admin, Emp e, Map<String, dynamic> changes) async {
    final b = db.batch();
    b.update(db.doc('users/${e.id}'), changes);
    _log(b, admin, 'employee_updated', 'user', e.id,
        {for (final k in changes.keys) k: _empField(e, k)}, changes);
    await b.commit();
  }

  static Object? _empField(Emp e, String k) => {
        'fullName': e.fullName,
        'phone': e.phone,
        'department': e.department,
        'employeeCode': e.code,
        'accountStatus': e.status,
      }[k];

  static Map<String, dynamic> _attSnap(Att a) => {
        'checkIn': a.inTime?.toUtc().toIso8601String(),
        'checkOut': a.outTime?.toUtc().toIso8601String(),
        'status': a.status,
      };

  static Future<void> correctAttendance(Emp admin, Att a, DateTime newIn, DateTime? newOut, String reason) async {
    final b = db.batch();
    b.update(db.doc('attendance/${a.id}'), {
      'checkInTime': Timestamp.fromDate(newIn),
      'checkOutTime': newOut == null ? null : Timestamp.fromDate(newOut),
      'status': newOut == null ? 'checked_in' : 'completed',
      'corrected': true,
      'correctedBy': admin.id,
      'correctionReason': reason,
      'updatedAt': serverNow,
    });
    _log(b, admin, 'attendance_corrected', 'attendance', a.id, _attSnap(a), {
      'checkIn': newIn.toUtc().toIso8601String(),
      'checkOut': newOut?.toUtc().toIso8601String(),
      'reason': reason,
    });
    await b.commit();
  }

  static Future<void> adminAddAttendance(Emp admin, Emp e, String date, DateTime inT, DateTime? outT, String reason) async {
    final id = '${e.id}_$date';
    if ((await db.doc('attendance/$id').get()).exists) throw 'A record already exists for this employee and date';
    final b = db.batch();
    b.set(db.doc('attendance/$id'), {
      'userId': e.id,
      'userName': e.fullName,
      'empCode': e.code,
      'date': date,
      'attendanceType': 'admin',
      'status': outT == null ? 'checked_in' : 'completed',
      'checkInTime': Timestamp.fromDate(inT),
      if (outT != null) 'checkOutTime': Timestamp.fromDate(outT),
      'corrected': true,
      'correctedBy': admin.id,
      'correctionReason': reason,
      'createdAt': serverNow,
      'updatedAt': serverNow,
    });
    _log(b, admin, 'attendance_added', 'attendance', id, null, {
      'employee': e.fullName,
      'date': date,
      'checkIn': inT.toUtc().toIso8601String(),
      'checkOut': outT?.toUtc().toIso8601String(),
      'reason': reason,
    });
    await b.commit();
  }

  static Future<void> saveHoliday(Emp admin, String? id, Map<String, dynamic> data, {Hol? old}) async {
    final ref = id == null ? db.collection('holidays').doc() : db.doc('holidays/$id');
    final b = db.batch();
    if (id == null) {
      b.set(ref, {...data, 'createdBy': admin.id, 'createdAt': serverNow, 'updatedAt': serverNow});
    } else {
      b.update(ref, {...data, 'updatedAt': serverNow});
    }
    _log(b, admin, id == null ? 'holiday_added' : 'holiday_updated', 'holiday', ref.id,
        old == null ? null : {'name': old.name, 'date': old.date, 'category': old.category, 'paid': old.paid},
        {'name': data['name'], 'date': data['date']});
    await b.commit();
  }

  static Future<void> addHolidays(Emp admin, List<Map<String, dynamic>> items) async {
    for (var i = 0; i < items.length; i += 200) {
      final b = db.batch();
      for (final d in items.skip(i).take(200)) {
        b.set(db.collection('holidays').doc(),
            {...d, 'createdBy': admin.id, 'createdAt': serverNow, 'updatedAt': serverNow});
      }
      await b.commit();
    }
    final b = db.batch();
    _log(b, admin, 'holidays_bulk_added', 'holiday', '-', null, {'count': items.length});
    await b.commit();
  }

  static Future<void> deleteHoliday(Emp admin, Hol h) async {
    final b = db.batch();
    b.delete(db.doc('holidays/${h.id}'));
    _log(b, admin, 'holiday_deleted', 'holiday', h.id, {'name': h.name, 'date': h.date}, null);
    await b.commit();
  }

  static Future<void> saveSettings(Emp admin, AppSettings old, AppSettings s) async {
    final b = db.batch();
    b.set(db.doc('settings/app'), s.toMap());
    _log(b, admin, 'settings_updated', 'settings', 'app', old.toMap(), s.toMap());
    await b.commit();
  }

  static Future<List<Map<String, dynamic>>> auditLogs() async {
    final s = await db.collection('auditLogs').orderBy('timestamp', descending: true).limit(150).get();
    return s.docs.map((d) => d.data()).toList();
  }
}

/// Live, role-aware data cache shared by all screens.
class AppStore extends ChangeNotifier {
  Emp me;
  AppSettings settings = const AppSettings();
  List<Hol> holidays = [];
  List<Att> myAtt = [];
  List<Req> myReqs = [];
  List<Emp> employees = [];
  List<Req> allReqs = [];
  List<Att> todayAtt = [];
  bool loaded = false;
  final _subs = <StreamSubscription>[];
  final _ready = <String>{};

  AppStore(this.me) {
    _listen<AppSettings>('settings', Repo.settings(), (v) => settings = v);
    _listen<List<Hol>>('hol', Repo.holidays(), (v) => holidays = v..sort((a, b) => a.date.compareTo(b.date)));
    if (me.isAdmin) {
      _listen<List<Emp>>('emps', Repo.employees(), (v) => employees = v..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase())));
      _listen<List<Req>>('reqs', Repo.allRequests(), (v) => allReqs = v);
      _listen<List<Att>>('today', Repo.attendanceOn(istDateKey()), (v) => todayAtt = v);
    } else {
      _listen<List<Att>>('att', Repo.attendanceOf(me.id), (v) => myAtt = v..sort((a, b) => b.date.compareTo(a.date)));
      _listen<List<Req>>('myreqs', Repo.requestsOf(me.id),
          (v) => myReqs = v..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now())));
    }
  }

  int get _expected => me.isAdmin ? 5 : 4;

  void _listen<T>(String key, Stream<T> s, void Function(T) set) {
    _subs.add(s.listen((v) {
      set(v);
      _ready.add(key);
      if (_ready.length >= _expected) loaded = true;
      notifyListeners();
    }, onError: (e) {
      debugPrint('stream $key error: $e');
      _ready.add(key);
      if (_ready.length >= _expected) loaded = true;
      notifyListeners();
    }));
  }

  void updateMe(Emp e) {
    me = e;
    notifyListeners();
  }

  // ---- derived helpers ----
  Att? get today => myAtt.where((a) => a.date == istDateKey()).firstOrNull;
  List<Req> get pendingReqs => allReqs.where((r) => r.pending).toList();
  Req? get approvedUnused =>
      myReqs.where((r) => r.approved && !r.isLeave && !r.used).firstOrNull;
  List<Req> get allLeaves => me.isAdmin ? allReqs.where((r) => r.isLeave && r.approved).toList() : myReqs.where((r) => r.isLeave && r.approved).toList();
  List<Hol> holidaysFor(String uid) => holidays.where((h) => h.appliesTo(uid)).toList();
  Emp? empById(String id) => employees.where((e) => e.id == id).firstOrNull;

  DayInfo infoFor(String uid, String date, Att? att) =>
      dayInfo(date: date, uid: uid, att: att, holidays: holidays, leaves: allLeaves, s: settings);

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
