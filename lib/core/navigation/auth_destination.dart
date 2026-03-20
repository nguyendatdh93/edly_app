import 'package:edly/pages/account_onboarding/account_onboarding_view.dart';
import 'package:edly/pages/home/home_view.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:flutter/widgets.dart';

Widget buildSignedInDestination() {
  if (AuthRepository.instance.needsFirstTimeOnboarding) {
    return const AccountOnboardingView();
  }

  return const HomeView();
}
