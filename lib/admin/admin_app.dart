import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/export.dart';
import '../core/ist.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/shared.dart';
import '../core/ui.dart';
import 'admin_more.dart';
import 'reports.dart';

class AdminApp extends StatelessWidget {
  final AppStore store;
  const AdminApp({super.key, required this.store});

  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: store,
        builder: (c, _) => Shell(
          title: 'Admin',
          me: store.me,
          onLogout: () => auth.signOut(),
          badges: {3: store.pendingReqs.length},
          items: [
            NavItem('Dashboard', Icons.dashboard_outlined, (go) => AdminDashboard(store: store, go: go)),
            NavItem('Employees', Icons.groups_outlined, (go) => EmployeesPage(store: store)),
            NavItem('Attendance Records', Icons.fact_check_outlined, (go) => RecordsPage(store: store)),
            NavItem('Approval Requests', Icons.approval_outlined, (go) => ApprovalsPage(store: store)),
            NavItem('Holiday Management', Icons.celebration_outlined, (go) => HolidayManagePage(store: store)),
            NavItem('Reports', Icons.bar_chart_outlined, (go) => ReportsPage(store: store)),
            NavItem('Settings', Icons.settings_outlined, (go) => AdminSettingsPage(store: store)),
          ],
        ),
      );
}

// ---------------------------------------------------------------- Dashboard
class AdminDashboard extends StatelessWidget {
  final AppStore store;
  final void Function(int) go;
  const AdminDashboard({super.key, required this.store, required this.go});

  @override
  Widget build(BuildContext c) {
    final today = istDateKey();
    final active = store.employees.where((e) => e.active).toList();
    final byUser = {for (final a in store.todayAtt) a.userId: a};
    var present = 0, absent = 0, late = 0, working = 0;
    var total = Duration.zero;
    final workingNow = <Att>[];
    for (final e in active) {
      final a = byUser[e.id];
      final i = store.infoFor(e.id, today, a);
      if (a?.inTime != null) {
        present++;
        if (i.late) late++;
        if (a!.outTime == null) {
          working++;
          workingNow.add(a);
          total += DateTime.now().difference(a.inTime!);
        } else {
          total += a.worked!;
        }
      } else if (i.kind == DayKind.notYet) {
        absent++;
      }
    }
    final upcoming = store.holidays.where((h) => h.date.compareTo(today) >= 0).take(4).toList();
    return PageBody(maxWidth: 1100, children: [
      Text('Hello, ${store.me.fullName.split(' ').first}', style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      Text(DateFormat('EEEE, dd MMMM yyyy').format(nowIst())),
      const SizedBox(height: 14),
      StatGrid([
        StatCard(Icons.groups, 'Total employees', '${active.length}', color: Colors.indigo, onTap: () => go(1)),
        StatCard(Icons.check_circle_outline, 'Present today', '$present', color: Colors.green, onTap: () => go(2)),
        StatCard(Icons.person_off_outlined, 'Absent / not in yet', '$absent', color: Colors.red),
        StatCard(Icons.schedule, 'Late arrivals', '$late', color: Colors.orange),
        StatCard(Icons.work_outline, 'Currently working', '$working', color: Colors.blue),
        StatCard(Icons.pending_actions, 'Pending requests', '${store.pendingReqs.length}', color: Colors.deepPurple, onTap: () => go(3)),
        StatCard(Icons.timer_outlined, "Working hours today", fmtDuration(total), color: Colors.teal),
        StatCard(Icons.celebration_outlined, 'Upcoming holidays', '${store.holidays.where((h) => h.date.compareTo(today) >= 0).length}', color: Colors.purple, onTap: () => go(4)),
      ]),
      SectionTitle('Currently working'),
      if (workingNow.isEmpty) const Card(child: Empty('Nobody is checked in right now')),
      for (final a in workingNow)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(child: ListTile(leading: const Icon(Icons.circle, color: Colors.green, size: 14), title: Text(a.userName), subtitle: Text('In since ${fmtTime(a.inTime)}'), trailing: const Icon(Icons.chevron_right), onTap: () => showAttendanceDetail(c, a))),
        ),
      SectionTitle('Pending approvals', trailing: TextButton(onPressed: () => go(3), child: const Text('Open'))),
      if (store.pendingReqs.isEmpty) const Card(child: Empty('No pending requests', icon: Icons.task_alt)),
      for (final r in store.pendingReqs.take(4))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(child: ListTile(title: Text('${r.userName} · ${r.isLeave ? 'Leave' : 'Manual'}'), subtitle: Text('${fmtDate(r.date)}\n${r.reason}', maxLines: 2, overflow: TextOverflow.ellipsis), isThreeLine: true, onTap: () => go(3))),
        ),
      SectionTitle('Upcoming holidays'),
      if (upcoming.isEmpty) const Card(child: Empty('No upcoming holidays', icon: Icons.event_busy_outlined)),
      for (final h in upcoming)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(leading: Icon(Icons.celebration, color: holidayColor(h.category)), title: Text(h.name), subtitle: Text(fmtDate(h.date)), trailing: Badge2(h.category, holidayColor(h.category))))),
    ]);
  }
}

