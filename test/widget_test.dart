import 'package:swift_stays_host/core/storage.dart';
import 'package:swift_stays_host/core/theme.dart';
import 'package:swift_stays_host/data/api_service.dart';
import 'package:swift_stays_host/data/controllers/host_controller.dart';
import 'package:swift_stays_host/screens/host_login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Host login renders Swift Stays controls', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = AppStorage.forTesting(
      await SharedPreferences.getInstance(),
    );
    final api = ApiService(storage);
    Get.put(HostController(api, storage));
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const HostLoginScreen()),
    );
    expect(find.text('Stays Host'), findsOneWidget);
    expect(find.text('Sign in as host'), findsOneWidget);
    expect(find.text('Create a host account'), findsOneWidget);
    await tester.tap(find.text('Create a host account'));
    await tester.pumpAndSettle();
    expect(find.text('Become a host'), findsOneWidget);
    expect(find.text('Create host account'), findsOneWidget);
    await Get.deleteAll(force: true);
  });
}
