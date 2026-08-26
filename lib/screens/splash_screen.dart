import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/swift_gradients.dart';
import '../widgets/swift_logo.dart';
import '../data/controllers/auth_controller.dart';
import '../environment.dart';
import 'login_screen.dart';
import 'orders_screen.dart';

/// Brief brand splash that routes to Orders (if a session exists) or Login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decideNext();
  }

  Future<void> _decideNext() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final loggedIn = Get.find<AuthController>().isLoggedIn;
    Get.off<void>(() => loggedIn ? const OrdersScreen() : const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: SwiftGradients.hero),
            ),
          ),
          // A soft high-left bloom keeps the wash from reading flat.
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SwiftLogoIntro(
                  variant: SwiftLogoVariant.stacked,
                  mono: true,
                  height: 190,
                ),
                const SizedBox(height: 20),
                Text(
                  Environment.appName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Order management',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
