import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const Color _activeColor = Color(0xFF1F2937);
  static const Color _inactiveColor = Color(0xFF9CA3AF);

  static const List<_NavItemData> _items = <_NavItemData>[
    _NavItemData(
      label: 'Trang chủ',
      icon: Icons.home_filled,
    ),
    _NavItemData(
      label: 'Trang giáo viên',
      icon: Icons.menu_book_outlined,
    ),
    _NavItemData(
      label: 'Menu',
      icon: Icons.menu_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = currentIndex >= 0 && currentIndex < _items.length
        ? currentIndex
        : 0;

    return SafeArea(
      top: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 72,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(
              top: BorderSide(
                color: Color(0xFFF1F5F9),
                width: 1,
              ),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: List<Widget>.generate(
              _items.length,
              (int index) {
                final _NavItemData item = _items[index];
                final bool isActive = index == selectedIndex;
                return Expanded(
                  child: _NavItem(
                    icon: item.icon,
                    label: item.label,
                    isActive: isActive,
                    activeColor: _activeColor,
                    inactiveColor: _inactiveColor,
                    onTap: () => onTap(index),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = isActive ? activeColor : inactiveColor;

    return InkWell(
      onTap: onTap,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 23, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                height: 1.1,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}
