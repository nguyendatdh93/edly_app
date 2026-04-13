import 'package:edly/core/network/app_exception.dart';
import 'package:edly/models/admin_dashboard.dart';
import 'package:edly/models/admin_management.dart';
import 'package:edly/pages/home/home_constants.dart';
import 'package:edly/pages/sign_in/sign_in_view.dart';
import 'package:edly/services/admin_repository.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<AdminDashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _dashboardFuture = AdminRepository.instance.fetchDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reloadDashboard() async {
    final future = AdminRepository.instance.fetchDashboard();
    setState(() {
      _dashboardFuture = future;
    });
    await future;
  }

  void _openManagementTab(String key) {
    if (!mounted) {
      return;
    }

    final tabIndex = switch (key) {
      'users' => 1,
      'courses' => 2,
      'transactions' => 3,
      _ => 0,
    };

    _tabController.animateTo(tabIndex);
  }

  Future<void> _signOut() async {
    await AuthRepository.instance.signOut();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SignInView()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomePalette.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Quản trị',
          style: TextStyle(
            color: HomePalette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _signOut,
            icon: const Icon(
              Icons.logout_rounded,
              color: HomePalette.textPrimary,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: HomePalette.primary,
          unselectedLabelColor: HomePalette.textSecondary,
          indicatorColor: HomePalette.primary,
          tabs: const [
            Tab(text: 'Tổng quan'),
            Tab(text: 'Users'),
            Tab(text: 'Courses'),
            Tab(text: 'Transactions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AdminOverviewTab(
            future: _dashboardFuture,
            onRefresh: _reloadDashboard,
            onQuickActionTap: _openManagementTab,
          ),
          const _AdminUsersTab(),
          const _AdminCoursesTab(),
          const _AdminTransactionsTab(),
        ],
      ),
    );
  }
}

class _AdminOverviewTab extends StatelessWidget {
  const _AdminOverviewTab({
    required this.future,
    required this.onRefresh,
    required this.onQuickActionTap,
  });

  final Future<AdminDashboardData> future;
  final Future<void> Function() onRefresh;
  final void Function(String key) onQuickActionTap;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: FutureBuilder<AdminDashboardData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingScroll();
          }

          if (snapshot.hasError) {
            return _AdminErrorState(
              message: _messageFromError(snapshot.error),
              onRetry: onRefresh,
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return _AdminErrorState(
              message: 'Không có dữ liệu quản trị.',
              onRetry: onRefresh,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _DashboardMeta(generatedAt: data.generatedAt),
              const SizedBox(height: 14),
              _SummaryGrid(summary: data.summary),
              const SizedBox(height: 22),
              const _SectionTitle(
                title: 'Thao tác quản trị',
                subtitle: 'Bấm để mở nhanh các module quản trị trên app.',
              ),
              const SizedBox(height: 12),
              ...data.quickActions.map(
                (action) => _QuickActionCard(
                  action: action,
                  onTap: () => _handleQuickActionTap(context, action),
                ),
              ),
              const SizedBox(height: 22),
              const _SectionTitle(
                title: 'Người dùng mới',
                subtitle: 'Tài khoản tạo gần đây trên hệ thống.',
              ),
              const SizedBox(height: 12),
              if (data.recentUsers.isEmpty)
                const _EmptyBox(message: 'Chưa có dữ liệu người dùng gần đây.')
              else
                ...data.recentUsers.map(_RecentUserTile.new),
            ],
          );
        },
      ),
    );
  }

  void _handleQuickActionTap(BuildContext context, AdminQuickAction action) {
    if (action.enabled) {
      if (action.key == 'users' ||
          action.key == 'courses' ||
          action.key == 'transactions') {
        onQuickActionTap(action.key);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đang mở module: ${action.title}')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Module ${action.title} sẽ được triển khai tiếp.'),
      ),
    );
  }
}

class _AdminUsersTab extends StatefulWidget {
  const _AdminUsersTab();

