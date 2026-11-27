import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/ist.dart';
import 'package:attendance_app/core/models.dart';

void main() {
  test('IST conversion is independent of device zone', () {
    final utc = DateTime.utc(2026, 1, 1, 18, 30); // 00:00 IST next day
    expect(istDateKey(utc), '2026-01-02');
    expect(minutesOfDayIst(utc), 0);
    expect(istInstant('2026-01-02', 0, 0), utc);
  });

  test('Indian phone validation', () {
    expect(normalizeIndianPhone('+91 98765-43210'), '9876543210');
    expect(normalizeIndianPhone('09876543210'), '9876543210');
    expect(normalizeIndianPhone('5876543210'), isNull);
    expect(normalizeIndianPhone('98765'), isNull);
  });

  test('late detection uses shift + grace', () {
    const s = AppSettings(shiftStart: '09:30', graceMinutes: 15);
    expect(s.isLate(istInstant('2026-03-02', 9, 45)), isFalse);
    expect(s.isLate(istInstant('2026-03-02', 9, 46)), isTrue);
  });

  test('holidays, weekly offs and leave are never absent', () {
    const s = AppSettings(weeklyOffs: [7]);
    final hol = Hol('h', {'name': 'Holi', 'date': '2020-03-10', 'category': 'Festival'});
    expect(dayInfo(date: '2020-03-10', uid: 'u', att: null, holidays: [hol], leaves: [], s: s).kind, DayKind.holiday);
    expect(dayInfo(date: '2020-03-08', uid: 'u', att: null, holidays: [], leaves: [], s: s).kind, DayKind.weeklyOff); // Sunday
    expect(dayInfo(date: '2020-03-09', uid: 'u', att: null, holidays: [], leaves: [], s: s).kind, DayKind.absent);
    final leave = Req('r', {'userId': 'u', 'type': 'leave', 'status': 'approved', 'date': '2020-03-09', 'endDate': '2020-03-09'});
    expect(dayInfo(date: '2020-03-09', uid: 'u', att: null, holidays: [], leaves: [leave], s: s).kind, DayKind.leave);
    // holiday assigned to someone else does not apply
    final other = Hol('h2', {'name': 'X', 'date': '2020-03-09', 'category': 'Regional', 'assignedTo': ['zzz']});
    expect(dayInfo(date: '2020-03-09', uid: 'u', att: null, holidays: [other], leaves: [], s: s).kind, DayKind.absent);
  });

  test('daysBetween is inclusive', () {
    expect(daysBetween('2026-02-27', '2026-03-02'), ['2026-02-27', '2026-02-28', '2026-03-01', '2026-03-02']);
  });
}
