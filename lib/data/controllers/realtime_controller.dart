import 'dart:convert';

import 'package:get/get.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../../core/storage.dart';
import '../../services/push_service.dart';
import '../../services/reverb_service.dart';
import '../models/food_order.dart';
import 'auth_controller.dart';
import 'orders_controller.dart';

/// Bridges live signals (Reverb socket + FCM) into the orders list. On a new
/// order it ingests the pushed record and raises a heads-up notification, so
/// the owner sees it without a manual refresh.
class RealtimeController extends GetxController {
  RealtimeController(this._storage, this._orders, this._auth);

  final AppStorage _storage;
  final OrdersController _orders;
  final AuthController _auth;

  static const String _newOrderEvent = 'new_food_order';

  @override
  void onInit() {
    super.onInit();
    ReverbService.instance.addListener(_onPusherEvent);
  }

  @override
  void onClose() {
    ReverbService.instance.removeListener(_onPusherEvent);
    super.onClose();
  }

  /// Connect the socket + FCM for the logged-in restaurant. Safe to call more
  /// than once (each underlying service guards against re-init).
  Future<void> start() async {
    final id = _auth.restaurant.value?.id ?? _storage.restaurant?['id'];
    if (id == null) return;

    await PushService.instance.initLocalNotifications();
    await ReverbService.instance.connect('private-restaurant-$id');
    await PushService.instance.initFcm(
      onForeground: (_) => _orders.refreshOrders(silent: true),
    );
  }

  Future<void> stop() => ReverbService.instance.disconnect();

  void _onPusherEvent(PusherEvent event) {
    if (event.eventName.toLowerCase() != _newOrderEvent) return;

    final raw = event.data;
    if (raw == null || raw.toString().isEmpty) return;

    try {
      final decoded = jsonDecode(raw.toString());
      final payload = decoded is Map ? decoded['data'] : null;
      final orderMap = payload is Map ? payload['food_order'] : null;
      if (orderMap is Map) {
        final order = FoodOrder.fromJson(orderMap.cast<String, dynamic>());
        _orders.ingest(order);
        PushService.instance.showSimple(
          title: 'New order ${order.reference}',
          body:
              '${order.itemCount} item(s) • ${order.customer?.name ?? 'Customer'}',
        );
        return;
      }
    } catch (_) {
      // Fall through to a plain refresh below.
    }
    _orders.refreshOrders(silent: true);
  }
}
