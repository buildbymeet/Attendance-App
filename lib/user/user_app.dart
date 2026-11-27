import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/capture.dart';
import '../core/ist.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/shared.dart';
import '../core/ui.dart';

class UserApp extends StatelessWidget {
  final AppStore store;
  const UserApp({super.key, required this.store});

  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: store,
        builder: (c, _) {
          final pending = store.myReqs.where((r) => r.pending).length;
          final ready = store.myReqs.where((r) => r.approved && !r.isLeave && !r.used).length;
          return Shell(
            title: 'Attendance',
            me: store.me,
            onLogout: () => auth.signOut(),
            badges: {3: ready},
            items: [
              NavItem('Dashboard', Icons.dashboard_outlined, (go) => DashboardPage(store: store, go: go, pending: pending)),
              NavItem('Punch Attendance', Icons.fingerprint, (go) => PunchPage(store: store)),
              NavItem('Attendance History', Icons.history, (go) => HistoryPage(store: store)),
              NavItem('Manual Requests', Icons.edit_calendar_outlined, (go) => RequestsPage(store: store)),
              NavItem('Holiday Calendar', Icons.celebration_outlined, (go) => HolidaysPage(store: store)),
              NavItem('Profile', Icons.person_outline, (go) => ProfilePage(store: store)),
            ],
          );
        },
      );
}

// ---------------------------------------------------------------- Dashboard
class DashboardPage extends StatelessWidget {
  final AppStore store;
  final void Function(int) go;
  final int pending;
  const DashboardPage({super.key, required this.store, required this.go, required this.pending});

  @override
  Widget build(BuildContext c) {
    final me = store.me;
    final now = nowIst();
    final a = store.today;
    final status = a == null ? 'Not Checked In' : a.outTime == null ? 'Checked In' : 'Attendance Completed';
    final statusColor = a == null ? Colors.grey : a.outTime == null ? Colors.blue : Colors.green;

    // Month summary, derived day by day so holidays/leaves/weekly-offs are never "absent".
    final today = istDateKey();
    final days = daysBetween(dateKeyOf(DateTime(now.year, now.month, 1)), today);
    final byDate = {for (final x in store.myAtt) x.date: x};
    var present = 0, absent = 0, late = 0, half = 0, leave = 0;
    Duration total = Duration.zero;
    for (final d in days) {
      final i = store.infoFor(me.id, d, byDate[d]);
      if (i.counted) present++;
      if (i.counted && i.late) late++;
      if (i.kind == DayKind.halfDay) half++;
      if (i.kind == DayKind.absent) absent++;
      if (i.kind == DayKind.leave) leave++;
      total += i.att?.worked ?? Duration.zero;
    }
    final upcoming = store.holidaysFor(me.id).where((h) => h.date.compareTo(today) >= 0).take(4).toList();
    final ready = store.approvedUnused;

    return PageBody(children: [
      Text('Welcome, ${me.fullName.split(' ').first} 👋', style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      Text(DateFormat('EEEE, dd MMMM yyyy').format(now), style: TextStyle(color: Theme.of(c).colorScheme.outline)),
      const SizedBox(height: 14),
      if (ready != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            color: Colors.green.withValues(alpha: 0.12),
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text('Manual request for ${fmtDateShort(ready.date)} approved'),
              subtitle: const Text('Tap to add the attendance entry'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => go(3),
            ),
          ),
        ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text("Today's status", style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Badge2(status, statusColor),
              if (pending > 0) ...[const SizedBox(width: 6), Badge2('Pending Approval · $pending', Colors.orange)],
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _Metric('Check-in', fmtTime(a?.inTime), Icons.login)),
              Expanded(child: _Metric('Check-out', fmtTime(a?.outTime), Icons.logout)),
              Expanded(child: _Metric('Hours', a?.worked != null ? fmtDuration(a!.worked) : '--', Icons.timer_outlined)),
            ]),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: a?.outTime != null ? null : () => go(1),
              icon: const Icon(Icons.fingerprint),
              label: Text(a == null ? 'Start Day – Check In' : a.outTime == null ? 'End Day – Check Out' : 'Attendance completed'),
            ),
          ]),
        ),
      ),
      SectionTitle('${DateFormat('MMMM').format(now)} summary'),
      StatGrid([
        StatCard(Icons.check_circle_outline, 'Present days', '$present', color: Colors.green),
        StatCard(Icons.cancel_outlined, 'Absent days', '$absent', color: Colors.red),
        StatCard(Icons.schedule, 'Late arrivals', '$late', color: Colors.orange),
        StatCard(Icons.beach_access_outlined, 'Approved leaves', '$leave', color: Colors.teal),
        StatCard(Icons.timelapse, 'Half days', '$half', color: Colors.amber.shade800),
        StatCard(Icons.pending_actions, 'Pending requests', '$pending', color: Colors.deepPurple, onTap: () => go(3)),
        StatCard(Icons.access_time, 'Hours this month', fmtDuration(total), color: Colors.indigo),
      ]),
      SectionTitle('Upcoming holidays', trailing: TextButton(onPressed: () => go(4), child: const Text('View all'))),
      if (upcoming.isEmpty) const Card(child: Empty('No upcoming holidays', icon: Icons.event_busy_outlined)),
      for (final h in upcoming)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: Icon(Icons.celebration, color: holidayColor(h.category)),
              title: Text(h.name),
              subtitle: Text(fmtDate(h.date)),
              trailing: Badge2(h.category, holidayColor(h.category)),
            ),
          ),
        ),
      SectionTitle('Recent attendance', trailing: TextButton(onPressed: () => go(2), child: const Text('History'))),
      if (store.myAtt.isEmpty) const Card(child: Empty('No attendance yet')),
      for (final x in store.myAtt.take(5))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AttendanceTile(date: x.date, info: store.infoFor(me.id, x.date, x), onTap: () => showAttendanceDetail(c, x)),
        ),
    ]);
  }
}

