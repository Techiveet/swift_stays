import 'package:get/get.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../core/storage.dart';
import '../core/urls.dart';
import '../data/api_service.dart';

typedef PusherEventHandler = void Function(PusherEvent event);

/// Thin wrapper over pusher_channels_flutter for the Reverb (Pusher-protocol)
/// live socket. Connection details come from the push_config the login
/// endpoint returned; channel auth is signed by the backend's
/// restaurant/pusher/auth endpoint. Best-effort throughout — if realtime is
/// unavailable the orders list still stays fresh via its poll fallback.
class ReverbService {
  ReverbService._();
  static final ReverbService instance = ReverbService._();

  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  final List<PusherEventHandler> _listeners = [];

  bool _initializing = false;

  bool get isConnected => _pusher.connectionState.toLowerCase() == 'connected';

  void addListener(PusherEventHandler handler) {
    if (!_listeners.contains(handler)) _listeners.add(handler);
  }

  void removeListener(PusherEventHandler handler) => _listeners.remove(handler);

  Future<void> connect(String channel) async {
    if (_initializing) return;
    final cfg = Get.find<AppStorage>().pushConfig;
    if (cfg == null) return; // no realtime config → rely on polling

    _initializing = true;
    try {
      final appKey = (cfg['app_key'] ?? '').toString();
      final cluster = (cfg['cluster'] ?? '').toString();
      final host = (cfg['host'] ?? '').toString();
      final scheme = (cfg['scheme'] ?? 'https').toString().toLowerCase();
      final useTLS = scheme == 'https';
      final port =
          int.tryParse((cfg['port'] ?? '').toString()) ?? (useTLS ? 443 : 80);

      await _safeDisconnect();
      await _pusher.init(
        apiKey: appKey,
        cluster: cluster,
        useTLS: useTLS,
        host: host.isNotEmpty ? host : null,
        wsPort: host.isNotEmpty ? port : null,
        wssPort: host.isNotEmpty ? port : null,
        onEvent: _dispatch,
        onAuthorizer: _authorize,
        onError: (_, _, _) {},
        onSubscriptionError: (_, _) {},
      );
      await _pusher.connect();
      await Future<void>.delayed(const Duration(seconds: 1));
      await _pusher.subscribe(channelName: channel);
    } catch (_) {
      // Realtime is optional; swallow and let polling carry the app.
    } finally {
      _initializing = false;
    }
  }

  Future<void> disconnect() async {
    await _safeDisconnect();
  }

  Future<void> _safeDisconnect() async {
    try {
      if (_pusher.connectionState.toLowerCase() != 'disconnected') {
        await _pusher.disconnect();
      }
    } catch (_) {}
  }

  void _dispatch(PusherEvent event) {
    for (final listener in List<PusherEventHandler>.from(_listeners)) {
      listener(event);
    }
  }

  /// Signs a private-channel subscription via the backend. The endpoint
  /// returns { "auth": "appkey:hmac" }, which pusher passes straight back to
  /// Reverb.
  Future<Map<String, dynamic>?> _authorize(
    String channelName,
    String socketId,
    dynamic options,
  ) async {
    try {
      final res = await Get.find<ApiService>().post(
        '${Urls.pusherAuth}$socketId/$channelName',
        null,
        auth: true,
      );
      if (res.statusCode == 200 && res.body is Map) {
        return Map<String, dynamic>.from(res.body as Map);
      }
    } catch (_) {}
    return null;
  }
}
