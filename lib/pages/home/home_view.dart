import 'dart:async';

import 'package:edupen/pages/course_detail/course_detail_view.dart';
import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/account_profile/account_profile_view.dart';
import 'package:edupen/pages/home/collection_courses_view.dart';
import 'package:edupen/pages/home/home_constants.dart';
import 'package:edupen/pages/home/home_models.dart';
import 'package:edupen/pages/home/home_repository.dart';
import 'package:edupen/pages/sign_in/sign_in_view.dart';
import 'package:edupen/services/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  Timer? _slideTimer;
  int _currentSlide = 0;
  late Future<HomeDashboardData> _dashboardFuture;
  late Future<List<HomeCollectionMenuItem>> _drawerMenuFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = HomeRepository.instance.fetchDashboard();
    _drawerMenuFuture = HomeRepository.instance.fetchCollectionMenu();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _reloadDashboard() async {
    try {
      await AuthRepository.instance.refreshCurrentUser();
    } catch (_) {
      // Nếu refresh user lỗi thì vẫn thử tải dashboard.
    }
    final dashboardFuture = HomeRepository.instance.fetchDashboard();
    final drawerMenuFuture = HomeRepository.instance.fetchCollectionMenu();

    setState(() {
      _dashboardFuture = dashboardFuture;
      _drawerMenuFuture = drawerMenuFuture;
    });

    try {
      await dashboardFuture;
    } catch (_) {
      // FutureBuilder sẽ render trạng thái lỗi.
    }
    try {
      await drawerMenuFuture;
    } catch (_) {
      // Drawer sẽ render trạng thái lỗi.
    }
  }

  Future<void> _reloadDrawerMenu() async {
    final future = HomeRepository.instance.fetchCollectionMenu();
    setState(() {
      _drawerMenuFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // Drawer sẽ render trạng thái lỗi.
    }
  }

  void _startAutoSlide() {
    if (HomeContent.slides.length <= 1) {
      return;
    }

    _slideTimer?.cancel();
    _slideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }

      final nextPage = (_currentSlide + 1) % HomeContent.slides.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  void _openCourseDetail(
    HomeCourseItem course,
    _CardVisual visual,
    String sourceLabel,
    List<HomeCourseItem> relatedCourses,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseDetailView(
          course: course,
          gradient: visual.gradient,
          accentColor: visual.accentColor,
          sourceLabel: sourceLabel,
          relatedCourses: relatedCourses,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    try {
      await AuthRepository.instance.refreshCurrentUser();
    } catch (_) {
      // Bỏ qua lỗi refresh user, vẫn reload dashboard.
    }
    await _reloadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomePalette.background,
      drawer: _HomeDrawer(
        menuFuture: _drawerMenuFuture,
        onReloadMenu: _reloadDrawerMenu,
      ),
      body: Builder(
        builder: (context) {
          return RefreshIndicator(
            onRefresh: _reloadDashboard,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  titleSpacing: 16,
                  leading: IconButton(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: HomePalette.textPrimary,
                    ),
                  ),
                  title: Row(
                    children: [
                      Image.asset(
                        HomeContent.logoAsset,
                        height: 34,
                        fit: BoxFit.contain,
                      ),
                      const Spacer(),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: HomePalette.chipGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: HomePalette.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SearchBox(),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 256,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: HomeContent.slides.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentSlide = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  right: index == HomeContent.slides.length - 1
                                      ? 0
                                      : 12,
                                ),
                                child: _HeroSlideCard(
                                  data: HomeContent.slides[index],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SlideIndicator(currentSlide: _currentSlide),
                        const SizedBox(height: 24),
                        FutureBuilder<HomeDashboardData>(
                          future: _dashboardFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return _HomeErrorState(
                                message: _messageFromError(snapshot.error),
                                onRetry: _reloadDashboard,
                              );
                            }

                            final dashboard =
                                snapshot.data ??
                                const HomeDashboardData(
                                  purchased: [],
                                  featured: [],
                                  recent: [],
                                  categories: [],
                                );

                            if (dashboard.isEmpty) {
                              return const _HomeEmptyState();
                            }

                            return _HomeSections(
                              data: dashboard,
                              onCourseTap: _openCourseDetail,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _messageFromError(Object? error) {
    if (error is AppException) {
      return error.message;
    }

    return 'Không thể tải dữ liệu trang chủ.';
  }
}

class _HomeSections extends StatelessWidget {
  const _HomeSections({required this.data, required this.onCourseTap});

  final HomeDashboardData data;
  final void Function(
    HomeCourseItem course,
    _CardVisual visual,
    String sourceLabel,
    List<HomeCourseItem> relatedCourses,
  )
  onCourseTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.purchased.isNotEmpty) ...[
          const _SectionHeader(
            icon: Icons.shopping_bag_outlined,
            iconColor: HomePalette.primary,
            title: 'Gói học đã mua',
            subtitle: 'Tiếp tục học các khóa học bạn đã sở hữu',
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 336,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: data.purchased.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final visual = _cardVisualAt(index);
                return _PurchasedCourseCard(
                  data: data.purchased[index],
                  visual: visual,
                  onTap: () => onCourseTap(
                    data.purchased[index],
                    visual,
                    'Gói học đã mua',
                    data.purchased,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),
        ],
        if (data.featured.isNotEmpty) ...[
          const _SectionHeader(
            icon: Icons.star_rounded,
            iconColor: HomePalette.warning,
            title: 'Gói học nổi bật',
            subtitle: 'Những khóa học đang được quan tâm nhiều trên web',
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 348,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: data.featured.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final visual = _cardVisualAt(index);
                return _ShowcaseCourseCard(
                  data: data.featured[index],
                  visual: visual,
                  tag: 'Nổi bật',
                  badge: 'Top khóa học',
                  onTap: () => onCourseTap(
                    data.featured[index],
                    visual,
                    'Gói học nổi bật',
                    data.featured,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),
        ],
        if (data.recent.isNotEmpty) ...[
          const _SectionHeader(
            icon: Icons.visibility_outlined,
            iconColor: Color(0xFF5B8CFF),
            title: 'Gói học đã xem',
            subtitle: 'Tiếp tục học từ những khóa học bạn đã xem gần đây',
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 348,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: data.recent.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final visual = _cardVisualAt(index + 1);
                return _ShowcaseCourseCard(
                  data: data.recent[index],
                  visual: visual,
                  tag: 'Đã xem',
                  badge: 'Xem gần đây',
                  onTap: () => onCourseTap(
                    data.recent[index],
                    visual,
                    'Gói học đã xem',
                    data.recent,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),
        ],
        ...data.categories.map(
          (section) => Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: _CategorySection(section: section, onCourseTap: onCourseTap),
          ),
        ),
      ],
    );
  }
}

class _HomeDrawer extends StatelessWidget {
  const _HomeDrawer({required this.menuFuture, required this.onReloadMenu});

  final Future<List<HomeCollectionMenuItem>> menuFuture;
  final Future<void> Function() onReloadMenu;

  Future<void> _openAccountProfile(BuildContext context) async {
    final navigator = Navigator.of(context);
    navigator.pop();
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => const AccountProfileView()),
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
    HomeCollectionMenuItem item, {
    String? sectionSlug,
  }) async {
    final slug = (sectionSlug ?? item.slug).trim();
    if (slug.isEmpty) {
      Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Danh mục chưa có slug hợp lệ để mở chi tiết.'),
          ),
        );
      }
      return;
    }

    final navigator = Navigator.of(context);
    navigator.pop();
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => CollectionCoursesView(
          collectionSlug: slug,
          collectionTitle: item.title,
        ),
      ),
    );
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
    if (signature.contains('miễn phí') || signature.contains('free')) {
      return Icons.menu_book_rounded;
    }
    if (signature.contains('bài viết') || signature.contains('blog')) {
      return Icons.article_outlined;
    }
    if (signature.contains('giáo viên') || signature.contains('teacher')) {
      return Icons.person_outline_rounded;
    }
    return isParent ? Icons.folder_outlined : Icons.subdirectory_arrow_right;
  }

  List<Widget> _buildMenuTree(
    BuildContext context,
    List<HomeCollectionMenuItem> items, {
    int depth = 0,
  }) {
    final widgets = <Widget>[];
    for (final item in items) {
      if (item.hasChildren) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey<String>(
                  'home-drawer-${item.id}-${item.slug}-$depth',
                ),
                tilePadding: EdgeInsets.only(left: 12 + depth * 14, right: 10),
                childrenPadding: const EdgeInsets.only(bottom: 4),
                iconColor: HomePalette.textMuted,
                collapsedIconColor: HomePalette.textMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: HomePalette.chipBlue.withValues(alpha: 0.45),
                leading: Icon(
                  _iconForMenuItem(item, isParent: true),
                  color: HomePalette.primary,
                ),
                title: Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: HomePalette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildLeafTile(
                      context,
                      item,
                      depth: depth + 1,
                      titleOverride: 'Tất cả ${item.title}',
                      iconOverride: Icons.dashboard_customize_outlined,
                      sectionSlug: null,
                    ),
                  ),
                  ..._buildMenuTree(context, item.children, depth: depth + 1),
                ],
              ),
            ),
          ),
        );
        continue;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildLeafTile(context, item, depth: depth),
        ),
      );
    }

    widgets.addAll([
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildStaticRouteTile(
          context,
          title: 'Trang giáo viên',
          icon: Icons.person_outline_rounded,
          onTap: () {
            Navigator.of(context).pop();
            Navigator.pushNamed(context, '/teacher');
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildStaticRouteTile(
          context,
          title: 'Bài viết',
          icon: Icons.article_outlined,
          onTap: () {
            Navigator.of(context).pop();
            Navigator.pushNamed(context, '/posts');
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildStaticRouteTile(
          context,
          title: 'Miễn phí SAT',
          icon: Icons.menu_book_rounded,
          onTap: () {
            Navigator.of(context).pop();
            Navigator.pushNamed(context, '/free-sat');
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildStaticRouteTile(
          context,
          title: 'Miễn phí IELTS',
          icon: Icons.school_outlined,
          onTap: () {
            Navigator.of(context).pop();
            Navigator.pushNamed(context, '/free-ielts');
          },
        ),
      ),
    ]);
    return widgets;
  }

  Widget _buildStaticRouteTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.only(left: 14, right: 10),
        leading: Icon(icon, color: HomePalette.primary, size: 22),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: HomePalette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: HomePalette.textMuted,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildLeafTile(
    BuildContext context,
    HomeCollectionMenuItem item, {
    required int depth,
    String? titleOverride,
    IconData? iconOverride,
    String? sectionSlug,
  }) {
    final title = (titleOverride ?? item.title).trim();
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        onTap: () => _openDrawerDestination(
          context,
          item,
          sectionSlug: sectionSlug ?? item.slug,
        ),
        contentPadding: EdgeInsets.only(left: 14 + depth * 14, right: 10),
        leading: Icon(
          iconOverride ?? _iconForMenuItem(item, isParent: false),
          color: HomePalette.primary,
          size: depth == 0 ? 22 : 20,
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: HomePalette.textPrimary,
            fontWeight: depth == 0 ? FontWeight.w600 : FontWeight.w500,
            fontSize: depth == 0 ? null : 14,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: HomePalette.textMuted,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  String _messageFromMenuError(Object? error) {
    if (error is AppException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return 'Không thể tải danh mục từ API.';
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
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
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _DrawerProfileCard(),
              const SizedBox(height: 22),
              ListTile(
                onTap: () => _openAccountProfile(context),
                leading: const Icon(
                  Icons.badge_outlined,
                  color: HomePalette.primary,
                ),
                title: Text(
                  'Trang cá nhân',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: HomePalette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Cập nhật thông tin tài khoản',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                tileColor: HomePalette.chipBlue,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: FutureBuilder<List<HomeCollectionMenuItem>>(
                  future: menuFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return _DrawerMenuStatus(
                        icon: Icons.error_outline_rounded,
                        message: _messageFromMenuError(snapshot.error),
                        actionLabel: 'Thử lại',
                        onAction: onReloadMenu,
                      );
                    }

                    final menuItems = snapshot.data ?? const [];
                    if (menuItems.isEmpty) {
                      return _DrawerMenuStatus(
                        icon: Icons.menu_open_rounded,
                        message: 'Chưa có danh mục nào để hiển thị.',
                        actionLabel: 'Tải lại',
                        onAction: onReloadMenu,
                      );
                    }

                    return ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Danh mục',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: HomePalette.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._buildMenuTree(context, menuItems),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async => _goToSignIn(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE9EC),
                    foregroundColor: const Color(0xFFE5485D),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
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
    );
  }
}

class _DrawerMenuStatus extends StatelessWidget {
  const _DrawerMenuStatus({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: HomePalette.textSecondary),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: HomePalette.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async => onAction(),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerProfileCard extends StatelessWidget {
  const _DrawerProfileCard();

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    final balance = user?.balance;
    final currencyFormat = NumberFormat.decimalPattern('vi_VN');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomePalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HomePalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: HomePalette.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              user?.initials ?? 'E',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user == null ? 'Chào bạn' : 'Xin chào',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: HomePalette.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.name.isNotEmpty == true
                      ? user!.name
                      : 'Khám phá khóa học Edupen',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: HomePalette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.subtitle ?? 'Đăng nhập để đồng bộ tiến độ học tập',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: HomePalette.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: HomePalette.chipGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: HomePalette.secondary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          balance == null
                              ? 'Số dư đang cập nhật'
                              : 'Số dư: ${currencyFormat.format(balance)}đ',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: HomePalette.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomePalette.border),
      ),
      child: const TextField(
        readOnly: true,
        onTapOutside: _dismissFocus,
        decoration: InputDecoration(
          icon: Icon(Icons.search_rounded, color: HomePalette.textMuted),
          hintText: HomeContent.searchHint,
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _HeroSlideCard extends StatelessWidget {
  const _HeroSlideCard({required this.data});

  final HomeHeroSlideData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: data.gradient,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x190F172A),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              data.highlight,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: data.gradient.last,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        data.buttonText,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: data.accent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlideIndicator extends StatelessWidget {
  const _SlideIndicator({required this.currentSlide});

  final int currentSlide;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        HomeContent.slides.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentSlide == index ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: currentSlide == index
                ? HomePalette.primary
                : HomePalette.border,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: HomePalette.textPrimary,
                            fontSize: 28,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HomePalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PurchasedCourseCard extends StatelessWidget {
  const _PurchasedCourseCard({
    required this.data,
    required this.visual,
    required this.onTap,
  });

  final HomeCourseItem data;
  final _CardVisual visual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = ((data.progress ?? 0).clamp(0, 100)) / 100;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 296,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HomePalette.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: HomePalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CourseThumbnail(
                imageUrl: data.thumbnailUrl,
                height: 142,
                visual: visual,
                badge: data.category ?? 'Đã mua',
                badgeColor: visual.accentColor,
                footerLabel: data.totalLessons != null
                    ? '${data.totalLessons} học phần'
                    : null,
                footerIcon: Icons.play_circle_fill_rounded,
              ),
              const SizedBox(height: 14),
              Text(
                data.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: HomePalette.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.shortDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HomePalette.textSecondary,
                  height: 1.35,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    'Progress: ${((data.progress ?? 0).clamp(0, 100))}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: HomePalette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (data.completedLessons != null &&
                      data.totalLessons != null)
                    Text(
                      '${data.completedLessons}/${data.totalLessons}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HomePalette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: HomePalette.border,
                  valueColor: AlwaysStoppedAnimation<Color>(visual.accentColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowcaseCourseCard extends StatelessWidget {
  const _ShowcaseCourseCard({
    required this.data,
    required this.visual,
    required this.tag,
    required this.badge,
    required this.onTap,
  });

  final HomeCourseItem data;
  final _CardVisual visual;
  final String tag;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 246,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: HomePalette.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: HomePalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CourseThumbnail(
                imageUrl: data.thumbnailUrl,
                height: 148,
                visual: visual,
                badge: tag,
                badgeColor: visual.accentColor,
                footerIcon: Icons.arrow_outward_rounded,
              ),
              const SizedBox(height: 14),
              Text(
                data.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: HomePalette.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.shortDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HomePalette.textSecondary,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: visual.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      color: visual.accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      badge,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: HomePalette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.section, required this.onCourseTap});

  final HomeCategorySection section;
  final void Function(
    HomeCourseItem course,
    _CardVisual visual,
    String sourceLabel,
    List<HomeCourseItem> relatedCourses,
  )
  onCourseTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.grid_view_rounded,
          iconColor: HomePalette.secondary,
          title: 'Khóa học ${section.title}',
          subtitle: section.subtitle,
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 348,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: section.courses.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final visual = _cardVisualAt(index + 2);
              return _ShowcaseCourseCard(
                data: section.courses[index],
                visual: visual,
                tag: section.title,
                badge: 'Khám phá ngay',
                onTap: () => onCourseTap(
                  section.courses[index],
                  visual,
                  'Khóa học ${section.title}',
                  section.courses,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CourseThumbnail extends StatelessWidget {
  const _CourseThumbnail({
    required this.imageUrl,
    required this.height,
    required this.visual,
    required this.badge,
    required this.badgeColor,
    this.footerLabel,
    this.footerIcon,
  });

  final String? imageUrl;
  final double height;
  final _CardVisual visual;
  final String badge;
  final Color badgeColor;
  final String? footerLabel;
  final IconData? footerIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: visual.gradient),
              ),
            ),
            if (imageUrl != null && imageUrl!.isNotEmpty)
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (footerLabel != null)
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    footerLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  footerIcon ?? Icons.open_in_new_rounded,
                  color: visual.accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomePalette.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 36,
            color: HomePalette.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HomePalette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => onRetry(),
            child: const Text('Tải lại'),
          ),
        ],
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomePalette.border),
      ),
      child: Text(
        'Chưa có dữ liệu gói học để hiển thị trên trang chủ.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: HomePalette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CardVisual {
  const _CardVisual({required this.gradient, required this.accentColor});

  final List<Color> gradient;
  final Color accentColor;
}

const List<_CardVisual> _cardVisuals = [
  _CardVisual(
    gradient: [Color(0xFFE8F0FF), Color(0xFFD8E6FF)],
    accentColor: Color(0xFF3F69FF),
  ),
  _CardVisual(
    gradient: [Color(0xFFFFF0EA), Color(0xFFFFE2D3)],
    accentColor: Color(0xFFFF6F3C),
  ),
  _CardVisual(
    gradient: [Color(0xFFE8FBF7), Color(0xFFD1F4EC)],
    accentColor: Color(0xFF17B97C),
  ),
  _CardVisual(
    gradient: [Color(0xFFFFF4D6), Color(0xFFFFE8A8)],
    accentColor: Color(0xFFFFB020),
  ),
];

_CardVisual _cardVisualAt(int index) {
  return _cardVisuals[index % _cardVisuals.length];
}

void _dismissFocus(PointerDownEvent _) {
  FocusManager.instance.primaryFocus?.unfocus();
}
