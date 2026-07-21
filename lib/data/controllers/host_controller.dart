import 'dart:async';

import 'package:get/get.dart';

import '../../core/storage.dart';
import '../../core/urls.dart';
import '../api_service.dart';
import '../../services/host_realtime_service.dart';

class HostController extends GetxController {
  HostController(this.api, this.storage);

  final ApiService api;
  final AppStorage storage;
  final busy = false.obs;
  final profile = <String, dynamic>{}.obs;
  final properties = <Map<String, dynamic>>[].obs;
  final bookings = <Map<String, dynamic>>[].obs;
  final earnings = <String, dynamic>{}.obs;
  final lastUpdated = Rxn<DateTime>();
  Timer? _poller;
  late final HostRealtimeService realtime = HostRealtimeService(
    api,
    refreshAll,
  );

  bool get signedIn => storage.isLoggedIn;

  Future<String?> login(String username, String password) async {
    busy.value = true;
    try {
      final result = await api.post(Urls.login, {
        'username': username.trim(),
        'password': password,
      });
      if (!result.success) {
        return result.firstMessage.isEmpty
            ? 'Could not sign in.'
            : result.firstMessage;
      }
      await storage.saveToken(
        '${result.data['access_token'] ?? ''}',
        '${result.data['token_type'] ?? 'Bearer'}',
      );
      await refreshAll();
      startRealtimeFallback();
      return null;
    } finally {
      busy.value = false;
    }
  }

  Future<String?> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? mobile,
    String? bio,
  }) async {
    busy.value = true;
    try {
      final result = await api.post(Urls.hostRegister, {
        'firstname': firstName.trim(),
        'lastname': lastName.trim(),
        'username': username.trim().toLowerCase(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'password_confirmation': passwordConfirmation,
        if (mobile != null && mobile.trim().isNotEmpty) 'mobile': mobile.trim(),
        if (bio != null && bio.trim().isNotEmpty) 'bio': bio.trim(),
      });
      if (!result.success) {
        return result.firstMessage.isEmpty
            ? 'Could not create your host account.'
            : result.firstMessage;
      }
      await storage.saveToken(
        '${result.data['access_token'] ?? ''}',
        '${result.data['token_type'] ?? 'Bearer'}',
      );
      await refreshAll();
      startRealtimeFallback();
      return null;
    } finally {
      busy.value = false;
    }
  }

  Future<void> refreshAll() async {
    busy.value = true;
    try {
      final results = await Future.wait([
        api.get(Urls.hostProfile),
        api.get(Urls.hostProperties),
        api.get(Urls.hostBookings),
        api.get(Urls.hostEarnings),
      ]);
      if (results[0].success) {
        profile.assignAll(_map(results[0].data['profile']));
        final userId = int.tryParse('${results[0].data['user_id'] ?? 0}') ?? 0;
        await realtime.connect(
          userId: userId,
          config: _map(results[0].data['realtime']),
        );
      }
      if (results[1].success) {
        properties.assignAll(_list(results[1].data['properties']));
      }
      if (results[2].success) {
        bookings.assignAll(_list(results[2].data['bookings']));
      }
      if (results[3].success) {
        earnings.assignAll(_map(results[3].data['summary']));
      }
      lastUpdated.value = DateTime.now();
    } finally {
      busy.value = false;
    }
  }

  Future<String?> bookingAction(
    Map<String, dynamic> booking,
    String action, {
    String? reason,
  }) async {
    final reference = '${booking['reference'] ?? booking['id']}';
    final result = await api.post(
      '${Urls.hostBookings}/$reference/$action',
      reason == null ? {} : {'reason': reason, 'response': reason},
    );
    if (!result.success) {
      return result.firstMessage.isEmpty
          ? 'Could not update booking.'
          : result.firstMessage;
    }
    await refreshAll();
    return null;
  }

  Future<String?> blockDates(
    Map<String, dynamic> property,
    DateTime start,
    DateTime end,
    String reason,
  ) async {
    final reference = '${property['reference'] ?? property['id']}';
    final result = await api.post(
      '${Urls.hostProperties}/$reference/blocked-dates',
      {'start_date': _date(start), 'end_date': _date(end), 'reason': reason},
    );
    if (!result.success) {
      return result.firstMessage.isEmpty
          ? 'Could not block dates.'
          : result.firstMessage;
    }
    await refreshAll();
    return null;
  }

  void startRealtimeFallback() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 12), (_) => refreshAll());
  }

  Future<void> logout() async {
    _poller?.cancel();
    await realtime.disconnect();
    await storage.clear();
    profile.clear();
    properties.clear();
    bookings.clear();
    earnings.clear();
  }

  @override
  void onClose() {
    _poller?.cancel();
    super.onClose();
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};
  static List<Map<String, dynamic>> _list(dynamic value) {
    final raw = value is Map ? value['data'] : value;
    return raw is List
        ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : [];
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