class _Metric extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _Metric(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext c) => Column(children: [
        Icon(icon, size: 20, color: Theme.of(c).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        Text(label, style: Theme.of(c).textTheme.bodySmall),
      ]);
}

// -------------------------------------------------------------------- Punch
class PunchPage extends StatefulWidget {
  final AppStore store;
  const PunchPage({super.key, required this.store});
  @override
  State<PunchPage> createState() => _PunchState();
}

class _PunchState extends State<PunchPage> {
  bool busy = false;

  Future<void> punch(bool checkIn) async {
    setState(() => busy = true);
    try {
      final cap = await captureAttendance(context, title: checkIn ? 'Check In' : 'Check Out');
      if (cap == null) return;
      if (checkIn) {
        await Repo.checkIn(widget.store.me, cap);
      } else {
        await Repo.checkOut(widget.store.me, widget.store.today!, cap);
      }
      if (mounted) toast(context, checkIn ? 'Checked in successfully ✔' : 'Checked out. Attendance completed ✔');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final s = widget.store;
    final a = s.today;
    final done = a?.outTime != null;
    final info = s.infoFor(s.me.id, istDateKey(), a);
    final color = done ? Colors.green : a == null ? Theme.of(c).colorScheme.primary : Colors.deepOrange;
    return PageBody(maxWidth: 520, children: [
      const SizedBox(height: 12),
      Center(child: Text(DateFormat('EEEE, dd MMM yyyy').format(nowIst()), style: Theme.of(c).textTheme.titleMedium)),
      const SizedBox(height: 4),
      Center(child: _Clock()),
      if (info.holiday != null) Padding(padding: const EdgeInsets.only(top: 8), child: Center(child: Badge2('Today is a holiday: ${info.holiday!.name}', Colors.purple))),
      const SizedBox(height: 28),
      Center(
        child: SizedBox(
          width: 190,
          height: 190,
          child: FilledButton(
            style: FilledButton.styleFrom(shape: const CircleBorder(), backgroundColor: color, padding: EdgeInsets.zero),
            onPressed: (busy || done) ? null : () => punch(a == null),
            child: busy
                ? const CircularProgressIndicator(color: Colors.white)
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(done ? Icons.verified : Icons.fingerprint, size: 64),
                    const SizedBox(height: 6),
                    Text(done ? 'Completed' : a == null ? 'CHECK IN' : 'CHECK OUT', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    if (!done) Text(a == null ? 'Start day' : 'End day', style: const TextStyle(fontSize: 12)),
                  ]),
          ),
        ),
      ),
      const SizedBox(height: 28),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: _Metric('Check-in', fmtTime(a?.inTime), Icons.login)),
            Expanded(child: _Metric('Check-out', fmtTime(a?.outTime), Icons.logout)),
            Expanded(child: _Metric('Hours', fmtDuration(a?.worked), Icons.timer_outlined)),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: const Text('Selfie + location required'),
          subtitle: const Text('A live front-camera selfie and your GPS location are captured only when you tap the button. Time is recorded by the server in IST.'),
        ),
      ),
      if (a == null) ...[
        const SizedBox(height: 12),
        Center(child: Text('Forgot to punch on an earlier day? Use Manual Requests.', style: Theme.of(c).textTheme.bodySmall)),
      ],
    ]);
  }
}

