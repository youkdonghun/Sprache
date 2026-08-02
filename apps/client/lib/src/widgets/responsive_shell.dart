import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../state/connection_state.dart';
import '../state/local_storage_state.dart';
import '../state/navigation_guard_state.dart';
import '../sync/sync_policy.dart';
import '../services/app_feedback_service.dart';
import 'course_picker.dart';
import 'global_search_palette.dart';
import 'quick_content_result_handler.dart';
import 'quick_content_sheet.dart';

class ResponsiveShell extends ConsumerStatefulWidget {
  const ResponsiveShell({
    required this.navigationShell,
    required this.onDismissTransientRoutes,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final VoidCallback onDismissTransientRoutes;

  static const _destinations = [
    ('/home', '오늘', '오늘', Icons.home_rounded),
    ('/learn', '학습', '학습', Icons.school_rounded),
    ('/library', '자료실', '자료실', Icons.menu_book_rounded),
    ('/stats', '기록', '기록', Icons.insights_rounded),
    ('/settings', '설정', '설정', Icons.tune_rounded),
  ];

  @override
  ConsumerState<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends ConsumerState<ResponsiveShell> {
  final FocusNode _contentFocusNode = FocusNode(
    debugLabel: 'Sprache main content',
  );
  int? _pendingDestination;
  bool _destinationSwitchScheduled = false;

  int get _selectedIndex => widget.navigationShell.currentIndex;

  @override
  void dispose() {
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _focusContent() {
    _contentFocusNode.requestFocus();
    SemanticsService.sendAnnouncement(
      View.of(context),
      '본문으로 이동했습니다.',
      Directionality.of(context),
    );
  }

  void _openGlobalSearch() {
    unawaited(showGlobalSearchPalette(context, ref));
  }

  void _openQuickAdd() {
    unawaited(_openQuickAddAndHandleResult());
  }

  Future<void> _openQuickAddAndHandleResult() async {
    final result = await showQuickContentSheet(context: context);
    if (!mounted) return;
    await handleQuickContentResult(context: context, ref: ref, result: result);
  }

  Future<void> _selectDestination(int index) async {
    final canNavigate = await ref.read(navigationGuardProvider).canNavigate();
    if (!mounted || !canNavigate) return;
    _pendingDestination = index;
    unawaited(
      AppFeedbackService(
        readPreferences: () =>
            ref.read(appControllerProvider).preferences.experience,
      ).selection(),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..clearMaterialBanners();
    widget.onDismissTransientRoutes();
    Navigator.maybeOf(
      context,
      rootNavigator: true,
    )?.popUntil((route) => route is! PopupRoute<dynamic>);
    if (_destinationSwitchScheduled) return;
    _destinationSwitchScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _destinationSwitchScheduled = false;
      final destination = _pendingDestination;
      _pendingDestination = null;
      if (!mounted || destination == null) return;
      widget.navigationShell.goBranch(destination, initialLocation: true);
    });
  }

  Widget _mainContent() {
    return Semantics(
      container: true,
      label: '본문',
      child: Focus(
        key: const Key('shell-main-content-focus'),
        focusNode: _contentFocusNode,
        skipTraversal: true,
        child: widget.navigationShell,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    ref.watch(appControllerProvider);
    final localStorage = ref.watch(localStorageControllerProvider);
    final activeSubject = ref
        .read(appControllerProvider.notifier)
        .activeSubject;
    final connection = ref.watch(connectionControllerProvider);
    final storageIndicator = _StorageIndicator.from(localStorage, connection);

    return CallbackShortcuts(
      key: const Key('responsive-shell-shortcuts'),
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f6): _focusContent,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _openGlobalSearch,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _openQuickAdd,
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showSidebar = isWindows && constraints.maxWidth >= 760;
          final compactNavigation =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.15;
          if (showSidebar) {
            final extended = constraints.maxWidth >= 1060;
            return Scaffold(
              body: Row(
                children: [
                  _DesktopSidebar(
                    extended: extended,
                    selectedIndex: _selectedIndex,
                    language: activeSubject.name,
                    storageIndicator: storageIndicator,
                    onSubjectPressed: () => showSubjectPicker(context),
                    onSearchPressed: _openGlobalSearch,
                    onQuickAddPressed: _openQuickAdd,
                    onSelected: _selectDestination,
                  ),
                  Expanded(child: _mainContent()),
                ],
              ),
            );
          }

          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _SubjectContextBar(
                    subjectSymbol: activeSubject.symbol,
                    subjectName: activeSubject.name,
                    storageIndicator: storageIndicator,
                    onPressed: () => showSubjectPicker(context),
                    onSearchPressed: _openGlobalSearch,
                    onQuickAddPressed: _openQuickAdd,
                  ),
                  Expanded(child: _mainContent()),
                ],
              ),
            ),
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
                  animationDuration: Duration.zero,
                  height: isWindows
                      ? 58
                      : compactNavigation
                      ? 60
                      : 64,
                  labelBehavior:
                      (isWindows && constraints.maxWidth < 420) ||
                          (!isWindows && compactNavigation)
                      ? NavigationDestinationLabelBehavior.onlyShowSelected
                      : NavigationDestinationLabelBehavior.alwaysShow,
                  selectedIndex: _selectedIndex.clamp(
                    0,
                    ResponsiveShell._destinations.length - 1,
                  ),
                  onDestinationSelected: _selectDestination,
                  destinations: [
                    for (final destination in ResponsiveShell._destinations)
                      NavigationDestination(
                        key: Key('nav-${destination.$1.substring(1)}'),
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
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.extended,
    required this.selectedIndex,
    required this.language,
    required this.storageIndicator,
    required this.onSubjectPressed,
    required this.onSearchPressed,
    required this.onQuickAddPressed,
    required this.onSelected,
  });

  final bool extended;
  final int selectedIndex;
  final String language;
  final _StorageIndicator storageIndicator;
  final VoidCallback onSubjectPressed;
  final VoidCallback onSearchPressed;
  final VoidCallback onQuickAddPressed;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
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
          const SizedBox(height: 16),
          _SidebarDestination(
            key: const Key('open-global-search'),
            extended: extended,
            selected: false,
            icon: Icons.search_rounded,
            label: '전체 검색',
            tooltip: '전체 검색 · Ctrl+K',
            onTap: onSearchPressed,
          ),
          const SizedBox(height: 7),
          _SidebarDestination(
            key: const Key('shell-quick-add'),
            extended: extended,
            selected: false,
            icon: Icons.add_circle_outline_rounded,
            label: '빠른 추가',
            tooltip: '빠른 자료 추가 · Ctrl+N',
            onTap: onQuickAddPressed,
          ),
          const SizedBox(height: 12),
          for (final (index, destination)
              in ResponsiveShell._destinations.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _SidebarDestination(
                key: Key('nav-${destination.$1.substring(1)}'),
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
            message: '$language · ${storageIndicator.label} · 주제 변경',
            child: Material(
              color: colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: colors.outlineVariant),
              ),
              child: InkWell(
                key: const Key('shell-subject-switcher'),
                onTap: onSubjectPressed,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: extended ? 12 : 0,
                    vertical: 11,
                  ),
                  child: Row(
                    mainAxisAlignment: extended
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      Icon(
                        key: const Key('shell-storage-status'),
                        storageIndicator.icon,
                        size: 18,
                        color: storageIndicator.color(colors),
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
                                storageIndicator.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.unfold_more_rounded, size: 16),
                      ],
                    ],
                  ),
                ),
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
    super.key,
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
    return Semantics(
      button: true,
      selected: selected,
      label: '$label 탭${selected ? ', 현재 위치' : ''}',
      child: Tooltip(
        message: extended ? '' : tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
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
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
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
      ),
    );
  }
}

