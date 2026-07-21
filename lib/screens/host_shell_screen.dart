import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../data/controllers/host_controller.dart';
import 'host_login_screen.dart';
import 'booking_detail_screen.dart';
import 'host_profile_screen.dart';
import 'property_detail_screen.dart';
import 'property_form_screen.dart';

class HostShellScreen extends StatefulWidget {
  const HostShellScreen({super.key});
  @override
  State<HostShellScreen> createState() => _HostShellScreenState();
}

class _HostShellScreenState extends State<HostShellScreen> {
  int tab = 0;
  final controller = Get.find<HostController>();
  @override
  void initState() {
    super.initState();
    controller.refreshAll();
    controller.startRealtimeFallback();
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Host overview',
      'Properties',
      'Bookings',
      'Earnings',
      'Account',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[tab]),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.busy.value && controller.user.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.loadError.value.isNotEmpty && controller.user.isEmpty) {
          return _HostLoadFailure(controller: controller);
        }
        final dashboard = RefreshIndicator(
          onRefresh: controller.refreshAll,
          child: IndexedStack(
            index: tab,
            children: [
              _Overview(controller: controller),
              _Properties(controller: controller),
              _Bookings(controller: controller),
              _Earnings(controller: controller),
              _Account(controller: controller),
            ],
          ),
        );
        if (controller.loadError.value.isEmpty) return dashboard;
        return Column(
          children: [
            MaterialBanner(
              content: Text(controller.loadError.value),
              leading: const Icon(Icons.cloud_off_outlined),
              actions: [
                TextButton(
                  onPressed: controller.refreshAll,
                  child: const Text('Retry'),
                ),
              ],
            ),
            Expanded(child: dashboard),
          ],
        );
      }),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_work_outlined),
            selectedIcon: Icon(Icons.home_work),
            label: 'Homes',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class _HostLoadFailure extends StatelessWidget {
  const _HostLoadFailure({required this.controller});
  final HostController controller;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Host workspace unavailable',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(controller.loadError.value, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: controller.refreshAll,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
          TextButton(
            onPressed: () async {
              await controller.logout();
              Get.offAll<void>(() => const HostLoginScreen());
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    ),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.controller});
  final HostController controller;
  @override
  Widget build(BuildContext context) {
    final pending = controller.bookings
        .where((b) => '${b['status']}' == 'pending_host')
        .length;
    final arrivals = controller.bookings
        .where((b) => '${b['status']}' == 'confirmed')
        .length;
    final profileStatus = '${controller.profile['status'] ?? 'pending'}';
    return _List(
      children: [
        if (profileStatus != 'approved') ...[
          _ApprovalBanner(controller: controller, status: profileStatus),
          const SizedBox(height: 16),
        ],
        Container(
          color: AppColors.ink,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your hosting command center',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${controller.properties.length} ${controller.properties.length == 1 ? 'listing' : 'listings'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.apartment_rounded,
                color: Color(0xFF5DDB91),
                size: 46,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _MetricRow(
          items: [
            ('Requests', '$pending', Icons.notifications_active_outlined),
            ('Arrivals', '$arrivals', Icons.login),
            (
              'Pending ETB',
              _money(controller.earnings['pending']),
              Icons.payments_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Needs attention', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (pending == 0)
          const _Empty(icon: Icons.task_alt, text: 'You are caught up.')
        else
          ...controller.bookings
              .where((b) => '${b['status']}' == 'pending_host')
              .take(3)
              .map((b) => _BookingCard(booking: b, controller: controller)),
        const SizedBox(height: 20),
        Text('Portfolio health', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (controller.properties.isEmpty)
          _Empty(
            icon: Icons.add_home_work_outlined,
            text: profileStatus == 'approved'
                ? 'Add your first property to begin hosting.'
                : 'Create your first draft while Dejen reviews your account.',
            action: () => Get.to<void>(() => const PropertyFormScreen()),
            actionLabel: 'Add property',
          )
        else
          ...controller.properties
              .take(4)
              .map((p) => _PropertyCard(property: p, controller: controller)),
      ],
    );
  }
}

class _Properties extends StatelessWidget {
  const _Properties({required this.controller});
  final HostController controller;
  @override
  Widget build(BuildContext context) => _List(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Your homes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          FilledButton.icon(
            onPressed: () => Get.to<void>(() => const PropertyFormScreen()),
            icon: const Icon(Icons.add_home_work),
            label: const Text('Add'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (controller.properties.isEmpty)
        _Empty(
          icon: Icons.home_work_outlined,
          text: controller.profile['status'] == 'approved'
              ? 'No properties yet.'
              : 'Create a draft now. Publishing unlocks after approval.',
          action: () => Get.to<void>(() => const PropertyFormScreen()),
          actionLabel: 'Add property',
        )
      else
        ...controller.properties.map(
          (p) => _PropertyCard(property: p, controller: controller),
        ),
    ],
  );
}

class _Bookings extends StatelessWidget {
  const _Bookings({required this.controller});
  final HostController controller;
  @override
  Widget build(BuildContext context) => _List(
    children: [
      Text('Guest stays', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      const Text(
        'Identity status is shown without exposing private document files.',
      ),
      const SizedBox(height: 12),
      if (controller.bookings.isEmpty)
        const _Empty(icon: Icons.event_busy, text: 'No bookings yet.')
      else
        ...controller.bookings.map(
          (b) => _BookingCard(booking: b, controller: controller),
        ),
    ],
  );
}

class _Earnings extends StatelessWidget {
  const _Earnings({required this.controller});
  final HostController controller;
  @override
  Widget build(BuildContext context) => _List(
    children: [
      Text('Earnings summary', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      _MetricRow(
        items: [
          ('Gross', _money(controller.earnings['gross']), Icons.trending_up),
          (
            'Commission',
            _money(controller.earnings['commission']),
            Icons.receipt_long,
          ),
          (
            'Net',
            _money(controller.earnings['net']),
            Icons.account_balance_wallet,
          ),
        ],
      ),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payout readiness',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: 8),
              Text(
                'ETB ${_money(controller.earnings['pending'])} is pending or available for payout.',
              ),
              const SizedBox(height: 14),
              const LinearProgressIndicator(value: .72),
              const SizedBox(height: 8),
              const Text(
                'Payouts are released after checkout and the configured hold period.',
              ),
            ],
          ),
        ),
      ),
      if (controller.payouts.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text('Payout history', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...controller.payouts.map(
          (payout) => Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: Text('ETB ${_money(payout['net_amount'])}'),
              subtitle: Text('${payout['created_at'] ?? ''}'),
              trailing: _Status('${payout['status'] ?? 'pending'}'),
            ),
          ),
        ),
      ],
    ],
  );
}

class _Account extends StatelessWidget {
  const _Account({required this.controller});
  final HostController controller;
  @override
  Widget build(BuildContext context) => _List(
    children: [
      Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(
            '${controller.user['display_name'] ?? 'Dejen Stays Host'}',
          ),
          subtitle: Text(
            'Verification: ${controller.profile['status'] ?? 'not started'}',
          ),
        ),
      ),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Host verification'),
              subtitle: Text(
                controller.profile['identity_verified'] != true
                    ? 'Identity review required'
                    : 'Verified',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.to<void>(() => const HostProfileScreen()),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: const Text('Payout account'),
              subtitle: Text(
                controller.profile['payout_configured'] == true
                    ? 'Configured securely'
                    : 'Setup required',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.to<void>(() => const HostProfileScreen()),
            ),
            const Divider(height: 1),
            const ListTile(
              leading: Icon(Icons.support_agent),
              title: Text('Host support'),
              subtitle: Text('Get help with guests, payouts, or safety'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () async {
          await controller.logout();
          Get.offAll<void>(() => const HostLoginScreen());
        },
        icon: const Icon(Icons.logout),
        label: const Text('Sign out'),
      ),
    ],
  );
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property, required this.controller});
  final Map<String, dynamic> property;
  final HostController controller;
  @override
  Widget build(BuildContext context) {
    final status = '${property['status'] ?? 'draft'}';
    final address = property['address'] is Map
        ? Map<String, dynamic>.from(property['address'])
        : <String, dynamic>{};
    final cover = '${property['cover_image'] ?? ''}';
    final price = _map(property['price_from']);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Get.to<void>(() => PropertyDetailScreen(property: property)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cover.isNotEmpty) ...[
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    cover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: AppColors.border,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${property['title'] ?? 'Untitled home'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _Status(status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${address['neighborhood'] ?? ''}${address['city'] == null ? '' : ', ${address['city']}'}',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.bed_outlined, size: 20),
                  const SizedBox(width: 6),
                  Text('${property['bedrooms'] ?? 0} beds'),
                  const Spacer(),
                  Text(
                    '${price['currency'] ?? 'ETB'} ${_money(price['amount'])}/night',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _blockDates(context),
                icon: const Icon(Icons.event_busy),
                label: const Text('Block dates'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => Get.to<void>(
                  () => PropertyDetailScreen(property: property),
                ),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Manage listing'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _blockDates(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (range == null) return;
    final error = await controller.blockDates(
      property,
      range.start,
      range.end,
      'Blocked by host',
    );
    _message(
      error == null ? 'Calendar updated' : 'Could not update',
      error ?? 'These dates are now unavailable.',
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.controller});
  final Map<String, dynamic> booking;
  final HostController controller;
  @override
  Widget build(BuildContext context) {
    final status = '${booking['status'] ?? ''}';
    final property = booking['property'] is Map
        ? Map<String, dynamic>.from(booking['property'])
        : <String, dynamic>{};
    final verification = booking['identity_verification'] is Map
        ? Map<String, dynamic>.from(booking['identity_verification'])
        : <String, dynamic>{};
    final guest = _map(booking['guest']);
    return Card(
      child: InkWell(
        onTap: () => Get.to<void>(() => BookingDetailScreen(booking: booking)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${property['title'] ?? 'Stay booking'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _Status(status),
                ],
              ),
              Text('${booking['reference'] ?? ''}'),
              if ('${guest['name'] ?? ''}'.isNotEmpty)
                Text(
                  '${guest['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.date_range, size: 19),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${booking['check_in'] ?? ''} to ${booking['check_out'] ?? ''}',
                    ),
                  ),
                  Text(
                    'ETB ${_money(booking['total'])}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    verification['status'] == 'verified'
                        ? Icons.verified_user
                        : Icons.hourglass_top,
                    size: 19,
                    color: verification['status'] == 'verified'
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Guest documents: ${verification['status'] ?? 'not submitted'}',
                  ),
                ],
              ),
              if (status == 'pending_host') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _act(
                          'decline',
                          reason: 'Unable to host these dates',
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _act('approve'),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
              if (status == 'confirmed') ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: verification['status'] == 'verified'
                      ? () => _act('check-in')
                      : null,
                  icon: const Icon(Icons.login),
                  label: Text(
                    verification['status'] == 'verified'
                        ? 'Check in guest'
                        : 'Await ID approval',
                  ),
                ),
              ],
              if (status == 'checked_in') ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _act('check-out'),
                  icon: const Icon(Icons.logout),
                  label: const Text('Check out guest'),
                ),
              ],
              if (status == 'checked_out') ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _act('complete'),
                  icon: const Icon(Icons.task_alt),
                  label: const Text('Complete stay'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _act(String action, {String? reason}) async {
    final error = await controller.bookingAction(
      booking,
      action,
      reason: reason,
    );
    _message(
      error == null ? 'Booking updated' : 'Update failed',
      error ?? 'The guest and operations team have been notified.',
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: children);
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.text,
    this.action,
    this.actionLabel,
  });
  final IconData icon;
  final String text;
  final VoidCallback? action;
  final String? actionLabel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      children: [
        Icon(icon, size: 42, color: AppColors.muted),
        const SizedBox(height: 8),
        Text(text),
        if (action != null) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: action,
            icon: const Icon(Icons.arrow_forward),
            label: Text(actionLabel ?? 'Continue'),
          ),
        ],
      ],
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      value.replaceAll('_', ' '),
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.items});
  final List<(String, String, IconData)> items;
  @override
  Widget build(BuildContext context) => Row(
    children: items
        .map(
          (item) => Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Icon(item.$3, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 6),
                    FittedBox(
                      child: Text(
                        item.$2,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(item.$1, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        )
        .toList(),
  );
}

String _money(dynamic value) =>
    NumberFormat('#,##0.00').format(num.tryParse('$value') ?? 0);
void _message(String title, String body) => Get.snackbar(
  title,
  body,
  snackPosition: SnackPosition.BOTTOM,
  margin: const EdgeInsets.all(12),
);

class _ApprovalBanner extends StatelessWidget {
  const _ApprovalBanner({required this.controller, required this.status});
  final HostController controller;
  final String status;

  @override
  Widget build(BuildContext context) {
    final rejected = status == 'rejected';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: rejected ? const Color(0xFFFFE8E8) : const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rejected ? AppColors.danger : AppColors.warning,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                rejected ? Icons.error_outline : Icons.hourglass_top,
                color: rejected ? AppColors.danger : AppColors.warning,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rejected
                      ? 'Host review needs attention'
                      : 'Host approval is in progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rejected
                ? '${controller.profile['rejection_reason'] ?? 'Update your host information and contact support.'}'
                : 'Complete your bio and payout setup now. You can add properties as soon as the Dejen team approves your account.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Get.to<void>(() => const HostProfileScreen()),
            icon: const Icon(Icons.assignment_ind_outlined),
            label: const Text('Complete host profile'),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
