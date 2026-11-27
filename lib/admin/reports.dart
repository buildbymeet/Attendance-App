import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/export.dart';
import '../core/ist.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/ui.dart';

class DayRow {
  final Emp e;
  final String date;
  final DayInfo info;
  DayRow(this.e, this.date, this.info);
  Att? get att => info.att;
}

/// Every employee x day in range, classified by the shared [dayInfo] rules.
List<DayRow> buildRows(AppStore s, List<Att> atts, String from, String to, {String? empId}) {
  final by = {for (final a in atts) a.id: a};
  final days = daysBetween(from, to);
  final emps = s.employees.where((e) => empId == null || e.id == empId).toList();
  final rows = <DayRow>[];
  for (final d in days) {
    for (final e in emps) {
      // Do not show days before the account existed.
      final created = e.createdAt == null ? null : istDateKey(e.createdAt);
      if (created != null && d.compareTo(created) < 0 && by['${e.id}_$d'] == null) continue;
      rows.add(DayRow(e, d, s.infoFor(e.id, d, by['${e.id}_$d'])));
    }
  }
  return rows;
}

const reportTypes = {
  'daily': 'Daily attendance',
  'monthly': 'Monthly attendance (summary)',
  'employee': 'Employee-wise',
  'late': 'Late arrivals',
  'missing': 'Missing punches',
  'manual': 'Manual attendance requests',
  'holiday': 'Holiday attendance',
  'hours': 'Working hours',
};