  @override
  State<_AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<_AdminUsersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedRole = 'all';
  late Future<AdminUsersData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<AdminUsersData> _load() {
    return AdminRepository.instance.fetchUsers(
      page: 1,
      perPage: 30,
      search: _searchController.text,
      role: _selectedRole,
    );
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  void _submitFilters() {
    final future = _load();
    setState(() {
      _future = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TabToolbar(
          searchController: _searchController,
          searchHint: 'Tìm tên, email, số điện thoại',
          onSearchSubmitted: (_) => _submitFilters(),
          onSearchTap: _submitFilters,
          filterLabel: 'Vai trò',
          filterValue: _selectedRole,
          options: const [
            _FilterOption(value: 'all', label: 'Tất cả'),
            _FilterOption(value: 'admin', label: 'Admin'),
            _FilterOption(value: 'staff', label: 'Staff'),
            _FilterOption(value: 'teacher', label: 'Teacher'),
            _FilterOption(value: 'student', label: 'Student'),
            _FilterOption(value: 'parent', label: 'Parent'),
          ],
          onFilterChanged: (value) {
            setState(() {
              _selectedRole = value;
            });
            _submitFilters();
          },
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<AdminUsersData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _LoadingScroll();
                }

                if (snapshot.hasError) {
                  return _AdminErrorState(
                    message: _messageFromError(snapshot.error),
                    onRetry: _reload,
                  );
                }

                final data = snapshot.data;
                if (data == null || data.items.isEmpty) {
                  return const _EmptyScrollable(
                    message: 'Không có người dùng phù hợp bộ lọc hiện tại.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
                  itemCount: data.items.length + 1,
                  separatorBuilder: (_, index) => index == 0
                      ? const SizedBox(height: 12)
                      : const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _MetaSummaryCard(
                        title: 'Danh sách người dùng',
                        meta: data.meta,
                      );
                    }

                    final user = data.items[index - 1];
                    return _AdminUserCard(user: user);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminCoursesTab extends StatefulWidget {
  const _AdminCoursesTab();

  @override
  State<_AdminCoursesTab> createState() => _AdminCoursesTabState();
}

class _AdminCoursesTabState extends State<_AdminCoursesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'all';
  late Future<AdminCoursesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<AdminCoursesData> _load() {
    return AdminRepository.instance.fetchCourses(
      page: 1,
      perPage: 30,
      search: _searchController.text,
      status: _selectedStatus,
    );
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  void _submitFilters() {
    final future = _load();
    setState(() {
      _future = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TabToolbar(
          searchController: _searchController,
          searchHint: 'Tìm tiêu đề hoặc slug khóa học',
          onSearchSubmitted: (_) => _submitFilters(),
          onSearchTap: _submitFilters,
          filterLabel: 'Trạng thái',
          filterValue: _selectedStatus,
          options: const [
            _FilterOption(value: 'all', label: 'Tất cả'),
            _FilterOption(value: 'published', label: 'Published'),
            _FilterOption(value: 'draft', label: 'Draft'),
            _FilterOption(value: 'hidden', label: 'Hidden'),
          ],
          onFilterChanged: (value) {
            setState(() {
              _selectedStatus = value;
            });
            _submitFilters();
          },
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<AdminCoursesData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _LoadingScroll();
                }

                if (snapshot.hasError) {
                  return _AdminErrorState(
                    message: _messageFromError(snapshot.error),
                    onRetry: _reload,
                  );
                }

                final data = snapshot.data;
                if (data == null || data.items.isEmpty) {
                  return const _EmptyScrollable(
                    message: 'Không có khóa học phù hợp bộ lọc hiện tại.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
                  itemCount: data.items.length + 1,
                  separatorBuilder: (_, index) => index == 0
                      ? const SizedBox(height: 12)
                      : const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _MetaSummaryCard(
                        title: 'Danh sách khóa học',
                        meta: data.meta,
                      );
                    }

                    final course = data.items[index - 1];
                    return _AdminCourseCard(course: course);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminTransactionsTab extends StatefulWidget {
  const _AdminTransactionsTab();

  @override
  State<_AdminTransactionsTab> createState() => _AdminTransactionsTabState();
}

class _AdminTransactionsTabState extends State<_AdminTransactionsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'all';
  late Future<AdminTransactionsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<AdminTransactionsData> _load() {
    return AdminRepository.instance.fetchTransactions(
      page: 1,
      perPage: 30,
      search: _searchController.text,
      status: _selectedStatus,
    );
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  void _submitFilters() {
    final future = _load();
    setState(() {
      _future = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TabToolbar(
          searchController: _searchController,
          searchHint: 'Tìm theo mã GD, loại, tên user',
          onSearchSubmitted: (_) => _submitFilters(),
          onSearchTap: _submitFilters,
          filterLabel: 'Status',
          filterValue: _selectedStatus,
          options: const [
            _FilterOption(value: 'all', label: 'Tất cả'),
            _FilterOption(value: 'COMPLETED', label: 'Completed'),
            _FilterOption(value: 'PENDING', label: 'Pending'),
            _FilterOption(value: 'FAILED', label: 'Failed'),
            _FilterOption(value: 'UNPROCESSED', label: 'Unprocessed'),
          ],
          onFilterChanged: (value) {
            setState(() {
              _selectedStatus = value;
            });
            _submitFilters();
          },
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<AdminTransactionsData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _LoadingScroll();
                }

                if (snapshot.hasError) {
                  return _AdminErrorState(
                    message: _messageFromError(snapshot.error),
                    onRetry: _reload,
                  );
                }

                final data = snapshot.data;
                if (data == null || data.items.isEmpty) {
                  return const _EmptyScrollable(
                    message: 'Không có giao dịch phù hợp bộ lọc hiện tại.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
                  itemCount: data.items.length + 1,
                  separatorBuilder: (_, index) => index == 0
                      ? const SizedBox(height: 12)
                      : const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _MetaSummaryCard(
                        title: 'Danh sách giao dịch',
                        meta: data.meta,
                      );
                    }

                    final transaction = data.items[index - 1];
                    return _AdminTransactionCard(transaction: transaction);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardMeta extends StatelessWidget {
  const _DashboardMeta({required this.generatedAt});

  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final text = generatedAt == null
        ? 'Đang hiển thị dữ liệu mới nhất'
        : 'Cập nhật lúc ${DateFormat('HH:mm dd/MM/yyyy').format(generatedAt!.toLocal())}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_outlined, color: HomePalette.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: HomePalette.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final AdminDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final metrics = <_DashboardMetric>[
      _DashboardMetric(
        title: 'Tổng người dùng',
        value: _number(summary.usersTotal),
        icon: Icons.groups_rounded,
        color: HomePalette.primary,
      ),
      _DashboardMetric(
        title: 'Mới hôm nay',
        value: _number(summary.usersNewToday),
        icon: Icons.person_add_alt_1_rounded,
        color: const Color(0xFF2C8EFF),
      ),
      _DashboardMetric(
        title: 'Đăng nhập hôm nay',
        value: _number(summary.activeToday),
        icon: Icons.login_rounded,
        color: const Color(0xFF17B97C),
      ),
      _DashboardMetric(
        title: 'Admin',
        value: _number(summary.adminsTotal),
        icon: Icons.admin_panel_settings_rounded,
        color: const Color(0xFF5D50F7),
      ),
      _DashboardMetric(
        title: 'Nhân viên',
        value: _number(summary.staffTotal),
        icon: Icons.badge_outlined,
        color: const Color(0xFF0E7490),
      ),
      _DashboardMetric(
        title: 'Học sinh',
        value: _number(summary.studentsTotal),
        icon: Icons.school_outlined,
        color: const Color(0xFFEA580C),
      ),
      _DashboardMetric(
        title: 'Khóa học publish',
        value: _number(summary.coursesPublished),
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF0F766E),
      ),
      _DashboardMetric(
        title: 'Doanh thu hôm nay',
        value: _currency(summary.revenueCompletedToday),
        icon: Icons.payments_outlined,
        color: const Color(0xFF9333EA),
      ),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.36,
      ),
      itemBuilder: (context, index) {
        return _MetricCard(metric: metrics[index]);
      },
    );
  }

  static String _number(int value) {
    return NumberFormat.decimalPattern().format(value);
  }

  static String _currency(int value) {
    if (value <= 0) {
      return '0đ';
    }
    return '${NumberFormat.decimalPattern().format(value)}đ';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _DashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(metric.icon, color: metric.color, size: 18),
          ),
          const Spacer(),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HomePalette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            metric.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HomePalette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action, required this.onTap});

  final AdminQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomePalette.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: action.enabled
                ? HomePalette.secondary.withValues(alpha: 0.16)
                : HomePalette.border,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.dashboard_customize_outlined,
            color: action.enabled
                ? HomePalette.secondary
                : HomePalette.textMuted,
          ),
        ),
        title: Text(
          action.title,
          style: const TextStyle(
            color: HomePalette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            action.description,
            style: const TextStyle(
              color: HomePalette.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        trailing: action.enabled
            ? const Icon(
                Icons.chevron_right_rounded,
                color: HomePalette.textMuted,
              )
            : const _SoonTag(),
        onTap: onTap,
      ),
    );
  }
}

class _RecentUserTile extends StatelessWidget {
  const _RecentUserTile(this.user);

  final AdminRecentUser user;

  @override
  Widget build(BuildContext context) {
    final subtitle = user.email ?? user.phone ?? 'Không có email/sđt';
    final createdAt = user.createdAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomePalette.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: HomePalette.chipBlue,
          foregroundColor: HomePalette.primary,
          child: Text(
            _initials(user.name),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HomePalette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if ((user.roleName ?? '').isNotEmpty)
              _RoleChip(label: user.roleName!),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: HomePalette.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              createdAt == null
                  ? 'Ngày tạo: --'
                  : 'Ngày tạo: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toLocal())}',
              style: const TextStyle(
                color: HomePalette.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminUserCard extends StatelessWidget {
  const _AdminUserCard({required this.user});

  final AdminUserListItem user;

  @override
  Widget build(BuildContext context) {
    final subtitle = user.email ?? user.phone ?? 'Không có email/sđt';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomePalette.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: HomePalette.chipBlue,
          foregroundColor: HomePalette.primary,
          child: Text(
            _initials(user.name),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HomePalette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if ((user.roleName ?? '').trim().isNotEmpty)
              _RoleChip(label: user.roleName!.trim()),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: HomePalette.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              'Tạo lúc: ${_dateTimeOrDash(user.createdAt)} • Login: ${_dateTimeOrDash(user.lastLoginAt)}',
              style: const TextStyle(
                color: HomePalette.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCourseCard extends StatelessWidget {
  const _AdminCourseCard({required this.course});

  final AdminCourseListItem course;

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (course.normalizedStatus) {
      'published' => const Color(0xFF0F766E),
      'draft' => const Color(0xFFEA580C),
      'hidden' => const Color(0xFF6B7280),
      _ => HomePalette.primary,
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomePalette.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.menu_book_rounded, color: accentColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                course.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HomePalette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _StatusChip(label: course.displayStatus, color: accentColor),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Slug: ${course.slug.isEmpty ? '--' : course.slug}',
              style: const TextStyle(color: HomePalette.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              'Collections: ${course.collectionsCount} • Cập nhật: ${_dateTimeOrDash(course.updatedAt)}',
              style: const TextStyle(
                color: HomePalette.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Text(
            _priceText(course.discountPrice),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminTransactionCard extends StatelessWidget {
  const _AdminTransactionCard({required this.transaction});

  final AdminTransactionListItem transaction;

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (transaction.normalizedStatus) {
      'COMPLETED' => const Color(0xFF0F766E),
      'PENDING' => const Color(0xFFEA580C),
      'FAILED' => const Color(0xFFB91C1C),
      'UNPROCESSED' => const Color(0xFF6B7280),
      _ => HomePalette.primary,
    };

    final userName = (transaction.user?.name ?? '').trim();
    final userLabel = userName.isEmpty ? 'Khách/ẩn danh' : userName;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomePalette.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.receipt_long_rounded, color: accentColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                transaction.code.isEmpty
                    ? 'Transaction #${transaction.id}'
                    : transaction.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HomePalette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _StatusChip(label: transaction.displayStatus, color: accentColor),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '$userLabel • ${transaction.typeLabel.isEmpty ? transaction.type : transaction.typeLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: HomePalette.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              'Thời gian: ${_dateTimeOrDash(transaction.createdAt)}',
              style: const TextStyle(
                color: HomePalette.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(
            _priceText(transaction.netAmount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _TabToolbar extends StatelessWidget {
  const _TabToolbar({
    required this.searchController,
    required this.searchHint,
    required this.onSearchSubmitted,
    required this.onSearchTap,
    required this.filterLabel,
    required this.filterValue,
    required this.options,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onSearchTap;
  final String filterLabel;
  final String filterValue;
  final List<_FilterOption> options;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: onSearchSubmitted,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    filled: true,
                    fillColor: HomePalette.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onSearchTap,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Lọc'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                filterLabel,
                style: const TextStyle(
                  color: HomePalette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: HomePalette.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: filterValue,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(12),
                      items: options
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.value,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        onFilterChanged(value);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterOption {
  const _FilterOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _MetaSummaryCard extends StatelessWidget {
  const _MetaSummaryCard({required this.title, required this.meta});

  final String title;
  final AdminPaginationMeta meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_outlined, color: HomePalette.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title: ${NumberFormat.decimalPattern().format(meta.total)} bản ghi · trang ${meta.page}/${meta.lastPage}',
              style: const TextStyle(
                color: HomePalette.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HomePalette.chipGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: HomePalette.secondary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _AdminErrorState extends StatelessWidget {
  const _AdminErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 46,
                color: HomePalette.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: HomePalette.textSecondary),
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: HomePalette.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: HomePalette.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _SoonTag extends StatelessWidget {
  const _SoonTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: HomePalette.chipBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Sắp mở',
        style: TextStyle(
          color: HomePalette.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomePalette.border),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: HomePalette.textSecondary),
        ),
      ),
    );
  }
}

class _EmptyScrollable extends StatelessWidget {
  const _EmptyScrollable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 120, 16, 20),
          child: _EmptyBox(message: message),
        ),
      ],
    );
  }
}

class _LoadingScroll extends StatelessWidget {
  const _LoadingScroll();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 120, 16, 20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _DashboardMetric {
  const _DashboardMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

String _messageFromError(Object? error) {
  if (error is AppException) {
    return error.message;
  }
  return 'Không thể tải trang quản trị.';
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList();

  if (parts.isEmpty) {
    return 'U';
  }

  return parts.map((part) => part.substring(0, 1).toUpperCase()).join();
}

String _dateTimeOrDash(DateTime? value) {
  if (value == null) {
    return '--';
  }
  return DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());
}

String _priceText(int value) {
  if (value <= 0) {
    return '0đ';
  }
  return '${NumberFormat.decimalPattern().format(value)}đ';
}
