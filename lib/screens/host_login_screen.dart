import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/theme.dart';
import '../data/controllers/host_controller.dart';
import 'register_screen.dart';
import 'host_shell_screen.dart';

class HostLoginScreen extends StatefulWidget {
  const HostLoginScreen({super.key});
  @override
  State<HostLoginScreen> createState() => _HostLoginScreenState();
}

class _HostLoginScreenState extends State<HostLoginScreen> {
  final user = TextEditingController();
  final password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool obscure = true;
  @override
  void dispose() {
    user.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final error = await Get.find<HostController>().login(
      user.text,
      password.text,
    );
    if (!mounted) return;
    if (error == null) {
      Get.offAll<void>(() => const HostShellScreen());
    } else {
      Get.snackbar(
        'Sign in failed',
        error,
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        children: [
          Container(
            color: AppColors.ink,
            padding: const EdgeInsets.fromLTRB(24, 38, 24, 32),
            child: Column(
              children: [
                Image.asset(
                  'assets/branding/dejen_logo_horizontal_dark.png',
                  height: 72,
                ),
                const SizedBox(height: 18),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apartment_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Stays Host',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome back',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Manage your homes, guests, calendar, and earnings.',
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: user,
                    decoration: const InputDecoration(
                      labelText: 'Username or email',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Enter your username or email'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: password,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: obscure ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Enter your password' : null,
                  ),
                  const SizedBox(height: 24),
                  Obx(
                    () => FilledButton.icon(
                      onPressed: Get.find<HostController>().busy.value
                          ? null
                          : submit,
                      icon: const Icon(Icons.login),
                      label: const Text('Sign in as host'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => Get.to<void>(() => const RegisterScreen()),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Create a host account'),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Use the same Dejen account you use across the platform.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