ReportTable buildReport(String type, AppStore s, List<Att> atts, String from, String to, String? empId) {
  final rows = buildRows(s, atts, from, to, empId: empId);
  final range = from == to ? fmtDate(from) : '${fmtDateShort(from)} – ${fmtDateShort(to)}';
  String title(String t) => '$t ($range)';
  List<String> base(DayRow r) => [
        r.date,
        r.e.code,
        r.e.fullName,
        fmtTime(r.att?.inTime),
        fmtTime(r.att?.outTime),
        fmtHours(r.att?.worked),
        r.info.label,
      ];
  const baseCols = ['Date', 'Emp ID', 'Employee', 'Check-in', 'Check-out', 'Hours', 'Status'];
  final today = istDateKey();
  final shown = rows.where((r) => r.info.kind != DayKind.upcoming && !(r.info.kind == DayKind.notYet && r.date == today && false));

  switch (type) {
    case 'monthly':
      final out = <List<String>>[];
      for (final e in s.employees.where((e) => empId == null || e.id == empId)) {
        final mine = rows.where((r) => r.e.id == e.id).toList();
        int n(bool Function(DayRow) f) => mine.where(f).length;
        final hrs = mine.fold<Duration>(Duration.zero, (a, r) => a + (r.att?.worked ?? Duration.zero));
        out.add([
          e.code, e.fullName,
          '${n((r) => r.info.counted)}',
          '${n((r) => r.info.counted && r.info.late)}',
          '${n((r) => r.info.kind == DayKind.halfDay)}',
          '${n((r) => r.info.kind == DayKind.absent)}',
          '${n((r) => r.info.kind == DayKind.leave)}',
          '${n((r) => r.info.kind == DayKind.holiday)}',
          '${n((r) => r.info.kind == DayKind.weeklyOff)}',
          '${n((r) => r.info.kind == DayKind.missingPunch)}',
          fmtHours(hrs),
        ]);
      }
      return ReportTable(title('Monthly attendance'), const ['Emp ID', 'Employee', 'Present', 'Late', 'Half day', 'Absent', 'Leave', 'Holidays', 'Weekly off', 'Missing punch', 'Hours'], out);
    case 'employee':
      final l = shown.where((r) => r.info.kind != DayKind.notYet).toList()..sort((a, b) => a.e.fullName.compareTo(b.e.fullName) != 0 ? a.e.fullName.compareTo(b.e.fullName) : a.date.compareTo(b.date));
      return ReportTable(title('Employee-wise attendance'), baseCols, l.map(base).toList());
    case 'late':
      final l = rows.where((r) => r.info.counted && r.info.late).toList();
      return ReportTable(title('Late arrivals'), ['Date', 'Emp ID', 'Employee', 'Check-in', 'Shift start', 'Late by (min)'],
          l.map((r) => [r.date, r.e.code, r.e.fullName, fmtTime(r.att!.inTime), s.settings.shiftStart, '${minutesOfDayIst(r.att!.inTime!) - s.settings.shiftMinutes}']).toList());
    case 'missing':
      final l = rows.where((r) => r.info.kind == DayKind.missingPunch).toList();
      return ReportTable(title('Missing punches'), ['Date', 'Emp ID', 'Employee', 'Check-in', 'Issue'], l.map((r) => [r.date, r.e.code, r.e.fullName, fmtTime(r.att!.inTime), 'Check-out missing']).toList());
    case 'manual':
      final l = s.allReqs.where((r) => !r.isLeave && r.date.compareTo(from) >= 0 && r.date.compareTo(to) <= 0 && (empId == null || r.userId == empId)).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      return ReportTable(title('Manual attendance'), ['Date', 'Employee', 'Req. check-in', 'Req. check-out', 'Reason', 'Status', 'Admin', 'Admin comment', 'Entry added'],
          l.map((r) => [r.date, r.userName, fmtTime(r.reqIn), fmtTime(r.reqOut), r.reason, r.status, r.approvedByName, r.adminComment, r.used ? 'Yes' : 'No']).toList());
    case 'holiday':
      final l = rows.where((r) => r.info.holiday != null && r.info.counted).toList();
      return ReportTable(title('Holiday attendance'), ['Date', 'Holiday', 'Emp ID', 'Employee', 'Check-in', 'Check-out', 'Hours'],
          l.map((r) => [r.date, r.info.holiday!.name, r.e.code, r.e.fullName, fmtTime(r.att?.inTime), fmtTime(r.att?.outTime), fmtHours(r.att?.worked)]).toList());
    case 'hours':
      final out = <List<String>>[];
      for (final e in s.employees.where((e) => empId == null || e.id == empId)) {
        final w = rows.where((r) => r.e.id == e.id && r.att?.worked != null).toList();
        final tot = w.fold<Duration>(Duration.zero, (a, r) => a + r.att!.worked!);
        out.add([e.code, e.fullName, '${w.length}', fmtHours(tot), w.isEmpty ? '0.00' : (tot.inMinutes / 60 / w.length).toStringAsFixed(2)]);
      }
      return ReportTable(title('Working hours'), const ['Emp ID', 'Employee', 'Days worked', 'Total hours', 'Avg hours/day'], out);
    default: // daily
      final l = shown.where((r) => r.info.kind != DayKind.notYet || r.date == today).toList();
      return ReportTable(title('Daily attendance'), baseCols, l.map(base).toList());
  }
}

class ReportsPage extends StatefulWidget {
  final AppStore store;
  const ReportsPage({super.key, required this.store});
  @override
  State<ReportsPage> createState() => _ReportsState();
}

class _ReportsState extends State<ReportsPage> {
  String type = 'daily';
  String? empId;
  late DateTime from = nowIst(), to = nowIst();
  final search = TextEditingController();
  List<Att> atts = [];
  bool loading = false, loaded = false;
  int? sortCol;
  bool asc = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final f = dateKeyOf(DateTime(from.year, from.month, from.day)), t = dateKeyOf(DateTime(to.year, to.month, to.day));
      atts = await Repo.fetchAttendance(f, t);
      loaded = true;
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> pick(bool isFrom) async {
    final d = await showDatePicker(context: context, initialDate: isFrom ? from : to, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d == null) return;
    setState(() {
      if (isFrom) {
        from = d;
        if (to.isBefore(d)) to = d;
      } else {
        to = d;
        if (from.isAfter(d)) from = d;
      }
    });
    load();
  }

  void preset(String p) {
    final n = nowIst();
    setState(() {
      if (p == 'today') {
        from = to = n;
      } else if (p == 'week') {
        from = n.subtract(Duration(days: n.weekday - 1));
        to = n;
      } else {
        from = DateTime(n.year, n.month, 1);
        to = n;
      }
    });
    load();
  }

