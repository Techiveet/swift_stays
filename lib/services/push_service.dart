import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../core/urls.dart';
import '../data/api_service.dart';

/// Background/terminated message handler. Must be a top-level (or static)
/// function so the platform can invoke it in a fresh isolate.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Intentionally empty: the orders list re-syncs on next foreground/poll.
  // Declared so Android can deliver data messages while backgrounded.
}

/// Local heads-up notifications plus a best-effort FCM registration. FCM is
/// fully optional at runtime — if Firebase isn't configured for the platform
/// (no google-services.json / GoogleService-Info.plist) the app runs normally
/// on the Reverb socket + poll fallback.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _localReady = false;
  bool _fcmReady = false;
  bool _refreshBound = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'orders',
    'Order alerts',
    description: 'New order and delivery notifications',
    importance: Importance.high,
  );

  Future<void> initLocalNotifications() async {
    if (_localReady) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    _localReady = true;
  }

  Future<void> showSimple({required String title, required String body}) async {
    if (!_localReady) await initLocalNotifications();
    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Best-effort FCM init. Silently no-ops when Firebase isn't configured.
  Future<void> initFcm({void Function(RemoteMessage)? onForeground}) async {
    if (_fcmReady) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Push: Firebase not configured — FCM disabled ($e)');
      }
      return;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n != null) {
          showSimple(title: n.title ?? 'New order', body: n.body ?? '');
        }
        onForeground?.call(message);
      });

      final token = await messaging.getToken();
      final registered =
          token != null && token.isNotEmpty && await _registerToken(token);
      if (!_refreshBound) {
        _refreshBound = true;
        messaging.onTokenRefresh.listen((token) async {
          await _registerToken(token);
        });
      }
      _fcmReady = registered;
    } catch (e) {
      if (kDebugMode) debugPrint('Push: FCM setup error ($e)');
    }
  }

  Future<bool> _registerToken(String token) async {
    try {
      final result = await Get.find<ApiService>().post(Urls.saveDeviceToken, {
        'token': token,
      }, auth: true);
      if (!result.success && kDebugMode) {
        debugPrint('Push: token registration failed (${result.firstMessage})');
      }
      return result.success;
    } catch (error) {
      // Non-fatal — the owner still sees orders via socket/poll.
      if (kDebugMode) debugPrint('Push: token registration error ($error)');
      return false;
    }
  }
}
