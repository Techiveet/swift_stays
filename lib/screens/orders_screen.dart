import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';
import '../data/controllers/orders_controller.dart';
import '../data/controllers/realtime_controller.dart';
import '../data/models/food_order.dart';
import '../services/push_service.dart';
import '../widgets/in_app_announcement_host.dart';
import 'login_screen.dart';
import 'menu_screen.dart';
import 'order_detail_screen.dart';
import 'order_status_chip.dart';
import 'restaurant_pictures_screen.dart';

enum _OrderFilter { all, newOrders, preparing, ready, completed }

extension on _OrderFilter {
  String get label => switch (this) {
    _OrderFilter.all => 'All',
    _OrderFilter.newOrders => 'New',
    _OrderFilter.preparing => 'Preparing',
    _OrderFilter.ready => 'Ready',
    _OrderFilter.completed => 'Completed',
  };
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _auth = Get.find<AuthController>();
  final _orders = Get.find<OrdersController>();
  final _realtime = Get.find<RealtimeController>();
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final Set<int> _actingOrderIds = <int>{};

  _OrderFilter _filter = _OrderFilter.all;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _orders.syncOpenFromAuth();
      _orders.refreshOrders();
      _orders.startPolling();
      _realtime.start();
      PushService.instance.initFcm();
    });
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _search.dispose();
    _orders.stopPolling();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _orders.loadMore();
    }
  }

  Future<void> _toggleOpen() async {
    final next = !_orders.isOpen.value;
    final error = await _orders.setOpen(next);
    if (!mounted) return;
    Get.snackbar(
      error == null
          ? (next ? 'Open for orders' : 'Now closed')
          : 'Could not update',
      error ?? (next ? 'Customers can order again.' : 'New orders are paused.'),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: error == null ? AppColors.primary : AppColors.danger,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
    );
  }

  Future<void> _runQuickAction(
    FoodOrder order,
    Future<String?> Function() action,
    String successMessage,
  ) async {
    setState(() => _actingOrderIds.add(order.id));
    final error = await action();
    if (!mounted) return;
    setState(() => _actingOrderIds.remove(order.id));
    Get.snackbar(
      error == null ? 'Order updated' : 'Could not update order',
      error ?? successMessage,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: error == null ? AppColors.primary : AppColors.danger,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
    );
  }

  Future<void> _confirmLogout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to view orders.'),
        actions: [
          const InAppAnnouncementHost(),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Log out',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (yes == true) {
      await _realtime.stop();
      await _auth.logout();
      Get.offAll<void>(() => const LoginScreen());
    }
  }

  List<FoodOrder> _visibleOrders(List<FoodOrder> orders) {
    final query = _search.text.trim().toLowerCase();
    return orders.where((order) {
      final matchesFilter = switch (_filter) {
        _OrderFilter.all => true,
        _OrderFilter.newOrders => order.canAccept,
        _OrderFilter.preparing =>
          order.restaurantStatus == KitchenStatus.preparing,
        _OrderFilter.ready =>
          order.restaurantStatus == KitchenStatus.ready &&
              order.status != OrderStatus.canceled,
        _OrderFilter.completed =>
          order.status == OrderStatus.delivered ||
              order.status == OrderStatus.canceled ||
              order.restaurantStatus == KitchenStatus.rejected,
      };
      if (!matchesFilter || query.isEmpty) return matchesFilter;
      final haystack = [
        order.reference,
        order.customer?.name,
        order.deliveryAddress,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  void _selectDestination(int index) {
    if (index == 1) Get.to<void>(() => const MenuScreen());
    if (index == 2) Get.to<void>(() => const RestaurantPicturesScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _auth.restaurant.value?.name ?? 'Restaurant',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Order workspace',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh orders',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _orders.refreshOrders(),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'logout') _confirmLogout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout_rounded, color: AppColors.danger),
                  title: Text('Log out'),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: _selectDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu_rounded),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Store',
          ),
        ],
      ),
      body: Obx(() {
        if (_orders.loading.value && _orders.orders.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_orders.error.value != null && _orders.orders.isEmpty) {
          return _ErrorState(
            message: _orders.error.value!,
            onRetry: () => _orders.refreshOrders(),
          );
        }

        final allOrders = _orders.orders.toList();
        final visibleOrders = _visibleOrders(allOrders);
        return Column(
          children: [
            _OperationsHeader(
              orders: allOrders,
              isOpen: _orders.isOpen.value,
              onToggleOpen: _toggleOpen,
            ),
            _OrderTools(
              controller: _search,
              selected: _filter,
              onSearchChanged: (_) => setState(() {}),
              onFilterChanged: (filter) => setState(() => _filter = filter),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _orders.refreshOrders(silent: true),
                child: visibleOrders.isEmpty
                    ? _EmptyState(
                        hasOrders: allOrders.isNotEmpty,
                        onClear: () {
                          _search.clear();
                          setState(() => _filter = _OrderFilter.all);
                        },
                      )
                    : ListView.separated(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        itemCount:
                            visibleOrders.length + (_orders.hasMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          if (i >= visibleOrders.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final order = visibleOrders[i];
                          return _OrderCard(
                            order: order,
                            busy: _actingOrderIds.contains(order.id),
                            onAccept: () => _runQuickAction(
                              order,
                              () => _orders.acceptOrder(order.id),
                              'The kitchen can start preparing this order.',
                            ),
                            onReady: () => _runQuickAction(
                              order,
                              () => _orders.markReady(order.id),
                              'The driver can now collect this order.',
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _OperationsHeader extends StatelessWidget {
  const _OperationsHeader({
    required this.orders,
    required this.isOpen,
    required this.onToggleOpen,
  });

  final List<FoodOrder> orders;
  final bool isOpen;
  final VoidCallback onToggleOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final newCount = orders.where((order) => order.canAccept).length;
    final preparing = orders
        .where((order) => order.restaurantStatus == KitchenStatus.preparing)
        .length;
    final ready = orders
        .where(
          (order) =>
              order.restaurantStatus == KitchenStatus.ready &&
              order.status != OrderStatus.canceled,
        )
        .length;
    final sales = orders
        .where((order) => order.status == OrderStatus.delivered)
        .fold<double>(0, (sum, order) => sum + order.amount);

    return ColoredBox(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOpen ? 'Accepting orders' : 'Orders are paused',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOpen
                            ? 'Your restaurant is visible to customers.'
                            : 'Open when the kitchen is ready.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Accepting orders',
                  value: isOpen ? 'On' : 'Off',
                  child: Switch(
                    value: isOpen,
                    onChanged: (_) => onToggleOpen(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 76,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _Metric(
                    label: 'New',
                    value: '$newCount',
                    color: AppColors.danger,
                  ),
                  _Metric(
                    label: 'Preparing',
                    value: '$preparing',
                    color: AppColors.warning,
                  ),
                  _Metric(
                    label: 'Ready',
                    value: '$ready',
                    color: AppColors.info,
                  ),
                  _Metric(
                    label: 'Delivered sales',
                    value: money(sales),
                    color: AppColors.success,
                    wide: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
    this.wide = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: wide ? 148 : 108,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _OrderTools extends StatelessWidget {
  const _OrderTools({
    required this.controller,
    required this.selected,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final TextEditingController controller;
  final _OrderFilter selected;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_OrderFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search order, customer, or address',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _OrderFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final filter = _OrderFilter.values[index];
                return ChoiceChip(
                  label: Text(filter.label),
                  selected: filter == selected,
                  onSelected: (_) => onFilterChanged(filter),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.busy,
    required this.onAccept,
    required this.onReady,
  });

  final FoodOrder order;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Get.to<void>(() => OrderDetailScreen(orderId: order.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.reference,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.kitchenLabel,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  OrderStatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      order.customer?.name ?? 'Customer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    money(order.amount),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                  ),
                  if (order.createdAt != null) ...[
                    const Spacer(),
                    Text(
                      prettyDateTime(order.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              if (order.canAccept || order.canReady) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy
                            ? null
                            : order.canAccept
                            ? onAccept
                            : onReady,
                        icon: busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                order.canAccept
                                    ? Icons.check_rounded
                                    : Icons.notifications_active_outlined,
                              ),
                        label: Text(
                          order.canAccept ? 'Accept order' : 'Mark ready',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'View order details',
                      onPressed: () => Get.to<void>(
                        () => OrderDetailScreen(orderId: order.id),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasOrders, required this.onClear});

  final bool hasOrders;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasOrders
                          ? Icons.search_off_rounded
                          : Icons.inbox_outlined,
                      size: 56,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      hasOrders ? 'No matching orders' : 'No orders yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasOrders
                          ? 'Try another search or kitchen status.'
                          : 'New orders will appear here automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    if (hasOrders) ...[
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: onClear,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Clear filters'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              child: ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
