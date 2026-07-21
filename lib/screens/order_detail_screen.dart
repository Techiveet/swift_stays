import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/controllers/orders_controller.dart';
import '../data/models/food_order.dart';
import 'order_status_chip.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _orders = Get.find<OrdersController>();

  FoodOrder? _order;
  bool _loading = true;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    // Seed with whatever is already in the list for an instant paint, then
    // fetch the authoritative copy.
    _order = _orders.orders.firstWhereOrNull((o) => o.id == widget.orderId);
    _load();
  }

  Future<void> _load() async {
    final fresh = await _orders.fetchDetails(widget.orderId);
    if (!mounted) return;
    setState(() {
      if (fresh != null) _order = fresh;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(
        title: Text(order != null ? 'Order ${order.reference}' : 'Order'),
      ),
      bottomNavigationBar: order == null ? null : _actionBar(order),
      body: order == null
          ? Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Order not found'),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _statusHeader(order),
                  const SizedBox(height: 16),
                  _customerCard(order),
                  if (order.driver?.hasData == true) ...[
                    const SizedBox(height: 12),
                    _driverCard(order),
                  ],
                  const SizedBox(height: 12),
                  _itemsCard(order),
                  const SizedBox(height: 12),
                  _totalsCard(order),
                  if ((order.note ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _noteCard(order),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _statusHeader(FoodOrder order) {
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.reference,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                if (order.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    prettyDateTime(order.createdAt),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Kitchen: ${order.kitchenLabel}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          OrderStatusChip(status: order.status),
        ],
      ),
    );
  }

  /// Accept / Ready / Reject actions, shown only for the states they apply to.
  Widget? _actionBar(FoodOrder order) {
    if (!order.canAccept && !order.canReady && !order.canReject) return null;

    final buttons = <Widget>[];
    if (order.canAccept) {
      buttons.add(
        Expanded(
          child: _actionButton(
            'Accept',
            AppColors.primary,
            Colors.white,
            () => _runAction(
              () => _orders.acceptOrder(order.id),
              'Order accepted',
            ),
          ),
        ),
      );
    }
    if (order.canReady) {
      buttons.add(
        Expanded(
          child: _actionButton(
            'Mark Ready',
            const Color(0xFF2563EB),
            Colors.white,
            () => _runAction(() => _orders.markReady(order.id), 'Marked ready'),
          ),
        ),
      );
    }
    if (order.canReject) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 10));
      buttons.add(
        Expanded(
          child: _actionButton(
            'Reject',
            Colors.white,
            AppColors.danger,
            () => _confirmReject(order),
            outlined: true,
          ),
        ),
      );
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(children: buttons),
    );
  }

  Widget _actionButton(
    String label,
    Color bg,
    Color fg,
    VoidCallback onTap, {
    bool outlined = false,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _acting ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          side: outlined
              ? const BorderSide(color: AppColors.danger)
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _confirmReject(FoodOrder order) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject order?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The customer will be refunded. Add a reason (optional):',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g. out of an ingredient',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Reject',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _runAction(
        () => _orders.rejectOrder(order.id, controller.text.trim()),
        'Order rejected',
      );
    }
  }

  Future<void> _runAction(
    Future<String?> Function() action,
    String successMsg,
  ) async {
    setState(() => _acting = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _acting = false);
    await _load();
    if (!mounted) return;
    Get.snackbar(
      error == null ? 'Done' : 'Could not complete',
      error ?? successMsg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: error == null ? AppColors.primary : AppColors.danger,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
    );
  }

  Widget _customerCard(FoodOrder order) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Customer'),
          const SizedBox(height: 10),
          _kv(Icons.person_outline, order.customer?.name ?? '—'),
          if ((order.customer?.phone ?? '').isNotEmpty)
            _kv(Icons.phone_outlined, order.customer!.phone!),
          if ((order.deliveryAddress ?? '').isNotEmpty)
            _kv(Icons.location_on_outlined, order.deliveryAddress!),
        ],
      ),
    );
  }

  Widget _driverCard(FoodOrder order) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Driver'),
          const SizedBox(height: 10),
          _kv(Icons.delivery_dining_outlined, order.driver?.name ?? '—'),
          if ((order.driver?.phone ?? '').isNotEmpty)
            _kv(Icons.phone_outlined, order.driver!.phone!),
        ],
      ),
    );
  }

  Widget _itemsCard(FoodOrder order) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Items'),
          const SizedBox(height: 4),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.scaffold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.quantity}×',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(color: AppColors.ink),
                    ),
                  ),
                  Text(
                    money(item.subtotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalsCard(FoodOrder order) {
    return _card(
      child: Column(
        children: [
          _totalRow('Subtotal', money(order.itemsAmount)),
          _totalRow('Delivery fee', money(order.deliveryFee)),
          if (order.discountAmount > 0)
            _totalRow('Discount', '-${money(order.discountAmount)}'),
          const Divider(height: 20),
          _totalRow('Total', money(order.amount), emphasize: true),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 18,
                color: AppColors.muted,
              ),
              const SizedBox(width: 8),
              Text(
                order.paymentTypeLabel,
                style: const TextStyle(color: AppColors.muted),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (order.isPaid ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.isPaid ? 'Paid' : 'Unpaid',
                  style: TextStyle(
                    color: order.isPaid ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noteCard(FoodOrder order) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Note'),
          const SizedBox(height: 8),
          Text(order.note!, style: const TextStyle(color: AppColors.ink)),
        ],
      ),
    );
  }

  // ---- small building blocks ---------------------------------------------

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
      color: AppColors.muted,
    ),
  );

  Widget _kv(IconData icon, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(value, style: const TextStyle(color: AppColors.ink)),
        ),
      ],
    ),
  );

  Widget _totalRow(String label, String value, {bool emphasize = false}) {
    final style = TextStyle(
      color: AppColors.ink,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
      fontSize: emphasize ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: emphasize ? style : const TextStyle(color: AppColors.muted),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}
