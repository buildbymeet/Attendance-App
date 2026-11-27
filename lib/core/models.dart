import 'package:cloud_firestore/cloud_firestore.dart';
import 'ist.dart';

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;
double? _d(dynamic v) => v is num ? v.toDouble() : null;

class Emp {
  final String id, fullName, username, email, phone, role, status, department, code;
  final DateTime? createdAt;
  Emp(this.id, Map<String, dynamic> m)
      : fullName = m['fullName'] ?? '',
        username = m['username'] ?? '',
        email = m['email'] ?? '',
        phone = m['phone'] ?? '',
        role = m['role'] ?? 'employee',
        status = m['accountStatus'] ?? 'active',
        department = m['department'] ?? '',
        code = (m['employeeCode'] ?? '').toString().isNotEmpty
            ? m['employeeCode']
            : id.substring(0, id.length < 6 ? id.length : 6).toUpperCase(),
        createdAt = _ts(m['createdAt']);
  bool get isAdmin => role == 'admin';
  bool get active => status == 'active';
  String get phonePretty => phone.length == 10 ? '+91 ${phone.substring(0, 5)} ${phone.substring(5)}' : phone;
}

class Att {
  final String id, userId, userName, empCode, date, type, status;
  final DateTime? inTime, outTime;
  final double? inLat, inLng, inAcc, outLat, outLng, outAcc;
  final String? inAddr, outAddr, inSelfie, outSelfie, requestId, inDevice, outDevice;
  final bool corrected;
  Att(this.id, Map<String, dynamic> m)
      : userId = m['userId'] ?? '',
        userName = m['userName'] ?? '',
        empCode = m['empCode'] ?? '',
        date = m['date'] ?? '',
        type = m['attendanceType'] ?? 'selfie',
        status = m['status'] ?? 'checked_in',
        inTime = _ts(m['checkInTime']),
        outTime = _ts(m['checkOutTime']),
        inLat = _d(m['checkInLat']),
        inLng = _d(m['checkInLng']),
        inAcc = _d(m['checkInAccuracy']),
        outLat = _d(m['checkOutLat']),
        outLng = _d(m['checkOutLng']),
        outAcc = _d(m['checkOutAccuracy']),
        inAddr = m['checkInAddress'],
        outAddr = m['checkOutAddress'],
        inSelfie = m['checkInSelfieId'],
        outSelfie = m['checkOutSelfieId'],
        requestId = m['requestId'],
        inDevice = m['checkInDevice'],
        outDevice = m['checkOutDevice'],
        corrected = m['corrected'] == true;
  Duration? get worked => (inTime != null && outTime != null) ? outTime!.difference(inTime!) : null;
  bool get isManual => type == 'manual';
  String get typeLabel => isManual ? 'Manual Attendance – Admin Approved' : 'Selfie Attendance';
}

class Req {
  final String id, userId, userName, type, date, endDate, reason, notes, status, adminComment, approvedByName;
  final DateTime? reqIn, reqOut, approvedAt, createdAt;
  final bool used;
  final String? attendanceId;
  Req(this.id, Map<String, dynamic> m)
      : userId = m['userId'] ?? '',
        userName = m['userName'] ?? '',
        type = m['type'] ?? 'manual',
        date = m['date'] ?? '',
        endDate = m['endDate'] ?? (m['date'] ?? ''),
        reason = m['reason'] ?? '',
        notes = m['notes'] ?? '',
        status = m['status'] ?? 'pending',
        adminComment = m['adminComment'] ?? '',
        approvedByName = m['approvedByName'] ?? '',
        reqIn = _ts(m['requestedCheckIn']),
        reqOut = _ts(m['requestedCheckOut']),
        approvedAt = _ts(m['approvedAt']),
        createdAt = _ts(m['createdAt']),
        used = m['used'] == true,
        attendanceId = m['attendanceId'];
  bool get pending => status == 'pending';
  bool get approved => status == 'approved';
  bool get rejected => status == 'rejected';
  bool get isLeave => type == 'leave';
  bool covers(String d) => isLeave && approved && d.compareTo(date) >= 0 && d.compareTo(endDate) <= 0;
}

class Hol {
  final String id, name, date, category, description, region, createdBy;
  final bool paid;
  final List<String> assigned; // empty = all employees
  Hol(this.id, Map<String, dynamic> m)
      : name = m['name'] ?? '',
        date = m['date'] ?? '',
        category = m['category'] ?? 'Festival',
        description = m['description'] ?? '',
        region = m['region'] ?? 'All India',
        createdBy = m['createdBy'] ?? '',
        paid = m['paid'] != false,
        assigned = List<String>.from(m['assignedTo'] ?? const []);
  bool appliesTo(String uid) => assigned.isEmpty || assigned.contains(uid);
}

