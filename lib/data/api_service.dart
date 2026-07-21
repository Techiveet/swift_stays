import 'package:dio/dio.dart';

import '../core/storage.dart';
import '../core/urls.dart';
import '../environment.dart';

/// Normalized result of an API call.
class ApiResult {
  ApiResult({
    required this.success,
    required this.statusCode,
    required this.body,
    this.message,
  });

  final bool success;
  final int statusCode;
  final dynamic body;
  final String? message;

  Map<String, dynamic> get data {
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    return <String, dynamic>{};
  }

  /// First message string from the backend envelope, if any.
  String get firstMessage {
    if (message != null && message!.isNotEmpty) return message!;
    if (body is Map &&
        body['message'] is List &&
        (body['message'] as List).isNotEmpty) {
      return (body['message'] as List).first.toString();
    }
    return '';
  }

  bool get isUnauthorized => statusCode == 401;
}

/// Dio wrapper that adds the dev-token + bearer auth header and returns a
/// normalized [ApiResult]. Kept deliberately small — the restaurant app only
/// talks to a handful of endpoints.
class ApiService {
  ApiService(this._storage) {
    _dio.options
      ..headers = {
        'Accept': 'application/json',
        'dev-token': Environment.devToken,
      }
      ..connectTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(seconds: 30)
      ..validateStatus = (status) => status != null && status < 500;
  }

  final AppStorage _storage;
  final Dio _dio = Dio();

  Options _authOptions() {
    final token = _storage.token;
    return Options(
      headers: token != null && token.isNotEmpty
          ? {'Authorization': '${_storage.tokenType} $token'}
          : null,
    );
  }

  Future<ApiResult> post(
    String path,
    Map<String, dynamic>? data, {
    bool auth = false,
  }) async {
    return _wrap(
      () => _dio.post(
        '${Urls.baseUrl}$path',
        data: data,
        options: auth ? _authOptions() : null,
      ),
    );
  }

  Future<ApiResult> get(String path, {bool auth = true}) async {
    return _wrap(
      () => _dio.get(
        '${Urls.baseUrl}$path',
        options: auth ? _authOptions() : null,
      ),
    );
  }

  Future<ApiResult> put(String path, Map<String, dynamic>? data) async {
    return _wrap(
      () =>
          _dio.put('${Urls.baseUrl}$path', data: data, options: _authOptions()),
    );
  }

  Future<ApiResult> delete(String path) async {
    return _wrap(
      () => _dio.delete('${Urls.baseUrl}$path', options: _authOptions()),
    );
  }

  Future<ApiResult> postMultipart(String path, FormData data) async {
    return _wrap(
      () => _dio.post(
        '${Urls.baseUrl}$path',
        data: data,
        options: _authOptions(),
      ),
    );
  }

  Future<ApiResult> _wrap(Future<Response> Function() call) async {
    try {
      final res = await call();
      final ok =
          res.statusCode == 200 &&
          res.data is Map &&
          (res.data['status'] == 'success');
      return ApiResult(
        success: ok,
        statusCode: res.statusCode ?? 0,
        body: res.data,
      );
    } on DioException catch (e) {
      return ApiResult(
        success: false,
        statusCode: e.response?.statusCode ?? 0,
        body: e.response?.data,
        message: 'Network error. Please check your connection.',
      );
    } catch (e) {
      return ApiResult(
        success: false,
        statusCode: 0,
        body: null,
        message: e.toString(),
      );
    }
  }
}
