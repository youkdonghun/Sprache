import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../domain/accessibility_input_profile.dart';
import '../domain/app_experience_preferences.dart';
import '../state/app_state.dart';
import '../state/connection_state.dart';
import '../state/device_preferences_state.dart';
import '../state/global_app_error_state.dart';
import '../state/local_storage_state.dart';
import '../state/navigation_guard_state.dart';
import '../state/pending_import_state.dart';
import '../sync/sync_policy.dart';
import '../services/app_feedback_service.dart';
import '../services/window_workspace_service.dart';
import '../theme/app_theme.dart';
import '../theme/study_accessibility_theme.dart';
import 'course_picker.dart';
import 'global_search_palette.dart';
import 'keyboard_help_overlay.dart';
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
    ('/home', '오늘', '오늘', Icons.home_outlined, Icons.home_rounded),
    ('/learn', '학습', '학습', Icons.school_outlined, Icons.school_rounded),
    (
      '/library',
      '자료실',
      '자료실',
      Icons.menu_book_outlined,
      Icons.menu_book_rounded,
    ),
    ('/stats', '기록', '기록', Icons.insights_outlined, Icons.insights_rounded),
    ('/settings', '설정', '설정', Icons.tune_outlined, Icons.tune_rounded),
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
  bool _fileDragActive = false;
  String? _dismissedGlobalErrorFingerprint;

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

  void _openKeyboardHelp() {
    final profile = ref.read(accessibilityInputProfileProvider);
    unawaited(
      showKeyboardHelpOverlay(
        context: context,
        profile: profile,
        helpContext: keyboardHelpContextForLocation(
          GoRouterState.of(context).uri.path,
        ),
        fallbackFocus: _contentFocusNode,
      ),
    );
  }

  Future<void> _goProtected(String location) async {
    if (!await ref.read(navigationGuardProvider).canNavigate() || !mounted) {
      return;
    }
    context.go(location);
  }

  Widget _withNativeDesktopMenu(Widget child) {
    if (defaultTargetPlatform != TargetPlatform.macOS) return child;
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Sprache',
          menus: const [
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about),
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
          ],
        ),
        PlatformMenu(
          label: '자료',
          menus: [
            PlatformMenuItem(
              label: '전체 검색',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyK,
                meta: true,
              ),
              onSelected: _openGlobalSearch,
            ),
            PlatformMenuItem(
              label: '빠른 추가',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                meta: true,
              ),
              onSelected: _openQuickAdd,
            ),
            PlatformMenuItem(
              label: '파일 가져오기',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                meta: true,
              ),
              onSelected: () => unawaited(_goProtected('/import')),
            ),
            PlatformMenuItem(
              label: '그룹으로 이동·정리',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyG,
                meta: true,
                shift: true,
              ),
              onSelected: () => unawaited(_goProtected('/library/groups')),
            ),
          ],
        ),
        PlatformMenu(
          label: '보기',
          menus: [
            PlatformMenuItem(
              label: '설정',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.comma,
                meta: true,
              ),
              onSelected: () => unawaited(_selectDestination(4)),
            ),
          ],
        ),
      ],
      child: child,
    );
  }

  Future<void> _handleFileDrop(DropDoneDetails details) async {
    if (details.files.isEmpty) return;
    final supported = {'xlsx', 'csv', 'tsv', 'json', 'jsonl'};
    final file = details.files.cast<DropItem?>().firstWhere((candidate) {
      final name = candidate?.name.toLowerCase() ?? '';
      final dot = name.lastIndexOf('.');
      return dot >= 0 && supported.contains(name.substring(dot + 1));
    }, orElse: () => null);
    if (file == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel, CSV, TSV, JSON, JSONL 파일을 가져올 수 있어요.'),
          ),
        );
      }
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (!await ref.read(navigationGuardProvider).canNavigate() || !mounted) {
        return;
      }
      ref.read(pendingImportFileProvider.notifier).state = PendingImportFile(
        name: file.name,
        bytes: bytes,
      );
      context.go('/import?dropped=true');
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('놓은 파일을 읽지 못했습니다. 파일 권한을 확인해 주세요.')),
        );
      }
    }
  }

  Widget _withDesktopFileDrop(Widget child) {
    final desktop =
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
    if (!desktop) return child;
    return DropTarget(
      key: const Key('desktop-import-drop-target'),
      onDragEntered: (_) => setState(() => _fileDragActive = true),
      onDragExited: (_) => setState(() => _fileDragActive = false),
      onDragDone: (details) {
        setState(() => _fileDragActive = false);
        unawaited(_handleFileDrop(details));
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (_fileDragActive)
            IgnorePointer(
              child: ColoredBox(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                child: Center(
                  child: Card(
                    key: const Key('desktop-import-drop-overlay'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 22,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.file_download_outlined,
                            size: 42,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '놓으면 가져올 내용을 먼저 확인할 수 있어요',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Text('내용을 확인하고 저장하기 전까지 기존 자료는 바뀌지 않아요.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
        readDevicePreferences: () =>
            ref.read(devicePreferencesControllerProvider).preferences.voice,
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
    final isDesktop =
        isWindows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
    final appState = ref.watch(appControllerProvider);
    final experience = appState.preferences.experience;
    final accessibilityProfile = ref.watch(accessibilityInputProfileProvider);
    final localStorage = ref.watch(localStorageControllerProvider);
    final activeSubject = ref
        .read(appControllerProvider.notifier)
        .activeSubject;
    final connection = ref.watch(connectionControllerProvider);
    final workspaceError = ref.watch(
      windowWorkspaceControllerProvider.select((state) => state.errorMessage),
    );
    final manuallyReportedError = ref.watch(globalAppErrorProvider);
    final storageIndicator = _StorageIndicator.from(localStorage, connection);
    final sourceError =
        connection.userInitiatedOperation && connection.errorMessage != null
        ? GlobalAppErrorNotice(
            source: 'connection',
            message: connection.errorMessage!,
            actionRoute: '/settings?focus=storage',
          )
        : localStorage.errorMessage != null
        ? GlobalAppErrorNotice(
            source: 'local-storage',
            message: localStorage.errorMessage!,
            actionRoute: '/settings?focus=storage',
          )
        : workspaceError != null
        ? GlobalAppErrorNotice(
            source: 'window-workspace',
            message: workspaceError,
            actionRoute: '/settings?focus=windows',
          )
        : null;
    final candidateError = manuallyReportedError ?? sourceError;
    final candidateFingerprint = candidateError == null
        ? null
        : '${candidateError.source}\u001f${candidateError.message}';
    if (candidateError == null && _dismissedGlobalErrorFingerprint != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _dismissedGlobalErrorFingerprint != null) {
          setState(() => _dismissedGlobalErrorFingerprint = null);
        }
      });
    }
    final visibleError =
        candidateFingerprint == _dismissedGlobalErrorFingerprint
        ? null
        : candidateError;
    final layout =
        Theme.of(context).extension<AppLayoutDensity>() ??
        AppLayoutDensity.fromPreference(
          experience.density,
          isDesktop: isDesktop,
        );

    return _withNativeDesktopMenu(
      _withDesktopFileDrop(
        CallbackShortcuts(
          key: const Key('responsive-shell-shortcuts'),
          bindings: accessibilityProfile.globalBindingsFor({
            GlobalShortcutAction.focusContent: _focusContent,
            GlobalShortcutAction.openSearch: _openGlobalSearch,
            GlobalShortcutAction.quickAdd: _openQuickAdd,
            GlobalShortcutAction.keyboardHelp: _openKeyboardHelp,
          }),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showSidebar = isDesktop && constraints.maxWidth >= 840;
              final compactNavigation =
                  constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.15;

              Widget desktopMainContent() {
                if (experience.contentWidth == AppContentWidth.balanced) {
                  return _mainContent();
                }
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    key: const Key('shell-main-content-width'),
                    constraints: BoxConstraints(
                      maxWidth: AppTheme.contentMaxWidth(
                        experience.contentWidth,
                      ),
                    ),
                    child: SizedBox.expand(child: _mainContent()),
                  ),
                );
              }

              Widget mainContentWithError(Widget child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (visibleError != null)
                      _GlobalAppErrorStrip(
                        notice: visibleError,
                        onOpen: () => _goProtected(visibleError.actionRoute),
                        onDismiss: () {
                          setState(
                            () => _dismissedGlobalErrorFingerprint =
                                candidateFingerprint,
                          );
                          if (identical(visibleError, manuallyReportedError)) {
                            ref.read(globalAppErrorProvider.notifier).dismiss();
                          }
                        },
                      ),
                    Expanded(child: child),
                  ],
                );
              }

              if (showSidebar) {
                final extended =
                    constraints.maxWidth >= 1060 &&
                    experience.navigationLabelMode !=
                        AppNavigationLabelMode.iconsOnly;
                return Scaffold(
                  body: Row(
                    children: [
                      _DesktopSidebar(
                        extended: extended,
                        selectedIndex: _selectedIndex,
                        language: activeSubject.name,
                        subjectSymbol: activeSubject.symbol,
                        storageIndicator: storageIndicator,
                        onSubjectPressed: () => showSubjectPicker(context),
                        onSearchPressed: _openGlobalSearch,
                        onQuickAddPressed: _openQuickAdd,
                        onSelected: _selectDestination,
                        showSearch: experience.showGlobalSearch,
                        showQuickAdd: experience.showQuickAdd,
                        showStorageStatus:
                            experience.showSyncStatus &&
                            connection.userInitiatedOperation,
                        navigationLabelMode: experience.navigationLabelMode,
                        navigationIconStyle: experience.navigationIconStyle,
                        decorationIntensity: experience.decorationIntensity,
                        compactSubject:
                            experience.subjectSwitcherStyle ==
                            AppSubjectSwitcherStyle.compact,
                      ),
                      Expanded(
                        child: mainContentWithError(desktopMainContent()),
                      ),
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
                        showSearch: experience.showGlobalSearch,
                        showQuickAdd: experience.showQuickAdd,
                        showStorageStatus:
                            experience.showSyncStatus &&
                            connection.userInitiatedOperation,
                        compactSubject:
                            experience.subjectSwitcherStyle ==
                            AppSubjectSwitcherStyle.compact,
                      ),
                      Expanded(child: mainContentWithError(_mainContent())),
                    ],
                  ),
                ),
                bottomNavigationBar: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color:
                            experience.decorationIntensity ==
                                AppDecorationIntensity.minimal
                            ? Colors.transparent
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: NavigationBar(
                      animationDuration: Duration.zero,
                      height: isDesktop
                          ? 58
                          : compactNavigation || layout.dense
                          ? 60
                          : 64,
                      labelBehavior: switch (experience.navigationLabelMode) {
                        AppNavigationLabelMode.iconsOnly =>
                          NavigationDestinationLabelBehavior.alwaysHide,
                        AppNavigationLabelMode.selected =>
                          NavigationDestinationLabelBehavior.onlyShowSelected,
                        AppNavigationLabelMode.always =>
                          compactNavigation
                              ? NavigationDestinationLabelBehavior
                                    .onlyShowSelected
                              : NavigationDestinationLabelBehavior.alwaysShow,
                      },
                      selectedIndex: _selectedIndex.clamp(
                        0,
                        ResponsiveShell._destinations.length - 1,
                      ),
                      onDestinationSelected: _selectDestination,
                      destinations: [
                        for (final (index, destination)
                            in ResponsiveShell._destinations.indexed)
                          NavigationDestination(
                            key: Key('nav-${destination.$1.substring(1)}'),
                            icon: Icon(
                              _navigationIcon(
                                destination,
                                selected: false,
                                style: experience.navigationIconStyle,
                              ),
                            ),
                            selectedIcon: Icon(
                              _navigationIcon(
                                destination,
                                selected: index == _selectedIndex,
                                style: experience.navigationIconStyle,
                              ),
                            ),
                            label: isDesktop ? destination.$2 : destination.$3,
                            tooltip: destination.$3,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.extended,
    required this.selectedIndex,
    required this.language,
    required this.subjectSymbol,
    required this.storageIndicator,
    required this.onSubjectPressed,
    required this.onSearchPressed,
    required this.onQuickAddPressed,
    required this.onSelected,
    required this.showSearch,
    required this.showQuickAdd,
    required this.showStorageStatus,
    required this.navigationLabelMode,
    required this.navigationIconStyle,
    required this.decorationIntensity,
    required this.compactSubject,
  });

  final bool extended;
  final int selectedIndex;
  final String language;
  final String subjectSymbol;
  final _StorageIndicator storageIndicator;
  final VoidCallback onSubjectPressed;
  final VoidCallback onSearchPressed;
  final VoidCallback onQuickAddPressed;
  final ValueChanged<int> onSelected;
  final bool showSearch;
  final bool showQuickAdd;
  final bool showStorageStatus;
  final AppNavigationLabelMode navigationLabelMode;
  final AppNavigationIconStyle navigationIconStyle;
  final AppDecorationIntensity decorationIntensity;
  final bool compactSubject;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final layout =
        Theme.of(context).extension<AppLayoutDensity>() ??
        AppLayoutDensity.fromPreference(AppDensity.platform, isDesktop: true);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final sidebarItemGap = layout.controlGap + (layout.dense ? 2 : 3);
    final settingsDestination = ResponsiveShell._destinations[4];
    return AnimatedContainer(
      key: const Key('desktop-sidebar'),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      width: extended
          ? layout.desktopSidebarExtendedWidth
          : layout.desktopSidebarCollapsedWidth,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      padding: layout.desktopSidebarPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BrandMark(
            extended: extended,
            decorationIntensity: decorationIntensity,
          ),
          SizedBox(height: layout.sectionGap),
          if (extended && (showSearch || showQuickAdd))
            _SidebarUtilityToolbar(
              showSearch: showSearch,
              showQuickAdd: showQuickAdd,
              onSearch: onSearchPressed,
              onQuickAdd: onQuickAddPressed,
            )
          else if (!extended) ...[
            if (showSearch) ...[
              _SidebarDestination(
                key: const Key('open-global-search'),
                extended: false,
                selected: false,
                icon: Icons.manage_search_rounded,
                label: '전체 검색',
                tooltip: '전체 검색 · Ctrl+K',
                onTap: onSearchPressed,
              ),
              SizedBox(height: sidebarItemGap),
            ],
            if (showQuickAdd) ...[
              _SidebarDestination(
                key: const Key('shell-quick-add'),
                extended: false,
                selected: false,
                icon: Icons.add_circle_outline_rounded,
                label: '빠른 추가',
                tooltip: '빠른 자료 추가 · Ctrl+N',
                onTap: onQuickAddPressed,
              ),
              SizedBox(height: sidebarItemGap),
            ],
          ],
          SizedBox(height: layout.sectionGap * 0.75),
          for (final (index, destination)
              in ResponsiveShell._destinations.take(4).indexed)
            Padding(
              padding: EdgeInsets.only(bottom: sidebarItemGap),
              child: _SidebarDestination(
                key: Key('nav-${destination.$1.substring(1)}'),
                extended:
                    extended &&
                    (navigationLabelMode == AppNavigationLabelMode.always ||
                        index == selectedIndex),
                alignLeading: extended,
                selected: index == selectedIndex,
                icon: _navigationIcon(
                  destination,
                  selected: index == selectedIndex,
                  style: navigationIconStyle,
                ),
                label: destination.$2,
                tooltip: destination.$3,
                onTap: () => onSelected(index),
              ),
            ),
          const Spacer(),
          _SidebarDestination(
            key: const Key('nav-settings'),
            extended:
                extended &&
                (navigationLabelMode == AppNavigationLabelMode.always ||
                    selectedIndex == 4),
            alignLeading: extended,
            selected: selectedIndex == 4,
            icon: _navigationIcon(
              settingsDestination,
              selected: selectedIndex == 4,
              style: navigationIconStyle,
            ),
            label: settingsDestination.$2,
            tooltip: settingsDestination.$3,
            onTap: () => onSelected(4),
          ),
          SizedBox(height: sidebarItemGap),
          Tooltip(
            message: showStorageStatus
                ? '$language · ${storageIndicator.label} · 주제 변경'
                : '$language · 주제 변경',
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
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: extended && !compactSubject
                          ? layout.sidebarControlHorizontalPadding
                          : 0,
                      vertical: layout.dense ? 8 : 11,
                    ),
                    child: Row(
                      mainAxisAlignment: extended && !compactSubject
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        if (compactSubject)
                          Text(
                            subjectSymbol,
                            key: const Key('shell-compact-subject-symbol'),
                            style: const TextStyle(fontSize: 20),
                          )
                        else
                          Icon(
                            key: const Key('shell-storage-status'),
                            showStorageStatus
                                ? storageIndicator.icon
                                : Icons.translate_rounded,
                            size: 18,
                            color: showStorageStatus
                                ? storageIndicator.color(colors)
                                : colors.primary,
                          ),
                        if (extended && !compactSubject) ...[
                          SizedBox(width: layout.controlGap + 5),
                          Expanded(
                            child: Text(
                              showStorageStatus
                                  ? '$language · ${storageIndicator.label}'
                                  : language,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          SizedBox(width: layout.controlGap),
                          const Icon(Icons.unfold_more_rounded, size: 16),
                        ],
                      ],
                    ),
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

class _SidebarUtilityToolbar extends StatelessWidget {
  const _SidebarUtilityToolbar({
    required this.showSearch,
    required this.showQuickAdd,
    required this.onSearch,
    required this.onQuickAdd,
  });

  final bool showSearch;
  final bool showQuickAdd;
  final VoidCallback onSearch;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Semantics(
        container: true,
        label: '빠른 도구',
        child: Row(
          key: const Key('desktop-sidebar-utility-toolbar'),
          children: [
            if (showSearch)
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    key: const Key('open-global-search'),
                    onPressed: onSearch,
                    icon: const Icon(Icons.manage_search_rounded, size: 18),
                    label: const Text('전체 검색'),
                    style: const ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(Size.fromHeight(44)),
                      padding: WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                ),
              ),
            if (showQuickAdd) ...[
              const SizedBox(width: 4),
              IconButton.filledTonal(
                key: const Key('shell-quick-add'),
                tooltip: '빠른 자료 추가 · Ctrl+N',
                onPressed: onQuickAdd,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ],
        ),
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
    this.alignLeading = false,
    super.key,
  });

  final bool extended;
  final bool selected;
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool alignLeading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final layout =
        Theme.of(context).extension<AppLayoutDensity>() ??
        AppLayoutDensity.fromPreference(AppDensity.platform, isDesktop: true);
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
              height: layout.sidebarControlHeight,
              padding: EdgeInsets.symmetric(
                horizontal: extended || alignLeading
                    ? layout.sidebarControlHorizontalPadding
                    : 0,
              ),
              decoration: BoxDecoration(
                color: selected ? colors.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: extended || alignLeading
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
                    SizedBox(width: layout.controlGap + 8),
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
    required this.showSearch,
    required this.showQuickAdd,
    required this.showStorageStatus,
    required this.compactSubject,
  });

  final String subjectSymbol;
  final String subjectName;
  final _StorageIndicator storageIndicator;
  final VoidCallback onPressed;
  final VoidCallback onSearchPressed;
  final VoidCallback onQuickAddPressed;
  final bool showSearch;
  final bool showQuickAdd;
  final bool showStorageStatus;
  final bool compactSubject;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final layout =
        Theme.of(context).extension<AppLayoutDensity>() ??
        AppLayoutDensity.fromPreference(AppDensity.platform, isDesktop: false);
    return Container(
      key: const Key('shell-subject-context'),
      height: layout.subjectContextHeight < 54
          ? 54
          : layout.subjectContextHeight,
      padding: layout.subjectContextPadding,
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
                        padding: EdgeInsets.symmetric(
                          horizontal: layout.dense ? 8 : 11,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              subjectSymbol,
                              style: const TextStyle(fontSize: 13),
                            ),
                            if (!compactSubject) ...[
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
                            ],
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
          if (showQuickAdd) ...[
            SizedBox(width: layout.controlGap),
            SizedBox.square(
              dimension: 44,
              child: IconButton(
                key: const Key('shell-quick-add'),
                tooltip: '빠른 자료 추가',
                onPressed: onQuickAddPressed,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ),
          ],
          if (showSearch) ...[
            SizedBox(width: layout.controlGap / 2),
            SizedBox.square(
              dimension: 44,
              child: IconButton(
                key: const Key('open-global-search'),
                tooltip: '전체 검색 · Ctrl/⌘+K',
                onPressed: onSearchPressed,
                icon: const Icon(Icons.manage_search_rounded),
              ),
            ),
          ],
          if (showStorageStatus) ...[
            SizedBox(width: layout.controlGap / 2),
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
        ],
      ),
    );
  }
}

IconData _navigationIcon(
  (String, String, String, IconData, IconData) destination, {
  required bool selected,
  required AppNavigationIconStyle style,
}) => switch (style) {
  AppNavigationIconStyle.adaptive => selected ? destination.$5 : destination.$4,
  AppNavigationIconStyle.outlined => destination.$4,
  AppNavigationIconStyle.filled => destination.$5,
};

enum _StorageIndicatorKind {
  loading,
  completed,
  waiting,
  syncing,
  local,
  setupRequired,
  attention,
}

class _GlobalAppErrorStrip extends StatelessWidget {
  const _GlobalAppErrorStrip({
    required this.notice,
    required this.onOpen,
    required this.onDismiss,
  });

  final GlobalAppErrorNotice notice;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('global-app-error-strip'),
      container: true,
      liveRegion: true,
      label: '문제가 발생했습니다. ${notice.message}',
      child: Material(
        color: colors.errorContainer,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 20,
                  color: colors.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notice.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('global-app-error-open'),
                  onPressed: onOpen,
                  tooltip: '해결 방법 보기',
                  color: colors.onErrorContainer,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                IconButton(
                  key: const Key('global-app-error-dismiss'),
                  onPressed: onDismiss,
                  tooltip: '안내 닫기',
                  color: colors.onErrorContainer,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
        SyncDisplayStatus.completed => _StorageIndicator(
          kind: _StorageIndicatorKind.completed,
          label: connection.lastSyncedAt == null
              ? 'Drive 저장 완료'
              : 'Drive ${_syncTime(connection.lastSyncedAt!)} 저장 완료',
          icon: Icons.cloud_done_outlined,
        ),
        SyncDisplayStatus.waiting => const _StorageIndicator(
          kind: _StorageIndicatorKind.waiting,
          label: '기기에 저장됨 · Drive 대기',
          icon: Icons.cloud_upload_outlined,
        ),
        SyncDisplayStatus.syncing => const _StorageIndicator(
          kind: _StorageIndicatorKind.syncing,
          label: 'Drive 저장 중',
          icon: Icons.sync_rounded,
        ),
        SyncDisplayStatus.error => const _StorageIndicator(
          kind: _StorageIndicatorKind.attention,
          label: '기기에 저장됨 · 재시도 필요',
          icon: Icons.cloud_off_outlined,
        ),
        SyncDisplayStatus.localSaved => const _StorageIndicator(
          kind: _StorageIndicatorKind.local,
          label: '기기에 저장됨',
          icon: Icons.save_outlined,
        ),
      };
    }
    return const _StorageIndicator(
      kind: _StorageIndicatorKind.setupRequired,
      label: 'Drive 연결 필요',
      icon: Icons.cloud_off_outlined,
    );
  }

  final _StorageIndicatorKind kind;
  final String label;
  final IconData icon;

  static String _syncTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

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
  const _BrandMark({required this.extended, required this.decorationIntensity});

  final bool extended;
  final AppDecorationIntensity decorationIntensity;

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
              color: decorationIntensity == AppDecorationIntensity.minimal
                  ? colors.primary
                  : null,
              gradient: decorationIntensity == AppDecorationIntensity.minimal
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors.primary, colors.secondary],
                    ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: decorationIntensity == AppDecorationIntensity.minimal
                  ? const []
                  : [
                      BoxShadow(
                        color: colors.primary.withValues(
                          alpha:
                              decorationIntensity ==
                                  AppDecorationIntensity.vivid
                              ? 0.3
                              : 0.18,
                        ),
                        blurRadius:
                            decorationIntensity == AppDecorationIntensity.vivid
                            ? 18
                            : 12,
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
                    'Sprache',
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