// ---------------------------------------------------------------- Employees
class EmployeesPage extends StatefulWidget {
  final AppStore store;
  const EmployeesPage({super.key, required this.store});
  @override
  State<EmployeesPage> createState() => _EmployeesState();
}

class _EmployeesState extends State<EmployeesPage> {
  String q = '';
  String show = 'all';
  @override
  Widget build(BuildContext c) {
    final l = widget.store.employees.where((e) {
      if (show == 'active' && !e.active) return false;
      if (show == 'inactive' && e.active) return false;
      final s = q.toLowerCase();
      return s.isEmpty || e.fullName.toLowerCase().contains(s) || e.username.toLowerCase().contains(s) || e.email.toLowerCase().contains(s) || e.phone.contains(s);
    }).toList();
    return PageBody(children: [
      TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search name, username, email or phone'), onChanged: (v) => setState(() => q = v)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [for (final o in ['all', 'active', 'inactive']) ChoiceChip(label: Text(o[0].toUpperCase() + o.substring(1)), selected: show == o, onSelected: (_) => setState(() => show = o))]),
      const SizedBox(height: 8),
      Text('${l.length} employees', style: Theme.of(c).textTheme.bodySmall),
      const SizedBox(height: 8),
      if (l.isEmpty) const Empty('No employees found', icon: Icons.groups_outlined),
      for (final e in l)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(e.fullName.isEmpty ? '?' : e.fullName[0].toUpperCase())),
              title: Text(e.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${e.code} · @${e.username}\n${e.email} · ${e.phonePretty}'),
              isThreeLine: true,
              trailing: Badge2(e.active ? 'Active' : 'Inactive', e.active ? Colors.green : Colors.red),
              onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => EmployeeDetail(store: widget.store, empId: e.id))),
            ),
          ),
        ),
    ]);
  }
}

class EmployeeDetail extends StatefulWidget {
  final AppStore store;
  final String empId;
  const EmployeeDetail({super.key, required this.store, required this.empId});
  @override
  State<EmployeeDetail> createState() => _EmployeeDetailState();
}