class _Clock extends StatefulWidget {
  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  late final t = Stream.periodic(const Duration(seconds: 1));
  @override
  Widget build(BuildContext c) => StreamBuilder(
        stream: t,
        builder: (c, _) => Text(DateFormat('hh:mm:ss a').format(nowIst()), style: Theme.of(c).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
      );
}

// ------------------------------------------------------------------ History
class HistoryPage extends StatefulWidget {
  final AppStore store;
  const HistoryPage({super.key, required this.store});
  @override
  State<HistoryPage> createState() => _HistoryState();
}

class _HistoryState extends State<HistoryPage> {
  late DateTime month = DateTime(nowIst().year, nowIst().month);

  @override
  Widget build(BuildContext c) {
    final s = widget.store;
    final today = istDateKey();
    final first = dateKeyOf(month);
    final last = dateKeyOf(DateTime(month.year, month.month + 1, 0));
    final end = last.compareTo(today) > 0 ? today : last;
    final days = first.compareTo(end) > 0 ? <String>[] : daysBetween(first, end).reversed.toList();
    final byDate = {for (final x in s.myAtt) x.date: x};
    final infos = {for (final d in days) d: s.infoFor(s.me.id, d, byDate[d])};
    final cnt = <DayKind, int>{};
    for (final i in infos.values) {
      cnt[i.kind] = (cnt[i.kind] ?? 0) + 1;
    }
    return PageBody(children: [
      Row(children: [
        IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
        Expanded(child: Center(child: Text(fmtMonth(month), style: Theme.of(c).textTheme.titleLarge))),
        IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 6, children: [
        Badge2('Present ${infos.values.where((i) => i.counted).length}', Colors.green),
        Badge2('Late ${infos.values.where((i) => i.counted && i.late).length}', Colors.orange),
        Badge2('Absent ${cnt[DayKind.absent] ?? 0}', Colors.red),
        Badge2('Leave ${cnt[DayKind.leave] ?? 0}', Colors.teal),
        Badge2('Holiday ${cnt[DayKind.holiday] ?? 0}', Colors.purple),
      ]),
      const SizedBox(height: 12),
      if (days.isEmpty) const Empty('Nothing to show for this month'),
      for (final d in days)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AttendanceTile(date: d, info: infos[d]!, onTap: byDate[d] == null ? null : () => showAttendanceDetail(c, byDate[d]!)),
        ),
    ]);
  }
}

// ----------------------------------------------------------------- Requests
class RequestsPage extends StatefulWidget {
  final AppStore store;
  const RequestsPage({super.key, required this.store});
  @override
  State<RequestsPage> createState() => _RequestsState();
}

class _RequestsState extends State<RequestsPage> {
  bool busy = false;

