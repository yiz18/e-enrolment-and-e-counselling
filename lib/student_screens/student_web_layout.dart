import 'package:flutter/material.dart';

/// A responsive wrapper that adds a persistent left sidebar to student screens.
///
/// On screens 768 px wide or wider (web / tablet) the sidebar is rendered
/// alongside [child]. On narrower screens (mobile / Android) [child] is
/// returned unchanged so all existing mobile behaviour is fully preserved.
class StudentWebLayout extends StatelessWidget {
  final Widget child;
  final int selectedIndex;

  const StudentWebLayout({
    super.key,
    required this.child,
    required this.selectedIndex,
  });

  static const double _breakpoint = 768;

  static const List<String> _routes = [
    '/dashboard',
    '/myApplications',
  ];

  void _navigate(BuildContext context, int index) {
    if (index == selectedIndex) return;
    Navigator.pushReplacementNamed(context, _routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < _breakpoint) {
      return child;
    }

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          _StudentSidebar(
            selectedIndex: selectedIndex,
            onTap: (index) => _navigate(context, index),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _StudentSidebar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int index) onTap;

  const _StudentSidebar({
    required this.selectedIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItem(
      label: 'Dashboard',
      outlinedIcon: Icons.dashboard_outlined,
      filledIcon: Icons.dashboard,
    ),
    _NavItem(
      label: 'My Applications',
      outlinedIcon: Icons.assignment_outlined,
      filledIcon: Icons.assignment,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      child: SizedBox(
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SidebarHeader(),
            const SizedBox(height: 12),
            for (int i = 0; i < _items.length; i++) _buildNavTile(i, _items[i]),
            const Spacer(),
            const _SidebarFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile(int index, _NavItem item) {
    final isSelected = index == selectedIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? Colors.blueAccent.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onTap(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isSelected ? item.filledIcon : item.outlinedIcon,
                  color: isSelected ? Colors.blueAccent : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? Colors.blueAccent : Colors.grey[700],
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
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

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: Colors.blueAccent,
      child: const Row(
        children: [
          Icon(Icons.school, color: Colors.white, size: 22),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'Student Portal',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          'E-Enrolment System',
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData outlinedIcon;
  final IconData filledIcon;

  const _NavItem({
    required this.label,
    required this.outlinedIcon,
    required this.filledIcon,
  });
}