class _EmployeeDetailState extends State<EmployeeDetail> {
  late DateTime month = DateTime(nowIst().year, nowIst().month);
  List<Att> atts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final s = await db.collection('attendance').where('userId', isEqualTo: widget.empId).get();
      atts = s.docs.map((d) => Att(d.id, d.data())).toList();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> edit(Emp e) async {
    final name = TextEditingController(text: e.fullName), phone = TextEditingController(text: e.phone), dept = TextEditingController(text: e.department), code = TextEditingController(text: e.code);
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Edit employee'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Full name'), validator: (v) => (v ?? '').trim().length < 2 ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile', prefixText: '+91 '), validator: (v) => normalizeIndianPhone(v ?? '') == null ? 'Invalid mobile' : null),
              const SizedBox(height: 12),
              TextFormField(controller: dept, decoration: const InputDecoration(labelText: 'Department')),
              const SizedBox(height: 12),
              TextFormField(controller: code, decoration: const InputDecoration(labelText: 'Employee ID')),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(d, true); }, child: const Text('Save'))],
      ),
    );
    if (ok == true && mounted) {
      await guarded(context, () => Repo.updateEmployee(widget.store.me, e, {'fullName': name.text.trim(), 'phone': normalizeIndianPhone(phone.text), 'department': dept.text.trim(), 'employeeCode': code.text.trim()}), ok: 'Employee updated');
    }
  }

  Future<void> toggle(Emp e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(e.active ? 'Deactivate account?' : 'Activate account?'),
        content: Text(e.active ? '${e.fullName} will be signed out and will not be able to log in or punch.' : '${e.fullName} will be able to log in again.'),
        actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(e.active ? 'Deactivate' : 'Activate'))],
      ),
    );
    if (ok == true && mounted) await guarded(context, () => Repo.updateEmployee(widget.store.me, e, {'accountStatus': e.active ? 'inactive' : 'active'}), ok: e.active ? 'Account deactivated' : 'Account activated');
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: widget.store,
        builder: (c, _) {
          final e = widget.store.empById(widget.empId);
          if (e == null) return Scaffold(appBar: AppBar(), body: const Empty('Employee not found'));
          final today = istDateKey();
          final first = dateKeyOf(month), last = dateKeyOf(DateTime(month.year, month.month + 1, 0));
          final end = last.compareTo(today) > 0 ? today : last;
          final days = first.compareTo(end) > 0 ? <String>[] : daysBetween(first, end).reversed.toList();
          final by = {for (final a in atts) a.date: a};
          final infos = {for (final d in days) d: widget.store.infoFor(e.id, d, by[d])};
          ReportTable table() => ReportTable('${e.fullName} attendance ${DateFormat('MMM yyyy').format(month)}', ['Date', 'Check-in', 'Check-out', 'Hours', 'Status', 'Type'],
              [for (final d in days.reversed) [d, fmtTime(infos[d]!.att?.inTime), fmtTime(infos[d]!.att?.outTime), fmtHours(infos[d]!.att?.worked), infos[d]!.label, infos[d]!.att?.typeLabel ?? '']]);
          return Scaffold(
            appBar: AppBar(title: Text(e.fullName), actions: [IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => edit(e))]),
            body: PageBody(onRefresh: load, children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(radius: 28, child: Text(e.fullName.isEmpty ? '?' : e.fullName[0].toUpperCase(), style: const TextStyle(fontSize: 24))),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.fullName, style: Theme.of(c).textTheme.titleLarge), Text('ID ${e.code} · @${e.username}')])),
                      Badge2(e.active ? 'Active' : 'Inactive', e.active ? Colors.green : Colors.red),
                    ]),
                    const Divider(height: 24),
                    Text('Email: ${e.email}'),
                    Text('Phone: ${e.phonePretty}'),
                    if (e.department.isNotEmpty) Text('Department: ${e.department}'),
                    Text('Joined: ${fmtDateTime(e.createdAt)}'),
                    const SizedBox(height: 12),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Account active'), value: e.active, onChanged: (_) => toggle(e)),
                  ]),
                ),
              ),
              SectionTitle('Attendance history', trailing: IconButton(tooltip: 'Export month', icon: const Icon(Icons.download), onPressed: () => shareCsv(c, table()))),
              Row(children: [
                IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
                Expanded(child: Center(child: Text(fmtMonth(month), style: Theme.of(c).textTheme.titleMedium))),
                IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
              ]),
              if (loading) const LinearProgressIndicator(),
              for (final d in days)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: AttendanceTile(date: d, info: infos[d]!, onTap: by[d] == null ? null : () => showAttendanceDetail(c, by[d]!, action: _correctBtn(c, widget.store, by[d]!, load)))),
            ]),
          );
        },
      );
}

Widget _correctBtn(BuildContext c, AppStore s, Att a, VoidCallback after) => OutlinedButton.icon(
      onPressed: () async {
        Navigator.pop(c);
        final ok = await correctDialog(c, s, a);
        if (ok == true) after();
      },
      icon: const Icon(Icons.edit_note),
      label: const Text('Correct this record'),
    );

/// Admin correction of an attendance record (audit logged).
Future<bool?> correctDialog(BuildContext context, AppStore s, Att a) async {
  var tin = TimeOfDay.fromDateTime(toIst(a.inTime!));
  TimeOfDay? tout = a.outTime == null ? null : TimeOfDay.fromDateTime(toIst(a.outTime!));
  final reason = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: Text('Correct ${fmtDateShort(a.date)} · ${a.userName}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () async { final t = await showTimePicker(context: d, initialTime: tin); if (t != null) set(() => tin = t); }, child: Text('In ${tin.format(d)}'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () async { final t = await showTimePicker(context: d, initialTime: tout ?? const TimeOfDay(hour: 18, minute: 0)); if (t != null) set(() => tout = t); }, child: Text(tout == null ? 'Out --' : 'Out ${tout!.format(d)}'))),
            ]),
            if (tout != null) TextButton(onPressed: () => set(() => tout = null), child: const Text('Clear check-out')),
            const SizedBox(height: 8),
            TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason for correction *')),
            const SizedBox(height: 6),
            const Text('Original values are kept in the audit log.', style: TextStyle(fontSize: 12)),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () {
          if (reason.text.trim().length < 3) return toast(d, 'Reason is required', error: true);
          if (tout != null && tout!.hour * 60 + tout!.minute <= tin.hour * 60 + tin.minute) return toast(d, 'Check-out must be after check-in', error: true);
          Navigator.pop(d, true);
        }, child: const Text('Save'))],
      ),
    ),
  );
  if (ok != true || !context.mounted) return ok;
  return guarded(context, () => Repo.correctAttendance(s.me, a, istInstant(a.date, tin.hour, tin.minute), tout == null ? null : istInstant(a.date, tout!.hour, tout!.minute), reason.text.trim()), ok: 'Attendance corrected & logged');
}