class AppSettings {
  final String shiftStart; // HH:mm in IST
  final int graceMinutes;
  final double fullDayHours, halfDayHours;
  final List<int> weeklyOffs; // DateTime.weekday numbers, 7 = Sunday
  final String company;
  const AppSettings({
    this.shiftStart = '09:30',
    this.graceMinutes = 15,
    this.fullDayHours = 8,
    this.halfDayHours = 4,
    this.weeklyOffs = const [7],
    this.company = 'My Company',
  });
  AppSettings.fromMap(Map<String, dynamic> m)
      : shiftStart = m['shiftStart'] ?? '09:30',
        graceMinutes = (m['graceMinutes'] ?? 15).toInt(),
        fullDayHours = (m['fullDayHours'] ?? 8).toDouble(),
        halfDayHours = (m['halfDayHours'] ?? 4).toDouble(),
        weeklyOffs = List<int>.from((m['weeklyOffs'] ?? const [7]).map((e) => (e as num).toInt())),
        company = m['company'] ?? 'My Company';
  Map<String, dynamic> toMap() => {
        'shiftStart': shiftStart,
        'graceMinutes': graceMinutes,
        'fullDayHours': fullDayHours,
        'halfDayHours': halfDayHours,
        'weeklyOffs': weeklyOffs,
        'company': company,
      };
  int get shiftMinutes {
    final p = shiftStart.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  bool isLate(DateTime? inTime) => inTime != null && minutesOfDayIst(inTime) > shiftMinutes + graceMinutes;
  bool isWeeklyOff(String dateKey) => weeklyOffs.contains(parseDateKey(dateKey).weekday);
}

enum DayKind { present, halfDay, absent, holiday, weeklyOff, leave, missingPunch, working, notYet, upcoming }

class DayInfo {
  final DayKind kind;
  final bool late;
  final Hol? holiday;
  final Att? att;
  const DayInfo(this.kind, {this.late = false, this.holiday, this.att});

  String get label {
    switch (kind) {
      case DayKind.present:
        return late ? 'Late' : 'Present';
      case DayKind.halfDay:
        return 'Half Day';
      case DayKind.absent:
        return 'Absent';
      case DayKind.holiday:
        return 'Holiday';
      case DayKind.weeklyOff:
        return 'Weekly Off';
      case DayKind.leave:
        return 'On Leave';
      case DayKind.missingPunch:
        return 'Missing Punch';
      case DayKind.working:
        return 'Working';
      case DayKind.notYet:
        return 'Not Checked In';
      case DayKind.upcoming:
        return 'Upcoming';
    }
  }

  bool get counted => att != null && att!.inTime != null;
}

/// Single source of truth for what a calendar day means for one employee.
/// Late / half-day / missing-punch are *derived* from the server timestamps and
/// admin settings, never trusted from a client-written flag.
DayInfo dayInfo({
  required String date,
  required String uid,
  required Att? att,
  required List<Hol> holidays,
  required List<Req> leaves,
  required AppSettings s,
}) {
  final today = istDateKey();
  Hol? hol;
  for (final h in holidays) {
    if (h.date == date && h.appliesTo(uid)) {
      hol = h;
      break;
    }
  }
  if (att != null && att.inTime != null) {
    final late = s.isLate(att.inTime);
    if (att.outTime == null) {
      return DayInfo(date == today ? DayKind.working : DayKind.missingPunch, late: late, holiday: hol, att: att);
    }
    final hrs = att.worked!.inMinutes / 60;
    if (hrs < s.halfDayHours) return DayInfo(DayKind.halfDay, late: late, holiday: hol, att: att);
    return DayInfo(DayKind.present, late: late, holiday: hol, att: att);
  }
  if (hol != null) return DayInfo(DayKind.holiday, holiday: hol);
  if (leaves.any((r) => r.userId == uid && r.covers(date))) return const DayInfo(DayKind.leave);
  if (s.isWeeklyOff(date)) return const DayInfo(DayKind.weeklyOff);
  final c = date.compareTo(today);
  if (c > 0) return const DayInfo(DayKind.upcoming);
  if (c == 0) return const DayInfo(DayKind.notYet);
  return const DayInfo(DayKind.absent);
}
