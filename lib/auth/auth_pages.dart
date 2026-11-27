import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/ist.dart';
import '../core/repo.dart';
import '../core/ui.dart';

Future<void> setRemember(bool v) async {
  try {
    (await SharedPreferences.getInstance()).setBool('remember', v);
  } catch (_) {}
}

class _AuthScaffold extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  const _AuthScaffold({required this.title, required this.subtitle, required this.children});
  @override
  Widget build(BuildContext c) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Icon(Icons.how_to_reg, size: 56, color: brand),
                  const SizedBox(height: 12),
                  Text(title, textAlign: TextAlign.center, style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(c).colorScheme.outline)),
                  const SizedBox(height: 28),
                  ...children,
                ]),
              ),
            ),
          ),
        ),
      );
}

String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
String? _email(String? v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email';

class LoginPage extends StatefulWidget {
  final bool admin;
  const LoginPage({super.key, this.admin = false});
  @override
  State<LoginPage> createState() => _LoginState();
}

class _LoginState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), pass = TextEditingController();
  bool busy = false, remember = true, hide = true;

  Future<void> go() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    await setRemember(remember);
    if (!mounted) return;
    final ok = await guarded(context, () => Repo.login(email.text, pass.text, admin: widget.admin));
    if (!mounted) return;
    setState(() => busy = false);
    if (ok && Navigator.of(context).canPop()) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext c) {
    final a = widget.admin;
    return _AuthScaffold(
      title: a ? 'Admin Login' : 'Welcome back',
      subtitle: a ? 'Administrators only' : 'Sign in to mark your attendance',
      children: [
        Form(
          key: form,
          child: Column(children: [
            TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                validator: _email),
            const SizedBox(height: 14),
            TextFormField(
                controller: pass,
                obscureText: hide,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hide = !hide))),
                validator: _req,
                onFieldSubmitted: (_) => go()),
          ]),
        ),
        Row(children: [
          Checkbox(value: remember, onChanged: (v) => setState(() => remember = v ?? true)),
          const Text('Remember me'),
          const Spacer(),
          TextButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const ForgotPage())), child: const Text('Forgot password?')),
        ]),
        const SizedBox(height: 8),
        FilledButton(onPressed: busy ? null : go, child: busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('Sign in')),
        const SizedBox(height: 16),
        if (!a) ...[
          OutlinedButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const SignUpPage())), child: const Text('Create employee account')),
          const SizedBox(height: 8),
          TextButton.icon(
              onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const LoginPage(admin: true))),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Admin login')),
        ] else
          TextButton.icon(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.arrow_back), label: const Text('Employee login')),
      ],
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpState();
}

class _SignUpState extends State<SignUpPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), user = TextEditingController(), email = TextEditingController(), phone = TextEditingController(), pass = TextEditingController(), pass2 = TextEditingController();
  bool busy = false, hide = true;

  Future<void> go() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    await setRemember(true);
    if (!mounted) return;
    final ok = await guarded(
        context,
        () => Repo.signUp(
            fullName: name.text,
            username: user.text,
            email: email.text,
            phone: normalizeIndianPhone(phone.text)!,
            password: pass.text));
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext c) => _AuthScaffold(
        title: 'Create account',
        subtitle: 'Register as an employee',
        children: [
          Form(
            key: form,
            child: Column(children: [
              TextFormField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)), validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your full name' : null),
              const SizedBox(height: 14),
              TextFormField(
                  controller: user,
                  decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.alternate_email), helperText: 'Letters, numbers, . and _ (3–20)'),
                  validator: (v) => RegExp(r'^[A-Za-z0-9_.]{3,20}$').hasMatch((v ?? '').trim()) ? null : 'Use 3–20 letters, numbers, . or _'),
              const SizedBox(height: 14),
              TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)), validator: _email),
              const SizedBox(height: 14),
              TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91 ', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) => normalizeIndianPhone(v ?? '') == null ? 'Enter a valid 10-digit Indian mobile number' : null),
              const SizedBox(height: 14),
              TextFormField(
                  controller: pass,
                  obscureText: hide,
                  decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), helperText: 'At least 8 characters, with a letter and a number', suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hide = !hide))),
                  validator: (v) => RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$').hasMatch(v ?? '') ? null : 'Min 8 characters with a letter and a number'),
              const SizedBox(height: 14),
              TextFormField(controller: pass2, obscureText: hide, decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_outline)), validator: (v) => v == pass.text ? null : 'Passwords do not match'),
            ]),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: busy ? null : go, child: busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('Sign up')),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Already have an account? Sign in')),
        ],
      );
}

class ForgotPage extends StatefulWidget {
  const ForgotPage({super.key});
  @override
  State<ForgotPage> createState() => _ForgotState();
}

class _ForgotState extends State<ForgotPage> {
  final email = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false, sent = false;

  Future<void> go() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    // Always report success so the form cannot be used to discover registered emails.
    try {
      await Repo.resetPassword(email.text);
    } catch (_) {}
    if (mounted) {
      setState(() {
        busy = false;
        sent = true;
      });
    }
  }

  @override
  Widget build(BuildContext c) => _AuthScaffold(
        title: 'Reset password',
        subtitle: "We'll email you a secure link to set a new password",
        children: sent
            ? [
                const Icon(Icons.mark_email_read_outlined, size: 48, color: Colors.green),
                const SizedBox(height: 12),
                const Text('If an account exists for that email, a password-reset link is on its way. Check your inbox (and spam).', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Back to sign in')),
              ]
            : [
                Form(key: form, child: TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)), validator: _email)),
                const SizedBox(height: 20),
                FilledButton(onPressed: busy ? null : go, child: const Text('Send reset link')),
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('Back')),
              ],
      );
}
