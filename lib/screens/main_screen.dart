import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'sites_screen.dart';
import 'inspections_screen.dart';
import 'issues_screen.dart';
import 'monthly_screen.dart';
import 'quarterly_screen.dart';
import '../utils/theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int _prevIndex = 0; // 이전 탭 인덱스 추적
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: '대시보드'),
    _NavItem(icon: Icons.business_outlined, activeIcon: Icons.business, label: '현장관리'),
    _NavItem(icon: Icons.assignment_outlined, activeIcon: Icons.assignment, label: '검사관리'),
    _NavItem(icon: Icons.warning_amber_outlined, activeIcon: Icons.warning_amber, label: '지적사항'),
    _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: '월점검'),
    _NavItem(icon: Icons.memory_outlined, activeIcon: Icons.memory, label: '분기점검'),
  ];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(key: _dashboardKey),
      const SitesScreen(),
      const InspectionsScreen(),
      const IssuesScreen(),
      const MonthlyScreen(),
      const QuarterlyScreen(),
    ];
  }

  void _onTabSelected(int index) {
    // 다른 탭에서 대시보드(0)로 돌아올 때 자동 새로고침
    if (index == 0 && _prevIndex != 0) {
      _dashboardKey.currentState?.reload();
    }
    setState(() {
      _prevIndex = _selectedIndex;
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    return isWide ? _buildWideLayout() : _buildNarrowLayout();
  }

  // ── 태블릿/데스크탑: 항상 사이드바 표시 ──────────────────────
  Widget _buildWideLayout() {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Container(width: 1, color: const Color(0xFFF1F5F9)),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }

  // ── 모바일: AppBar 햄버거 버튼 + Drawer ──────────────────────
  Widget _buildNarrowLayout() {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: '메뉴',
        ),
        title: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.elevator, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _navItems[_selectedIndex].label,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: '설정',
          ),
        ],
      ),
      drawer: Drawer(
        child: _buildSidebar(isDrawer: true),
      ),
      body: _screens[_selectedIndex],
    );
  }

  // ── 공통 사이드바 위젯 ────────────────────────────────────────
  Widget _buildSidebar({bool isDrawer = false}) {
    return Container(
      width: isDrawer ? null : 220,
      color: Colors.white,
      child: Column(
        children: [
          // 상단 여백 (드로어는 상태바 포함)
          if (isDrawer)
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                right: 20,
                bottom: 16,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.elevator, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('승강기 관리',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                        Text('Elevator Manager',
                          style: TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.elevator, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('승강기 관리',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.gray800)),
                        Text('Elevator Manager',
                          style: TextStyle(fontSize: 10, color: AppTheme.gray400)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 메뉴 목록
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                _buildMenuSection('메인'),
                _buildSidebarItem(0, isDrawer: isDrawer),
                const SizedBox(height: 8),
                _buildMenuSection('관리 메뉴'),
                for (int i = 1; i < _navItems.length; i++)
                  _buildSidebarItem(i, isDrawer: isDrawer),
              ],
            ),
          ),

          // 설정 버튼
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: ListTile(
              leading: const Icon(Icons.settings_outlined, size: 18, color: AppTheme.gray400),
              title: const Text('설정', style: TextStyle(fontSize: 13, color: AppTheme.gray500)),
              dense: true,
              onTap: () {
                if (isDrawer) Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Text(title,
        style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: AppTheme.gray400, letterSpacing: 0.5,
        )),
    );
  }

  Widget _buildSidebarItem(int index, {bool isDrawer = false}) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        _onTabSelected(index);
        if (isDrawer) Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                size: 16,
                color: isSelected ? Colors.white : AppTheme.gray500,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppTheme.primary : AppTheme.gray700,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}
