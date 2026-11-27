import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/holiday_defaults.dart';
import '../core/ist.dart';
import '../core/models.dart';
import '../core/repo.dart';
import '../core/shared.dart';
import '../core/ui.dart';
import '../user/user_app.dart' show changePasswordDialog;

// ------------------------------------------------------------------ Holidays
class HolidayManagePage extends StatefulWidget {
  final AppStore store;
  const HolidayManagePage({super.key, required this.store});
  @override
  State<HolidayManagePage> createState() => _HolidayManageState();
}

class _HolidayManageState extends State<HolidayManagePage> {
  int year = nowIst().year;
  bool calendar = true;

  Future<void> addDefaults() async {
    final existing = widget.store.holidays.where((h) => h.date.startsWith('$year')).map((h) => '${h.name}|${h.date}').toSet();
    final items = defaultHolidays(year).where((h) => !existing.contains('${h['name']}|${h['date']}')).toList();
    final lunar = hasLunarDefaults(year);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Load default holidays for $year'),
        content: Text('${items.length} holidays will be added.\n\n${lunar ? 'Festival dates are indicative – please verify them for your region and edit as needed.' : 'Only fixed-date national holidays are available for $year. Lunar festivals (Holi, Diwali, Eid…) vary every year, so add them manually.'}'),
        actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: items.isEmpty ? null : () => Navigator.pop(d, true), child: const Text('Add'))],
      ),
    );
    if (ok == true && mounted) await guarded(context, () => Repo.addHolidays(widget.store.me, items), ok: '${items.length} holidays added');
  }

  Future<void> edit({Hol? h, String? date}) async {
    final name = TextEditingController(text: h?.name ?? ''), desc = TextEditingController(text: h?.description ?? '');
    final form = GlobalKey<FormState>();
    var d = h != null ? parseDateKey(h.date) : date != null ? parseDateKey(date) : DateTime(year, nowIst().month, nowIst().day);
    var cat = h?.category ?? 'Festival', region = h?.region ?? 'All India', paid = h?.paid ?? true;
    var assigned = [...?h?.assigned];
    final emps = widget.store.employees;
    await showDialog<void>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (dc, set) => AlertDialog(
          title: Text(h == null ? 'Add holiday' : 'Edit holiday'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Holiday name'), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: () async { final x = await showDatePicker(context: dc, initialDate: d, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (x != null) set(() => d = x); }, icon: const Icon(Icons.event), label: Text(DateFormat('EEE, dd MMM yyyy').format(d))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(initialValue: cat, decoration: const InputDecoration(labelText: 'Category'), items: [for (final x in holidayCategories) DropdownMenuItem(value: x, child: Text(x))], onChanged: (v) => set(() => cat = v!)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(initialValue: region, isExpanded: true, decoration: const InputDecoration(labelText: 'Region / state'), items: [for (final x in {...indianRegions, region}) DropdownMenuItem(value: x, child: Text(x))], onChanged: (v) => set(() => region = v!)),
                  const SizedBox(height: 12),
                  TextFormField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Paid holiday'), value: paid, onChanged: (v) => set(() => paid = v)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Applies to all employees'), value: assigned.isEmpty, onChanged: (v) => set(() => assigned = v ? [] : [if (emps.isNotEmpty) emps.first.id])),
                  if (assigned.isNotEmpty)
                    Wrap(spacing: 6, children: [for (final e in emps) FilterChip(label: Text(e.fullName), selected: assigned.contains(e.id), onSelected: (v) => set(() { v ? assigned.add(e.id) : assigned.remove(e.id); }))]),
                ]),
              ),
            ),
          ),
          actions: [
            if (h != null) TextButton(onPressed: () async { Navigator.pop(dc); await confirmDelete(h); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
            TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                Navigator.pop(dc);
                await guarded(context, () => Repo.saveHoliday(widget.store.me, h?.id, {'name': name.text.trim(), 'date': dateKeyOf(d), 'category': cat, 'region': region, 'description': desc.text.trim(), 'paid': paid, 'assignedTo': assigned}, old: h), ok: h == null ? 'Holiday added' : 'Holiday updated');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> confirmDelete(Hol h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(title: const Text('Delete holiday?'), content: Text('${h.name} · ${fmtDate(h.date)}'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete'))]),
    );
    if (ok == true && mounted) await guarded(context, () => Repo.deleteHoliday(widget.store.me, h), ok: 'Holiday deleted');
  }

  @override
  Widget build(BuildContext c) {
    final s = widget.store;
    final yearList = s.holidays.where((h) => h.date.startsWith('$year')).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: () => edit(), icon: const Icon(Icons.add), label: const Text('Add holiday')),
      body: PageBody(children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => year--), icon: const Icon(Icons.chevron_left)),
          Text('$year', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          IconButton(onPressed: () => setState(() => year++), icon: const Icon(Icons.chevron_right)),
          const Spacer(),
          SegmentedButton<bool>(showSelectedIcon: false, segments: const [ButtonSegment(value: true, icon: Icon(Icons.calendar_month)), ButtonSegment(value: false, icon: Icon(Icons.list))], selected: {calendar}, onSelectionChanged: (v) => setState(() => calendar = v.first)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: addDefaults, icon: const Icon(Icons.auto_awesome), label: Text('Load default Indian holidays for $year')),
          Badge2('${yearList.length} holidays in $year', Colors.indigo),
        ]),
        const SizedBox(height: 12),
        if (calendar)
          HolidayCalendar(key: ValueKey(year), holidays: s.holidays, settings: s.settings, onTapHoliday: (h) => edit(h: h), onTapEmptyDay: (d) => edit(date: d))
        else ...[
          if (yearList.isEmpty) const Card(child: Empty('No holidays for this year. Load the defaults or add your own.', icon: Icons.event_busy_outlined)),
          for (final h in yearList)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Icon(Icons.celebration, color: holidayColor(h.category)),
                  title: Text(h.name),
                  subtitle: Text('${fmtDate(h.date)} · ${h.category} · ${h.region}\n${h.paid ? 'Paid' : 'Unpaid'}${h.assigned.isEmpty ? ' · All employees' : ' · ${h.assigned.length} employee(s)'}'),
                  isThreeLine: true,
                  onTap: () => edit(h: h),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => confirmDelete(h)),
                ),
              ),
            ),
        ],
        const SizedBox(height: 70),
      ]),
    );
  }
}

