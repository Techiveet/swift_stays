import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/theme.dart';
import '../data/controllers/host_controller.dart';

class HostProfileScreen extends StatefulWidget {
  const HostProfileScreen({super.key});

  @override
  State<HostProfileScreen> createState() => _HostProfileScreenState();
}

class _HostProfileScreenState extends State<HostProfileScreen> {
  final controller = Get.find<HostController>();
  final form = GlobalKey<FormState>();
  late final TextEditingController bio;
  late final TextEditingController languages;
  late final TextEditingController payoutAccount;
  String payoutProvider = 'bank';

  @override
  void initState() {
    super.initState();
    bio = TextEditingController(text: '${controller.profile['bio'] ?? ''}');
    languages = TextEditingController(
      text: ((controller.profile['languages'] as List?) ?? const []).join(', '),
    );
    payoutProvider = '${controller.profile['payout_provider'] ?? 'bank'}';
    payoutAccount = TextEditingController();
  }

  @override
  void dispose() {
    bio.dispose();
    languages.dispose();
    payoutAccount.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final error = await controller.saveProfile(
      bio: bio.text,
      languages: languages.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      payoutProvider: payoutProvider,
      payoutAccount: payoutAccount.text,
    );
    if (!mounted) return;
    if (error == null) {
      Get.back<void>();
      Get.snackbar('Profile saved', 'Your host details are up to date.');
    } else {
      Get.snackbar(
        'Could not save profile',
        error,
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Host profile')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'About your hosting',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Guests see this information when they review your property.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: bio,
            minLines: 4,
            maxLines: 7,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Host bio',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (value) => (value ?? '').trim().length < 20
                ? 'Tell guests a little more about yourself'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: languages,
            decoration: const InputDecoration(
              labelText: 'Languages',
              helperText: 'Separate languages with commas',
              prefixIcon: Icon(Icons.translate),
            ),
          ),
          const SizedBox(height: 24),
          Text('Payout setup', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            controller.profile['payout_configured'] == true
                ? 'A payout account is already protected on file. Enter a new one only to replace it.'
                : 'Add an account so earnings can be released after completed stays.',
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: payoutProvider,
            decoration: const InputDecoration(
              labelText: 'Payout method',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'bank', child: Text('Bank account')),
              DropdownMenuItem(value: 'telebirr', child: Text('Telebirr')),
              DropdownMenuItem(
                value: 'mobile_money',
                child: Text('Mobile money'),
              ),
            ],
            onChanged: (value) =>
                setState(() => payoutProvider = value ?? 'bank'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: payoutAccount,
            obscureText: true,
            decoration: InputDecoration(
              labelText: controller.profile['payout_configured'] == true
                  ? 'Replace payout account (optional)'
                  : 'Payout account',
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            validator: (value) =>
                controller.profile['payout_configured'] != true &&
                    (value ?? '').trim().isEmpty
                ? 'Enter your payout account'
                : null,
          ),
          const SizedBox(height: 24),
          Obx(
            () => FilledButton.icon(
              onPressed: controller.busy.value ? null : submit,
              icon: const Icon(Icons.save_outlined),
              label: Text(controller.busy.value ? 'Saving...' : 'Save profile'),
            ),
          ),
        ],
      ),
    ),
  );
}
