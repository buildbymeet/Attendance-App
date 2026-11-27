import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'repo.dart';

const brand = Color(0xFF3F51B5);
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> loadThemePref() async {
  try {
    final p = await SharedPreferences.getInstance();
    themeMode.value = {'dark': ThemeMode.dark, 'light': ThemeMode.light}[p.getString('theme')] ?? ThemeMode.system;
  } catch (_) {}
}

Future<void> setThemePref(ThemeMode m) async {
  themeMode.value = m;
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString('theme', m.name);
  } catch (_) {}
}

ThemeData buildTheme(Brightness b) {
  final cs = ColorScheme.fromSeed(seedColor: brand, brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF5F6FA) : null,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    appBarTheme: const AppBarTheme(centerTitle: false, scrolledUnderElevation: 0),
  );
}

void toast(BuildContext c, String m, {bool error = false}) {
  final cs = Theme.of(c).colorScheme;
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: error ? cs.onError : Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(m, style: TextStyle(color: error ? cs.onError : Colors.white))),
      ]),
      backgroundColor: error ? cs.error : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
}

/// Runs [fn], shows a toast with the result and returns true on success.
Future<bool> guarded(BuildContext c, Future<void> Function() fn, {String? ok}) async {
  try {
    await fn();
    if (ok != null && c.mounted) toast(c, ok);
    return true;
  } catch (e) {
    if (c.mounted) toast(c, friendlyError(e), error: true);
    return false;
  }
}

Color kindColor(DayInfo i) {
  switch (i.kind) {
    case DayKind.present:
      return i.late ? Colors.orange.shade700 : Colors.green.shade600;
    case DayKind.halfDay:
      return Colors.amber.shade800;
    case DayKind.absent:
      return Colors.red.shade600;
    case DayKind.holiday:
      return Colors.purple.shade400;
    case DayKind.weeklyOff:
      return Colors.blueGrey;
    case DayKind.leave:
      return Colors.teal;
    case DayKind.missingPunch:
      return Colors.deepOrange;
    case DayKind.working:
      return Colors.blue;
    case DayKind.notYet:
    case DayKind.upcoming:
      return Colors.grey;
  }
}

Color reqColor(String s) => s == 'approved' ? Colors.green.shade600 : s == 'rejected' ? Colors.red.shade600 : Colors.orange.shade700;

class Badge2 extends StatelessWidget {
  final String text;
  final Color color;
  const Badge2(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      );
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? color;
  final VoidCallback? onTap;
  const StatCard(this.icon, this.label, this.value, {super.key, this.color, this.onTap});
  @override
  Widget build(BuildContext c) {
    final col = color ?? Theme.of(c).colorScheme.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(backgroundColor: col.withValues(alpha: 0.14), child: Icon(icon, color: col)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text(label, style: Theme.of(c).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
          ]),
        ),
      ),
    );
  }
}

/// Responsive grid of stat cards (2 columns on phones, more on wide screens).
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  const StatGrid(this.children, {super.key});
  @override
  Widget build(BuildContext c) => LayoutBuilder(builder: (c, k) {
        final cols = k.maxWidth > 900 ? 4 : k.maxWidth > 600 ? 3 : 2;
        const gap = 10.0;
        final w = (k.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final x in children) SizedBox(width: w, child: x)]);
      });
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ]),
      );
}

class Empty extends StatelessWidget {
  final String text;
  final IconData icon;
  const Empty(this.text, {super.key, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Theme.of(c).colorScheme.outline),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(c).colorScheme.outline)),
        ])),
      );
}

/// Centered, max-width page body so tablets/desktop don't stretch forms.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  final Future<void> Function()? onRefresh;
  const PageBody({super.key, required this.children, this.maxWidth = 900, this.onRefresh});
  @override
  Widget build(BuildContext c) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: children,
    );
    final body = Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: list));
    return onRefresh == null ? body : RefreshIndicator(onRefresh: onRefresh!, child: body);
  }
}

