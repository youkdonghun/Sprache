import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';

class ResponsiveShell extends ConsumerWidget {
  const ResponsiveShell({
    required this.currentPath,
    required this.child,
    super.key,
  });

  final String currentPath;
  final Widget child;

  static const _destinations = [
    ('/home', '오늘', '오늘', Icons.home_rounded),
    ('/path', '코스', '코스', Icons.route_rounded),
    ('/learn', '연습', '연습', Icons.grid_view_rounded),
    ('/library', '단어장', '단어장', Icons.menu_book_rounded),
    ('/stats', '리포트', '기록', Icons.insights_rounded),
    ('/settings', '환경설정', '설정', Icons.tune_rounded),
  ];

  int get _selectedIndex {
    if (currentPath == '/path' || currentPath.startsWith('/unit/')) {
      return 1;
    }
    if (currentPath == '/learn' ||
        currentPath == '/missions' ||
        currentPath.startsWith('/mission/')) {
      return 2;
    }
    if (currentPath == '/import' || currentPath.startsWith('/library')) {
      return 3;
    }
    final index = _destinations.indexWhere(
      (destination) => destination.$1 == currentPath,
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final state = ref.watch(appControllerProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final showSidebar = isWindows && constraints.maxWidth >= 760;
        if (showSidebar) {
          final extended = constraints.maxWidth >= 1060;
          return Scaffold(
            body: Row(
              children: [
                _DesktopSidebar(
                  extended: extended,
                  selectedIndex: _selectedIndex,
                  language: state.selectedLanguage.nativeName,
                  connected: state.driveConnected,
                  onSelected: (index) => context.go(_destinations[index].$1),
                ),
                Expanded(child: child),
              ],
            ),
          );
        }

        final mobileDestinations = _destinations
            .take(5)
            .toList(growable: false);
        final mobileSelectedIndex = currentPath == '/settings'
            ? 4
            : _selectedIndex.clamp(0, mobileDestinations.length - 1);
        return Scaffold(
          body: child,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: NavigationBar(
                height: isWindows ? 58 : 70,
                labelBehavior: isWindows && constraints.maxWidth < 420
                    ? NavigationDestinationLabelBehavior.onlyShowSelected
                    : NavigationDestinationLabelBehavior.alwaysShow,
                selectedIndex: mobileSelectedIndex,
                onDestinationSelected: (index) =>
                    context.go(mobileDestinations[index].$1),
                destinations: [
                  for (final destination in mobileDestinations)
                    NavigationDestination(
                      icon: Icon(destination.$4),
                      selectedIcon: Icon(destination.$4),
                      label: isWindows ? destination.$2 : destination.$3,
                      tooltip: destination.$3,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.extended,
    required this.selectedIndex,
    required this.language,
    required this.connected,
    required this.onSelected,
  });

  final bool extended;
  final int selectedIndex;
  final String language;
  final bool connected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: extended ? 226 : 78,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BrandMark(extended: extended),
          const SizedBox(height: 28),
          for (final (index, destination)
              in ResponsiveShell._destinations.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _SidebarDestination(
                extended: extended,
                selected: index == selectedIndex,
                icon: destination.$4,
                label: destination.$2,
                tooltip: destination.$3,
                onTap: () => onSelected(index),
              ),
            ),
          const Spacer(),
          Tooltip(
            message: connected ? '$language · 클라우드 연결됨' : '$language · 로컬 저장',
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: extended ? 12 : 0,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Icon(
                    connected
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    size: 18,
                    color: connected ? const Color(0xFF238B57) : colors.outline,
                  ),
                  if (extended) ...[
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            language,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            connected ? '자동 저장 연결됨' : '이 장치에 저장',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.extended,
    required this.selected,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final bool extended;
  final bool selected;
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: extended ? '' : tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 46,
            padding: EdgeInsets.symmetric(horizontal: extended ? 13 : 0),
            decoration: BoxDecoration(
              color: selected ? colors.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: extended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: selected
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
                if (extended) ...[
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Sprache',
      child: Row(
        mainAxisAlignment: extended
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primary, colors.secondary],
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          if (extended) ...[
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SPRACHE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Daily language desk',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
