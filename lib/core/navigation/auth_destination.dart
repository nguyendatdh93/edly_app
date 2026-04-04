import 'package:edupen/pages/account_onboarding/account_onboarding_view.dart';
import 'package:edupen/pages/home/home_view.dart';
import 'package:edupen/services/auth_repository.dart';
import 'package:flutter/widgets.dart';

Widget buildSignedInDestination() {
  if (AuthRepository.instance.needsFirstTimeOnboarding) {
    return const AccountOnboardingView();
  }

  return const HomeView();
}