  Future<void> addEntry(Req r) async {
    setState(() => busy = true);
    try {
      final existing = await Repo.attendanceFor(widget.store.me.id, r.date);
      if (existing != null && (existing.outTime != null || r.reqOut == null)) {
        throw 'An attendance record already exists for ${fmtDateShort(r.date)}. Ask the admin to correct it.';
      }
      if (!mounted) return;
      final cap = await captureAttendance(context, title: 'Manual attendance · ${fmtDateShort(r.date)}');
      if (cap == null) return;
      await Repo.completeManual(widget.store.me, r, cap, existing);
      if (mounted) toast(context, 'Manual attendance added ✔');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final reqs = widget.store.myReqs;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => RequestForm(store: widget.store))),
        icon: const Icon(Icons.add),
        label: const Text('Request Manual Attendance'),
      ),
      body: PageBody(children: [
        if (busy) const LinearProgressIndicator(),
        if (reqs.isEmpty) const Empty('No requests yet.\nForgot to punch? Tap the button below.', icon: Icons.edit_calendar_outlined),
        for (final r in reqs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(r.isLeave ? Icons.beach_access_outlined : Icons.edit_calendar_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r.isLeave ? 'Leave · ${r.date == r.endDate ? fmtDateShort(r.date) : '${fmtDateShort(r.date)} – ${fmtDateShort(r.endDate)}'}' : 'Manual · ${fmtDate(r.date)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    Badge2(r.status[0].toUpperCase() + r.status.substring(1), reqColor(r.status)),
                  ]),
                  if (!r.isLeave) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Check-in ${fmtTime(r.reqIn)}  ·  Check-out ${fmtTime(r.reqOut)}')),
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text('Reason: ${r.reason}')),
                  if (r.adminComment.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${r.rejected ? 'Rejection reason' : 'Admin comment'}: ${r.adminComment}', style: TextStyle(color: r.rejected ? Colors.red.shade400 : null, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 8),
                  if (r.pending)
                    Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => guarded(c, () => Repo.cancelRequest(r), ok: 'Request cancelled'), icon: const Icon(Icons.close), label: const Text('Cancel request'))),
                  if (r.approved && !r.isLeave && !r.used)
                    FilledButton.icon(onPressed: busy ? null : () => addEntry(r), icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Add attendance (selfie + location)')),
                  if (r.approved && !r.isLeave && r.used) const Badge2('Attendance added · Manual Attendance – Admin Approved', Colors.deepPurple),
                ]),
              ),
            ),
          ),
        const SizedBox(height: 70),
      ]),
    );
  }
}

