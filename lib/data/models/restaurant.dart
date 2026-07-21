import '../../environment.dart';

/// A restaurant as returned by the login endpoint. Only the fields the owner
/// app actually renders are surfaced as typed getters; the untouched decoded
/// map is kept in [raw] so nothing is lost when we persist/re-hydrate it.
class Restaurant {
  Restaurant({
    required this.id,
    required this.name,
    required this.username,
    this.phone,
    this.address,
    this.logo,
    this.coverImage,
    this.rating = 0,
    this.status = 1,
    this.raw = const {},
  });

  final int id;
  final String name;
  final String username;
  final String? phone;
  final String? address;
  final String? logo;
  final String? coverImage;
  final double rating;
  final int status;
  final Map<String, dynamic> raw;

  bool get isActive => status == 1;

  /// Owner's open/closed toggle (defaults open). Backend casts it to a bool,
  /// but tolerate 1/0 too.
  bool get isOpen {
    final v = raw['is_open'];
    if (v is bool) return v;
    return _asInt(v, fallback: 1) == 1;
  }

  String? get logoUrl => _imageUrl(logo);
  String? get coverImageUrl => _imageUrl(coverImage);

  static String? _imageUrl(String? file) {
    if (file == null || file.isEmpty) return null;
    return '${Environment.domainUrl}/assets/images/restaurant/$file';
  }

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      logo: json['logo']?.toString(),
      coverImage: json['cover_image']?.toString(),
      rating: _asDouble(json['rating']),
      status: _asInt(json['status'], fallback: 1),
      raw: json,
    );
  }

  /// Persisted verbatim — [raw] round-trips every field the backend sent.
  Map<String, dynamic> toJson() => raw;
}

int _asInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

double _asDouble(dynamic v, {double fallback = 0}) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? fallback;
}
