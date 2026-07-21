import 'dart:async';

import 'package:get/get.dart';

import '../../core/urls.dart';
import '../../environment.dart';
import '../api_service.dart';
import '../models/food_order.dart';
import 'auth_controller.dart';

/// Loads and holds the restaurant's order list. Watches for new orders two
/// ways: a lightweight fallback poll (Environment.pollInterval) and, when the
/// live socket is connected, an [ingest] push from the Reverb listener.
class OrdersController extends GetxController {
  OrdersController(this._api);

  final ApiService _api;

  final RxList<FoodOrder> orders = <FoodOrder>[].obs;
  final RxBool loading = false.obs;
  final RxBool loadingMore = false.obs;
  final RxnString error = RxnString();

  int _page = 1;
  int _lastPage = 1;
  Timer? _poll;

  bool get hasMore => _page < _lastPage;
  List<FoodOrder> get liveOrders => orders.where((o) => o.isLive).toList();

  @override
  void onClose() {
    _poll?.cancel();
    super.onClose();
  }

  /// (Re)load from page 1. Silent refreshes (poll/socket) don't toggle the
  /// full-screen spinner so the list doesn't flicker.
  Future<void> refreshOrders({bool silent = false}) async {
    if (!silent) loading.value = true;
    error.value = null;
    try {
      final res = await _api.get('${Urls.orders}?page=1');
      if (!res.success) {
        if (!silent) error.value = _messageOr(res, 'Could not load orders.');
        return;
      }
      final page = _parsePage(res.data['orders']);
      _page = 1;
      _lastPage = page.lastPage;
      orders.assignAll(page.rows);
    } finally {
      if (!silent) loading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (loadingMore.value || !hasMore) return;
    loadingMore.value = true;
    try {
      final next = _page + 1;
      final res = await _api.get('${Urls.orders}?page=$next');
      if (res.success) {
        final page = _parsePage(res.data['orders']);
        _page = next;
        _lastPage = page.lastPage;
        // De-dupe in case a poll/socket refresh raced us.
        final existing = orders.map((o) => o.id).toSet();
        orders.addAll(page.rows.where((o) => !existing.contains(o.id)));
      }
    } finally {
      loadingMore.value = false;
    }
  }

  /// Merge a single order (from a push/socket event) into the top of the list,
  /// replacing any existing copy so its status stays current.
  void ingest(FoodOrder order) {
    final idx = orders.indexWhere((o) => o.id == order.id);
    if (idx >= 0) {
      orders[idx] = order;
    } else {
      orders.insert(0, order);
    }
  }

  Future<FoodOrder?> fetchDetails(int id) async {
    final res = await _api.get('${Urls.orderDetails}$id');
    if (!res.success || res.data['order'] is! Map) return null;
    final order = FoodOrder.fromJson(
      (res.data['order'] as Map).cast<String, dynamic>(),
    );
    ingest(order);
    return order;
  }

  // ---- Restaurant order workflow ---------------------------------------

  /// Owner's open/closed state, seeded from the logged-in restaurant.
  final RxBool isOpen = true.obs;

  void syncOpenFromAuth() {
    if (Get.isRegistered<AuthController>()) {
      final r = Get.find<AuthController>().restaurant.value;
      if (r != null) isOpen.value = r.isOpen;
    }
  }

  Future<String?> acceptOrder(int id) =>
      _orderAction('${Urls.acceptOrder}$id', null);
  Future<String?> markReady(int id) =>
      _orderAction('${Urls.readyOrder}$id', null);
  Future<String?> rejectOrder(int id, String? reason) =>
      _orderAction('${Urls.rejectOrder}$id', {'reason': reason ?? ''});

  Future<String?> _orderAction(String url, Map<String, dynamic>? body) async {
    final res = await _api.post(url, body ?? {}, auth: true);
    if (res.success && res.data['order'] is Map) {
      ingest(
        FoodOrder.fromJson((res.data['order'] as Map).cast<String, dynamic>()),
      );
    } else {
      await refreshOrders(silent: true);
    }
    return res.success
        ? null
        : (res.firstMessage.isNotEmpty
              ? res.firstMessage
              : 'Action failed. Please try again.');
  }

  /// Toggle whether the restaurant is accepting new orders. Returns null on
  /// success or an error message.
  Future<String?> setOpen(bool open) async {
    final res = await _api.post(Urls.setOpen, {
      'is_open': open ? 1 : 0,
    }, auth: true);
    if (res.success) {
      isOpen.value = open;
      return null;
    }
    return res.firstMessage.isNotEmpty
        ? res.firstMessage
        : 'Could not update your status.';
  }

  void startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(
      Environment.pollInterval,
      (_) => refreshOrders(silent: true),
    );
  }

  void stopPolling() => _poll?.cancel();

  String _messageOr(ApiResult res, String fallback) {
    final msg = res.firstMessage;
    return msg.isNotEmpty ? msg : fallback;
  }

  _Page _parsePage(dynamic paginator) {
    if (paginator is! Map) return const _Page(rows: [], lastPage: 1);
    final rows = (paginator['data'] as List?) ?? const [];
    return _Page(
      rows: rows
          .whereType<Map>()
          .map((e) => FoodOrder.fromJson(e.cast<String, dynamic>()))
          .toList(),
      lastPage: (paginator['last_page'] as num?)?.toInt() ?? 1,
    );
  }
}

class _Page {
  const _Page({required this.rows, required this.lastPage});
  final List<FoodOrder> rows;
  final int lastPage;
}
