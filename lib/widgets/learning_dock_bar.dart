import 'package:edupen/pages/home/home_constants.dart';
import 'package:edupen/pages/home/home_view.dart';
import 'package:edupen/pages/menu/menu_view.dart';
import 'package:edupen/pages/purchased_courses/purchased_courses_view.dart';
import 'package:edupen/pages/teacher/teacher_view.dart';
import 'package:flutter/material.dart';

enum LearningDockTab { home, purchasedCourses, teacher, account }

class LearningDockBar extends StatelessWidget {
  const LearningDockBar({super.key, required this.currentTab});

  final LearningDockTab currentTab;

  Future<void> _onTabSelected(
    BuildContext context,
    LearningDockTab destinationTab,
  ) async {
    if (destinationTab == currentTab) return;

    final Widget destination;
    switch (destinationTab) {
      case LearningDockTab.home:
        destination = const HomeView();
        break;
      case LearningDockTab.purchasedCourses:
        destination = const PurchasedCoursesView();
        break;
      case LearningDockTab.teacher:
        destination = const TeacherView();
        break;
      case LearningDockTab.account:
        destination = const MenuView();
        break;
    }

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => destination),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: List.generate(_dockTabs.length, (index) {
              final tab = _dockTabs[index];
              final isSelected = currentTab == tab.tab;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _onTabSelected(context, tab.tab),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFEFF6FF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? tab.activeIcon : tab.icon,
                            size: 19,
                            color: isSelected
                                ? HomePalette.primary
                                : HomePalette.textMuted,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tab.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 11,
                                  height: 1.1,
                                  color: isSelected
                                      ? HomePalette.primary
                                      : HomePalette.textMuted,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _DockTabItem {
  const _DockTabItem({
    required this.tab,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final LearningDockTab tab;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const List<_DockTabItem> _dockTabs = [
  _DockTabItem(
    tab: LearningDockTab.home,
    label: 'Trang chủ',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
  ),
  _DockTabItem(
    tab: LearningDockTab.purchasedCourses,
    label: 'Đã mua',
    icon: Icons.menu_book_outlined,
    activeIcon: Icons.menu_book_rounded,
  ),
  _DockTabItem(
    tab: LearningDockTab.teacher,
    label: 'Trang giáo viên',
    icon: Icons.school_outlined,
    activeIcon: Icons.school_rounded,
  ),
  _DockTabItem(
    tab: LearningDockTab.account,
    label: 'Menu',
    icon: Icons.menu_rounded,
    activeIcon: Icons.menu_rounded,
  ),
];
