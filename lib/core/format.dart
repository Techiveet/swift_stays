import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'storage.dart';

/// Formats a money amount using the currency symbol captured at login. Falls
/// back to a bare number if storage isn't registered yet (e.g. in tests).
String money(num amount) {
  final symbol = Get.isRegistered<AppStorage>()
      ? Get.find<AppStorage>().currency
      : '';
  final formatted = NumberFormat('#,##0.##').format(amount);
  return symbol.isEmpty ? formatted : '$symbol$formatted';
}

/// e.g. "Jul 5, 2:30 PM". Empty string for null.
String prettyDateTime(DateTime? when) {
  if (when == null) return '';
  return DateFormat('MMM d, h:mm a').format(when);
}
