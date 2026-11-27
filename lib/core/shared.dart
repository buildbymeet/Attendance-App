import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'capture.dart';
import 'ist.dart';
import 'models.dart';
import 'ui.dart';

const holidayCategories = ['National', 'Festival', 'Regional', 'Company Holiday'];

Color holidayColor(String cat) {
  switch (cat) {
    case 'National':
      return Colors.indigo;
    case 'Regional':
      return Colors.teal;
    case 'Company Holiday':
      return Colors.brown;
    default:
      return Colors.deepPurple;
  }
}

/// Month grid with highlighted holidays + the month's holiday list underneath.
class HolidayCalendar extends StatefulWidget {
  final List<Hol> holidays;
  final AppSettings settings;
  final void Function(Hol)? onTapHoliday;
  final void Function(String date)? onTapEmptyDay;
  final Widget Function(Hol)? trailing;
  const HolidayCalendar({super.key, required this.holidays, required this.settings, this.onTapHoliday, this.onTapEmptyDay, this.trailing});
  @override
  State<HolidayCalendar> createState() => _HolidayCalendarState();
}

class _HolidayCalendarState extends State<HolidayCalendar> {
  late DateTime month = DateTime(nowIst().year, nowIst().month);

  void _move(int d) => setState(() => month = DateTime(month.year, month.month + d));

  @override
  Widget build(BuildContext c) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final lead = first.weekday % 7; // Sunday-first grid
    final today = istDateKey();
    final byDate = <String, List<Hol>>{};
    for (final h in widget.holidays) {
      (byDate[h.date] ??= []).add(h);
    }
    final monthKey = DateFormat('yyyy-MM').format(month);
    final list = widget.holidays.where((h) => h.date.startsWith(monthKey)).toList()..sort((a, b) => a.date.compareTo(b.date));
    final cs = Theme.of(c).colorScheme;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              IconButton(onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(child: Center(child: Text(fmtMonth(month), style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)))),
              IconButton(onPressed: () => _move(1), icon: const Icon(Icons.chevron_right)),
            ]),
            Row(children: [for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S']) Expanded(child: Center(child: Text(d, style: TextStyle(color: cs.outline, fontWeight: FontWeight.w600))))]),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.05,
              children: [
                for (var i = 0; i < lead; i++) const SizedBox(),
                for (var d = 1; d <= days; d++)
                  Builder(builder: (c) {
                    final key = dateKeyOf(DateTime(month.year, month.month, d));
                    final hs = byDate[key] ?? const [];
                    final isHol = hs.isNotEmpty;
                    final off = widget.settings.isWeeklyOff(key);
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (isHol && widget.onTapHoliday != null && hs.length == 1) {
                          widget.onTapHoliday!(hs.first);
                        } else if (isHol) {
                          showModalBottomSheet(context: c, builder: (_) => ListView(shrinkWrap: true, children: [for (final h in hs) ListTile(title: Text(h.name), subtitle: Text(h.category), onTap: () { Navigator.pop(c); widget.onTapHoliday?.call(h); })]));
                        } else {
                          widget.onTapEmptyDay?.call(key);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isHol ? holidayColor(hs.first.category).withValues(alpha: 0.18) : null,
                          border: key == today ? Border.all(color: cs.primary, width: 2) : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('$d', style: TextStyle(fontWeight: isHol ? FontWeight.w800 : FontWeight.w500, color: isHol ? holidayColor(hs.first.category) : off ? cs.outline : null)),
                          if (isHol) Container(width: 5, height: 5, margin: const EdgeInsets.only(top: 2), decoration: BoxDecoration(color: holidayColor(hs.first.category), shape: BoxShape.circle)),
                        ]),
                      ),
                    );
                  }),
              ],
            ),
          ]),
        ),
      ),
      SectionTitle('Holidays in ${DateFormat('MMMM').format(month)}'),
      if (list.isEmpty) const Card(child: Empty('No holidays this month', icon: Icons.event_busy_outlined)),
      for (final h in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              onTap: widget.onTapHoliday == null ? null : () => widget.onTapHoliday!(h),
              leading: CircleAvatar(
                backgroundColor: holidayColor(h.category).withValues(alpha: 0.15),
                child: Text(h.date.substring(8), style: TextStyle(color: holidayColor(h.category), fontWeight: FontWeight.w800)),
              ),
              title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${DateFormat('EEEE').format(parseDateKey(h.date))} · ${h.category} · ${h.region}\n${h.paid ? 'Paid' : 'Unpaid'} holiday${h.description.isEmpty ? '' : ' · ${h.description}'}'),
              isThreeLine: true,
              trailing: widget.trailing?.call(h),
            ),
          ),
        ),
    ]);
  }
}

