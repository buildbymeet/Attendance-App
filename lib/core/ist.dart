import 'package:intl/intl.dart';

/// All attendance times are stored as UTC instants (Firestore Timestamps) and
/// always *displayed* in Indian Standard Time (UTC+05:30), whatever the phone's
/// own time zone is set to.
const istOffset = Duration(hours: 5, minutes: 30);

DateTime toIst(DateTime t) => t.toUtc().add(istOffset);
DateTime nowIst() => toIst(DateTime.now());

final _dateKey = DateFormat('yyyy-MM-dd');
String istDateKey([DateTime? t]) => _dateKey.format(toIst(t ?? DateTime.now()));
String dateKeyOf(DateTime d) => _dateKey.format(d); // d is already a plain date
DateTime parseDateKey(String k) => DateTime.parse(k); // local-midnight, tz-agnostic use only

String fmtTime(DateTime? t) => t == null ? '--:--' : DateFormat('hh:mm a').format(toIst(t));
String fmtDate(String key) => DateFormat('EEE, dd MMM yyyy').format(parseDateKey(key));
String fmtDateShort(String key) => DateFormat('dd MMM').format(parseDateKey(key));
String fmtDateTime(DateTime? t) => t == null ? '-' : DateFormat('dd MMM yyyy, hh:mm a').format(toIst(t));
String fmtMonth(DateTime d) => DateFormat('MMMM yyyy').format(d);

String fmtDuration(Duration? d) {
  if (d == null) return '--';
  final m = d.inMinutes;
  return '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
}

String fmtHours(Duration? d) => d == null ? '' : (d.inMinutes / 60).toStringAsFixed(2);

/// Builds a UTC instant from an IST date key + wall-clock time of day.
DateTime istInstant(String dateKey, int hour, int minute) {
  final d = parseDateKey(dateKey);
  return DateTime.utc(d.year, d.month, d.day, hour, minute).subtract(istOffset);
}

int minutesOfDayIst(DateTime t) {
  final i = toIst(t);
  return i.hour * 60 + i.minute;
}

/// Inclusive list of date keys between two keys.
List<String> daysBetween(String from, String to) {
  var d = parseDateKey(from);
  final end = parseDateKey(to);
  final out = <String>[];
  while (!d.isAfter(end)) {
    out.add(dateKeyOf(d));
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return out;
}

final phoneRe = RegExp(r'^[6-9][0-9]{9}$');

/// Accepts +91 / 91 / 0 prefixes and spaces/dashes; returns 10 digits or null.
String? normalizeIndianPhone(String raw) {
  var s = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  if (s.startsWith('+91')) {
    s = s.substring(3);
  } else if (s.startsWith('91') && s.length == 12) {
    s = s.substring(2);
  } else if (s.startsWith('0') && s.length == 11) {
    s = s.substring(1);
  }
  return phoneRe.hasMatch(s) ? s : null;
}
