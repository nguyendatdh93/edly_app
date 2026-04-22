import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/account_profile/account_profile_view.dart';
import 'package:edupen/pages/home/collection_courses_view.dart';
import 'package:edupen/pages/home/home_constants.dart';
import 'package:edupen/pages/home/home_models.dart';
import 'package:edupen/pages/home/home_repository.dart';
import 'package:edupen/pages/sign_in/sign_in_view.dart';
import 'package:edupen/services/auth_repository.dart';
import 'package:edupen/widgets/learning_dock_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MenuView extends StatefulWidget {
  const MenuView({super.key});

  @override
  State<MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends State<MenuView> {
  late Future<List<HomeCollectionMenuItem>> _menuFuture;

  @override
  void initState() {
    super.initState();
    _menuFuture = HomeRepository.instance.fetchCollectionMenu();
  }

  Future<void> _reloadMenu() async {
    final future = HomeRepository.instance.fetchCollectionMenu();
    setState(() {
      _menuFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder sẽ hiển thị trạng thái lỗi.
    }
  }

  Future<void> _openAccountProfile() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AccountProfileView()));
  }

  Future<void> _goToSignIn() async {
    await AuthRepository.instance.signOut();

    if (!mounted) {
      return;
    }

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SignInView()),
      (route) => false,
    );
  }

  Future<void> _openCollectionDestination(
    HomeCollectionMenuItem item, {
    String? sectionSlug,
  }) async {
    final slug = (sectionSlug ?? item.slug).trim();
    if (slug.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Danh mục chưa có slug hợp lệ để mở chi tiết.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CollectionCoursesView(
          collectionSlug: slug,
          collectionTitle: item.title,
        ),
      ),
    );
  }

  Future<void> _openNamedRoute(String routeName) async {
    await Navigator.of(context).pushNamed(routeName);
  }

  void _showTopUpComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng nạp tiền sẽ sớm được cập nhật.')),
    );
  }

  Future<void> _showFreeCourseSheet() async {
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
                  title: 'Miễn phí',
                  subtitle: 'Đề luyện và tài liệu miễn phí',
                  icon: Icons.menu_book_rounded,
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _openNamedRoute('/free-sat');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _messageFromMenuError(Object? error) {
    if (error is AppException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return 'Không thể tải danh mục từ API.';
  }

  IconData _iconForMenuItem(
    HomeCollectionMenuItem item, {
    required bool isParent,
  }) {
    final signature = '${item.slug} ${item.title}'.trim().toLowerCase();
    if (signature.contains('ielts')) {
      return Icons.language_rounded;
    }
    if (signature.contains('sat') || RegExp(r'\bact\b').hasMatch(signature)) {
      return Icons.auto_awesome_rounded;
    }
    if (signature.contains('miễn phí') ||
        signature.contains('mien phi') ||
        signature.contains('free')) {
      return Icons.menu_book_rounded;
    }
    if (signature.contains('bài viết') ||
        signature.contains('bai viet') ||
        signature.contains('blog')) {
      return Icons.article_outlined;
    }
    if (signature.contains('giáo viên') ||
        signature.contains('giao vien') ||
        signature.contains('teacher')) {
      return Icons.person_outline_rounded;
    }
    return isParent ? Icons.folder_outlined : Icons.subdirectory_arrow_right;
  }

  List<Widget> _buildMenuTree(
    BuildContext context,
    List<HomeCollectionMenuItem> items, {
    int depth = 0,
  }) {
    return items.map((item) {
      if (item.hasChildren) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _MenuFolderCard(
            depth: depth,
            item: item,
            leadingIcon: _iconForMenuItem(item, isParent: true),
            allCoursesTile: _buildLeafTile(
              item,
              depth: depth + 1,
              titleOverride: 'Tất cả ${item.title}',
              iconOverride: Icons.dashboard_customize_outlined,
              sectionSlug: null,
            ),
            children: _buildMenuTree(context, item.children, depth: depth + 1),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildLeafTile(item, depth: depth),
      );
    }).toList();
  }

  Widget _buildLeafTile(
    HomeCollectionMenuItem item, {
    required int depth,
    String? titleOverride,
    IconData? iconOverride,
    String? sectionSlug,
  }) {
    final title = (titleOverride ?? item.title).trim();

    return _MenuActionTile(
      title: title,
      icon: iconOverride ?? _iconForMenuItem(item, isParent: false),
      depth: depth,
      onTap: () => _openCollectionDestination(
        item,
        sectionSlug: sectionSlug ?? item.slug,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomePalette.background,
      bottomNavigationBar: const LearningDockBar(
        currentTab: LearningDockTab.account,
      ),
      body: RefreshIndicator(
        onRefresh: _reloadMenu,
        child: ListView(
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
                  _MenuWalletCard(onTopUp: _showTopUpComingSoon),
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
                        onTap: _openAccountProfile,
                      ),
                      _QuickActionCard(
                        title: 'Trang giáo viên',
                        subtitle: 'Mở danh sách giáo viên và lộ trình',
                        icon: Icons.person_outline_rounded,
                        accent: const Color(0xFFE9F8F2),
                        onTap: () => _openNamedRoute('/teacher'),
                      ),
                      _QuickActionCard(
                        title: 'Bài viết',
                        subtitle: 'Xem bài viết, chia sẻ và tài liệu',
                        icon: Icons.article_outlined,
                        accent: const Color(0xFFFFF2E2),
                        onTap: () => _openNamedRoute('/posts'),
                      ),
                      _QuickActionCard(
                        title: 'Kho miễn phí',
                        subtitle: 'Danh sách khóa học miễn phí cho bạn',
                        icon: Icons.auto_stories_outlined,
                        accent: const Color(0xFFFDEAF1),
                        onTap: _showFreeCourseSheet,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Thư mục khóa học',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: HomePalette.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Khám phá các nhóm khóa học theo từng danh mục để bắt đầu lộ trình học hiệu quả hơn.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: HomePalette.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<HomeCollectionMenuItem>>(
                    future: _menuFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        return _MenuStatusCard(
                          icon: Icons.error_outline_rounded,
                          message: _messageFromMenuError(snapshot.error),
                          actionLabel: 'Thử lại',
                          onAction: _reloadMenu,
                        );
                      }

                      final menuItems = snapshot.data ?? const [];
                      if (menuItems.isEmpty) {
                        return _MenuStatusCard(
                          icon: Icons.folder_open_rounded,
                          message: 'Chưa có danh mục nào để hiển thị.',
                          actionLabel: 'Tải lại',
                          onAction: _reloadMenu,
                        );
                      }

                      return Column(
                        children: [
                          ..._buildMenuTree(context, menuItems),
                          const SizedBox(height: 8),
                          _SecondaryLinkCard(
                            title: 'Miễn phí',
                            subtitle: 'Danh sách khóa học miễn phí cho bạn',
                            icon: Icons.menu_book_rounded,
                            onTap: () => _openNamedRoute('/free-courses'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _goToSignIn,
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
      ),
    );
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

class _MenuFolderCard extends StatelessWidget {
  const _MenuFolderCard({
    required this.depth,
    required this.item,
    required this.leadingIcon,
    required this.allCoursesTile,
    required this.children,
  });

  final int depth;
  final HomeCollectionMenuItem item;
  final IconData leadingIcon;
  final Widget allCoursesTile;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final radius = (24 - depth.clamp(0, 2) * 2).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: HomePalette.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.only(
            left: 14 + depth * 8,
            right: 14,
            top: 4,
            bottom: 4,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          iconColor: HomePalette.textMuted,
          collapsedIconColor: HomePalette.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: HomePalette.chipBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(leadingIcon, color: HomePalette.primary),
          ),
          title: Text(
            item.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: HomePalette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            'Mở thư mục để xem danh mục con',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: HomePalette.textSecondary),
          ),
          children: [
            allCoursesTile,
            if (children.isNotEmpty) const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MenuActionTile extends StatelessWidget {
  const _MenuActionTile({
    required this.title,
    required this.icon,
    required this.depth,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final int depth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: depth == 0 ? Colors.white : const Color(0xFFF8FAFF),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: depth == 0 ? HomePalette.border : const Color(0xFFE7ECF7),
            ),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.only(
              left: 14 + depth * 10,
              right: 12,
              top: 2,
              bottom: 2,
            ),
            leading: Container(
              width: depth == 0 ? 42 : 38,
              height: depth == 0 ? 42 : 38,
              decoration: BoxDecoration(
                color: depth == 0 ? HomePalette.chipBlue : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: HomePalette.primary, size: 20),
            ),
            title: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: HomePalette.textPrimary,
                fontWeight: depth == 0 ? FontWeight.w700 : FontWeight.w600,
                fontSize: depth == 0 ? null : 14,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: HomePalette.textMuted,
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

class _MenuStatusCard extends StatelessWidget {
  const _MenuStatusCard({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomePalette.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: HomePalette.textSecondary),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: HomePalette.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: HomePalette.primary,
              side: const BorderSide(color: HomePalette.border),
              minimumSize: const Size(120, 44),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