class RequestForm extends StatefulWidget {
  final AppStore store;
  const RequestForm({super.key, required this.store});
  @override
  State<RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<RequestForm> {
  final form = GlobalKey<FormState>();
  bool leave = false, busy = false;
  late DateTime date = nowIst().subtract(const Duration(days: 1));
  late DateTime endDate = date;
  TimeOfDay? tin, tout;
  final reason = TextEditingController(), notes = TextEditingController();

  Future<void> pickDate(bool end) async {
    final now = nowIst();
    final d = await showDatePicker(
      context: context,
      initialDate: end ? endDate : date,
      firstDate: end ? date : DateTime(now.year, now.month - 3, 1),
      lastDate: leave ? DateTime(now.year + 1, 12, 31) : DateTime(now.year, now.month, now.day),
    );
    if (d == null) return;
    setState(() {
      if (end) {
        endDate = d;
      } else {
        date = d;
        if (endDate.isBefore(d) || !leave) endDate = d;
      }
    });
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final key = dateKeyOf(date);
    if (!leave) {
      if (tin == null) return toast(context, 'Select the requested check-in time', error: true);
      if (tout != null && (tout!.hour * 60 + tout!.minute) <= (tin!.hour * 60 + tin!.minute)) return toast(context, 'Check-out must be after check-in', error: true);
    }
    final dup = widget.store.myReqs.any((r) => r.pending && r.type == (leave ? 'leave' : 'manual') && r.date == key);
    if (dup) return toast(context, 'You already have a pending request for this date', error: true);
    setState(() => busy = true);
    final ok = await guarded(
        context,
        () => Repo.submitRequest(widget.store.me, {
              'type': leave ? 'leave' : 'manual',
              'date': key,
              'endDate': dateKeyOf(endDate),
              'reason': reason.text.trim(),
              'notes': notes.text.trim(),
              if (!leave) 'requestedCheckIn': Timestamp2.of(key, tin!),
              if (!leave && tout != null) 'requestedCheckOut': Timestamp2.of(key, tout!),
            }),
        ok: 'Request sent to admin');
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(leave ? 'Request Leave' : 'Request Manual Attendance')),
        body: PageBody(maxWidth: 560, children: [
          Form(
            key: form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SegmentedButton<bool>(
                segments: const [ButtonSegment(value: false, label: Text('Missed punch'), icon: Icon(Icons.edit_calendar_outlined)), ButtonSegment(value: true, label: Text('Leave'), icon: Icon(Icons.beach_access_outlined))],
                selected: {leave},
                onSelectionChanged: (v) => setState(() {
                  leave = v.first;
                  if (!leave) {
                    final n = nowIst();
                    if (date.isAfter(DateTime(n.year, n.month, n.day))) date = DateTime(n.year, n.month, n.day);
                  }
                  endDate = date;
                }),
              ),
              const SizedBox(height: 16),
              ListTile(shape: RoundedRectangleBorder(side: BorderSide(color: Theme.of(c).colorScheme.outline), borderRadius: BorderRadius.circular(12)), leading: const Icon(Icons.event), title: Text(leave ? 'From date' : 'Attendance date'), subtitle: Text(DateFormat('EEE, dd MMM yyyy').format(date)), onTap: () => pickDate(false)),
              if (leave) ...[
                const SizedBox(height: 12),
                ListTile(shape: RoundedRectangleBorder(side: BorderSide(color: Theme.of(c).colorScheme.outline), borderRadius: BorderRadius.circular(12)), leading: const Icon(Icons.event), title: const Text('To date'), subtitle: Text(DateFormat('EEE, dd MMM yyyy').format(endDate)), onTap: () => pickDate(true)),
              ] else ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () async { final t = await showTimePicker(context: c, initialTime: tin ?? const TimeOfDay(hour: 9, minute: 30)); if (t != null) setState(() => tin = t); }, icon: const Icon(Icons.login), label: Text(tin == null ? 'Check-in *' : tin!.format(c)))),
                  const SizedBox(width: 12),
                  Expanded(child: OutlinedButton.icon(onPressed: () async { final t = await showTimePicker(context: c, initialTime: tout ?? const TimeOfDay(hour: 18, minute: 30)); if (t != null) setState(() => tout = t); }, icon: const Icon(Icons.logout), label: Text(tout == null ? 'Check-out (optional)' : tout!.format(c)))),
                ]),
                if (tout != null) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => tout = null), child: const Text('Clear check-out'))),
              ],
              const SizedBox(height: 12),
              TextFormField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason *'), validator: (v) => (v ?? '').trim().length < 5 ? 'Please give a reason' : null),
              const SizedBox(height: 12),
              TextFormField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Additional notes (optional)')),
              const SizedBox(height: 8),
              if (!leave) const Text('After the admin approves, you will add the entry with a selfie and location from the Requests screen.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              FilledButton(onPressed: busy ? null : submit, child: const Text('Submit request')),
            ]),
          ),
        ]),
      );
}

class Timestamp2 {
  /// IST wall-clock time on [dateKey] as a Firestore-compatible UTC DateTime.
  static dynamic of(String dateKey, TimeOfDay t) => Timestamp.fromDate(istInstant(dateKey, t.hour, t.minute));
}

// ----------------------------------------------------------------- Holidays
class HolidaysPage extends StatelessWidget {
  final AppStore store;
  const HolidaysPage({super.key, required this.store});
  @override
  Widget build(BuildContext c) => PageBody(children: [
        HolidayCalendar(
          holidays: store.holidaysFor(store.me.id),
          settings: store.settings,
          onTapHoliday: (h) => showDialog(
              context: c,
              builder: (_) => AlertDialog(
                    title: Text(h.name),
                    content: Text('${fmtDate(h.date)}\n${h.category} · ${h.region}\n${h.paid ? 'Paid' : 'Unpaid'} holiday\n\n${h.description}'),
                    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
                  )),
        ),
      ]);
}