class SelfieView extends StatelessWidget {
  final String? id;
  final double size;
  const SelfieView(this.id, {super.key, this.size = 90});
  @override
  Widget build(BuildContext c) {
    if (id == null || id!.isEmpty) return _box(c, const Icon(Icons.no_photography_outlined));
    return FutureBuilder(
      future: Repo.selfie(id),
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return _box(c, const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
        final b = s.data;
        if (b == null) return _box(c, const Icon(Icons.broken_image_outlined));
        return GestureDetector(
          onTap: () => showDialog(context: c, builder: (_) => Dialog(child: InteractiveViewer(child: Image.memory(b)))),
          child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(b, width: size, height: size * 1.25, fit: BoxFit.cover)),
        );
      },
    );
  }

  Widget _box(BuildContext c, Widget child) => Container(
        width: size,
        height: size * 1.25,
        decoration: BoxDecoration(color: Theme.of(c).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
        child: Center(child: child),
      );
}

class NavItem {
  final String label;
  final IconData icon;
  final Widget Function(void Function(int) go) build;
  const NavItem(this.label, this.icon, this.build);
}

/// Sidebar on wide screens, bottom navigation + drawer on phones.
class Shell extends StatefulWidget {
  final String title;
  final List<NavItem> items;
  final Emp me;
  final int mobileTabs;
  final Map<int, int> badges;
  final VoidCallback onLogout;
  const Shell({super.key, required this.title, required this.items, required this.me, required this.onLogout, this.mobileTabs = 4, this.badges = const {}});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  final key = GlobalKey<ScaffoldState>();
  void go(int v) => setState(() => i = v);

  Widget _ic(int idx, IconData ic) {
    final n = widget.badges[idx] ?? 0;
    return n > 0 ? Badge(label: Text('$n'), child: Icon(ic)) : Icon(ic);
  }

  @override
  Widget build(BuildContext c) {
    final wide = MediaQuery.of(c).size.width >= 900;
    final it = widget.items;
    final page = AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: KeyedSubtree(key: ValueKey(i), child: it[i].build(go)));
    final bar = AppBar(
      title: Text(it[i].label),
      actions: [
        IconButton(
          tooltip: 'Toggle theme',
          icon: Icon(Theme.of(c).brightness == Brightness.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          onPressed: () => setThemePref(Theme.of(c).brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark),
        ),
      ],
    );
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            extended: true,
            selectedIndex: i,
            onDestinationSelected: go,
            leading: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.how_to_reg, color: brand),
                const SizedBox(width: 8),
                Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(padding: const EdgeInsets.all(12), child: TextButton.icon(onPressed: widget.onLogout, icon: const Icon(Icons.logout), label: const Text('Logout'))),
              ),
            ),
            destinations: [for (var k = 0; k < it.length; k++) NavigationRailDestination(icon: _ic(k, it[k].icon), label: Text(it[k].label))],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: Scaffold(appBar: bar, body: page)),
        ]),
      );
    }
    final n = widget.mobileTabs;
    return Scaffold(
      key: key,
      appBar: bar,
      drawer: Drawer(
        child: SafeArea(
          child: Column(children: [
            UserAccountsDrawerHeader(
              accountName: Text(widget.me.fullName),
              accountEmail: Text(widget.me.email),
              currentAccountPicture: CircleAvatar(child: Text(widget.me.fullName.isEmpty ? '?' : widget.me.fullName[0].toUpperCase())),
            ),
            for (var k = 0; k < it.length; k++)
              ListTile(
                leading: _ic(k, it[k].icon),
                title: Text(it[k].label),
                selected: i == k,
                onTap: () {
                  Navigator.pop(c);
                  go(k);
                },
              ),
            const Spacer(),
            const Divider(),
            ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: widget.onLogout),
          ]),
        ),
      ),
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: i < n ? i : n,
        onDestinationSelected: (v) => v == n ? key.currentState?.openDrawer() : go(v),
        destinations: [
          for (var k = 0; k < n; k++) NavigationDestination(icon: _ic(k, it[k].icon), label: it[k].label),
          const NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}
