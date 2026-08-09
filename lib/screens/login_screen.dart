import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/push.dart';
import '../core/session.dart';
import 'conversations_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _server = TextEditingController(text: Session.apiBaseUrl);
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Session.saveServer(_server.text);
      await Api.login(_user.text.trim(), _pass.text);
      await Push.registerIfLoggedIn();
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ConversationsScreen()));
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              children: [
                const Icon(Icons.support_agent, size: 72, color: Color(0xFFB91C1C)),
                const SizedBox(height: 8),
                Text('دعم ركاب',
                    style: Theme.of(context).textTheme.headlineSmall),
                const Text('تطبيق فريق الدعم الفني'),
                const SizedBox(height: 24),
                TextField(
                  controller: _user,
                  decoration: const InputDecoration(
                      labelText: 'اسم المستخدم', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  onSubmitted: (_) => _login(),
                  decoration: const InputDecoration(
                      labelText: 'كلمة المرور', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _server,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                      labelText: 'رابط الخادم', border: OutlineInputBorder()),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _login,
                    child: _busy
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('دخول'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