// ------------------------------------------------------------------ Profile
class ProfilePage extends StatelessWidget {
  final AppStore store;
  const ProfilePage({super.key, required this.store});

  @override
  Widget build(BuildContext c) {
    final me = store.me;
    return PageBody(maxWidth: 560, children: [
      Center(child: CircleAvatar(radius: 40, child: Text(me.fullName.isEmpty ? '?' : me.fullName[0].toUpperCase(), style: const TextStyle(fontSize: 32)))),
      const SizedBox(height: 10),
      Center(child: Text(me.fullName, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
      Center(child: Text('Employee ID ${me.code}')),
      const SizedBox(height: 16),
      Card(
        child: Column(children: [
          ListTile(leading: const Icon(Icons.alternate_email), title: const Text('Username'), subtitle: Text(me.username)),
          ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Email'), subtitle: Text(me.email)),
          ListTile(leading: const Icon(Icons.phone_outlined), title: const Text('Phone'), subtitle: Text(me.phonePretty)),
          if (me.department.isNotEmpty) ListTile(leading: const Icon(Icons.business_outlined), title: const Text('Department'), subtitle: Text(me.department)),
        ]),
      ),
      const SizedBox(height: 12),
      Card(
        child: Column(children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Edit name & phone'), onTap: () => editProfile(c, me)),
          ListTile(leading: const Icon(Icons.password), title: const Text('Change password'), onTap: () => changePasswordDialog(c)),
          ValueListenableBuilder(
            valueListenable: themeMode,
            builder: (c, m, _) => ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark mode'),
              trailing: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [ButtonSegment(value: ThemeMode.system, label: Text('Auto')), ButtonSegment(value: ThemeMode.light, label: Text('Off')), ButtonSegment(value: ThemeMode.dark, label: Text('On'))],
                selected: {m},
                onSelectionChanged: (v) => setThemePref(v.first),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () => auth.signOut(), icon: const Icon(Icons.logout), label: const Text('Logout')),
    ]);
  }
}

Future<void> editProfile(BuildContext c, Emp me) async {
  final name = TextEditingController(text: me.fullName), phone = TextEditingController(text: me.phone);
  final form = GlobalKey<FormState>();
  final ok = await showDialog<bool>(
    context: c,
    builder: (d) => AlertDialog(
      title: const Text('Edit profile'),
      content: Form(
        key: form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Full name'), validator: (v) => (v ?? '').trim().length < 2 ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile', prefixText: '+91 '), validator: (v) => normalizeIndianPhone(v ?? '') == null ? 'Invalid Indian mobile number' : null),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(d, true); }, child: const Text('Save'))],
    ),
  );
  if (ok == true && c.mounted) {
    await guarded(c, () => db.doc('users/${me.id}').update({'fullName': name.text.trim(), 'phone': normalizeIndianPhone(phone.text)}), ok: 'Profile updated');
  }
}

Future<void> changePasswordDialog(BuildContext c) async {
  final cur = TextEditingController(), nw = TextEditingController();
  final form = GlobalKey<FormState>();
  final ok = await showDialog<bool>(
    context: c,
    builder: (d) => AlertDialog(
      title: const Text('Change password'),
      content: Form(
        key: form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: cur, obscureText: true, decoration: const InputDecoration(labelText: 'Current password'), validator: (v) => (v ?? '').isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: nw, obscureText: true, decoration: const InputDecoration(labelText: 'New password'), validator: (v) => RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$').hasMatch(v ?? '') ? null : 'Min 8 chars with a letter and a number'),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(d, true); }, child: const Text('Update'))],
    ),
  );
  if (ok == true && c.mounted) await guarded(c, () => Repo.changePassword(cur.text, nw.text), ok: 'Password updated');
}