Future<bool?> addRecordDialog(BuildContext context, AppStore s, Emp e, String date) async {
  var tin = const TimeOfDay(hour: 9, minute: 30);
  TimeOfDay? tout = const TimeOfDay(hour: 18, minute: 30);
  final reason = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: Text('Add record · ${e.fullName}\n${fmtDateShort(date)}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () async { final t = await showTimePicker(context: d, initialTime: tin); if (t != null) set(() => tin = t); }, child: Text('In ${tin.format(d)}'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () async { final t = await showTimePicker(context: d, initialTime: tout ?? const TimeOfDay(hour: 18, minute: 0)); if (t != null) set(() => tout = t); }, child: Text(tout == null ? 'Out --' : 'Out ${tout!.format(d)}'))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason *')),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () {
          if (reason.text.trim().length < 3) return toast(d, 'Reason is required', error: true);
          if (tout != null && tout!.hour * 60 + tout!.minute <= tin.hour * 60 + tin.minute) return toast(d, 'Check-out must be after check-in', error: true);
          Navigator.pop(d, true);
        }, child: const Text('Add'))],
      ),
    ),
  );
  if (ok != true || !context.mounted) return ok;
  return guarded(context, () => Repo.adminAddAttendance(s.me, e, date, istInstant(date, tin.hour, tin.minute), tout == null ? null : istInstant(date, tout!.hour, tout!.minute), reason.text.trim()), ok: 'Record added & logged');
}

// ------------------------------------------------------------------ Records
class RecordsPage extends StatefulWidget {
  final AppStore store;
  const RecordsPage({super.key, required this.store});
  @override
  State<RecordsPage> createState() => _RecordsState();
}

class _RecordsState extends State<RecordsPage> {
  late DateTime from = nowIst(), to = nowIst();
  String? empId, dept;
  String status = 'records';
  List<Att> atts = [];
  bool loading = false;

  static const statuses = {
    'records': 'Attendance records',
    'late': 'Late arrivals',
    'half': 'Half day',
    'missing': 'Missing punch',
    'absent': 'Absent',
    'manual': 'Manual / admin entries',
    'off': 'Holiday / weekly off / leave',
    'all': 'Everything',
  };

  @override
  void initState() {
    super.initState();
    load();
  }

  String _k(DateTime d) => dateKeyOf(DateTime(d.year, d.month, d.day));