// ------------------------------------------------------------------ Settings
class AdminSettingsPage extends StatefulWidget {
  final AppStore store;
  const AdminSettingsPage({super.key, required this.store});
  @override
  State<AdminSettingsPage> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettingsPage> {
  late AppSettings st = widget.store.settings;
  late final company = TextEditingController(text: st.company);
  bool busy = false;

  Future<void> save() async {
    setState(() => busy = true);
    final n = AppSettings(shiftStart: st.shiftStart, graceMinutes: st.graceMinutes, fullDayHours: st.fullDayHours, halfDayHours: st.halfDayHours, weeklyOffs: st.weeklyOffs, company: company.text.trim());
    await guarded(context, () => Repo.saveSettings(widget.store.me, widget.store.settings, n), ok: 'Settings saved');
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final p = st.shiftStart.split(':');
    final t = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    return PageBody(maxWidth: 640, children: [
      const SectionTitle('Work rules'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: company, decoration: const InputDecoration(labelText: 'Company name')),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.access_time),
              label: Text('Shift start (IST): ${t.format(c)}'),
              onPressed: () async {
                final x = await showTimePicker(context: c, initialTime: t);
                if (x != null) setState(() => st = AppSettings(shiftStart: '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}', graceMinutes: st.graceMinutes, fullDayHours: st.fullDayHours, halfDayHours: st.halfDayHours, weeklyOffs: st.weeklyOffs, company: st.company));
              },
            ),
            const SizedBox(height: 14),
            Text('Late grace period: ${st.graceMinutes} min'),
            Slider(value: st.graceMinutes.toDouble(), min: 0, max: 60, divisions: 12, label: '${st.graceMinutes}', onChanged: (v) => setState(() => st = AppSettings(shiftStart: st.shiftStart, graceMinutes: v.round(), fullDayHours: st.fullDayHours, halfDayHours: st.halfDayHours, weeklyOffs: st.weeklyOffs, company: st.company))),
            Text('Half day if worked less than: ${st.halfDayHours.toStringAsFixed(1)} h'),
            Slider(value: st.halfDayHours, min: 1, max: 8, divisions: 14, label: st.halfDayHours.toStringAsFixed(1), onChanged: (v) => setState(() => st = AppSettings(shiftStart: st.shiftStart, graceMinutes: st.graceMinutes, fullDayHours: st.fullDayHours, halfDayHours: v, weeklyOffs: st.weeklyOffs, company: st.company))),
            const SizedBox(height: 8),
            const Text('Weekly off days'),
            Wrap(spacing: 6, children: [
              for (var i = 0; i < 7; i++)
                FilterChip(
                  label: Text(names[i]),
                  selected: st.weeklyOffs.contains(i + 1),
                  onSelected: (v) => setState(() {
                    final l = [...st.weeklyOffs];
                    v ? l.add(i + 1) : l.remove(i + 1);
                    st = AppSettings(shiftStart: st.shiftStart, graceMinutes: st.graceMinutes, fullDayHours: st.fullDayHours, halfDayHours: st.halfDayHours, weeklyOffs: l, company: st.company);
                  }),
                ),
            ]),
            const SizedBox(height: 16),
            FilledButton(onPressed: busy ? null : save, child: const Text('Save settings')),
          ]),
        ),
      ),
      const SectionTitle('Account'),
      Card(
        child: Column(children: [
          ListTile(leading: const Icon(Icons.admin_panel_settings_outlined), title: Text(widget.store.me.fullName), subtitle: Text(widget.store.me.email)),
          ListTile(leading: const Icon(Icons.password), title: const Text('Change admin password'), onTap: () => changePasswordDialog(c)),
          ListTile(leading: const Icon(Icons.history_edu_outlined), title: const Text('Audit log'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AuditLogPage()))),
          ValueListenableBuilder(
            valueListenable: themeMode,
            builder: (c, m, _) => ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark mode'),
              trailing: SegmentedButton<ThemeMode>(showSelectedIcon: false, segments: const [ButtonSegment(value: ThemeMode.system, label: Text('Auto')), ButtonSegment(value: ThemeMode.light, label: Text('Off')), ButtonSegment(value: ThemeMode.dark, label: Text('On'))], selected: {m}, onSelectionChanged: (v) => setThemePref(v.first)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () => auth.signOut(), icon: const Icon(Icons.logout), label: const Text('Logout')),
    ]);
  }
}

class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Audit log')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: Repo.auditLogs(),
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return Empty(friendlyError(s.error!), icon: Icons.error_outline);
            final l = s.data!;
            if (l.isEmpty) return const Empty('No audit entries yet');
            return PageBody(children: [
              for (final e in l)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text('${e['action']}  ·  ${e['entityType']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('By ${e['actorName']} · ${fmtDateTime((e['timestamp'] as dynamic)?.toDate())}\nOld: ${e['oldValue'] ?? '-'}\nNew: ${e['newValue'] ?? '-'}'),
                      isThreeLine: true,
                    ),
                  ),
                ),
            ]);
          },
        ),
      );
}
