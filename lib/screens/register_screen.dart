import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/theme.dart';
import '../data/controllers/host_controller.dart';
import 'host_shell_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _bio = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _username,
      _email,
      _mobile,
      _bio,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value, String label) =>
      (value == null || value.trim().isEmpty) ? 'Enter $label' : null;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final error = await Get.find<HostController>().register(
      firstName: _firstName.text,
      lastName: _lastName.text,
      username: _username.text,
      email: _email.text,
      mobile: _mobile.text,
      bio: _bio.text,
      password: _password.text,
      passwordConfirmation: _confirmation.text,
    );
    if (!mounted) return;

    if (error == null) {
      Get.offAll<void>(() => const HostShellScreen());
      Get.snackbar(
        'Welcome to Dejen Stays',
        'Your host profile is pending review. You can prepare your profile now.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    Get.snackbar(
      'Registration failed',
      error,
      backgroundColor: AppColors.danger,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Become a host')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.home_work_outlined, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Create your account, complete your host profile, and submit properties for review.',
                        style: TextStyle(color: Colors.white, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.givenName],
                      decoration: const InputDecoration(
                        labelText: 'First name',
                      ),
                      validator: (value) => _required(value, 'your first name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.familyName],
                      decoration: const InputDecoration(labelText: 'Last name'),
                      validator: (value) => _required(value, 'your last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _username,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.alternate_email),
                  helperText:
                      'At least 6 lowercase letters, numbers, or underscores',
                ),
                validator: (value) {
                  final username = (value ?? '').trim();
                  if (username.length < 6) return 'Use at least 6 characters';
                  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
                    return 'Use lowercase letters, numbers, or underscores only';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (email.isEmpty) return 'Enter your email';
                  if (!GetUtils.isEmail(email)) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  labelText: 'Phone number (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bio,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'About you (optional)',
                  prefixIcon: Icon(Icons.badge_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _password,
                label: 'Password',
                obscure: _obscurePassword,
                onToggle: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                validator: (value) => (value ?? '').length < 6
                    ? 'Use at least 6 characters'
                    : null,
              ),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _confirmation,
                label: 'Confirm password',
                obscure: _obscureConfirmation,
                onToggle: () => setState(
                  () => _obscureConfirmation = !_obscureConfirmation,
                ),
                validator: (value) =>
                    value != _password.text ? 'Passwords do not match' : null,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              Obx(() {
                final busy = Get.find<HostController>().busy.value;
                return FilledButton.icon(
                  onPressed: busy ? null : _submit,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1),
                  label: Text(
                    busy ? 'Creating account...' : 'Create host account',
                  ),
                );
              }),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Get.back<void>(),
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?) validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscure,
    textInputAction: onSubmitted == null
        ? TextInputAction.next
        : TextInputAction.done,
    autofillHints: const [AutofillHints.newPassword],
    onFieldSubmitted: onSubmitted,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: obscure ? 'Show password' : 'Hide password',
        onPressed: onToggle,
        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
      ),
    ),
    validator: validator,
  );
}
