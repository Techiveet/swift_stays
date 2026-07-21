/// Food-order status codes — must stay in sync with the backend's
/// App\Constants\Status (FOOD_ORDER_*).
class OrderStatus {
  static const int pending = 0;
  static const int accepted = 1;
  static const int pickedUp = 2;
  static const int delivered = 3;
  static const int canceled = 9;

  static String label(int status) {
    switch (status) {
      case accepted:
        return 'Accepted';
      case pickedUp:
        return 'Picked Up';
      case delivered:
        return 'Delivered';
      case canceled:
        return 'Canceled';
      default:
        return 'Pending';
    }
  }

  /// Still moving through the pipeline (not delivered, not canceled).
  static bool isLive(int status) =>
      status == pending || status == accepted || status == pickedUp;
}

/// Kitchen (restaurant-side) status — must match App\Constants\Status
/// (KITCHEN_*). Tracked separately from the delivery status above.
class KitchenStatus {
  static const int pending = 0;
  static const int preparing = 1;
  static const int ready = 2;
  static const int rejected = 9;

  static String label(int status) {
    switch (status) {
      case preparing:
        return 'Preparing';
      case ready:
        return 'Ready for pickup';
      case rejected:
        return 'Rejected';
      default:
        return 'New — needs confirmation';
    }
  }
}

/// Payment type codes — must match App\Constants\Status (PAYMENT_TYPE_*).
class PaymentType {
  static const int gateway = 1;
  static const int cash = 2;
  static const int wallet = 3;

  static String label(int type) {
    switch (type) {
      case cash:
        return 'Cash';
      case wallet:
        return 'Wallet';
      default:
        return 'Online';
    }
  }
}

/// A single line item on an order. Name/price are snapshotted server-side at
/// order time, so they render faithfully even after later menu edits.
class FoodOrderItem {
  FoodOrderItem({
    required this.name,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  final String name;
  final double price;
  final int quantity;
  final double subtotal;

  factory FoodOrderItem.fromJson(Map<String, dynamic> json) {
    return FoodOrderItem(
      name: (json['name'] ?? '').toString(),
      price: _asDouble(json['price']),
      quantity: _asInt(json['quantity'], fallback: 1),
      subtotal: _asDouble(json['subtotal']),
    );
  }
}

/// A person attached to an order (the customer or the assigned driver). Kept
/// deliberately loose — different backend models expose slightly different
/// name/phone column names.
class OrderParty {
  OrderParty({this.name, this.phone});

  final String? name;
  final String? phone;

  bool get hasData => (name != null && name!.isNotEmpty);

  factory OrderParty.fromJson(Map<String, dynamic> json) {
    final first = json['firstname']?.toString();
    final last = json['lastname']?.toString();
    final composed = [
      first,
      last,
    ].where((p) => p != null && p.isNotEmpty).join(' ').trim();
    return OrderParty(
      name: (json['name'] ?? (composed.isEmpty ? null : composed))?.toString(),
      phone: (json['mobile'] ?? json['phone'])?.toString(),
    );
  }
}

/// A food order as seen by the restaurant owner app.
class FoodOrder {
  FoodOrder({
    required this.id,
    required this.uid,
    required this.status,
    required this.restaurantStatus,
    required this.paymentType,
    required this.paymentStatus,
    required this.itemsAmount,
    required this.deliveryFee,
    required this.discountAmount,
    required this.amount,
    this.deliveryAddress,
    this.note,
    this.createdAt,
    this.items = const [],
    this.customer,
    this.driver,
  });

  final int id;
  final String uid;
  final int status;
  final int restaurantStatus;
  final int paymentType;
  final int paymentStatus;
  final double itemsAmount;
  final double deliveryFee;
  final double discountAmount;
  final double amount;
  final String? deliveryAddress;
  final String? note;
  final DateTime? createdAt;
  final List<FoodOrderItem> items;
  final OrderParty? customer;
  final OrderParty? driver;

  String get statusLabel => OrderStatus.label(status);
  String get kitchenLabel => KitchenStatus.label(restaurantStatus);
  String get paymentTypeLabel => PaymentType.label(paymentType);
  bool get isLive => OrderStatus.isLive(status);
  bool get isPaid => paymentStatus == 1;
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  // Which restaurant actions apply, based on the kitchen state.
  bool get canAccept =>
      restaurantStatus == KitchenStatus.pending &&
      status != OrderStatus.canceled;
  bool get canReady => restaurantStatus == KitchenStatus.preparing;
  bool get canReject =>
      (restaurantStatus == KitchenStatus.pending ||
          restaurantStatus == KitchenStatus.preparing) &&
      status != OrderStatus.pickedUp &&
      status != OrderStatus.delivered &&
      status != OrderStatus.canceled;

  /// A short human reference, e.g. "#1042" (falls back to the uid).
  String get reference => uid.isNotEmpty ? uid : '#$id';

  factory FoodOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return FoodOrder(
      id: _asInt(json['id']),
      uid: (json['uid'] ?? '').toString(),
      status: _asInt(json['status']),
      restaurantStatus: _asInt(json['restaurant_status']),
      paymentType: _asInt(json['payment_type'], fallback: PaymentType.cash),
      paymentStatus: _asInt(json['payment_status']),
      itemsAmount: _asDouble(json['items_amount']),
      deliveryFee: _asDouble(json['delivery_fee']),
      discountAmount: _asDouble(json['discount_amount']),
      amount: _asDouble(json['amount']),
      deliveryAddress: json['delivery_address']?.toString(),
      note: json['note']?.toString(),
      createdAt: _asDate(json['created_at']),
      items: rawItems
          .whereType<Map>()
          .map((e) => FoodOrderItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      customer: json['user'] is Map
          ? OrderParty.fromJson((json['user'] as Map).cast<String, dynamic>())
          : null,
      driver: json['driver'] is Map
          ? OrderParty.fromJson((json['driver'] as Map).cast<String, dynamic>())
          : null,
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

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}
