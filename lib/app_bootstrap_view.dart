import 'package:edupen/core/navigation/auth_destination.dart';
import 'package:edupen/pages/sign_in/sign_in_view.dart';
import 'package:edupen/services/auth_repository.dart';
import 'package:flutter/material.dart';

/// Khởi động app và quyết định mở màn đăng nhập hay home từ session đã lưu.
class AppBootstrapView extends StatefulWidget {
  const AppBootstrapView({super.key});

  @override
  State<AppBootstrapView> createState() => _AppBootstrapViewState();
}

class _AppBootstrapViewState extends State<AppBootstrapView> {
  late final Future<bool> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = AuthRepository.instance.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.data == true) {
          return buildSignedInDestination();
        }

        return const SignInView();
      },
    );
  }
}
