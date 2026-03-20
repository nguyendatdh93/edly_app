import 'package:edly/app.dart';
import 'package:edly/core/config/flavor_config.dart';
import 'package:edly/pages/sign_in/sign_in_view.dart';
import 'package:edly/pages/home/home_view.dart';
import 'package:edly/pages/sign_up/sign_up_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    FlavorConfig.initialize(AppFlavor.prod);
  });

  testWidgets('Home preview renders core content', (WidgetTester tester) async {
    await tester.pumpWidget(const EdlyApp());

    expect(find.text('Gói học đã mua'), findsOneWidget);
    expect(find.text('Gói nổi bật'), findsOneWidget);
    expect(find.text('Gói đã xem'), findsOneWidget);
    expect(find.byType(HomeView), findsOneWidget);
  });

  testWidgets('Drawer logout goes back to sign in', (WidgetTester tester) async {
    await tester.pumpWidget(const EdlyApp());

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Đăng xuất'), findsOneWidget);

    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();

    expect(find.text('Đăng nhập với Google'), findsOneWidget);
    expect(find.text('Email hoặc số điện thoại'), findsOneWidget);
  });

  testWidgets('Login button goes back to home', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SignInView(),
      ),
    );

    final loginButton = find.widgetWithText(FilledButton, 'Đăng nhập');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.byType(HomeView), findsOneWidget);
    expect(find.text('Gói học đã mua'), findsOneWidget);
  });

  testWidgets('Sign up preview renders core content', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SignUpView(),
      ),
    );

    expect(find.text('Đăng ký'), findsNWidgets(2));
    expect(find.text('Tạo tài khoản mới để bắt đầu'), findsOneWidget);
    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsOneWidget);
  });
}
