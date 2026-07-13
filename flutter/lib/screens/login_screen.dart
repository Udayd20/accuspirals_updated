import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final idCtl = TextEditingController();
  final pwCtl = TextEditingController();
  String? error;
  bool busy = false;

  Future<void> _submit() async {
    final id = idCtl.text.trim();
    if (id.isEmpty) {
      setState(() => error = 'Enter your employee ID');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final session = context.read<Session>();
    final data = context.read<AppData>();
    final err = await session.login(id, pwCtl.text);
    if (err != null) {
      if (mounted) {
        setState(() {
          busy = false;
          error = err;
        });
      }
      return;
    }
    await data.loadAll(session); // Boot is watching session and will show the shell
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF2A63AD), Color(0xFF14417C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 360,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 40, offset: Offset(0, 24))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('ACCUSPIRALS',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF14417C), letterSpacing: 1)),
                const SizedBox(height: 2),
                const Text('Tool & Consumables Inventory', style: TextStyle(color: Color(0xFF5A6B7F), fontSize: 12)),
                const SizedBox(height: 20),
                _field('EMPLOYEE ID', idCtl, hint: 'e.g. EMP102'),
                const SizedBox(height: 12),
                _field('PASSWORD', pwCtl, hint: 'your password', obscure: true, onSubmit: _submit),
                const SizedBox(height: 6),
                SizedBox(
                  height: 18,
                  child: error == null ? null : Text(error!, style: const TextStyle(color: Color(0xFFC0392B), fontSize: 12)),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : _submit,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF356EC0), padding: const EdgeInsets.symmetric(vertical: 13)),
                    child: busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Log in', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Your role is set by your account. Forgot your password? Ask an admin to reset it.',
                    textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7A8AA0), fontSize: 11, height: 1.6)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {String? hint, bool obscure = false, VoidCallback? onSubmit}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF5A6B7F), fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      TextField(
        controller: c,
        obscureText: obscure,
        onSubmitted: (_) => onSubmit?.call(),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFC4D2E2))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFC4D2E2))),
        ),
      ),
    ]);
  }
}
