import 'dart:async';

import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

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
  final payouts = <Map<String, dynamic>>[].obs;
  final configuration = <String, dynamic>{}.obs;
  final user = <String, dynamic>{}.obs;
  final loadError = ''.obs;
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
        api.get(Urls.staysConfiguration, auth: false),
      ]);
      var failure = '';
      if (results[0].success) {
        profile.assignAll(_map(results[0].data['profile']));
        user.assignAll(_map(results[0].data['user']));
        final userId = int.tryParse('${results[0].data['user_id'] ?? 0}') ?? 0;
        await realtime.connect(
          userId: userId,
          config: _map(results[0].data['realtime']),
        );
      } else {
        failure = _error(results[0], 'Could not load your host profile.');
      }
      if (results[1].success) {
        properties.assignAll(_list(results[1].data['properties']));
      } else if (failure.isEmpty) {
        failure = _error(results[1], 'Could not load your properties.');
      }
      if (results[2].success) {
        bookings.assignAll(_list(results[2].data['bookings']));
      } else if (failure.isEmpty) {
        failure = _error(results[2], 'Could not load your bookings.');
      }
      if (results[3].success) {
        earnings.assignAll(_map(results[3].data['summary']));
        payouts.assignAll(_list(results[3].data['payouts']));
      } else if (failure.isEmpty) {
        failure = _error(results[3], 'Could not load your earnings.');
      }
      if (results[4].success) {
        configuration.assignAll(results[4].data);
      }
      loadError.value = failure;
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
      auth: true,
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
      {'starts_on': _date(start), 'ends_on': _date(end), 'reason': reason},
      auth: true,
    );
    if (!result.success) {
      return result.firstMessage.isEmpty
          ? 'Could not block dates.'
          : result.firstMessage;
    }
    await refreshAll();
    return null;
  }

  Future<String?> saveProfile({
    required String bio,
    required List<String> languages,
    String? payoutProvider,
    String? payoutAccount,
  }) async {
    busy.value = true;
    try {
      final result = await api.put(Urls.hostProfile, {
        'bio': bio.trim(),
        'languages': languages,
        if (payoutAccount != null &&
            payoutAccount.trim().isNotEmpty &&
            payoutProvider != null &&
            payoutProvider.isNotEmpty)
          'payout_provider': payoutProvider,
        if (payoutAccount != null && payoutAccount.trim().isNotEmpty)
          'payout_account': payoutAccount.trim(),
      });
      if (!result.success) return _error(result, 'Could not save profile.');
      profile.assignAll(_map(result.data['profile']));
      return null;
    } finally {
      busy.value = false;
    }
  }

  Future<Map<String, dynamic>?> propertyDetails(
    Map<String, dynamic> property,
  ) async {
    final reference = '${property['reference'] ?? property['id']}';
    final result = await api.get('${Urls.hostProperties}/$reference');
    if (!result.success) return null;
    final details = _map(result.data['property']);
    details['documents'] = result.data['documents'];
    return details;
  }

  Future<({String? error, Map<String, dynamic>? property})> saveProperty(
    Map<String, dynamic> payload, {
    String? reference,
  }) async {
    busy.value = true;
    try {
      final result = reference == null
          ? await api.post(Urls.hostProperties, payload, auth: true)
          : await api.put('${Urls.hostProperties}/$reference', payload);
      if (!result.success) {
        return (
          error: _error(result, 'Could not save property.'),
          property: null,
        );
      }
      await refreshAll();
      return (error: null, property: _map(result.data['property']));
    } finally {
      busy.value = false;
    }
  }

  Future<String?> submitProperty(Map<String, dynamic> property) async {
    final reference = '${property['reference'] ?? property['id']}';
    final result = await api.post(
      '${Urls.hostProperties}/$reference/submit',
      {},
      auth: true,
    );
    if (!result.success) return _error(result, 'Could not submit property.');
    await refreshAll();
    return null;
  }

  Future<String?> uploadPropertyPhoto(
    Map<String, dynamic> property,
    XFile file,
    String altText,
  ) async {
    final reference = '${property['reference'] ?? property['id']}';
    final form = dio.FormData.fromMap({
      'file': await dio.MultipartFile.fromFile(file.path, filename: file.name),
      'alt_text': altText,
    });
    final result = await api.postMultipart(
      '${Urls.hostProperties}/$reference/media',
      form,
    );
    return result.success ? null : _error(result, 'Could not upload photo.');
  }

  Future<String?> uploadPropertyDocument(
    Map<String, dynamic> property,
    XFile file,
    String type,
  ) async {
    final reference = '${property['reference'] ?? property['id']}';
    final form = dio.FormData.fromMap({
      'file': await dio.MultipartFile.fromFile(file.path, filename: file.name),
      'type': type,
    });
    final result = await api.postMultipart(
      '${Urls.hostProperties}/$reference/documents',
      form,
    );
    return result.success ? null : _error(result, 'Could not upload document.');
  }

  Future<String?> deletePropertyPhoto(int mediaId) async {
    final result = await api.delete('stays/host/media/$mediaId');
    return result.success ? null : _error(result, 'Could not delete photo.');
  }

  Future<String?> setCoverPhoto(
    Map<String, dynamic> property,
    List<Map<String, dynamic>> media,
    int coverId,
  ) async {
    final reference = '${property['reference'] ?? property['id']}';
    final result = await api.put(
      '${Urls.hostProperties}/$reference/media/order',
      {
        'media': [
          for (var index = 0; index < media.length; index++)
            {'id': media[index]['id'], 'sort_order': index * 10},
        ],
        'cover_id': coverId,
      },
    );
    return result.success
        ? null
        : _error(result, 'Could not update cover photo.');
  }

  Future<String?> saveUnit(
    Map<String, dynamic> property,
    Map<String, dynamic> payload, {
    int? unitId,
  }) async {
    final reference = '${property['reference'] ?? property['id']}';
    final suffix = unitId == null ? '' : '/$unitId';
    final result = await api.post(
      '${Urls.hostProperties}/$reference/units$suffix',
      payload,
      auth: true,
    );
    return result.success ? null : _error(result, 'Could not save unit.');
  }

  Future<String?> savePriceRule(
    Map<String, dynamic> property,
    Map<String, dynamic> payload,
  ) async {
    final reference = '${property['reference'] ?? property['id']}';
    final result = await api.post(
      '${Urls.hostProperties}/$reference/price-rules',
      payload,
      auth: true,
    );
    return result.success
        ? null
        : _error(result, 'Could not save seasonal price.');
  }

  Future<String?> saveAvailabilityRule(
    Map<String, dynamic> property,
    Map<String, dynamic> payload,
  ) async {
    final reference = '${property['reference'] ?? property['id']}';
    final result = await api.post(
      '${Urls.hostProperties}/$reference/availability-rules',
      payload,
      auth: true,
    );
    return result.success
        ? null
        : _error(result, 'Could not save availability rule.');
  }

  Future<List<Map<String, dynamic>>> searchAddresses(String query) async {
    if (query.trim().length < 3) return [];
    final result = await api.get(
      Urls.searchAddress,
      query: {'input': query.trim(), 'country_code': 'ET'},
    );
    final raw = _map(result.body);
    final predictions = raw['predictions'];
    return _list(predictions);
  }

  Future<Map<String, dynamic>?> placeDetails(String placeId) async {
    final result = await api.get(
      Urls.placeDetails,
      query: {'place_id': placeId},
    );
    final raw = _map(result.body);
    final details = _map(raw['result']);
    return details.isEmpty ? null : details;
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
    payouts.clear();
    configuration.clear();
    user.clear();
    loadError.value = '';
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

  static String _error(ApiResult result, String fallback) =>
      result.firstMessage.isEmpty ? fallback : result.firstMessage;
}
