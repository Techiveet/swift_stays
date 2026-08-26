import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/storage.dart';
import 'core/theme.dart';
import 'data/api_service.dart';
import 'data/controllers/host_controller.dart';
import 'environment.dart';
import 'screens/host_login_screen.dart';
import 'screens/host_shell_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await AppStorage.create();
  final api = ApiService(storage);
  Get.put(storage, permanent: true);
  Get.put(api, permanent: true);
  Get.put(HostController(api, storage), permanent: true);
  runApp(const SwiftStaysHostApp());
}

class SwiftStaysHostApp extends StatelessWidget {
  const SwiftStaysHostApp({super.key});
  @override
  Widget build(BuildContext context) => GetMaterialApp(
    title: Environment.appName,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    home: const _LaunchScreen(),
  );
}

class _LaunchScreen extends StatefulWidget {
  const _LaunchScreen();
  @override
  State<_LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<_LaunchScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final host = Get.find<HostController>();
      if (host.signedIn) {
        host.refreshAll();
        host.startRealtimeFallback();
        Get.offAll<void>(() => const HostShellScreen());
      } else {
        Get.offAll<void>(() => const HostLoginScreen());
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.ink,
    body: Center(
      child: Image.asset(
        'assets/branding/swift_logo_horizontal_dark.png',
        width: 230,
        fit: BoxFit.contain,
      ),
    ),
  );
}
