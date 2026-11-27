import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin/admin_app.dart';
import 'auth/auth_pages.dart';
import 'core/models.dart';
import 'core/repo.dart';
import 'core/ui.dart';
import 'firebase_options.dart';
import 'user/user_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadThemePref();
  if (!DefaultFirebaseOptions.isConfigured) {
    runApp(const _App(home: _SetupNeeded()));
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // "Remember me" unchecked on last login -> drop the persisted session on next launch.
  try {
    final p = await SharedPreferences.getInstance();
    if (p.getBool('remember') == false && FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
  } catch (_) {}
  runApp(const _App(home: Gate()));
}

class _App extends StatelessWidget {
  final Widget home;
  const _App({required this.home});
  @override
  Widget build(BuildContext c) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode,
        builder: (c, m, _) => MaterialApp(
          title: 'Attendance',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: m,
          home: home,
        ),
      );
}

class _SetupNeeded extends StatelessWidget {
  const _SetupNeeded();
  @override
  Widget build(BuildContext c) => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.settings_suggest_outlined, size: 56),
              SizedBox(height: 12),
              Text('Firebase is not configured yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text('Run `flutterfire configure` in the project folder (see SETUP.md) to generate lib/firebase_options.dart, then rebuild.', textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}

/// Routes by auth state -> profile -> role.
class Gate extends StatelessWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext c) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) return const _Splash();
          final u = s.data;
          if (u == null) return const LoginPage();
          return _ProfileLoader(key: ValueKey(u.uid), uid: u.uid);
        },
      );
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext c) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _ProfileLoader extends StatefulWidget {
  final String uid;
  const _ProfileLoader({super.key, required this.uid});
  @override
  State<_ProfileLoader> createState() => _ProfileLoaderState();
}

class _ProfileLoaderState extends State<_ProfileLoader> {
  AppStore? store;
  bool signedOutForStatus = false;

  @override
  void dispose() {
    store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.doc('users/${widget.uid}').snapshots(),
        builder: (c, s) {
          if (s.hasError) return _Msg('Could not load your profile.\n${friendlyError(s.error!)}');
          if (!s.hasData || !s.data!.exists) {
            // Profile is written right after sign-up; show a spinner meanwhile.
            return const _Splash();
          }
          final e = Emp(s.data!.id, s.data!.data()!);
          if (!e.active) {
            if (!signedOutForStatus) {
              signedOutForStatus = true;
              WidgetsBinding.instance.addPostFrameCallback((_) => auth.signOut());
            }
            return const _Msg('Your account has been deactivated. Contact your administrator.');
          }
          if (store == null) {
            store = AppStore(e);
          } else {
            store!.updateMe(e);
          }
          return ListenableBuilder(
            listenable: store!,
            builder: (c, _) => !store!.loaded ? const _Splash() : (e.isAdmin ? AdminApp(store: store!) : UserApp(store: store!)),
          );
        },
      );
}

class _Msg extends StatelessWidget {
  final String text;
  const _Msg(this.text);
  @override
  Widget build(BuildContext c) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(text, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: auth.signOut, child: const Text('Logout')),
            ]),
          ),
        ),
      );
}
