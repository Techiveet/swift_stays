import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../data/controllers/host_controller.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.booking});
  final Map<String, dynamic> booking;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final controller = Get.find<HostController>();
  late Map<String, dynamic> booking = widget.booking;

  Future<void> action(String value, {String? reason}) async {
    final error = await controller.bookingAction(
      booking,
      value,
      reason: reason,
    );
    if (!mounted) return;
    if (error == null) {
      final reference = '${booking['reference']}';
      booking = controller.bookings.firstWhere(
        (item) => '${item['reference']}' == reference,
        orElse: () => booking,
      );
      setState(() {});
      Get.snackbar('Booking updated', 'The guest has been notified.');
    } else {
      Get.snackbar(
        'Could not update booking',
        error,
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
      );
    }
  }

  Future<void> cancel() async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: TextField(
          controller: reason,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Cancellation reason',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await action(
        'cancel',
        reason: reason.text.trim().isEmpty
            ? 'Cancelled by host'
            : reason.text.trim(),
      );
    }
    reason.dispose();
  }

  Future<void> openMap() async {
    final property = _map(booking['property']);
    final lat = property['latitude'];
    final lng = property['longitude'];
    if (lat == null || lng == null) return;
    await launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final property = _map(booking['property']);
    final guest = _map(booking['guest']);
    final verification = _map(booking['identity_verification']);
    final status = '${booking['status'] ?? ''}';
    return Scaffold(
      appBar: AppBar(title: const Text('Booking details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${property['title'] ?? 'Guest stay'}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              _Badge(status),
            ],
          ),
          const SizedBox(height: 4),
          Text('${booking['reference'] ?? ''}'),
          const SizedBox(height: 18),
          _Section(
            title: 'Guest',
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text('${guest['name'] ?? 'Guest'}'),
                subtitle: Text('${guest['email'] ?? guest['mobile'] ?? ''}'),
              ),
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: const Text('Guests'),
                subtitle: Text(_guestSummary(_map(booking['guests']))),
              ),
              ListTile(
                leading: Icon(
                  verification['status'] == 'verified'
                      ? Icons.verified_user
                      : Icons.hourglass_top,
                ),
                title: const Text('Identity documents'),
                subtitle: Text(
                  '${verification['status'] ?? 'not submitted'} | ${verification['document_count'] ?? 0} documents',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Stay',
            children: [
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Check-in'),
                trailing: Text('${booking['check_in'] ?? ''}'),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Check-out'),
                trailing: Text('${booking['check_out'] ?? ''}'),
              ),
              ListTile(
                leading: const Icon(Icons.nights_stay_outlined),
                title: const Text('Length'),
                trailing: Text('${booking['nights'] ?? 0} nights'),
              ),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(
                  '${property['address_line'] ?? property['neighborhood'] ?? property['city'] ?? ''}',
                ),
                trailing: IconButton(
                  tooltip: 'Directions',
                  onPressed: openMap,
                  icon: const Icon(Icons.directions_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Payment',
            children: [
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Booking total'),
                trailing: Text(
                  '${booking['currency'] ?? 'ETB'} ${_money(booking['total'])}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Payment status'),
                trailing: Text(_paymentStatus(booking['payment_status'])),
              ),
            ],
          ),
          if ('${booking['guest_message'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Section(
              title: 'Guest message',
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('${booking['guest_message']}'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (status == 'pending_host')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        action('decline', reason: 'Unable to host these dates'),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => action('approve'),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          if (status == 'confirmed') ...[
            FilledButton.icon(
              onPressed: verification['status'] == 'verified'
                  ? () => action('check-in')
                  : null,
              icon: const Icon(Icons.login),
              label: Text(
                verification['status'] == 'verified'
                    ? 'Check in guest'
                    : 'Await identity approval',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: cancel,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel booking'),
            ),
          ],
          if (status == 'checked_in')
            FilledButton.icon(
              onPressed: () => action('check-out'),
              icon: const Icon(Icons.logout),
              label: const Text('Check out guest'),
            ),
          if (status == 'checked_out')
            FilledButton.icon(
              onPressed: () => action('complete'),
              icon: const Icon(Icons.task_alt),
              label: const Text('Complete stay'),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ...children,
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.value);
  final String value;
  @override
  Widget build(BuildContext context) =>
      Chip(label: Text(toBeginningOfSentenceCase(value.replaceAll('_', ' '))));
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
String _money(dynamic value) =>
    NumberFormat('#,##0.00').format(num.tryParse('$value') ?? 0);
String _guestSummary(Map<String, dynamic> value) =>
    '${value['adults'] ?? 0} adults | ${value['children'] ?? 0} children | ${value['infants'] ?? 0} infants';
String _paymentStatus(dynamic value) => switch (int.tryParse('$value')) {
  1 => 'Paid',
  2 => 'Pending',
  3 => 'Cash due',
  _ => 'Unpaid',
};
