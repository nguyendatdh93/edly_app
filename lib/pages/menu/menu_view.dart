import 'package:edly/core/navigation/app_routes.dart';
import 'package:edly/pages/account_profile/account_profile_view.dart';
import 'package:edly/pages/ielts_packages/ielts_packages_view.dart';
import 'package:edly/pages/sat_packages/sat_packages_view.dart';
import 'package:flutter/material.dart';

class MenuView extends StatelessWidget {
  const MenuView({super.key});

  Future<void> _openAccountProfile(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.accountProfile),
        builder: (_) => const AccountProfileView(),
      ),
    );
  }

  Future<void> _openSatFree(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.satFree),
        builder: (_) => const SatPackagesView(),
      ),
    );
  }

  Future<void> _openIeltsFree(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.ieltsFree),
        builder: (_) => const IeltsPackagesView(),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title sẽ sớm có trên bản mobile.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Trang cá nhân'),
            onTap: () => _openAccountProfile(context),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Bài viết'),
            onTap: () => _showComingSoon(context, 'Bài viết'),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Miễn phí SAT'),
            onTap: () => _openSatFree(context),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Miễn phí IELTS'),
            onTap: () => _openIeltsFree(context),
          ),
        ],
      ),
    );
  }
}
