import 'package:get/get.dart';
import 'package:dio/dio.dart' as dio;
import 'package:image_picker/image_picker.dart';

import '../../core/storage.dart';
import '../../core/urls.dart';
import '../api_service.dart';
import '../models/restaurant.dart';

/// Owns the auth session: login, logout, and the cached logged-in restaurant.
/// Registered once at startup (see main.dart) and looked up with Get.find.
class AuthController extends GetxController {
  AuthController(this._api, this._storage);

  final ApiService _api;
  final AppStorage _storage;

  final Rxn<Restaurant> restaurant = Rxn<Restaurant>();
  final RxBool busy = false.obs;

  bool get isLoggedIn => _storage.isLoggedIn;
  String get currency => _storage.currency;

  @override
  void onInit() {
    super.onInit();
    // Re-hydrate the last known restaurant so the UI has something to show
    // immediately on a warm start, before any network call.
    final cached = _storage.restaurant;
    if (cached != null) restaurant.value = Restaurant.fromJson(cached);
  }

  /// Returns null on success, or a human-readable error message on failure.
  Future<String?> login(String username, String password) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return 'Please enter your username and password.';
    }
    busy.value = true;
    try {
      final res = await _api.post(Urls.login, {
        'username': username.trim(),
        'password': password,
      });
      if (!res.success) {
        final msg = res.firstMessage;
        return msg.isNotEmpty ? msg : 'Login failed. Please try again.';
      }

      final data = res.data;
      await _storage.saveToken(
        (data['access_token'] ?? '').toString(),
        (data['token_type'] ?? 'Bearer').toString(),
      );
      final rMap = (data['restaurant'] as Map?)?.cast<String, dynamic>() ?? {};
      await _storage.saveRestaurant(rMap);
      await _storage.saveCurrency(data['currency']?.toString());
      await _storage.savePushConfig(
        (data['push_config'] as Map?)?.cast<String, dynamic>(),
      );

      restaurant.value = Restaurant.fromJson(rMap);
      return null;
    } finally {
      busy.value = false;
    }
  }

  /// Submit a self-registration. Returns null on success (the account is then
  /// pending admin approval — no token is issued), or an error message.
  Future<String?> register({
    required String name,
    required String username,
    required String password,
    String? email,
    String? phone,
    String? address,
  }) async {
    busy.value = true;
    try {
      final res = await _api.post(Urls.register, {
        'name': name.trim(),
        'username': username.trim(),
        'password': password,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
      });
      if (!res.success) {
        final msg = res.firstMessage;
        return msg.isNotEmpty ? msg : 'Registration failed. Please try again.';
      }
      return null;
    } finally {
      busy.value = false;
    }
  }

  Future<void> logout() async {
    // Best-effort server-side token revocation; we clear locally regardless.
    try {
      await _api.get(Urls.logout);
    } catch (_) {
      // Offline / already-expired token — ignore and clear anyway.
    }
    await _storage.clear();
    restaurant.value = null;
  }

  Future<String?> updatePictures({XFile? logo, XFile? cover}) async {
    if (logo == null && cover == null) return 'Choose a logo or cover image.';
    busy.value = true;
    try {
      final form = dio.FormData.fromMap({
        if (logo != null)
          'logo': await dio.MultipartFile.fromFile(
            logo.path,
            filename: logo.name,
          ),
        if (cover != null)
          'cover_image': await dio.MultipartFile.fromFile(
            cover.path,
            filename: cover.name,
          ),
      });
      final res = await _api.postMultipart(Urls.profileImages, form);
      if (!res.success) {
        return res.firstMessage.isNotEmpty
            ? res.firstMessage
            : 'Could not upload pictures.';
      }
      final raw =
          (res.data['restaurant'] as Map?)?.cast<String, dynamic>() ?? {};
      await _storage.saveRestaurant(raw);
      restaurant.value = Restaurant.fromJson(raw);
      return null;
    } finally {
      busy.value = false;
    }
  }
}
