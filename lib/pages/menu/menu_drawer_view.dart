import 'package:edly/core/navigation/app_routes.dart';
import 'package:edly/pages/account_profile/account_profile_view.dart';
import 'package:edly/pages/admin/admin_dashboard_view.dart';
import 'package:edly/pages/home/home_constants.dart';
import 'package:edly/pages/ielts_packages/ielts_packages_view.dart';
import 'package:edly/pages/sat_packages/sat_packages_view.dart';
import 'package:edly/pages/sign_in/sign_in_view.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:flutter/material.dart';

class MenuDrawerView extends StatelessWidget {
  const MenuDrawerView({super.key});

  Future<void> _openAccountProfile(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.accountProfile),
        builder: (_) => const AccountProfileView(),
      ),
    );
  }

  Future<void> _openAdminDashboard(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminDashboardView()),
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

  Future<void> _goToSignIn(BuildContext context) async {
    await AuthRepository.instance.signOut();

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SignInView()),
    );
  }

  Future<void> _openDrawerDestination(
    BuildContext context,
    HomeDrawerItemData item,
  ) async {
    final title = item.title.trim().toLowerCase();

    if (title == 'sat' || title == 'sat/act' || title.contains('sat')) {
      await _openSatFree(context);
      return;
    }

    if (title == 'ielts' || title.contains('ielts')) {
      await _openIeltsFree(context);
      return;
    }

    _showComingSoon(context, item.title);
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title sẽ sớm có trên bản mobile.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthRepository.instance.currentUser;
    final canAccessAdminPortal = AuthRepository.instance.isAdminPortalUser;

    return Scaffold(
      backgroundColor: HomePalette.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          HomeContent.logoAsset,
                          height: 38,
                          fit: BoxFit.contain,
                        ),
                        const Spacer(),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: HomePalette.border),
                          ),
                          child: const Icon(
                            Icons.menu_rounded,
                            color: HomePalette.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Menu',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: HomePalette.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Truy cập nhanh tài khoản và các mục học tập.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: HomePalette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _MenuProfileCard(
                      name: user?.name ?? 'Tài khoản Edly',
                      subtitle: user?.subtitle ?? 'Thông tin tài khoản',
                      initials: user?.initials ?? 'E',
                      onTap: () => _openAccountProfile(context),
                    ),
                    const SizedBox(height: 14),
                    if (canAccessAdminPortal) ...[
                      _MenuShortcutCard(
                        title: 'Trang quản trị',
                        subtitle: 'Mở dashboard quản trị trên mobile',
                        icon: Icons.admin_panel_settings_outlined,
                        color: HomePalette.chipGreen,
                        onTap: () => _openAdminDashboard(context),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const _MenuSectionTitle(
                      title: 'Khám phá',
                      subtitle: 'Các mục đang có sẵn trên ứng dụng.',
                    ),
                    const SizedBox(height: 12),
                    ...HomeContent.drawerItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MenuTile(
                          title: item.title,
                          icon: item.icon,
                          onTap: () => _openDrawerDestination(context, item),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _MenuSectionTitle(
                      title: 'Phiên làm việc',
                      subtitle: 'Đăng xuất khi cần đổi tài khoản.',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _goToSignIn(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: HomePalette.textPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text(
                          'Đăng xuất',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuProfileCard extends StatelessWidget {
  const _MenuProfileCard({
    required this.name,
    required this.subtitle,
    required this.initials,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: HomePalette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: HomePalette.chipBlue,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: HomePalette.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: HomePalette.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: HomePalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: HomePalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuShortcutCard extends StatelessWidget {
  const _MenuShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: HomePalette.primary),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: HomePalette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: HomePalette.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: HomePalette.textMuted,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      tileColor: color,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    );
  }
}

class _MenuSectionTitle extends StatelessWidget {
  const _MenuSectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: HomePalette.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: HomePalette.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: HomePalette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: HomePalette.chipBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: HomePalette.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: HomePalette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: HomePalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
