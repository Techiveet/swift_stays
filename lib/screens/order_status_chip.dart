import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models/food_order.dart';

/// Small coloured pill showing an order's status. Shared by the list and the
/// detail screen so the colour mapping lives in one place.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final int status;

  Color get _color {
    switch (status) {
      case OrderStatus.accepted:
        return AppColors.info;
      case OrderStatus.pickedUp:
        return AppColors.warning;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.canceled:
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        OrderStatus.label(status),
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