  Future<void> load() async {
    setState(() => loading = true);
    try {
      atts = await Repo.fetchAttendance(_k(from), _k(to));
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> pick(bool f) async {
    final d = await showDatePicker(context: context, initialDate: f ? from : to, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d == null) return;
    setState(() {
      if (f) {
        from = d;
        if (to.isBefore(d)) to = d;
      } else {
        to = d;
        if (from.isAfter(d)) from = d;
      }
    });
    load();
  }

  bool _match(DayRow r) {
    final i = r.info;
    switch (status) {
      case 'records':
        return i.att != null || i.kind == DayKind.absent;
      case 'late':
        return i.counted && i.late;
      case 'half':
        return i.kind == DayKind.halfDay;
      case 'missing':
        return i.kind == DayKind.missingPunch;
      case 'absent':
        return i.kind == DayKind.absent;
      case 'manual':
        return i.att != null && i.att!.type != 'selfie';
      case 'off':
        return i.att == null && (i.kind == DayKind.holiday || i.kind == DayKind.weeklyOff || i.kind == DayKind.leave);
      default:
        return i.kind != DayKind.upcoming;
    }
  }

  @override
  Widget build(BuildContext c) {
    final s = widget.store;
    final f = _k(from), t = _k(to);
    final depts = {for (final e in s.employees) if (e.department.isNotEmpty) e.department}.toList()..sort();
    final tooLong = daysBetween(f, t).length * s.employees.length > 20000;
    var rows = tooLong ? <DayRow>[] : buildRows(s, atts, f, t, empId: empId).where((r) => (dept == null || r.e.department == dept) && _match(r)).toList();
    rows.sort((a, b) => b.date != a.date ? b.date.compareTo(a.date) : a.e.fullName.compareTo(b.e.fullName));
    ReportTable table() => ReportTable('Attendance records ${f == t ? f : '$f to $t'}', ['Date', 'Emp ID', 'Employee', 'Check-in', 'Check-out', 'Hours', 'Status', 'Type', 'Check-in map', 'Check-out map'], [
          for (final r in rows)
            [r.date, r.e.code, r.e.fullName, fmtTime(r.att?.inTime), fmtTime(r.att?.outTime), fmtHours(r.att?.worked), r.info.label, r.att?.typeLabel ?? '',
              r.att?.inLat == null ? '' : 'https://maps.google.com/?q=${r.att!.inLat},${r.att!.inLng}',
              r.att?.outLat == null ? '' : 'https://maps.google.com/?q=${r.att!.outLat},${r.att!.outLng}']
        ]);
    return PageBody(maxWidth: 1000, onRefresh: load, children: [
      Wrap(spacing: 10, runSpacing: 10, children: [
        OutlinedButton.icon(onPressed: () => pick(true), icon: const Icon(Icons.event), label: Text('From ${DateFormat('dd MMM yy').format(from)}')),
        OutlinedButton.icon(onPressed: () => pick(false), icon: const Icon(Icons.event), label: Text('To ${DateFormat('dd MMM yy').format(to)}')),
        SizedBox(width: 220, child: DropdownButtonFormField<String?>(initialValue: empId, isExpanded: true, decoration: const InputDecoration(labelText: 'Employee'), items: [const DropdownMenuItem(value: null, child: Text('All')), for (final e in s.employees) DropdownMenuItem(value: e.id, child: Text(e.fullName, overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => empId = v))),
        SizedBox(width: 220, child: DropdownButtonFormField<String>(initialValue: status, isExpanded: true, decoration: const InputDecoration(labelText: 'Status'), items: [for (final e in statuses.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (v) => setState(() => status = v!))),
        if (depts.isNotEmpty) SizedBox(width: 200, child: DropdownButtonFormField<String?>(initialValue: dept, isExpanded: true, decoration: const InputDecoration(labelText: 'Department'), items: [const DropdownMenuItem(value: null, child: Text('All')), for (final d in depts) DropdownMenuItem(value: d, child: Text(d))], onChanged: (v) => setState(() => dept = v))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text('${rows.length} rows', style: Theme.of(c).textTheme.bodySmall)),
        OutlinedButton.icon(onPressed: rows.isEmpty ? null : () => shareCsv(c, table()), icon: const Icon(Icons.download), label: const Text('Export CSV')),
      ]),
      const SizedBox(height: 8),
      if (loading) const LinearProgressIndicator(),
      if (tooLong) const Empty('Range too large – choose a shorter date range or one employee.'),
      if (!tooLong && rows.isEmpty && !loading) const Card(child: Empty('No records match these filters', icon: Icons.fact_check_outlined)),
      for (final r in rows.take(300))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AttendanceTile(
            date: r.date,
            info: r.info,
            title: '${r.e.fullName} · ${fmtDateShort(r.date)}',
            onTap: () {
              if (r.att != null) {
                showAttendanceDetail(c, r.att!, action: _correctBtn(c, s, r.att!, load));
              } else if (r.info.kind == DayKind.absent || r.info.kind == DayKind.notYet) {
                addRecordDialog(c, s, r.e, r.date).then((ok) => ok == true ? load() : null);
              }
            },
          ),
        ),
      if (rows.length > 300) const Padding(padding: EdgeInsets.all(8), child: Text('Showing first 300 – narrow the filters or export for all rows.')),
      const SizedBox(height: 8),
      const Text('Tip: tap a record to see selfies, map and correct it. Tap an absent day to add a record.', style: TextStyle(fontSize: 12)),
    ]);
  }
}

// ---------------------------------------------------------------- Approvals
class ApprovalsPage extends StatelessWidget {
  final AppStore store;
  const ApprovalsPage({super.key, required this.store});
  @override
  Widget build(BuildContext c) {
    final pending = store.pendingReqs, hist = store.allReqs.where((r) => !r.pending).toList();
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(tabs: [Tab(text: 'Pending (${pending.length})'), const Tab(text: 'History')]),
        Expanded(
          child: TabBarView(children: [
            PageBody(maxWidth: 800, children: [
              if (pending.isEmpty) const Empty('All caught up – no pending requests', icon: Icons.task_alt),
              for (final r in pending) Padding(padding: const EdgeInsets.only(bottom: 12), child: _ReqCard(store: store, r: r, key: ValueKey(r.id))),
            ]),
            PageBody(maxWidth: 800, children: [
              if (hist.isEmpty) const Empty('No history yet'),
              for (final r in hist) Padding(padding: const EdgeInsets.only(bottom: 12), child: _ReqCard(store: store, r: r, key: ValueKey(r.id))),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _ReqCard extends StatefulWidget {
  final AppStore store;
  final Req r;
  const _ReqCard({super.key, required this.store, required this.r});
  @override
  State<_ReqCard> createState() => _ReqCardState();
}

class _ReqCardState extends State<_ReqCard> {
  final comment = TextEditingController();
  bool busy = false;
  late final Future<Att?> existing = widget.r.isLeave ? Future.value(null) : Repo.attendanceFor(widget.r.userId, widget.r.date);

  Future<void> decide(bool approve) async {
    if (!approve && comment.text.trim().isEmpty) return toast(context, 'Please add a comment explaining the rejection', error: true);
    setState(() => busy = true);
    await guarded(context, () => Repo.decideRequest(widget.store.me, widget.r, approve, comment.text), ok: approve ? 'Request approved' : 'Request rejected');
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    final r = widget.r;
    final emp = widget.store.empById(r.userId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(child: Text(r.userName.isEmpty ? '?' : r.userName[0].toUpperCase())),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.userName, style: const TextStyle(fontWeight: FontWeight.w700)), Text(r.isLeave ? 'Leave request' : 'Manual attendance request', style: Theme.of(c).textTheme.bodySmall)])),
            Badge2(r.status[0].toUpperCase() + r.status.substring(1), reqColor(r.status)),
          ]),
          const Divider(height: 22),
          Text(r.isLeave ? 'Dates: ${fmtDate(r.date)}${r.endDate != r.date ? ' → ${fmtDate(r.endDate)}' : ''}' : 'Date: ${fmtDate(r.date)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          if (!r.isLeave) Text('Requested: In ${fmtTime(r.reqIn)} · Out ${fmtTime(r.reqOut)}'),
          const SizedBox(height: 6),
          Text('Reason: ${r.reason}'),
          if (r.notes.isNotEmpty) Text('Notes: ${r.notes}'),
          Text('Submitted ${fmtDateTime(r.createdAt)}', style: Theme.of(c).textTheme.bodySmall),
          if (!r.isLeave)
            FutureBuilder<Att?>(
              future: existing,
              builder: (c, s) {
                if (s.connectionState != ConnectionState.done) return const SizedBox();
                final a = s.data;
                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Theme.of(c).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                  child: Text(a == null ? 'Existing record for that date: none' : 'Existing record: In ${fmtTime(a.inTime)} · Out ${fmtTime(a.outTime)} (${a.typeLabel})'),
                );
              },
            ),
          if (emp != null) TextButton.icon(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => EmployeeDetail(store: widget.store, empId: emp.id))), icon: const Icon(Icons.person_search_outlined), label: const Text('View employee profile & history')),
          if (r.pending) ...[
            const SizedBox(height: 4),
            TextField(controller: comment, decoration: const InputDecoration(labelText: 'Admin comment (required to reject)')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: busy ? null : () => decide(false), icon: const Icon(Icons.close, color: Colors.red), label: const Text('Reject'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(onPressed: busy ? null : () => decide(true), icon: const Icon(Icons.check), label: const Text('Approve'))),
            ]),
          ] else ...[
            const SizedBox(height: 6),
            Text('${r.approved ? 'Approved' : 'Rejected'} by ${r.approvedByName} · ${fmtDateTime(r.approvedAt)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (r.adminComment.isNotEmpty) Text('Comment: ${r.adminComment}'),
            if (r.approved && !r.isLeave) Text(r.used ? 'Employee has added the attendance entry.' : 'Waiting for employee to add the entry.', style: Theme.of(c).textTheme.bodySmall),
          ],
        ]),
      ),
    );
  }
}