class _SubjectContextBar extends StatelessWidget {
  const _SubjectContextBar({
    required this.subjectSymbol,
    required this.subjectName,
    required this.storageIndicator,
    required this.onPressed,
    required this.onSearchPressed,
    required this.onQuickAddPressed,
  });

  final String subjectSymbol;
  final String subjectName;
  final _StorageIndicator storageIndicator;
  final VoidCallback onPressed;
  final VoidCallback onSearchPressed;
  final VoidCallback onQuickAddPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('shell-subject-context'),
      height: 56,
      padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                button: true,
                label: '현재 학습 주제 $subjectName, 주제 바꾸기',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Material(
                    color: colors.surfaceContainerLow,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      key: const Key('shell-mobile-subject-switcher'),
                      onTap: onPressed,
                      customBorder: const StadiumBorder(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              subjectSymbol,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                subjectName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.expand_more_rounded, size: 17),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox.square(
            dimension: 44,
            child: IconButton(
              key: const Key('shell-quick-add'),
              tooltip: '빠른 자료 추가',
              onPressed: onQuickAddPressed,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ),
          const SizedBox(width: 2),
          SizedBox.square(
            dimension: 44,
            child: IconButton(
              key: const Key('open-global-search'),
              tooltip: '전체 검색',
              onPressed: onSearchPressed,
              icon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(width: 2),
          Semantics(
            container: true,
            label: storageIndicator.label,
            child: Tooltip(
              message: storageIndicator.label,
              child: Icon(
                key: const Key('shell-storage-status'),
                storageIndicator.icon,
                size: 18,
                color: storageIndicator.color(colors),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _StorageIndicatorKind {
  loading,
  completed,
  waiting,
  syncing,
  local,
  setupRequired,
  attention,
}

class _StorageIndicator {
  const _StorageIndicator({
    required this.kind,
    required this.label,
    required this.icon,
  });

  factory _StorageIndicator.from(
    LocalStorageState state,
    ConnectionState connection,
  ) {
    if (!state.initialized) {
      return const _StorageIndicator(
        kind: _StorageIndicatorKind.loading,
        label: '저장 확인 중',
        icon: Icons.sync_rounded,
      );
    }
    if (state.driveConnected) {
      return switch (connection.displayStatus) {
        SyncDisplayStatus.completed => const _StorageIndicator(
          kind: _StorageIndicatorKind.completed,
          label: '동기화 완료',
          icon: Icons.cloud_done_outlined,
        ),
        SyncDisplayStatus.waiting => const _StorageIndicator(
          kind: _StorageIndicatorKind.waiting,
          label: '동기화 대기',
          icon: Icons.cloud_upload_outlined,
        ),
        SyncDisplayStatus.syncing => const _StorageIndicator(
          kind: _StorageIndicatorKind.syncing,
          label: '동기화 중',
          icon: Icons.sync_rounded,
        ),
        SyncDisplayStatus.error => const _StorageIndicator(
          kind: _StorageIndicatorKind.attention,
          label: '동기화 오류',
          icon: Icons.cloud_off_outlined,
        ),
        SyncDisplayStatus.localSaved => const _StorageIndicator(
          kind: _StorageIndicatorKind.local,
          label: '로컬 저장',
          icon: Icons.save_outlined,
        ),
      };
    }
    if (state.busy) {
      return const _StorageIndicator(
        kind: _StorageIndicatorKind.syncing,
        label: '로컬 저장 중',
        icon: Icons.sync_rounded,
      );
    }
    if (state.errorMessage != null ||
        state.existingArchiveAvailable ||
        state.settings.awaitingExistingArchiveDecision) {
      return const _StorageIndicator(
        kind: _StorageIndicatorKind.attention,
        label: '저장 확인 필요',
        icon: Icons.error_outline_rounded,
      );
    }
    if (state.localMirrorActive) {
      return const _StorageIndicator(
        kind: _StorageIndicatorKind.local,
        label: '로컬 저장 중',
        icon: Icons.folder_copy_outlined,
      );
    }
    return const _StorageIndicator(
      kind: _StorageIndicatorKind.setupRequired,
      label: '저장 위치 필요',
      icon: Icons.create_new_folder_outlined,
    );
  }

  final _StorageIndicatorKind kind;
  final String label;
  final IconData icon;

  Color color(ColorScheme colors) => switch (kind) {
    _StorageIndicatorKind.loading => colors.onSurfaceVariant,
    _StorageIndicatorKind.completed => const Color(0xFF197A4B),
    _StorageIndicatorKind.waiting => colors.tertiary,
    _StorageIndicatorKind.syncing => colors.primary,
    _StorageIndicatorKind.local => colors.primary,
    _StorageIndicatorKind.setupRequired => colors.tertiary,
    _StorageIndicatorKind.attention => colors.error,
  };
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
