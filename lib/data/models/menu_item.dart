import '../../environment.dart';

/// A menu item as managed by the restaurant owner. `available` mirrors the
/// backend FoodItem.status (1 = available, 0 = sold out / "86'd").
class FoodMenuItem {
  FoodMenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.image,
    required this.available,
    this.arModelUrl,
    this.arIosModelUrl,
  });

  final int id;
  final String name;
  final String? description;
  final double price;
  final String? image;
  final bool available;
  final String? arModelUrl;
  final String? arIosModelUrl;

  String? get imageUrl {
    if (image == null || image!.isEmpty) return null;
    return '${Environment.domainUrl}/assets/images/food_item/$image';
  }

  factory FoodMenuItem.fromJson(Map<String, dynamic> json) {
    return FoodMenuItem(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      price: _asDouble(json['price']),
      image: json['image']?.toString(),
      available: _asInt(json['status'], fallback: 1) == 1,
      arModelUrl: json['ar_model_url']?.toString(),
      arIosModelUrl: json['ar_ios_model_url']?.toString(),
    );
  }
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
