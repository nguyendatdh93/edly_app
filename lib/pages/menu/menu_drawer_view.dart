import 'package:edly/core/navigation/app_routes.dart';
import 'package:edly/pages/account_profile/account_profile_view.dart';
import 'package:edly/pages/admin/admin_dashboard_view.dart';
import 'package:edly/pages/home/home_constants.dart';
import 'package:edly/pages/ielts_packages/ielts_packages_view.dart';
import 'package:edly/pages/menu/user_course_list_view.dart';
import 'package:edly/pages/sat_packages/sat_packages_view.dart';
import 'package:edly/pages/sign_in/sign_in_view.dart';
import 'package:edly/pages/teacher/teacher_view.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:edly/widgets/mobile_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MenuDrawerView extends StatelessWidget {
  const MenuDrawerView({super.key});

  static final NumberFormat _currencyFormat = NumberFormat.decimalPattern(
    'vi_VN',
  );

  Future<void> _openAccountProfile(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.accountProfile),
        builder: (_) => const AccountProfileView(),
      ),
    );
  }

  Future<void> _openAdminDashboard(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AdminDashboardView()));
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

  Future<void> _openPurchasedCourses(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const UserCourseListView(mode: UserCourseListMode.purchased),
      ),
    );
  }

  Future<void> _openLearningProgress(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const UserCourseListView(mode: UserCourseListMode.progress),
      ),
    );
  }

  Future<void> _openTeacherPage(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TeacherView()));
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

  Future<void> _openDepositSheet(BuildContext context) async {
    final result = await showDepositSheet(context);
    if (result?.completed != true || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result!.message)));
  }

  Future<void> _openDrawerDestination(
    BuildContext context,
    HomeDrawerItemData item,
  ) async {
    final title = item.title.trim().toLowerCase();

    if (title == 'miễn phí sat') {
      await _openSatFree(context);
      return;
    }

    if (title == 'miễn phí ielts') {
      await _openIeltsFree(context);
      return;
    }

    if (title == 'bài viết') {
      _showMissingMobileApi(context, item.title);
      return;
    }

    if (title == 'hướng dẫn') {
      _showMissingMobileApi(context, item.title);
      return;
    }

    if (title == 'trang giáo viên' || title == 'dành cho giáo viên') {
      await _openTeacherPage(context);
      return;
    }

    if (title == 'sat' || title == 'sat/act') {
      await _openSatFree(context);
      return;
    }

    if (title == 'ielts') {
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

  void _showMissingMobileApi(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title cần API mobile để hiển thị native.')),
    );
  }

  String _formatBalance(int? balance) {
    return 'Số dư: ${_currencyFormat.format(balance ?? 0)}đ';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthRepository.instance.currentUser;
    final canAccessAdminPortal = AuthRepository.instance.isAdminPortalUser;
    final isStaff = user?.isStaff ?? false;
    final isTeacher =
        user?.normalizedRole == 'teacher' ||
        user?.normalizedRoleName == 'giáo viên';
    final adminPortalTitle = isStaff && !(user?.isAdmin ?? false)
        ? 'Thông tin nhập liệu'
        : 'Trang quản trị';

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
                    Image.asset(
                      HomeContent.logoAsset,
                      height: 38,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Menu',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: HomePalette.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _MenuProfileCard(
                      title: 'Trang cá nhân',
                      subtitle: user?.name ?? 'Tài khoản Edly',
                      balanceText: _formatBalance(user?.balance),
                      initials: user?.initials ?? 'E',
                      onTap: () => _openAccountProfile(context),
                    ),
                    const SizedBox(height: 14),
                    if (canAccessAdminPortal) ...[
                      _MenuShortcutCard(
                        title: adminPortalTitle,
                        icon: Icons.admin_panel_settings_outlined,
                        color: HomePalette.chipGreen,
                        onTap: () => _openAdminDashboard(context),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _MenuTile(
                      title: 'Nạp tiền',
                      icon: Icons.add_card_rounded,
                      onTap: () => _openDepositSheet(context),
                    ),
                    const SizedBox(height: 12),
                    _MenuTile(
                      title: 'Đã mua',
                      icon: Icons.shopping_bag_outlined,
                      onTap: () => _openPurchasedCourses(context),
                    ),
                    const SizedBox(height: 10),
                    _MenuTile(
                      title: 'Tiến độ học tập',
                      icon: Icons.bar_chart_rounded,
                      onTap: () => _openLearningProgress(context),
                    ),
                    if (!isTeacher && !canAccessAdminPortal) ...[
                      const SizedBox(height: 10),
                      _MenuTile(
                        title: 'Đăng ký giáo viên',
                        icon: Icons.person_add_alt_1_outlined,
                        onTap: () =>
                            _showMissingMobileApi(context, 'Đăng ký giáo viên'),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const _MenuSectionTitle(title: 'Khám phá'),
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
                    const SizedBox(height: 86),
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
    required this.title,
    required this.subtitle,
    required this.balanceText,
    required this.initials,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String balanceText;
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
                      title,
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
                    const SizedBox(height: 4),
                    Text(
                      balanceText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: HomePalette.primary,
                        fontWeight: FontWeight.w800,
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
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
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
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: HomePalette.textMuted,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      tileColor: color,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    );
  }
}

class _MenuSectionTitle extends StatelessWidget {
  const _MenuSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        color: HomePalette.textPrimary,
        fontWeight: FontWeight.w800,
      ),
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
