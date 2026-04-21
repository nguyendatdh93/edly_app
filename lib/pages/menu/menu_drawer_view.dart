import 'package:edly/core/navigation/app_routes.dart';
import 'package:edly/pages/account_profile/account_profile_view.dart';
import 'package:edly/pages/admin/admin_dashboard_view.dart';
import 'package:edly/pages/articles/article_list_view.dart';
import 'package:edly/pages/home/home_constants.dart';
import 'package:edly/pages/ielts_packages/ielts_packages_view.dart';
import 'package:edly/pages/menu/user_course_list_view.dart';
import 'package:edly/pages/sat_packages/sat_packages_view.dart';
import 'package:edly/pages/sign_in/sign_in_view.dart';
import 'package:edly/pages/teacher/teacher_view.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:edly/widgets/learning_dock_bar.dart';
import 'package:edly/widgets/mobile_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
        builder: (_) => const UserCourseListView(
          mode: UserCourseListMode.purchased,
          currentTab: LearningDockTab.account,
        ),
      ),
    );
  }

  Future<void> _openLearningProgress(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const UserCourseListView(
          mode: UserCourseListMode.progress,
          currentTab: LearningDockTab.account,
        ),
      ),
    );
  }

  Future<void> _openTeacherPage(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TeacherView()));
  }

  Future<void> _openArticles(
    BuildContext context, {
    String title = 'Bài viết',
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ArticleListView(title: title, currentTab: LearningDockTab.account),
      ),
    );
  }

  Future<void> _goToSignIn(BuildContext context) async {
    await AuthRepository.instance.signOut();

    if (!context.mounted) {
      return;
    }

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SignInView()),
      (route) => false,
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

  Future<void> _openNamedRoute(BuildContext context, String routeName) async {
    switch (routeName) {
      case AppRoutes.teacher:
        await _openTeacherPage(context);
        return;
      case AppRoutes.satFree:
        await _openSatFree(context);
        return;
      case AppRoutes.ieltsFree:
        await _openIeltsFree(context);
        return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng này chưa hỗ trợ trên mobile.')),
    );
  }

  Future<void> _showFreeCourseSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: HomePalette.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                _SecondaryLinkCard(
                  title: 'Miễn phí SAT',
                  subtitle: 'Đề luyện và tài liệu SAT miễn phí',
                  icon: Icons.menu_book_rounded,
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _openNamedRoute(context, AppRoutes.satFree);
                  },
                ),
                const SizedBox(height: 12),
                _SecondaryLinkCard(
                  title: 'Miễn phí IELTS',
                  subtitle: 'Đề luyện và tài liệu IELTS miễn phí',
                  icon: Icons.school_outlined,
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _openNamedRoute(context, AppRoutes.ieltsFree);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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

    if (title == 'bài viết') {
      await _openArticles(context, title: item.title);
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
      bottomNavigationBar: const LearningDockBar(
        currentTab: LearningDockTab.account,
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MenuProfileCard(
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).pop()
                      : null,
                ),
                const SizedBox(height: 14),
                _MenuWalletCard(onTopUp: () => _openDepositSheet(context)),
                const SizedBox(height: 28),
                Text(
                  'Truy cập nhanh',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: HomePalette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _QuickActionCard(
                      title: 'Trang cá nhân',
                      subtitle: 'Cập nhật hồ sơ và thông tin học tập',
                      icon: Icons.badge_outlined,
                      accent: const Color(0xFFEAF0FF),
                      onTap: () => _openAccountProfile(context),
                    ),
                    _QuickActionCard(
                      title: 'Trang giáo viên',
                      subtitle: 'Mở danh sách giáo viên và lộ trình',
                      icon: Icons.person_outline_rounded,
                      accent: const Color(0xFFE9F8F2),
                      onTap: () => _openTeacherPage(context),
                    ),
                    _QuickActionCard(
                      title: 'Đã mua',
                      subtitle: 'Xem nhanh các khóa học và quyền truy cập',
                      icon: Icons.shopping_bag_outlined,
                      accent: const Color(0xFFFFF2E2),
                      onTap: () => _openPurchasedCourses(context),
                    ),
                    _QuickActionCard(
                      title: 'Kho miễn phí',
                      subtitle: 'SAT và IELTS miễn phí cho bạn',
                      icon: Icons.auto_stories_outlined,
                      accent: const Color(0xFFFDEAF1),
                      onTap: () => _showFreeCourseSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Thư mục khóa học',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: HomePalette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Khám phá các khóa học, đề luyện và tài liệu học tập dành cho bạn.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: HomePalette.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                if (canAccessAdminPortal) ...[
                  _SecondaryLinkCard(
                    title: adminPortalTitle,
                    subtitle: 'Mở khu vực quản trị và công cụ nội bộ',
                    icon: Icons.admin_panel_settings_outlined,
                    onTap: () => _openAdminDashboard(context),
                  ),
                  const SizedBox(height: 12),
                ],
                _SecondaryLinkCard(
                  title: 'Tiến độ học tập',
                  subtitle: 'Theo dõi tiến độ hoàn thành các khóa học đã mua',
                  icon: Icons.bar_chart_rounded,
                  onTap: () => _openLearningProgress(context),
                ),
                if (!isTeacher && !canAccessAdminPortal) ...[
                  const SizedBox(height: 12),
                  _SecondaryLinkCard(
                    title: 'Đăng ký giáo viên',
                    subtitle:
                        'Gửi yêu cầu để mở quyền sử dụng công cụ giáo viên',
                    icon: Icons.person_add_alt_1_outlined,
                    onTap: () => Future<void>.sync(
                      () => _showMissingMobileApi(context, 'Đăng ký giáo viên'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ...HomeContent.drawerItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SecondaryLinkCard(
                      title: item.title,
                      subtitle: _subtitleForDrawerItem(item.title),
                      icon: item.icon,
                      onTap: () => _openDrawerDestination(context, item),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _goToSignIn(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFE9EC),
                      foregroundColor: const Color(0xFFE5485D),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text(
                      'Đăng xuất',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitleForDrawerItem(String title) {
    final normalized = title.trim().toLowerCase();
    if (normalized.contains('ielts')) {
      return 'Mở kho đề và tài liệu IELTS.';
    }
    if (normalized.contains('sat')) {
      return 'Mở kho đề và tài liệu SAT.';
    }
    if (normalized.contains('giáo viên')) {
      return 'Truy cập công cụ và nội dung dành cho giáo viên.';
    }
    if (normalized.contains('bài viết')) {
      return 'Xem bài viết và tài liệu tham khảo.';
    }
    return 'Mở nhanh nội dung tương ứng.';
  }
}

class _MenuProfileCard extends StatelessWidget {
  const _MenuProfileCard({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    final displayName = user?.name.isNotEmpty == true ? user!.name : 'Admin';

    return Container(
      padding: const EdgeInsets.only(top: 40),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
              onPressed: onBack,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF6F8FC),
                foregroundColor: HomePalette.textPrimary,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD66B), Color(0xFFFFB443)],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              user?.initials ?? 'A',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user == null ? 'Hi' : 'Xin chào',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: HomePalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: HomePalette.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: HomePalette.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A16345D),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: HomePalette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuWalletCard extends StatelessWidget {
  const _MenuWalletCard({required this.onTopUp});

  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    final balance = user?.balance ?? 0;
    final currencyFormat = NumberFormat.decimalPattern('vi_VN');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HomePalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: HomePalette.chipGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: HomePalette.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Số dư',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: HomePalette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${currencyFormat.format(balance)}đ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: HomePalette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onTopUp,
            style: FilledButton.styleFrom(
              backgroundColor: HomePalette.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Nạp tiền',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 44) / 2;

    return SizedBox(
      width: width < 150 ? double.infinity : width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: HomePalette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: HomePalette.textPrimary),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: HomePalette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: HomePalette.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryLinkCard extends StatelessWidget {
  const _SecondaryLinkCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HomePalette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HomePalette.chipBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: HomePalette.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: HomePalette.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HomePalette.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: HomePalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showMissingMobileApi(BuildContext context, String title) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$title can API mobile de hien thi native.')),
  );
}