  @override
  Widget build(BuildContext c) {
    final s = widget.store;
    final f = dateKeyOf(DateTime(from.year, from.month, from.day)), t = dateKeyOf(DateTime(to.year, to.month, to.day));
    final tooLong = daysBetween(f, t).length * s.employees.length > 20000;
    var table = tooLong ? ReportTable('', const [], const []) : buildReport(type, s, atts, f, t, empId);
    var rows = table.rows;
    final q = search.text.trim().toLowerCase();
    if (q.isNotEmpty) rows = rows.where((r) => r.any((x) => x.toLowerCase().contains(q))).toList();
    if (sortCol != null && sortCol! < table.columns.length) {
      int cmp(List<String> a, List<String> b) {
        final x = a[sortCol!], y = b[sortCol!];
        final nx = double.tryParse(x), ny = double.tryParse(y);
        return (nx != null && ny != null) ? nx.compareTo(ny) : x.compareTo(y);
      }

      rows = [...rows]..sort((a, b) => asc ? cmp(a, b) : cmp(b, a));
    }
    final out = ReportTable(table.title, table.columns, rows);

    return PageBody(maxWidth: 1400, children: [
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<String>(
            initialValue: type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Report'),
            items: [for (final e in reportTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() {
              type = v!;
              sortCol = null;
              if (type == 'monthly' && from.month == to.month && from.day == to.day) preset('month');
            }),
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String?>(
            initialValue: empId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Employee'),
            items: [const DropdownMenuItem(value: null, child: Text('All employees')), for (final e in s.employees) DropdownMenuItem(value: e.id, child: Text(e.fullName, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => empId = v),
          ),
        ),
        OutlinedButton.icon(onPressed: () => pick(true), icon: const Icon(Icons.event), label: Text('From ${DateFormat('dd MMM yy').format(from)}')),
        OutlinedButton.icon(onPressed: () => pick(false), icon: const Icon(Icons.event), label: Text('To ${DateFormat('dd MMM yy').format(to)}')),
        SizedBox(width: 220, child: TextField(controller: search, decoration: const InputDecoration(labelText: 'Search', prefixIcon: Icon(Icons.search)), onChanged: (_) => setState(() {}))),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        ActionChip(label: const Text('Today'), onPressed: () => preset('today')),
        ActionChip(label: const Text('This week'), onPressed: () => preset('week')),
        ActionChip(label: const Text('This month'), onPressed: () => preset('month')),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Text('${out.rows.length} rows', style: Theme.of(c).textTheme.bodySmall)),
        OutlinedButton.icon(onPressed: out.rows.isEmpty ? null : () => shareCsv(c, out), icon: const Icon(Icons.download), label: const Text('CSV / Excel')),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: out.rows.isEmpty ? null : () => printTable(c, out), icon: const Icon(Icons.print_outlined), label: const Text('Print / PDF')),
      ]),
      const SizedBox(height: 8),
      if (loading) const LinearProgressIndicator(),
      if (tooLong) const Empty('Range too large – choose a shorter date range or one employee.')
      else if (loaded && out.rows.isEmpty) const Card(child: Empty('No data for these filters'))
      else if (out.columns.isNotEmpty)
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              sortColumnIndex: sortCol,
              sortAscending: asc,
              columnSpacing: 22,
              headingRowHeight: 44,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 56,
              columns: [for (var i = 0; i < out.columns.length; i++) DataColumn(label: Text(out.columns[i], style: const TextStyle(fontWeight: FontWeight.w700)), onSort: (ci, a) => setState(() { sortCol = ci; asc = a; }))],
              rows: [for (final r in out.rows.take(500)) DataRow(cells: [for (final x in r) DataCell(Text(x))])],
            ),
          ),
        ),
      if (out.rows.length > 500) Padding(padding: const EdgeInsets.all(8), child: Text('Showing first 500 rows on screen – exports include all ${out.rows.length}.', style: Theme.of(c).textTheme.bodySmall)),
    ]);
  }
}