/// Details of one attendance record: times, hours, both selfies, map links.
void showAttendanceDetail(BuildContext context, Att a, {Widget? action}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (c, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        Text(a.userName.isEmpty ? 'Attendance' : a.userName, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        Text(fmtDate(a.date)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          Badge2(a.typeLabel, a.isManual ? Colors.deepPurple : Colors.indigo),
          if (a.type == 'admin') const Badge2('Added by Admin', Colors.brown),
          if (a.corrected) const Badge2('Corrected by Admin', Colors.orange),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _kv('Check-in', fmtTime(a.inTime))),
          Expanded(child: _kv('Check-out', fmtTime(a.outTime))),
          Expanded(child: _kv('Hours', fmtDuration(a.worked))),
        ]),
        const Divider(height: 28),
        _punch(c, 'Check-in', a.inSelfie, a.inLat, a.inLng, a.inAcc, a.inAddr, a.inDevice),
        const Divider(height: 28),
        _punch(c, 'Check-out', a.outSelfie, a.outLat, a.outLng, a.outAcc, a.outAddr, a.outDevice),
        if (action != null) ...[const SizedBox(height: 16), action],
      ]),
    ),
  );
}

Widget _kv(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(k, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))]);

Widget _punch(BuildContext c, String title, String? selfie, double? lat, double? lng, double? acc, String? addr, String? device) {
  if (selfie == null && lat == null) return Text('$title: no data', style: TextStyle(color: Theme.of(c).colorScheme.outline));
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SelfieView(selfie),
      const SizedBox(width: 12),
      Expanded(
        child: lat == null
            ? const Text('No location')
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${lat.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}'),
                if (acc != null) Text('Accuracy ±${acc.round()} m', style: Theme.of(c).textTheme.bodySmall),
                if (addr != null && addr.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(addr, style: Theme.of(c).textTheme.bodySmall)),
                if (device != null && device.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(device, style: Theme.of(c).textTheme.labelSmall)),
                TextButton.icon(onPressed: () => openMap(lat, lng), icon: const Icon(Icons.map_outlined), label: const Text('Open in Maps')),
              ]),
      ),
    ]),
    if (lat != null) ...[
      const SizedBox(height: 8),
      SizedBox(height: 150, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: LocationMap(point: LatLng(lat, lng!), accuracy: acc, interactive: true))),
    ],
  ]);
}

/// One row in a history list.
class AttendanceTile extends StatelessWidget {
  final String date;
  final DayInfo info;
  final VoidCallback? onTap;
  final String? title;
  const AttendanceTile({super.key, required this.date, required this.info, this.onTap, this.title});
  @override
  Widget build(BuildContext c) {
    final a = info.att;
    final col = kindColor(info);
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: col.withValues(alpha: 0.14),
          child: Text(date.substring(8), style: TextStyle(color: col, fontWeight: FontWeight.w800)),
        ),
        title: Text(title ?? fmtDate(date), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(a != null
            ? 'In ${fmtTime(a.inTime)} · Out ${fmtTime(a.outTime)} · ${fmtDuration(a.worked)}${a.isManual ? '\nManual – Admin Approved' : ''}'
            : (info.holiday?.name ?? '')),
        isThreeLine: a != null && a.isManual,
        trailing: Badge2(info.label, col),
      ),
    );
  }
}
