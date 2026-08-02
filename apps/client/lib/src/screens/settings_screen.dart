import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' as widgets show ConnectionState;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../backup/backup_archive.dart';
import '../backup/settings_transfer_bundle.dart';
import '../backup/study_data_csv_exporter.dart';
import '../backup/study_data_xlsx_exporter.dart';
import '../domain/app_experience_preferences.dart';
import '../domain/accessibility_input_profile.dart';
import '../domain/app_platform.dart';
import '../domain/device_preferences.dart';
import '../domain/language.dart';
import '../domain/study_interaction_preferences.dart';
import '../domain/study_preferences.dart';
import '../domain/local_storage.dart';
import '../integrations/google/google_connection_service.dart';
import '../services/window_workspace_service.dart';
import '../services/recovery_backup_catalog.dart';
import '../services/recovery_checkpoint_service.dart';
import '../services/app_clock.dart';
import '../services/study_notification_service.dart';
import '../services/tts_service.dart';
import '../state/app_state.dart';
import '../state/app_state_view.dart';
import '../state/connection_state.dart';
import '../state/device_preferences_state.dart';
import '../state/local_storage_state.dart';
import '../sync/pending_sync.dart';
import '../sync/sync_merge_report.dart';
import '../sync/sync_policy.dart';
import '../theme/app_theme.dart';
import '../widgets/advanced_preferences_panel.dart';
import '../widgets/accessibility_input_profile_card.dart';
import 'storage_maintenance_dialog.dart';

enum _ExistingLocalChoice { later, keepCurrent, mergeExisting }

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _connectionDiagnosticAnchorKey = GlobalKey();
  final GlobalKey _storageSectionKey = GlobalKey();
  final GlobalKey _displaySectionKey = GlobalKey();
  final GlobalKey _learningSectionKey = GlobalKey();
  final GlobalKey _windowsSectionKey = GlobalKey();
  final GlobalKey _privacySectionKey = GlobalKey();
  final GlobalKey _aboutSectionKey = GlobalKey();
  final FocusNode _storageSectionFocus = FocusNode(
    debugLabel: 'settings-storage-section',
  );
  final FocusNode _displaySectionFocus = FocusNode(
    debugLabel: 'settings-display-section',
  );
  final FocusNode _learningSectionFocus = FocusNode(
    debugLabel: 'settings-learning-section',
  );
  final FocusNode _windowsSectionFocus = FocusNode(
    debugLabel: 'settings-windows-section',
  );
  final FocusNode _privacySectionFocus = FocusNode(
    debugLabel: 'settings-privacy-section',
  );
  final FocusNode _aboutSectionFocus = FocusNode(
    debugLabel: 'settings-about-section',
  );
  Timer? _searchNavigationTimer;
  String _query = '';

  @override
  void dispose() {
    _searchNavigationTimer?.cancel();
    _searchController.dispose();
    _storageSectionFocus.dispose();
    _displaySectionFocus.dispose();
    _learningSectionFocus.dispose();
    _windowsSectionFocus.dispose();
    _privacySectionFocus.dispose();
    _aboutSectionFocus.dispose();
    super.dispose();
  }

  bool _matches(String keywords) {
    return _matchesQuery(_query, keywords);
  }

  bool _matchesQuery(String value, String keywords) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return true;
    final haystack = keywords.toLowerCase();
    return query
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .every(haystack.contains);
  }

  void _handleSearchChanged(String value) {
    setState(() => _query = value);
    _searchNavigationTimer?.cancel();
    if (value.trim().isEmpty) return;
    _searchNavigationTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || _query != value) return;
      _focusFirstSearchResult(value);
    });
  }

  void _focusFirstSearchResult(String query) {
    final candidates = <(GlobalKey, FocusNode, String)>[
      if (_matchesQuery(
        query,
        '저장 google 구글 drive 드라이브 로컬 폴더 동기화 백업 계정 연결 railway',
      ))
        (_storageSectionKey, _storageSectionFocus, '저장·동기화'),
      if (_matchesQuery(
        query,
        '화면 학습 편의 테마 색상 다크 라이트 글자 밀도 모션 진동 소리 tts 음성 읽기 발음 퀴즈 접근성 고대비 카드 큰 버튼 단축키 제스처',
      ))
        (_displaySectionKey, _displaySectionFocus, '화면·학습 편의'),
      if (_matchesQuery(query, '학습 분량 목표 xp 문제 수 세션 복습 새 표현 문장 비율 방식 일정 알림'))
        (_learningSectionKey, _learningSectionFocus, '학습 분량'),
      if (defaultTargetPlatform == TargetPlatform.windows &&
          _matchesQuery(query, 'windows 윈도우 창 크기 컴팩트 최소화 항상 위 업무'))
        (_windowsSectionKey, _windowsSectionFocus, 'Windows 창 도구'),
      if (_matchesQuery(
        query,
        '데이터 개인정보 백업 복원 excel 엑셀 csv 내보내기 삭제 보안 보관 정리 콘텐츠 품질 점검 교정',
      ))
        (_privacySectionKey, _privacySectionFocus, '데이터와 개인정보'),
      if (_matchesQuery(query, '앱 정보 sprache 버전 플랫폼 환경'))
        (_aboutSectionKey, _aboutSectionFocus, '앱 정보'),
    ];
    if (candidates.isEmpty) return;
    final target = candidates.first;
    target.$2.requestFocus();
    _jumpTo(target.$1);
    SemanticsService.sendAnnouncement(
      View.of(context),
      '${target.$3} 설정으로 이동했습니다.',
      Directionality.of(context),
    );
  }

  void _jumpTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: 0.08,
    );
  }

  void _revealConnectionDiagnostic() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _connectionDiagnosticAnchorKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: 0.12,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final calendarDay = ref.watch(calendarDayProvider);
    final connection = ref.watch(connectionControllerProvider);
    final localStorage = ref.watch(localStorageControllerProvider);
    final deviceState = ref.watch(devicePreferencesControllerProvider);
    final devicePreferences = deviceState.preferences;
    final config = ref.watch(appConfigProvider);
    final connected = state.driveConnected;
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final usesDesktopKeyboard =
        isWindows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
    final windowWorkspace = ref.watch(windowWorkspaceControllerProvider);
    final notificationSpecs = buildStudyNotificationSpecs(
      state.preferences.savedSessionPlans,
      now: DateTime.now(),
      preferences: devicePreferences.notifications,
    );
    final notificationCount = notificationSpecs.length;
    final showStorage = _matches(
      '저장 google 구글 drive 드라이브 로컬 폴더 동기화 백업 계정 연결 railway',
    );
    final showDisplay = _matches(
      '화면 학습 편의 테마 색상 다크 라이트 글자 밀도 모션 진동 소리 tts 음성 읽기 발음 퀴즈 접근성 고대비 카드 큰 버튼 단축키 제스처',
    );
    final showLearning = _matches('학습 분량 목표 xp 문제 수 세션 복습 새 표현 문장 비율 방식 일정 알림');
    final showWindows =
        isWindows && _matches('windows 윈도우 창 크기 컴팩트 최소화 항상 위 업무');
    final showPrivacy = _matches(
      '데이터 개인정보 백업 복원 excel 엑셀 csv 내보내기 삭제 보안 보관 정리 콘텐츠 품질 점검 교정',
    );
    final showAbout = _matches('앱 정보 sprache 버전 플랫폼 환경');
    final hasSearchResult =
        showStorage ||
        showDisplay ||
        showLearning ||
        showWindows ||
        showPrivacy ||
        showAbout;

    ref.listen(connectionControllerProvider, (previous, next) {
      if (next.phase == ConnectionPhase.failed &&
          next.errorMessage != previous?.errorMessage) {
        _revealConnectionDiagnostic();
        SemanticsService.sendAnnouncement(
          View.of(context),
          next.errorMessage ?? 'Google 연결에 실패했습니다.',
          Directionality.of(context),
        );
      }
    });

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final veryNarrow = constraints.maxWidth < 360;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              compact ? 14 : 20,
              compact ? 12 : 24,
              compact ? 14 : 20,
              compact ? 16 : 28,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 940),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '환경설정',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  veryNarrow
                                      ? '학습·저장 설정을 관리합니다.'
                                      : '저장 위치와 학습 환경을 확인합니다.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          _ModePill(mock: config.mockMode),
                        ],
                      ),
                      SizedBox(height: compact ? 14 : 18),
                      _SettingsSearchPanel(
                        controller: _searchController,
                        query: _query,
                        onChanged: _handleSearchChanged,
                        onSubmitted: _focusFirstSearchResult,
                        onClear: () {
                          _searchNavigationTimer?.cancel();
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        onResetAll: () => _confirmAndResetAll(context, ref),
                        onJumpStorage: () => _jumpTo(_storageSectionKey),
                        onJumpDisplay: () => _jumpTo(_displaySectionKey),
                        onJumpLearning: () => _jumpTo(_learningSectionKey),
                        onJumpPrivacy: () => _jumpTo(_privacySectionKey),
                      ),
                      if (!hasSearchResult) ...[
                        const SizedBox(height: 16),
                        _SettingsEmptySearch(query: _query),
                      ],
                      if (showStorage) ...[
                        const SizedBox(height: 20),
                        Focus(
                          key: const Key('settings-section-focus-storage'),
                          focusNode: _storageSectionFocus,
                          child: _SectionLabel(
                            key: _storageSectionKey,
                            title: '저장·동기화',
                            caption: '로컬 폴더와 Google Drive 연결 상태',
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ConnectionCard(
                          diagnosticAnchorKey: _connectionDiagnosticAnchorKey,
                          connected: connected,
                          connection: connection,
                          localStorage: localStorage,
                          pendingSync: connected ? state.pendingSync : null,
                          mockMode: config.mockMode,
                          onChooseLocalFolder: () =>
                              _chooseLocalFolder(context, ref),
                          onSaveLocalNow: () => _saveLocalNow(context, ref),
                          onRestoreLocal: () =>
                              _restoreSelectedLocalBackup(context, ref),
                          onClearLocalFolder: () =>
                              _clearLocalFolder(context, ref),
                          onConnect: () => ref
                              .read(connectionControllerProvider.notifier)
                              .connect(),
                          onSync: () => ref
                              .read(connectionControllerProvider.notifier)
                              .syncNow(),
                          onDisconnect: () => ref
                              .read(connectionControllerProvider.notifier)
                              .disconnect(),
                        ),
                      ],
                      if (showDisplay) ...[
                        const SizedBox(height: 20),
                        Focus(
                          key: const Key('settings-section-focus-display'),
                          focusNode: _displaySectionFocus,
                          child: _SectionLabel(
                            key: _displaySectionKey,
                            title: '화면·학습 편의',
                            caption: '필요한 항목만 펼쳐서 조정',
                            resetKey: const Key('reset-display-settings'),
                            onReset: () =>
                                _confirmAndResetDisplay(context, ref),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Card(
                          key: const Key('open-personalization-studio'),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.palette_outlined),
                            ),
                            title: const Text('개인화 스튜디오'),
                            subtitle: const Text(
                              '테마 미리보기, 홈 구성, 내비게이션과 빠른 등록 기본값',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/settings/personalize'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        AdvancedPreferencesPanel(
                          searchQuery: _query,
                          experiencePreferences: state.preferences.experience,
                          interactionPreferences: state.preferences.interaction,
                          ttsRate: state.preferences.ttsRate,
                          onExperiencePreferencesChanged: ref
                              .read(appControllerProvider.notifier)
                              .updateExperiencePreferences,
                          onInteractionPreferencesChanged: ref
                              .read(appControllerProvider.notifier)
                              .updateInteractionPreferences,
                          onTtsRateChanged: ref
                              .read(appControllerProvider.notifier)
                              .updateTtsRate,
                        ),
                        const SizedBox(height: 10),
                        AccessibilityInputProfileCard(
                          profile:
                              localStorage.settings.accessibilityInputProfile,
                          isWindows: usesDesktopKeyboard,
                          isAndroid: isAndroid,
                          onChanged: (profile) => unawaited(
                            ref
                                .read(localStorageControllerProvider.notifier)
                                .updateAccessibilityInputProfile(profile),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DeviceFeedbackPreferencesCard(
                          preferences: devicePreferences.voice,
                          language: state.selectedLanguage,
                          ttsService: ref.watch(deviceTtsServiceProvider),
                          ttsRate: state.preferences.ttsRate,
                          preferOfflineVoice:
                              state.preferences.interaction.preferOfflineVoice,
                          onChanged: (value) => unawaited(
                            ref
                                .read(
                                  devicePreferencesControllerProvider.notifier,
                                )
                                .updateVoice(value),
                          ),
                        ),
                      ],
                      if (showLearning) ...[
                        const SizedBox(height: 20),
                        Focus(
                          key: const Key('settings-section-focus-learning'),
                          focusNode: _learningSectionFocus,
                          child: _SectionLabel(
                            key: _learningSectionKey,
                            title: '학습 분량',
                            caption: '주제별 목표와 기본 세션 구성',
                            resetKey: const Key('reset-learning-settings'),
                            onReset: () =>
                                _confirmAndResetLearning(context, ref),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _LearningPreferencesCard(
                          preferences: state.preferences,
                          subjectName: ref
                              .read(appControllerProvider.notifier)
                              .activeSubject
                              .name,
                          dailyXp: state.activeCourseDailyXpAt(calendarDay),
                          dailyGoal: state.dailyGoal,
                          accountTotalXp: state.totalXp,
                          onDailyGoalChanged: ref
                              .read(appControllerProvider.notifier)
                              .updateActiveDailyGoal,
                          onChanged: ref
                              .read(appControllerProvider.notifier)
                              .updatePreferences,
                        ),
                        const SizedBox(height: 10),
                        _StudyNotificationsCard(
                          plannedCount: notificationCount,
                          platformName: appPlatformName(defaultTargetPlatform),
                          onConfigure: () =>
                              _configureStudyNotifications(context, ref),
                        ),
                        const SizedBox(height: 10),
                        _DeviceNotificationPreferencesCard(
                          preferences: devicePreferences.notifications,
                          previews: notificationSpecs.take(3).toList(),
                          hydrated: deviceState.isHydrated,
                          onChanged: (value) => unawaited(
                            ref
                                .read(
                                  devicePreferencesControllerProvider.notifier,
                                )
                                .updateNotifications(value),
                          ),
                          onTest: () => _testStudyNotification(
                            context,
                            ref,
                            devicePreferences.notifications,
                          ),
                        ),
                      ],
                      if (showWindows) ...[
                        const SizedBox(height: 20),
                        Focus(
                          key: const Key('settings-section-focus-windows'),
                          focusNode: _windowsSectionFocus,
                          child: _SectionLabel(
                            key: _windowsSectionKey,
                            title: 'Windows 창 도구',
                            caption: '작게 두고 공부하거나 필요할 때 즉시 최소화',
                          ),
                        ),
                        const SizedBox(height: 10),
                        _WindowsWorkspaceCard(
                          state: windowWorkspace,
                          onToggleCompact: () => ref
                              .read(windowWorkspaceControllerProvider.notifier)
                              .toggleCompact(),
                          onToggleAlwaysOnTop: () => ref
                              .read(windowWorkspaceControllerProvider.notifier)
                              .toggleAlwaysOnTop(),
                          onMinimize: () => ref
                              .read(windowWorkspaceControllerProvider.notifier)
                              .minimize(),
                        ),
                      ],
                      if (showPrivacy) ...[
                        const SizedBox(height: 20),
                        Focus(
                          key: const Key('settings-section-focus-privacy'),
                          focusNode: _privacySectionFocus,
                          child: _SectionLabel(
                            key: _privacySectionKey,
                            title: '데이터와 개인정보',
                            caption: '연결 전에 저장 범위를 확인하세요',
                          ),
                        ),
                        const SizedBox(height: 10),
                        _PrivacyCard(
                          onOpenDetails: () => _showPrivacyDetails(
                            context,
                            appVersion: config.appVersion,
                          ),
                          privacyPolicyUrl: config.privacyPolicyUrl,
                          connected: connected,
                          onDeleteAccountBinding: () => _deleteAccountBinding(
                            context,
                            ref,
                            connected: connected,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DevicePrivacyPreferencesCard(
                          preferences: devicePreferences.privacy,
                          hydrated: deviceState.isHydrated,
                          onChanged: (value) => unawaited(
                            ref
                                .read(
                                  devicePreferencesControllerProvider.notifier,
                                )
                                .updatePrivacy(value),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Card(
                          key: const Key('open-data-health'),
                          child: ListTile(
                            leading: const Icon(
                              Icons.health_and_safety_outlined,
                            ),
                            title: const Text('데이터 건강'),
                            subtitle: const Text(
                              '앱 DB·로컬 폴더·Drive·대기 작업과 백업 검증 영수증 확인',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/settings/data-health'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Card(
                          key: const Key('open-content-quality'),
                          child: ListTile(
                            leading: const Icon(Icons.fact_check_outlined),
                            title: const Text('콘텐츠 품질 점검'),
                            subtitle: const Text(
                              '읽기·문맥·출처·연습 준비·교정 메모를 한곳에서 확인',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/library/quality'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _BackupDataCard(
                          customItemCount: state.customItems.length,
                          recentSessionCount: state.recentSessions.length,
                          onExportBackup: () => _exportJson(context, ref),
                          onRestoreBackup: () => _restoreJson(context, ref),
                          onExportSettings: () => _exportSettings(context, ref),
                          onImportSettings: () => _importSettings(context, ref),
                          onExportXlsx: () => _exportXlsx(context, ref),
                          onExportCsv: () => _exportCsv(context, ref),
                        ),
                        const SizedBox(height: 10),
                        _StorageMaintenanceCard(
                          onOpen: () {
                            final service = ref.read(
                              googleConnectionServiceProvider,
                            );
                            showDialog<void>(
                              context: context,
                              builder: (context) => StorageMaintenanceDialog(
                                localCatalog: RecoveryBackupCatalogService(),
                                onRestoreLocal: (backup) =>
                                    _restoreRecoveryCheckpoint(
                                      context,
                                      ref,
                                      backup,
                                    ),
                                remoteService:
                                    connected &&
                                        service is RemoteStorageRetentionService
                                    ? service as RemoteStorageRetentionService
                                    : null,
                              ),
                            );
                          },
                        ),
                      ],
                      if (showAbout) ...[
                        const SizedBox(height: 20),
                        Focus(
                          key: const Key('settings-section-focus-about'),
                          focusNode: _aboutSectionFocus,
                          child: _SectionLabel(
                            key: _aboutSectionKey,
                            title: '앱 정보',
                            caption: '',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Card(
                          child: Column(
                            children: [
                              _SettingRow(
                                icon: Icons.translate_rounded,
                                title: 'Sprache',
                                subtitle: '언어와 모든 주제를 위한 반복학습',
                                trailing: config.appVersion,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const Divider(),
                              _SettingRow(
                                icon: Icons.devices_rounded,
                                title: '현재 플랫폼',
                                subtitle: appPlatformDescription(
                                  defaultTargetPlatform,
                                ),
                                trailing: config.appEnvironment,
                                color: AppTheme.desktopPrimary,
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
          );
        },
      ),
    );
  }

  Future<bool> _confirmReset(
    BuildContext context, {
    required String title,
    required List<String> changes,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('다음 항목을 Sprache 기본값으로 되돌립니다.'),
                const SizedBox(height: 10),
                for (final change in changes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(change)),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  '학습 자료, 진도, 저장 위치, Google 연결은 변경하지 않습니다.',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              FilledButton(
                key: const Key('confirm-settings-reset'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('초기화'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _applyDisplayReset(WidgetRef ref) {
    final controller = ref.read(appControllerProvider.notifier);
    controller.updateExperiencePreferences(const AppExperiencePreferences());
    controller.updateInteractionPreferences(
      const StudyInteractionPreferences(),
    );
    controller.updateTtsRate(0.45);
    unawaited(
      ref
          .read(localStorageControllerProvider.notifier)
          .updateAccessibilityInputProfile(const AccessibilityInputProfile()),
    );
  }

  void _applyLearningReset(WidgetRef ref) {
    final controller = ref.read(appControllerProvider.notifier);
    controller.updateActiveDailyGoal(100);
    final current = ref.read(appControllerProvider);
    controller.updatePreferences(
      current.preferences.copyWith(
        sessionItemLimit: 10,
        newItemLimit: 10,
        reviewLimit: 30,
        sentenceRatio: 0.3,
        preferredMode: StudyMode.mixed,
        sessionPlan: StudySessionPlan(subjectId: current.activeSubjectId),
      ),
    );
  }

  Future<void> _confirmAndResetDisplay(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final approved = await _confirmReset(
      context,
      title: '화면·학습 편의를 초기화할까요?',
      changes: const [
        '테마, 강조색, 밀도와 글자 크기',
        '모션, 진동, 효과음과 TTS 속도',
        '읽기 표기, 출제 방향과 자동 넘김',
        '고대비, 카드 크기, 입력 제스처와 단축키',
      ],
    );
    if (!approved || !context.mounted) return;
    _applyDisplayReset(ref);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('화면·학습 편의를 기본값으로 되돌렸습니다.')));
  }

  Future<void> _confirmAndResetLearning(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final approved = await _confirmReset(
      context,
      title: '학습 분량을 초기화할까요?',
      changes: const [
        '현재 주제의 하루 목표를 100 XP로 변경',
        '기본 세션 10문제, 새 표현 10개, 복습 30개',
        '문장 비율 30%, 혼합 학습 방식',
      ],
    );
    if (!approved || !context.mounted) return;
    _applyLearningReset(ref);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('학습 분량을 기본값으로 되돌렸습니다.')));
  }

  Future<void> _confirmAndResetAll(BuildContext context, WidgetRef ref) async {
    final approved = await _confirmReset(
      context,
      title: '편의 설정을 모두 초기화할까요?',
      changes: const ['화면, 소리, 읽기와 퀴즈 편의 설정', '현재 주제의 하루 목표와 기본 세션 분량'],
    );
    if (!approved || !context.mounted) return;
    _applyDisplayReset(ref);
    _applyLearningReset(ref);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('편의 설정을 모두 기본값으로 되돌렸습니다.')));
  }

  Future<void> _configureStudyNotifications(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await ref
        .read(appControllerProvider.notifier)
        .setupStudyNotifications();
    if (!context.mounted) return;
    final message = switch (result.permission) {
      StudyNotificationPermission.denied =>
        '알림 권한이 꺼져 있습니다. 기기 설정에서 Sprache 알림을 허용해 주세요.',
      StudyNotificationPermission.unavailable =>
        '이 기기에서는 학습 일정 알림을 연결하지 못했습니다.',
      StudyNotificationPermission.granted
          when !result.reconcileResult.available =>
        '알림 권한은 있지만 예약을 갱신하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      StudyNotificationPermission.granted =>
        result.reconcileResult.scheduledCount == 0
            ? '알림을 연결했습니다. 미래 학습 일정을 저장하면 이 기기에서 알려드려요.'
            : '미래 일정 ${result.reconcileResult.scheduledCount}개의 알림을 이 기기와 맞췄습니다.',
    };
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _testStudyNotification(
    BuildContext context,
    WidgetRef ref,
    DeviceNotificationPreferences preferences,
  ) async {
    final permission = await ref
        .read(appControllerProvider.notifier)
        .requestStudyNotificationPermission();
    final shown = permission == StudyNotificationPermission.granted
        ? await showStudyNotificationTest(
            ref.read(studyNotificationServiceProvider),
            preferences,
          )
        : false;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shown ? '테스트 알림을 보냈습니다.' : '테스트 알림을 보내지 못했습니다. 기기 권한을 확인해 주세요.',
        ),
      ),
    );
  }

  Future<bool> _createRecoveryCheckpoint(
    BuildContext context,
    WidgetRef ref, {
    required RecoveryCheckpointReason reason,
  }) async {
    try {
      final receipt = await RecoveryCheckpointService().create(
        ref.read(appControllerProvider.notifier).exportArchive(),
        reason: reason,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${reason.label} 안전 지점을 만들었습니다 · ${receipt.itemCount}개 항목',
            ),
          ),
        );
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('안전 지점을 만들지 못해 작업을 시작하지 않았습니다.')),
        );
      }
      return false;
    }
  }

  Future<void> _restoreRecoveryCheckpoint(
    BuildContext context,
    WidgetRef ref,
    LocalRecoveryBackup backup,
  ) async {
    try {
      final service = RecoveryCheckpointService();
      final archive = await service.load(backup.path);
      if (!context.mounted) return;
      final controller = ref.read(appControllerProvider.notifier);
      final selection = await showDialog<BackupRestoreSelection>(
        context: context,
        builder: (context) => _BackupRestoreDialog(
          archive: archive,
          fileName: backup.reason ?? backup.id,
          previewBuilder: (selection) =>
              controller.previewBackupRestore(archive, selection: selection),
        ),
      );
      if (selection == null || !context.mounted) return;
      if (!await _createRecoveryCheckpoint(
        context,
        ref,
        reason: RecoveryCheckpointReason.restore,
      )) {
        return;
      }
      final result = await controller.restoreBackup(
        archive,
        selection: selection,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '안전 지점을 복원했습니다 · 콘텐츠 ${result.customItemCount}개 · '
            '진도 ${result.progressCount}개 · 세션 ${result.restoredSessionCount}개',
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('안전 지점이 손상되었거나 복원할 수 없습니다.')),
        );
      }
    }
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    try {
      final archive = ref.read(appControllerProvider.notifier).exportArchive();
      final content = const JsonEncoder.withIndent('  ').convert(archive);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Sprache 학습 데이터 저장',
        fileName: 'sprache-backup-${_dateStamp(DateTime.now())}.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(content)),
        lockParentWindow: true,
      );
      if (!context.mounted || path == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('백업을 저장했습니다: $path')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('백업 저장에 실패했습니다.')));
    }
  }

  Future<void> _exportSettings(BuildContext context, WidgetRef ref) async {
    try {
      final bundle = SettingsTransferBundle(
        appPreferences: ref.read(appControllerProvider).preferences,
        devicePreferences: ref
            .read(devicePreferencesControllerProvider)
            .preferences,
        exportedAt: DateTime.now().toUtc(),
      );
      final content = const SettingsTransferCodec().encode(bundle);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Sprache 설정만 저장',
        fileName: 'sprache-settings-${_dateStamp(DateTime.now())}.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(content)),
        lockParentWindow: true,
      );
      if (!context.mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('학습 콘텐츠가 없는 설정 파일을 저장했습니다: $path')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('설정 파일을 저장하지 못했습니다.')));
    }
  }

  Future<void> _importSettings(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Sprache 설정 파일 선택',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        allowMultiple: false,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      if (file.size > SettingsTransferCodec.maxBytes || file.bytes == null) {
        throw const SettingsTransferException('설정 파일은 512KB 이하여야 합니다.');
      }
      final bundle = const SettingsTransferCodec().decode(
        utf8.decode(file.bytes!, allowMalformed: false),
      );
      if (!context.mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('설정만 적용할까요?'),
          content: Text(
            '${bundle.exportedAt.toLocal()}에 만든 설정 파일입니다. '
            '테마·학습 방식·접근성·이 기기 알림과 개인정보 설정만 바꾸며, '
            '단어·진도·XP·세션은 변경하지 않습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton.icon(
              key: const Key('confirm-settings-import'),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('설정 적용'),
            ),
          ],
        ),
      );
      if (approved != true || !context.mounted) return;
      ref
          .read(appControllerProvider.notifier)
          .updatePreferences(bundle.appPreferences);
      await ref
          .read(devicePreferencesControllerProvider.notifier)
          .replace(bundle.devicePreferences);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정만 검증해 적용했습니다. 학습 데이터는 유지했습니다.')),
      );
    } on SettingsTransferException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on FormatException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정 파일의 문자 인코딩이 올바르지 않습니다.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('설정 파일을 적용하지 못했습니다.')));
    }
  }

  Future<void> _chooseLocalFolder(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref
          .read(localStorageControllerProvider.notifier)
          .chooseFolder();
      if (!context.mounted || result.cancelled) return;
      if (!result.existingArchiveAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로컬 보관 폴더를 연결했습니다. 자동 저장을 시작합니다.')),
        );
        return;
      }
      final choice = await showDialog<_ExistingLocalChoice>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('기존 Sprache 저장본을 찾았습니다'),
          content: const Text(
            '이 폴더의 기존 데이터를 검증한 뒤 현재 데이터와 병합하거나, '
            '현재 기기 데이터로 새 저장 세대를 만들 수 있습니다. 자동으로 덮어쓰지 않습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _ExistingLocalChoice.later),
              child: const Text('나중에'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _ExistingLocalChoice.keepCurrent,
              ),
              child: const Text('현재 데이터 사용'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                dialogContext,
                _ExistingLocalChoice.mergeExisting,
              ),
              icon: const Icon(Icons.merge_rounded),
              label: const Text('기존 저장본 병합'),
            ),
          ],
        ),
      );
      if (!context.mounted || choice == null) return;
      switch (choice) {
        case _ExistingLocalChoice.later:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('결정 전까지 기존 폴더를 덮어쓰지 않습니다.')),
          );
        case _ExistingLocalChoice.keepCurrent:
          await ref
              .read(localStorageControllerProvider.notifier)
              .keepCurrentDataInSelectedFolder();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('현재 데이터를 로컬 폴더에 저장했습니다.')),
            );
          }
        case _ExistingLocalChoice.mergeExisting:
          await _restoreSelectedLocalBackup(context, ref);
      }
    } catch (error) {
      if (!context.mounted) return;
      final state = ref.read(localStorageControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? '로컬 보관 폴더를 연결하지 못했습니다: $error'),
        ),
      );
    }
  }

  Future<void> _saveLocalNow(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(localStorageControllerProvider.notifier).saveNow();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 학습 데이터를 로컬 폴더에 저장했습니다.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      final error = ref.read(localStorageControllerProvider).errorMessage;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? '로컬 저장에 실패했습니다.')));
    }
  }

  Future<void> _deleteAccountBinding(
    BuildContext context,
    WidgetRef ref, {
    required bool connected,
  }) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('delete-account-binding-dialog'),
        title: const Text('계정 연결 기록을 삭제할까요?'),
        content: Text(
          connected
              ? '이 기기의 Google 로그인과 Railway의 HMAC 계정–Drive 폴더 연결을 '
                    '삭제합니다. Drive 파일, 로컬 DB와 로컬 보관 폴더는 지우지 않습니다. '
                    '다른 기기에서는 다음 실행 때 Google을 다시 연결해야 할 수 있습니다.'
              : 'Google 계정을 확인한 뒤 Railway에 남아 있는 HMAC 계정–Drive 폴더 '
                    '연결 기록을 삭제합니다. Drive 파일, 로컬 DB와 로컬 보관 폴더는 '
                    '지우지 않으며 현재 로컬 저장 모드도 그대로 유지됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(connected ? '연결 기록 삭제' : '확인 후 삭제'),
          ),
        ],
      ),
    );
    if (approved != true || !context.mounted) return;
    try {
      await ref
          .read(connectionControllerProvider.notifier)
          .deleteAccountBinding();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connected
                ? '계정 연결 기록을 삭제했습니다. 로컬 저장 모드로 전환합니다.'
                : '계정 연결 기록 삭제를 완료했습니다. 로컬 저장 모드는 그대로 유지됩니다.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('계정 연결 기록을 삭제하지 못했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _restoreSelectedLocalBackup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final storageController = ref.read(
        localStorageControllerProvider.notifier,
      );
      final archive = await storageController.loadExistingBackup();
      if (!context.mounted) return;
      if (archive == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('복원할 정상 로컬 저장본이 없습니다.')));
        return;
      }
      final controller = ref.read(appControllerProvider.notifier);
      final selection = await showDialog<BackupRestoreSelection>(
        context: context,
        builder: (dialogContext) => _BackupRestoreDialog(
          archive: archive,
          fileName: '선택한 로컬 보관 폴더',
          previewBuilder: (selection) =>
              controller.previewBackupRestore(archive, selection: selection),
        ),
      );
      if (selection == null || !context.mounted) return;
      if (!await _createRecoveryCheckpoint(
        context,
        ref,
        reason: RecoveryCheckpointReason.restore,
      )) {
        return;
      }
      final restored = await controller.restoreBackup(
        archive,
        selection: selection,
      );
      await storageController.markExistingBackupMerged();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '로컬 저장본 병합 완료 · 개인 콘텐츠 ${restored.customItemCount}개 · '
            '진도 ${restored.progressCount}개 · 세션 ${restored.restoredSessionCount}개',
          ),
        ),
      );
    } on BackupArchiveException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로컬 저장본 검증 실패: ${error.message}')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로컬 저장본을 불러오지 못했습니다. 현재 데이터는 유지됩니다.')),
      );
    }
  }

  Future<void> _clearLocalFolder(BuildContext context, WidgetRef ref) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로컬 폴더 연결을 해제할까요?'),
        content: const Text(
          '폴더 안의 백업 파일과 앱의 학습 데이터는 삭제하지 않습니다. '
          'Google Drive가 연결되지 않았다면 새 로컬 폴더를 다시 선택해야 합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('연결만 해제'),
          ),
        ],
      ),
    );
    if (approved != true || !context.mounted) return;
    await ref.read(localStorageControllerProvider.notifier).clearFolder();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로컬 폴더 연결만 해제했습니다. 파일은 유지됩니다.')),
    );
  }

  Future<void> _restoreJson(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Sprache 백업 선택',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        allowMultiple: false,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      if (file.size > BackupArchiveCodec.maxArchiveBytes) {
        throw const BackupArchiveException('백업 파일은 10MB 이하여야 합니다.');
      }
      final bytes = file.bytes;
      if (bytes == null) {
        throw const BackupArchiveException('선택한 파일을 읽을 수 없습니다.');
      }
      final archive = const BackupArchiveCodec().decode(
        utf8.decode(bytes, allowMalformed: false),
      );
      if (!context.mounted) return;
      final controller = ref.read(appControllerProvider.notifier);
      final selection = await showDialog<BackupRestoreSelection>(
        context: context,
        builder: (dialogContext) => _BackupRestoreDialog(
          archive: archive,
          fileName: file.name,
          previewBuilder: (selection) =>
              controller.previewBackupRestore(archive, selection: selection),
        ),
      );
      if (selection == null || !context.mounted) return;
      if (!await _createRecoveryCheckpoint(
        context,
        ref,
        reason: RecoveryCheckpointReason.restore,
      )) {
        return;
      }
      final result = await controller.restoreBackup(
        archive,
        selection: selection,
      );
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '복원 완료 · 개인 콘텐츠 ${result.customItemCount}개 · '
            '진도 ${result.progressCount}개 · 세션 ${result.restoredSessionCount}개 반영',
          ),
        ),
      );
    } on BackupArchiveException catch (error) {
      if (!context.mounted) return;
      final location = error.path == null ? '' : ' (${error.path})';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('백업 검증 실패$location: ${error.message}')),
      );
    } on FormatException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('백업 파일의 문자 인코딩이 올바르지 않습니다.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('백업 복원 중 오류가 발생했습니다. 로컬 데이터는 유지됩니다.')),
      );
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    try {
      final items = ref.read(appControllerProvider).customItems;
      final content = const StudyDataCsvExporter().encode(items);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Sprache 개인 콘텐츠 CSV 저장',
        fileName: 'sprache-content-${_dateStamp(DateTime.now())}.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: Uint8List.fromList(utf8.encode(content)),
        lockParentWindow: true,
      );
      if (!context.mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('개인 콘텐츠 ${items.length}개를 저장했습니다: $path')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('CSV 저장에 실패했습니다.')));
    }
  }

  Future<void> _exportXlsx(BuildContext context, WidgetRef ref) async {
    try {
      final items = ref.read(appControllerProvider).customItems;
      final bytes = const StudyDataXlsxExporter().encode(items);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Sprache 개인 콘텐츠 Excel 저장',
        fileName: 'sprache-content-${_dateStamp(DateTime.now())}.xlsx',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        bytes: bytes,
        lockParentWindow: true,
      );
      if (!context.mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('편집 가능한 Excel에 개인 콘텐츠 ${items.length}개를 저장했습니다: $path'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel 저장에 실패했습니다. 로컬 데이터는 유지됩니다.')),
      );
    }
  }
}

class _StudyNotificationsCard extends StatelessWidget {
  const _StudyNotificationsCard({
    required this.plannedCount,
    required this.platformName,
    required this.onConfigure,
  });

  final int plannedCount;
  final String platformName;
  final Future<void> Function() onConfigure;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('study-notification-settings-card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '학습 일정 알림',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        plannedCount == 0
                            ? '미래 일정이 없습니다. 일정을 저장하면 $platformName에서 알려드려요.'
                            : '미래 일정 $plannedCount개를 $platformName 알림으로 관리합니다.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                key: const Key('study-notification-configure-button'),
                onPressed: onConfigure,
                icon: const Icon(Icons.sync_rounded),
                label: Text(plannedCount == 0 ? '알림 연결' : '알림 다시 맞추기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceNotificationPreferencesCard extends StatelessWidget {
  const _DeviceNotificationPreferencesCard({
    required this.preferences,
    required this.previews,
    required this.hydrated,
    required this.onChanged,
    required this.onTest,
  });

  final DeviceNotificationPreferences preferences;
  final List<StudyNotificationSpec> previews;
  final bool hydrated;
  final ValueChanged<DeviceNotificationPreferences> onChanged;
  final Future<void> Function() onTest;

  Future<void> _pickTime(BuildContext context, {required bool start}) async {
    final minutes = start
        ? preferences.quietStartMinutes
        : preferences.quietEndMinutes;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: start ? '조용한 시간 시작' : '조용한 시간 종료',
    );
    if (selected == null) return;
    final value = selected.hour * 60 + selected.minute;
    onChanged(
      start
          ? preferences.copyWith(quietStartMinutes: value)
          : preferences.copyWith(quietEndMinutes: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('device-notification-preferences-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('이 기기에서 알림 사용'),
              subtitle: const Text('알림 설정은 Drive로 동기화하지 않습니다.'),
              value: preferences.enabled,
              onChanged: hydrated
                  ? (value) => onChanged(preferences.copyWith(enabled: value))
                  : null,
            ),
            const Divider(),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('quiet-start-picker'),
                  onPressed: preferences.enabled
                      ? () => _pickTime(context, start: true)
                      : null,
                  icon: const Icon(Icons.bedtime_outlined),
                  label: Text(
                    '시작 ${_minuteLabel(preferences.quietStartMinutes)}',
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('quiet-end-picker'),
                  onPressed: preferences.enabled
                      ? () => _pickTime(context, start: false)
                      : null,
                  icon: const Icon(Icons.wb_sunny_outlined),
                  label: Text(
                    '종료 ${_minuteLabel(preferences.quietEndMinutes)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<NotificationLockScreenContent>(
              key: const Key('notification-lock-content-picker'),
              initialValue: preferences.lockScreenContent,
              decoration: const InputDecoration(labelText: '잠금화면 공개 범위'),
              items: [
                for (final value in NotificationLockScreenContent.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(_lockScreenLabel(value)),
                  ),
              ],
              onChanged: !preferences.enabled
                  ? null
                  : (value) {
                      if (value != null) {
                        onChanged(
                          preferences.copyWith(lockScreenContent: value),
                        );
                      }
                    },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '다음 알림 미리보기',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  key: const Key('send-test-notification'),
                  onPressed: preferences.enabled ? onTest : null,
                  icon: const Icon(Icons.notification_add_outlined),
                  label: const Text('테스트'),
                ),
              ],
            ),
            if (previews.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('예약된 미래 일정이 없습니다.'),
              )
            else
              for (final spec in previews)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text(spec.title),
                  subtitle: Text(
                    '${_dateTimeLabel(spec.scheduledAt.toLocal())} · ${spec.body}',
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _DeviceFeedbackPreferencesCard extends StatefulWidget {
  const _DeviceFeedbackPreferencesCard({
    required this.preferences,
    required this.language,
    required this.ttsService,
    required this.ttsRate,
    required this.preferOfflineVoice,
    required this.onChanged,
  });

  final DeviceVoicePreferences preferences;
  final LanguageTag language;
  final TtsService ttsService;
  final double ttsRate;
  final bool preferOfflineVoice;
  final ValueChanged<DeviceVoicePreferences> onChanged;

  @override
  State<_DeviceFeedbackPreferencesCard> createState() =>
      _DeviceFeedbackPreferencesCardState();
}

class _DeviceFeedbackPreferencesCardState
    extends State<_DeviceFeedbackPreferencesCard> {
  late Future<List<TtsVoice>> _voices;
  late double _pitch;
  bool _previewing = false;
  String? _voiceStatus;

  DeviceVoicePreferences get preferences => widget.preferences;

  @override
  void initState() {
    super.initState();
    _pitch = preferences.pitch;
    _voices = widget.ttsService.voicesFor(widget.language);
  }

  @override
  void didUpdateWidget(covariant _DeviceFeedbackPreferencesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language ||
        oldWidget.ttsService != widget.ttsService) {
      _voices = widget.ttsService.voicesFor(widget.language);
      _voiceStatus = null;
    }
    if (oldWidget.preferences.pitch != widget.preferences.pitch) {
      _pitch = widget.preferences.pitch;
    }
  }

  Future<void> _refreshVoices() async {
    setState(() {
      _voiceStatus = null;
      _voices = widget.ttsService.voicesFor(widget.language, refresh: true);
    });
    await _voices;
    if (mounted) setState(() {});
  }

  Future<void> _preview() async {
    if (_previewing) return;
    setState(() {
      _previewing = true;
      _voiceStatus = '미리 듣는 중';
    });
    try {
      await widget.ttsService.speak(
        language: widget.language,
        text: _voicePreviewText(widget.language),
        rate: widget.ttsRate,
        preferOfflineVoice: widget.preferOfflineVoice,
        preferredVoiceId: preferences.voiceIdByLanguage[widget.language.code],
        pitch: preferences.pitch,
      );
      if (mounted) setState(() => _voiceStatus = '미리 듣기를 재생했습니다.');
    } catch (_) {
      if (mounted) {
        setState(() => _voiceStatus = '이 기기에서 음성을 재생하지 못했습니다.');
      }
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Widget _strengthPicker({
    required Key key,
    required String label,
    required DeviceFeedbackStrength value,
    required ValueChanged<DeviceFeedbackStrength> onChanged,
  }) {
    return DropdownButtonFormField<DeviceFeedbackStrength>(
      key: key,
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final strength in DeviceFeedbackStrength.values)
          DropdownMenuItem(
            value: strength,
            child: Text(_feedbackStrengthLabel(strength)),
          ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('device-feedback-preferences-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('기기별 음성·피드백', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Text('${widget.language.koreanName} 음성과 효과음·진동 세기는 이 기기에만 저장합니다.'),
            const SizedBox(height: 12),
            FutureBuilder<List<TtsVoice>>(
              future: _voices,
              builder: (context, snapshot) {
                final voices = snapshot.data ?? const <TtsVoice>[];
                final savedId =
                    preferences.voiceIdByLanguage[widget.language.code];
                final selectedId = voices.any((voice) => voice.id == savedId)
                    ? savedId
                    : null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            key: const Key('device-installed-voice'),
                            initialValue: selectedId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: '${widget.language.koreanName} 설치 음성',
                              helperText:
                                  snapshot.connectionState ==
                                      widgets.ConnectionState.waiting
                                  ? '설치된 음성을 확인하는 중입니다.'
                                  : voices.isEmpty
                                  ? '일치하는 설치 음성이 없어 시스템 기본값을 사용합니다.'
                                  : '${voices.length}개 설치 음성',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                child: Text('자동 선택'),
                              ),
                              for (final voice in voices)
                                DropdownMenuItem<String?>(
                                  value: voice.id,
                                  child: Text(
                                    '${voice.name} · ${voice.locale}'
                                    '${voice.networkRequired == false
                                        ? ' · 오프라인'
                                        : voice.networkRequired == true
                                        ? ' · 네트워크'
                                        : ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged:
                                snapshot.connectionState ==
                                    widgets.ConnectionState.waiting
                                ? null
                                : (value) => widget.onChanged(
                                    preferences.selectVoice(
                                      widget.language.code,
                                      value,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          key: const Key('refresh-installed-voices'),
                          tooltip: '설치 음성 새로 고침',
                          onPressed: _refreshVoices,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Text('음성 높낮이 ${_pitch.toStringAsFixed(2)}×'),
            Slider(
              key: const Key('device-voice-pitch'),
              value: _pitch,
              min: 0.5,
              max: 2,
              divisions: 15,
              label: _pitch.toStringAsFixed(2),
              semanticFormatterCallback: (value) =>
                  '음성 높낮이 ${value.toStringAsFixed(2)}배',
              onChanged: (value) => setState(() => _pitch = value),
              onChangeEnd: (value) =>
                  widget.onChanged(preferences.copyWith(pitch: value)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('preview-device-voice'),
                onPressed: _previewing ? null : _preview,
                icon: Icon(
                  _previewing
                      ? Icons.hourglass_top_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(_previewing ? '재생 중' : '현재 음성 미리 듣기'),
              ),
            ),
            if (_voiceStatus case final status?)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(status, key: const Key('device-voice-status')),
                ),
              ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final sound = _strengthPicker(
                  key: const Key('device-sound-strength'),
                  label: '효과음',
                  value: preferences.soundStrength,
                  onChanged: (value) => widget.onChanged(
                    preferences.copyWith(soundStrength: value),
                  ),
                );
                final haptic = _strengthPicker(
                  key: const Key('device-haptic-strength'),
                  label: '진동',
                  value: preferences.hapticStrength,
                  onChanged: (value) => widget.onChanged(
                    preferences.copyWith(hapticStrength: value),
                  ),
                );
                final stacked =
                    constraints.maxWidth < 440 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [sound, const SizedBox(height: 10), haptic],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: sound),
                    const SizedBox(width: 10),
                    Expanded(child: haptic),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _voicePreviewText(LanguageTag language) => switch (language) {
  LanguageTag.korean => '안녕하세요. 오늘도 함께 학습해요.',
  LanguageTag.english => 'Hello. Let us learn together today.',
  LanguageTag.japanese => 'こんにちは。今日も一緒に勉強しましょう。',
  LanguageTag.german => 'Hallo. Lernen wir heute gemeinsam.',
  LanguageTag.french => 'Bonjour. Apprenons ensemble aujourd’hui.',
  LanguageTag.spanish => 'Hola. Aprendamos juntos hoy.',
  LanguageTag.simplifiedChinese => '你好。今天我们一起学习吧。',
};

class _DevicePrivacyPreferencesCard extends StatelessWidget {
  const _DevicePrivacyPreferencesCard({
    required this.preferences,
    required this.hydrated,
    required this.onChanged,
  });

  final DevicePrivacyPreferences preferences;
  final bool hydrated;
  final ValueChanged<DevicePrivacyPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('device-privacy-preferences-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('사생활 보호 모드'),
              subtitle: const Text('원문·뜻·계정 식별자를 화면에서 가립니다.'),
              value: preferences.privacyMode,
              onChanged: hydrated
                  ? (value) =>
                        onChanged(preferences.copyWith(privacyMode: value))
                  : null,
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<PrivacyCurtainDelay>(
              key: const Key('privacy-curtain-delay'),
              initialValue: preferences.curtainDelay,
              decoration: const InputDecoration(labelText: '백그라운드 보호 커튼'),
              items: [
                for (final value in PrivacyCurtainDelay.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(_curtainDelayLabel(value)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onChanged(preferences.copyWith(curtainDelay: value));
                }
              },
            ),
            const SizedBox(height: 8),
            const Text(
              '보호 시간과 알림·음성 설정은 기기 전용이며 Drive 스냅샷에 포함되지 않습니다.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

String _minuteLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

String _dateTimeLabel(DateTime value) =>
    '${value.month}/${value.day} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _lockScreenLabel(NotificationLockScreenContent value) => switch (value) {
  NotificationLockScreenContent.hidden => '내용 숨김',
  NotificationLockScreenContent.generic => '일반 안내만',
  NotificationLockScreenContent.detailed => '학습 내용 표시',
};

String _feedbackStrengthLabel(DeviceFeedbackStrength value) => switch (value) {
  DeviceFeedbackStrength.off => '끔',
  DeviceFeedbackStrength.light => '약하게',
  DeviceFeedbackStrength.normal => '보통',
  DeviceFeedbackStrength.strong => '강하게',
};

String _curtainDelayLabel(PrivacyCurtainDelay value) => switch (value) {
  PrivacyCurtainDelay.disabled => '사용 안 함',
  PrivacyCurtainDelay.immediate => '즉시',
  PrivacyCurtainDelay.seconds15 => '15초 뒤',
  PrivacyCurtainDelay.seconds60 => '60초 뒤',
};

class _WindowsWorkspaceCard extends StatelessWidget {
  const _WindowsWorkspaceCard({
    required this.state,
    required this.onToggleCompact,
    required this.onToggleAlwaysOnTop,
    required this.onMinimize,
  });

  final WindowWorkspaceState state;
  final VoidCallback onToggleCompact;
  final VoidCallback onToggleAlwaysOnTop;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('windows-workspace-card'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const SizedBox.square(
                    dimension: 44,
                    child: Icon(Icons.space_dashboard_outlined),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.compact ? '집중 창 사용 중' : '기본 창 사용 중',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '집중 창은 420×640으로 전환됩니다. 크기는 전환 후에도 자유롭게 조절할 수 있습니다.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  key: const Key('settings-window-compact'),
                  onPressed: state.busy ? null : onToggleCompact,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(154, 48),
                  ),
                  icon: Icon(
                    state.compact
                        ? Icons.open_in_full_rounded
                        : Icons.picture_in_picture_alt_rounded,
                  ),
                  label: Text(state.compact ? '기본 창으로' : '집중 창으로'),
                ),
                OutlinedButton.icon(
                  key: const Key('settings-window-pin'),
                  onPressed: state.busy ? null : onToggleAlwaysOnTop,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(154, 48),
                  ),
                  icon: Icon(
                    state.alwaysOnTop
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                  ),
                  label: Text(state.alwaysOnTop ? '항상 위 해제' : '항상 위에 표시'),
                ),
                TextButton.icon(
                  key: const Key('settings-window-minimize'),
                  onPressed: state.busy ? null : onMinimize,
                  style: TextButton.styleFrom(minimumSize: const Size(130, 48)),
                  icon: const Icon(Icons.minimize_rounded),
                  label: const Text('최소화'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '단축키: Ctrl+Shift+F 집중 창 전환 · Ctrl+Shift+M 빠른 최소화',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                state.errorMessage!,
                style: TextStyle(
                  color: colors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LearningPreferencesCard extends StatelessWidget {
  const _LearningPreferencesCard({
    required this.preferences,
    required this.subjectName,
    required this.dailyXp,
    required this.dailyGoal,
    required this.accountTotalXp,
    required this.onDailyGoalChanged,
    required this.onChanged,
  });

  final StudyPreferences preferences;
  final String subjectName;
  final int dailyXp;
  final int dailyGoal;
  final int accountTotalXp;
  final ValueChanged<int> onDailyGoalChanged;
  final ValueChanged<StudyPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(mobile ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ControlHeader(
              icon: Icons.flag_rounded,
              title: '$subjectName 하루 목표',
              description: '이 주제 오늘 $dailyXp XP · 계정 누적 $accountTotalXp XP',
              color: AppTheme.warning,
              trailing: DropdownButton<int>(
                key: const Key('active-subject-daily-goal'),
                value: dailyGoal,
                isDense: true,
                iconSize: 20,
                underline: const SizedBox.shrink(),
                items: ({50, 100, 150, 200, dailyGoal}.toList()..sort())
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value XP'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    onDailyGoalChanged(value);
                  }
                },
              ),
            ),
            Divider(height: mobile ? 20 : 28),
            _ControlHeader(
              icon: Icons.timer_outlined,
              title: '한 세션 문제 수',
              description: '1~100 사이에서 기본 학습 분량을 직접 입력',
              color: Theme.of(context).colorScheme.primary,
              trailing: _SessionLimitEditor(
                value: preferences.sessionItemLimit,
                onChanged: (value) =>
                    onChanged(preferences.copyWith(sessionItemLimit: value)),
              ),
            ),
            Divider(height: mobile ? 20 : 28),
            _PreferenceSlider(
              label: '세션당 새 표현',
              description: '한 번 학습할 때 처음 보는 항목 수',
              valueLabel: '${preferences.newItemLimit}개',
              value: preferences.newItemLimit.toDouble(),
              min: 0,
              max: 30,
              divisions: 30,
              onChanged: (value) =>
                  onChanged(preferences.copyWith(newItemLimit: value.round())),
            ),
            SizedBox(height: mobile ? 8 : 12),
            _PreferenceSlider(
              label: '세션당 복습',
              description: '복습 시점이 된 항목의 최대 출제 수',
              valueLabel: '${preferences.reviewLimit}개',
              value: preferences.reviewLimit.toDouble(),
              min: 5,
              max: 100,
              divisions: 19,
              onChanged: (value) =>
                  onChanged(preferences.copyWith(reviewLimit: value.round())),
            ),
            SizedBox(height: mobile ? 8 : 12),
            _PreferenceSlider(
              label: '문장 비율',
              description: '혼합 학습에서 문장이 차지하는 비중',
              valueLabel: '${(preferences.sentenceRatio * 100).round()}%',
              value: preferences.sentenceRatio,
              min: 0,
              max: 1,
              divisions: 10,
              onChanged: (value) =>
                  onChanged(preferences.copyWith(sentenceRatio: value)),
            ),
            Divider(height: mobile ? 20 : 28),
            _ControlHeader(
              icon: Icons.school_rounded,
              title: '기본 시작 모드',
              description: '홈의 큰 학습 버튼에 적용',
              color: Theme.of(context).colorScheme.secondary,
              trailing: DropdownButton<StudyMode>(
                value: preferences.preferredMode,
                isDense: true,
                iconSize: 20,
                underline: const SizedBox.shrink(),
                items: StudyMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(mode.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    onChanged(preferences.copyWith(preferredMode: value));
                  }
                },
              ),
            ),
            Divider(height: mobile ? 20 : 28),
            const _ControlHeader(
              icon: Icons.offline_bolt_rounded,
              title: '오프라인 학습',
              description: '네트워크 없이 SQLite에 먼저 저장',
              color: AppTheme.success,
              trailing: Text(
                '항상 켜짐',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceSlider extends StatelessWidget {
  const _PreferenceSlider({
    required this.label,
    required this.description,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String description;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              valueLabel,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SessionLimitEditor extends StatefulWidget {
  const _SessionLimitEditor({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_SessionLimitEditor> createState() => _SessionLimitEditorState();
}

class _SessionLimitEditorState extends State<_SessionLimitEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _SessionLimitEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.value != oldWidget.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text.trim());
    final next = (parsed ?? widget.value).clamp(1, 100).toInt();
    _controller.text = '$next';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    if (next != widget.value) widget.onChanged(next);
  }

  void _step(int delta) {
    final next = (widget.value + delta).clamp(1, 100).toInt();
    _controller.text = '$next';
    if (next != widget.value) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '한 세션 문제 수 ${widget.value}개',
      child: SizedBox(
        width: 168,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              key: const Key('session-item-limit-decrease'),
              container: true,
              button: true,
              enabled: widget.value > 1,
              label: '문제 수 줄이기',
              onTap: widget.value > 1 ? () => _step(-1) : null,
              child: ExcludeSemantics(
                child: IconButton(
                  tooltip: '문제 수 줄이기',
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: widget.value > 1 ? () => _step(-1) : null,
                  icon: const Icon(Icons.remove_rounded, size: 18),
                ),
              ),
            ),
            SizedBox(
              width: 72,
              child: TextField(
                key: const Key('session-item-limit'),
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 9,
                  ),
                  suffixText: '개',
                ),
                onSubmitted: (_) => _commit(),
              ),
            ),
            Semantics(
              key: const Key('session-item-limit-increase'),
              container: true,
              button: true,
              enabled: widget.value < 100,
              label: '문제 수 늘리기',
              onTap: widget.value < 100 ? () => _step(1) : null,
              child: ExcludeSemantics(
                child: IconButton(
                  tooltip: '문제 수 늘리기',
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: widget.value < 100 ? () => _step(1) : null,
                  icon: const Icon(Icons.add_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlHeader extends StatelessWidget {
  const _ControlHeader({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final iconBox = DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(9),
      ),
      child: SizedBox.square(
        dimension: 36,
        child: Icon(icon, color: color, size: 19),
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  iconBox,
                  const SizedBox(width: 12),
                  Expanded(child: copy),
                ],
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: trailing),
            ],
          );
        }
        return Row(
          children: [
            iconBox,
            const SizedBox(width: 12),
            Expanded(child: copy),
            const SizedBox(width: 10),
            trailing,
          ],
        );
      },
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.mock});

  final bool mock;

  @override
  Widget build(BuildContext context) {
    final color = mock ? AppTheme.warning : AppTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            mock ? Icons.science_outlined : Icons.verified_user_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            mock ? 'Mock Mode' : '실서비스',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends ConsumerWidget {
  const _ConnectionCard({
    required this.diagnosticAnchorKey,
    required this.connected,
    required this.connection,
    required this.localStorage,
    required this.pendingSync,
    required this.mockMode,
    required this.onChooseLocalFolder,
    required this.onSaveLocalNow,
    required this.onRestoreLocal,
    required this.onClearLocalFolder,
    required this.onConnect,
    required this.onSync,
    required this.onDisconnect,
  });

  final GlobalKey diagnosticAnchorKey;
  final bool connected;
  final ConnectionState connection;
  final LocalStorageState localStorage;
  final PendingSyncOperation? pendingSync;
  final bool mockMode;
  final VoidCallback onChooseLocalFolder;
  final VoidCallback onSaveLocalNow;
  final VoidCallback onRestoreLocal;
  final VoidCallback onClearLocalFolder;
  final VoidCallback onConnect;
  final VoidCallback onSync;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPending = pendingSync != null;
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final canSync =
        !(connection.diagnostic?.reconnectRequired ?? false) &&
        (connection.phase == ConnectionPhase.connected ||
            (connection.phase == ConnectionPhase.failed &&
                connection.runtimeReady));
    final driveHealthy =
        connected && connection.phase != ConnectionPhase.failed && !hasPending;
    final localHealthy =
        !connected &&
        localStorage.configured &&
        localStorage.errorMessage == null &&
        !localStorage.existingArchiveAvailable;
    final healthy = connected ? driveHealthy : localHealthy;
    final statusColor = connected
        ? driveHealthy
              ? AppTheme.success
              : hasPending && connection.phase != ConnectionPhase.failed
              ? AppTheme.warning
              : connection.phase == ConnectionPhase.failed
              ? AppTheme.danger
              : AppTheme.desktopPrimary
        : localStorage.errorMessage != null
        ? AppTheme.danger
        : localStorage.existingArchiveAvailable
        ? AppTheme.warning
        : localStorage.configured
        ? AppTheme.success
        : AppTheme.warning;
    final statusLabel = connected
        ? switch (connection.phase) {
            ConnectionPhase.connecting ||
            ConnectionPhase.syncing => connection.stage?.badgeLabel ?? '처리 중',
            ConnectionPhase.disconnecting => '연결 해제 중',
            ConnectionPhase.failed => '확인 필요',
            ConnectionPhase.connected => hasPending ? '업로드 대기' : '연결됨',
            ConnectionPhase.disconnected => '연결 기록 있음',
          }
        : !localStorage.initialized
        ? '확인 중'
        : localStorage.busy
        ? '저장 중'
        : localStorage.errorMessage != null
        ? '권한 확인'
        : localStorage.existingArchiveAvailable
        ? '선택 필요'
        : localStorage.configured
        ? '자동 저장'
        : '폴더 필요';

    return Card(
      key: const Key('connection-card'),
      child: Padding(
        padding: EdgeInsets.all(mobile ? 13 : 22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;
            final veryNarrow = constraints.maxWidth < 300;
            final icon = DecoratedBox(
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SizedBox.square(
                dimension: mobile
                    ? 40
                    : compact
                    ? 46
                    : 58,
                child: Icon(
                  connected
                      ? healthy
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_queue_rounded
                      : localStorage.configured
                      ? Icons.folder_copy_rounded
                      : Icons.create_new_folder_outlined,
                  color: statusColor,
                  size: mobile
                      ? 21
                      : compact
                      ? 23
                      : 28,
                ),
              ),
            );
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (compact) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          connected
                              ? 'Drive 백업'
                              : localStorage.configured
                              ? '로컬 보관'
                              : '저장 위치 설정',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ConnectionStatus(label: statusLabel, color: statusColor),
                    ],
                  ),
                ] else
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          connected
                              ? 'Google Drive 백업 및 기기 간 이어하기'
                              : localStorage.configured
                              ? '로컬 보관 폴더에 자동 저장'
                              : '로컬 보관 폴더를 선택하세요',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: 9),
                      _ConnectionStatus(label: statusLabel, color: statusColor),
                    ],
                  ),
                const SizedBox(height: 6),
                Text(
                  connected
                      ? mobile
                            ? '${connection.folderName ?? 'WordStudyData'} · '
                                  '${connection.lastSyncedAt == null ? '첫 동기화 대기' : '${_formatTime(connection.lastSyncedAt!)} 동기화'}'
                            : '${connection.folderName ?? 'WordStudyData'} 폴더 · '
                                  '${connection.lastSyncedAt == null ? '첫 동기화 대기' : '마지막 ${_formatTime(connection.lastSyncedAt!)}'}'
                      : mockMode
                      ? 'Mock 연결로 계정 없이 전체 동기화 흐름을 시험할 수 있습니다.'
                      : localStorage.configured
                      ? '${localStorage.settings.displayName} · '
                            '${localStorage.settings.lastSavedAt == null ? '첫 저장 준비' : '마지막 ${_formatTime(localStorage.settings.lastSavedAt!)}'}'
                      : 'Google에 연결하지 않을 때 사용할 폴더를 먼저 선택해 주세요.',
                  maxLines: mobile
                      ? veryNarrow
                            ? 2
                            : 1
                      : null,
                  overflow: mobile ? TextOverflow.ellipsis : null,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (!connected) ...[
                  const SizedBox(height: 10),
                  _LocalFolderStatusPanel(
                    state: localStorage,
                    compact: mobile,
                    onChooseFolder: onChooseLocalFolder,
                    onRestore: onRestoreLocal,
                    onClear: onClearLocalFolder,
                  ),
                ] else if (localStorage.configured) ...[
                  const SizedBox(height: 9),
                  Text(
                    '로컬 폴더 ${localStorage.settings.displayName}은(는) '
                    'Drive 연결 해제 시 다시 사용할 대기 위치로 유지됩니다.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (connected && localStorage.pendingImportCount > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '이전 버전의 임시 원본 ${localStorage.pendingImportCount}개가 기기 내부에 남아 있습니다. Drive에는 업로드하지 않습니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (connection.busy && connection.stage != null) ...[
                  const SizedBox(height: 10),
                  _ConnectionProgressPanel(
                    stage: connection.stage!,
                    isWindows: isWindows,
                  ),
                ] else if (isWindows && !connected && !mockMode) ...[
                  const SizedBox(height: 10),
                  const _WindowsLoopbackNote(),
                ],
                if (connection.diagnostic case final diagnostic?) ...[
                  const SizedBox(height: 9),
                  KeyedSubtree(
                    key: diagnosticAnchorKey,
                    child: _ConnectionErrorPanel(
                      diagnostic: diagnostic,
                      onRetry: canSync ? onSync : onConnect,
                    ),
                  ),
                ],
                if (pendingSync case final pending?) ...[
                  const SizedBox(height: 9),
                  Container(
                    key: const Key('pending-sync-status'),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_upload_outlined,
                          color: AppTheme.warning,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pending.attempts == 0
                                ? '로컬 변경을 안전하게 보관했습니다. 연결되면 Drive에 반영합니다.'
                                : '동기화 재시도 ${pending.attempts}회 · '
                                      '${_formatTime(pending.nextAttemptAt.toLocal())} 이후 자동 재시도',
                            style: const TextStyle(
                              color: AppTheme.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (connection.lastMergeReport case final report?) ...[
                  const SizedBox(height: 9),
                  _SyncMergeReportPanel(report: report, compact: mobile),
                ],
                if (connected) ...[
                  const SizedBox(height: 7),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('open-sync-center'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => const _SyncCenterDialog(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.manage_history_rounded, size: 18),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                '${connection.policy.mode.label} 동기화 · '
                                '${connection.history.isEmpty ? '상세 보기' : '이력 ${connection.history.length}건'}',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
            Widget primaryAction() {
              if (!connected) {
                return FilledButton.icon(
                  key: Key(
                    localStorage.configured
                        ? 'save-local-now'
                        : 'choose-local-folder',
                  ),
                  onPressed: localStorage.busy
                      ? null
                      : localStorage.configured
                      ? onSaveLocalNow
                      : onChooseLocalFolder,
                  icon: localStorage.busy
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          localStorage.configured
                              ? Icons.save_rounded
                              : Icons.create_new_folder_rounded,
                        ),
                  label: Text(localStorage.configured ? '지금 저장' : '폴더 선택'),
                );
              }
              if (canSync) {
                return FilledButton.icon(
                  key: const Key('sync-now'),
                  onPressed: connection.busy || connection.policy.offlineLock
                      ? null
                      : onSync,
                  icon: connection.phase == ConnectionPhase.syncing
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: const Text('지금 동기화'),
                );
              }
              return FilledButton.icon(
                key: const Key('connect-google'),
                onPressed: connection.busy || connection.policy.offlineLock
                    ? null
                    : onConnect,
                icon: connection.phase == ConnectionPhase.connecting
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_to_drive_rounded),
                label: const Text('Google 다시 연결'),
              );
            }

            Widget secondaryAction() {
              if (!connected) {
                return OutlinedButton.icon(
                  key: const Key('connect-google'),
                  onPressed: connection.busy || connection.policy.offlineLock
                      ? null
                      : onConnect,
                  icon: const Icon(Icons.add_to_drive_rounded),
                  label: Text(mockMode ? 'Mock 연결' : 'Google 연결'),
                );
              }
              return TextButton(
                onPressed: connection.busy || connection.policy.offlineLock
                    ? null
                    : onDisconnect,
                child: const Text('이 기기에서 연결 해제'),
              );
            }

            final actions = mobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      primaryAction(),
                      const SizedBox(height: 8),
                      secondaryAction(),
                    ],
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [primaryAction(), secondaryAction()],
                  );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      icon,
                      const SizedBox(width: 11),
                      Expanded(child: copy),
                    ],
                  ),
                  const SizedBox(height: 12),
                  actions,
                ],
              );
            }
            return Row(
              children: [
                icon,
                const SizedBox(width: 16),
                Expanded(child: copy),
                const SizedBox(width: 20),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SyncPolicyPanel extends StatelessWidget {
  const _SyncPolicyPanel({required this.policy, required this.onChanged});

  final SyncPolicy policy;
  final ValueChanged<SyncPolicy> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '자동 동기화 정책',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final mode in SyncMode.values)
                ChoiceChip(
                  key: Key('sync-policy-${mode.name}'),
                  label: Text(mode.label),
                  selected: policy.mode == mode,
                  onSelected: (_) => onChanged(policy.copyWith(mode: mode)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              key: const Key('complete-offline-lock'),
              contentPadding: EdgeInsets.zero,
              value: policy.offlineLock,
              onChanged: (value) =>
                  onChanged(policy.copyWith(offlineLock: value)),
              title: const Text('완전 오프라인 잠금'),
              subtitle: Text(
                policy.offlineLock
                    ? '잠금 해제 전까지 연결·복원·수동/자동 Drive 요청을 모두 막습니다.'
                    : '필요할 때 기기 밖 네트워크 요청을 명시적으로 잠글 수 있습니다.',
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            policy.mode == SyncMode.manual
                ? '변경 사항은 대기열에 보관됩니다. “지금 동기화”는 언제든 사용할 수 있습니다.'
                : policy.mode == SyncMode.wifiOnly
                ? 'Wi-Fi가 아닐 때 자동 전송만 미룹니다. 수동 동기화는 항상 가능합니다.'
                : 'Drive 연결 중 변경 사항을 자동으로 반영합니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SyncCenterDialog extends ConsumerWidget {
  const _SyncCenterDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionControllerProvider);
    final controller = ref.read(connectionControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.sync_alt_rounded),
          const SizedBox(width: 9),
          const Expanded(child: Text('동기화 이력·충돌 복구')),
          _ConnectionStatus(
            label: connection.displayStatus.label,
            color: switch (connection.displayStatus) {
              SyncDisplayStatus.completed => AppTheme.success,
              SyncDisplayStatus.waiting => AppTheme.warning,
              SyncDisplayStatus.syncing => colors.primary,
              SyncDisplayStatus.error => AppTheme.danger,
              SyncDisplayStatus.localSaved => colors.onSurfaceVariant,
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.68,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                '학습 자료는 이 기기와 연결된 Drive 사이에서만 비교합니다. Railway에는 계정·Drive 연결 정보만 저장됩니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _SyncPolicyPanel(
                policy: connection.policy,
                onChanged: controller.setPolicy,
              ),
              if (connection.lastComparison.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  '최근 로컬·Drive 비교 ${connection.lastComparison.length}건',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 7),
                for (final comparison in connection.lastComparison)
                  Card(
                    margin: const EdgeInsets.only(bottom: 7),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      title: Text(
                        '${_syncSectionLabel(comparison.section)} · ${comparison.recordId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        comparison.selection == null
                            ? '자동 병합 결과 사용'
                            : '${comparison.selection == SyncVersionSelection.local ? '이 기기' : 'Drive'} 버전 선택',
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [
                        _SyncVersionPreview(
                          title: '이 기기',
                          exists: comparison.localExists,
                          preview: comparison.localPreview,
                        ),
                        const SizedBox(height: 6),
                        _SyncVersionPreview(
                          title: 'Drive',
                          exists: comparison.driveExists,
                          preview: comparison.drivePreview,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            ChoiceChip(
                              label: const Text('이 기기 적용'),
                              selected:
                                  comparison.selection ==
                                  SyncVersionSelection.local,
                              onSelected: (_) => controller.selectSyncVersion(
                                comparison.key,
                                SyncVersionSelection.local,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Drive 적용'),
                              selected:
                                  comparison.selection ==
                                  SyncVersionSelection.drive,
                              onSelected: (_) => controller.selectSyncVersion(
                                comparison.key,
                                SyncVersionSelection.drive,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    FilledButton.icon(
                      key: const Key('apply-sync-selections'),
                      onPressed:
                          connection.selections.isEmpty ||
                              connection.busy ||
                              connection.policy.offlineLock
                          ? null
                          : controller.applySelectedVersions,
                      icon: const Icon(Icons.merge_rounded),
                      label: Text('선택 ${connection.selections.length}건 적용'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: connection.selections.isEmpty
                          ? null
                          : controller.clearSyncVersionSelections,
                      child: const Text('선택 해제'),
                    ),
                  ],
                ),
              ],
              if (connection.recoveryAvailable) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.restore_rounded,
                        color: AppTheme.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '직전 병합 이전으로 복구 가능',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '복구 전 현재 상태는 다시 복구 지점으로 남기지 않습니다. Drive 연결 중이면 복구 결과도 즉시 반영됩니다.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        key: const Key('restore-last-sync-merge'),
                        onPressed:
                            connection.busy || connection.policy.offlineLock
                            ? null
                            : controller.restoreLastMerge,
                        child: const Text('복구'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '기기 이력 ${connection.history.length}건',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: connection.history.isEmpty
                        ? null
                        : controller.clearSyncHistory,
                    child: const Text('이력 비우기'),
                  ),
                ],
              ),
              if (connection.history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('아직 이 기기의 동기화 이력이 없습니다.'),
                )
              else
                for (final entry in connection.history)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      switch (entry.status) {
                        SyncHistoryStatus.success => Icons.check_circle_outline,
                        SyncHistoryStatus.failed => Icons.error_outline,
                        SyncHistoryStatus.skipped => Icons.schedule_rounded,
                      },
                      color: switch (entry.status) {
                        SyncHistoryStatus.success => AppTheme.success,
                        SyncHistoryStatus.failed => AppTheme.danger,
                        SyncHistoryStatus.skipped => AppTheme.warning,
                      },
                    ),
                    title: Text(entry.summary),
                    subtitle: Text(
                      '${_formatTime(entry.endedAt.toLocal())}'
                      '${entry.changeCount == 0 ? '' : ' · 변경 ${entry.changeCount}건'}'
                      '${entry.diagnosticCode == null ? '' : ' · ${entry.diagnosticCode}'}',
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          key: const Key('copy-sync-diagnostics'),
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(text: controller.exportSyncDiagnostics()),
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('동기화 진단 JSON을 복사했습니다.')),
            );
          },
          icon: const Icon(Icons.copy_all_rounded),
          label: const Text('진단 JSON 복사'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _SyncVersionPreview extends StatelessWidget {
  const _SyncVersionPreview({
    required this.title,
    required this.exists,
    required this.preview,
  });

  final String title;
  final bool exists;
  final String preview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$title · ${exists ? preview : '없음'}',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

String _syncSectionLabel(String section) => switch (section) {
  'progress' => '학습 진도',
  'content' => '개인 자료',
  'settings' => '설정·일정',
  'profile' => 'XP·배지',
  'recentSessions' => '최근 학습',
  'activeSession' => '진행 중 세션',
  _ => section,
};

class _LocalFolderStatusPanel extends StatelessWidget {
  const _LocalFolderStatusPanel({
    required this.state,
    required this.compact,
    required this.onChooseFolder,
    required this.onRestore,
    required this.onClear,
  });

  final LocalStorageState state;
  final bool compact;
  final VoidCallback onChooseFolder;
  final VoidCallback onRestore;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final configured = state.configured;
    final hasError = state.errorMessage != null;
    final accent = hasError
        ? AppTheme.danger
        : state.existingArchiveAvailable
        ? AppTheme.warning
        : configured
        ? AppTheme.success
        : AppTheme.warning;
    final locationDetail =
        state.settings.locationKind ==
            LocalStorageLocationKind.androidDocumentTree
        ? 'Android 문서 폴더 · 재실행 후에도 권한 유지'
        : state.settings.locationId;

    return Semantics(
      liveRegion: hasError || state.busy,
      label: hasError
          ? '로컬 보관 폴더 오류. ${state.errorMessage}'
          : configured
          ? '로컬 보관 폴더 연결됨. ${state.settings.displayName}'
          : '로컬 보관 폴더 선택 필요',
      child: Container(
        key: const Key('local-folder-status'),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasError
                      ? Icons.folder_off_outlined
                      : configured
                      ? Icons.folder_copy_outlined
                      : Icons.info_outline_rounded,
                  color: accent,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasError
                            ? state.errorMessage!
                            : state.existingArchiveAvailable
                            ? '기존 저장본을 확인한 뒤 병합 또는 교체를 선택하세요.'
                            : configured
                            ? state.driveConnected
                                  ? '${state.settings.displayName}는 Drive 연결 해제 시 자동 복귀할 대기 위치입니다.'
                                  : '${state.settings.displayName}에 자동 보관합니다.'
                            : '앱 전용 DB에는 계속 저장됩니다. 폴더를 고르면 검증된 휴대용 사본도 자동 관리합니다.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: hasError ? AppTheme.danger : null,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (configured && locationDetail != null) ...[
                        const SizedBox(height: 3),
                        Tooltip(
                          message: locationDetail,
                          child: Text(
                            locationDetail,
                            maxLines: compact ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                      if (state.pendingImportCount > 0) ...[
                        const SizedBox(height: 3),
                        Text(
                          '이전 버전의 임시 원본 ${state.pendingImportCount}개가 기기 내부에 남아 있으며 '
                          '새 동기화에는 사용하지 않습니다.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.warning),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (configured) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    key: const Key('change-local-folder'),
                    onPressed: state.busy ? null : onChooseFolder,
                    icon: const Icon(Icons.drive_file_move_outline, size: 18),
                    label: const Text('폴더 변경'),
                  ),
                  TextButton.icon(
                    key: const Key('restore-local-backup'),
                    onPressed: state.busy ? null : onRestore,
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: const Text('저장본 복원'),
                  ),
                  TextButton(
                    key: const Key('clear-local-folder'),
                    onPressed: state.busy ? null : onClear,
                    child: const Text('연결 해제'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectionProgressPanel extends StatelessWidget {
  const _ConnectionProgressPanel({
    required this.stage,
    required this.isWindows,
  });

  final GoogleConnectionStage stage;
  final bool isWindows;

  @override
  Widget build(BuildContext context) {
    final description = switch (stage) {
      GoogleConnectionStage.checkingConnection =>
        'Railway HTTPS API와 Windows OAuth 중계 설정을 먼저 확인합니다. '
            '준비되지 않았으면 Google 로그인 창을 열지 않고 해결 방법을 안내합니다.',
      GoogleConnectionStage.signIn =>
        isWindows
            ? '기본 브라우저에서 Google 계정을 선택하고 동의를 완료하세요. '
                  '브라우저 창을 닫지 말고 다음 단계까지 진행해 주세요.'
            : 'Google 계정을 선택하고 로그인 동의를 완료하세요.',
      GoogleConnectionStage.folderSelection =>
        '이어지는 Google Picker에서 Sprache 데이터를 보관할 Drive 폴더를 '
            '선택하고 확인하세요.',
      GoogleConnectionStage.preparingDrive =>
        '선택한 폴더 ID를 확인하고 Sprache 전용 저장 구조를 안전하게 준비합니다.',
      GoogleConnectionStage.linkingAccount =>
        'Railway에는 학습 내용이 아니라 계정 키와 Drive 폴더 ID 연결만 저장합니다.',
      GoogleConnectionStage.pulling =>
        'Drive manifest와 snapshot의 revision·SHA-256을 확인하고 있습니다.',
      GoogleConnectionStage.merging => '정상 로컬 데이터를 유지하면서 양쪽 변경과 삭제 기록을 병합합니다.',
      GoogleConnectionStage.pushing => '검증과 병합이 끝난 변경 사항을 Drive에 업로드하고 있습니다.',
    };
    return Container(
      key: const Key('google-connection-progress'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.desktopPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.desktopPrimary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  stage.label,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(description),
          if (isWindows &&
              (stage == GoogleConnectionStage.signIn ||
                  stage == GoogleConnectionStage.folderSelection)) ...[
            const SizedBox(height: 8),
            const Text(
              '주소에 127.0.0.1이 보여도 정상입니다. 로그인 결과를 같은 PC의 '
              'Sprache로 돌려주는 임시 주소이며 공용 서버는 Railway HTTPS입니다.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _WindowsLoopbackNote extends StatelessWidget {
  const _WindowsLoopbackNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('windows-loopback-note'),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 19),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Windows 로그인 중 보이는 127.0.0.1은 임시 회신 주소입니다. '
              'Android·Windows 공용 서버는 Railway HTTPS이므로 '
              'Cloudflare Tunnel은 필요하지 않습니다.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionErrorPanel extends StatelessWidget {
  const _ConnectionErrorPanel({
    required this.diagnostic,
    required this.onRetry,
  });

  final ConnectionDiagnostic diagnostic;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('connection-diagnostic'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppTheme.danger,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  diagnostic.message,
                  style: const TextStyle(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                label: '오류 진단 코드 ${diagnostic.code}',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    diagnostic.code,
                    key: const Key('connection-diagnostic-code'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('copy-connection-diagnostic'),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: diagnostic.clipboardText),
                  );
                  if (!context.mounted) return;
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.removeCurrentSnackBar();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('오류 진단 내용을 복사했습니다.')),
                  );
                },
                icon: const Icon(Icons.copy_all_rounded, size: 18),
                label: const Text('진단 복사'),
              ),
              if (diagnostic.retryable)
                FilledButton.tonalIcon(
                  key: const Key('retry-connection-error'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('다시 시도'),
                ),
            ],
          ),
          if (diagnostic.recoverySteps.isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              key: const Key('connection-recovery-steps'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '지금 할 일',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  for (
                    var index = 0;
                    index < diagnostic.recoverySteps.length;
                    index += 1
                  )
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '${index + 1}. ${diagnostic.recoverySteps[index]}',
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (diagnostic.quarantine case final quarantine?) ...[
            const SizedBox(height: 9),
            Container(
              key: const Key('remote-quarantine-preview'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '원격 파일 격리 완료',
                    style: TextStyle(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    quarantine.fileName,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '안전 미리보기 · ${quarantine.preview}',
                    key: const Key('remote-quarantine-safe-preview'),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '내용 원문은 화면이나 진단 코드에 노출하지 않습니다.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
          if (diagnostic.detail case final detail?) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _SyncMergeReportPanel extends StatelessWidget {
  const _SyncMergeReportPanel({required this.report, required this.compact});

  final SyncMergeReport report;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final conflictColor = report.conflictCount > 0
        ? AppTheme.warning
        : AppTheme.success;
    return Material(
      key: const Key('sync-merge-report'),
      color: conflictColor.withValues(alpha: 0.07),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: conflictColor.withValues(alpha: 0.2)),
      ),
      child: ExpansionTile(
        key: const Key('sync-conflict-review'),
        initiallyExpanded: report.conflictCount > 0 && !compact,
        tilePadding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16),
        visualDensity: compact
            ? const VisualDensity(horizontal: -2, vertical: -3)
            : VisualDensity.standard,
        leading: Icon(
          report.conflictCount > 0
              ? Icons.rule_folder_outlined
              : Icons.fact_check_outlined,
          color: conflictColor,
          size: compact ? 20 : 24,
        ),
        title: Text(
          report.isEmpty ? '변경 없음' : '마지막 동기화',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 14 : null,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          report.isEmpty
              ? '이 기기와 Drive 데이터가 같습니다.'
              : compact
              ? '↑ ${report.uploadCount} · ↓ ${report.downloadCount} · 검토 ${report.conflictCount}'
              : '업로드 ${report.uploadCount} · 다운로드 ${report.downloadCount} · '
                    '충돌 검토 ${report.conflictCount}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: EdgeInsets.fromLTRB(
          compact ? 9 : 12,
          0,
          compact ? 9 : 12,
          compact ? 9 : 12,
        ),
        children: [
          if (report.changes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('추가로 확인할 변경이 없습니다.'),
            )
          else
            for (final change in report.changes.take(20))
              Container(
                margin: const EdgeInsets.only(top: 7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _syncDecisionIcon(change.decision),
                      size: 18,
                      color: change.decision.isConflict
                          ? AppTheme.warning
                          : colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${change.section.label} · ${_syncRecordLabel(change)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            change.decision.label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          if (report.changes.length > 20)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                '그 외 ${report.changes.length - 20}개 변경은 같은 규칙으로 병합했습니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

IconData _syncDecisionIcon(SyncMergeDecision decision) => switch (decision) {
  SyncMergeDecision.uploadLocal => Icons.cloud_upload_outlined,
  SyncMergeDecision.downloadRemote => Icons.cloud_download_outlined,
  SyncMergeDecision.keepLocal => Icons.computer_rounded,
  SyncMergeDecision.useRemote => Icons.cloud_done_outlined,
  SyncMergeDecision.merge => Icons.merge_rounded,
};

String _syncRecordLabel(SyncMergeChange change) => switch (change.recordId) {
  'settings' => '전체 설정',
  'profile' => '계정 통계',
  'activeStudy' => '이어하기 상태',
  _ => change.recordId,
};

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SettingsSearchPanel extends StatelessWidget {
  const _SettingsSearchPanel({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onResetAll,
    required this.onJumpStorage,
    required this.onJumpDisplay,
    required this.onJumpLearning,
    required this.onJumpPrivacy,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onResetAll;
  final VoidCallback onJumpStorage;
  final VoidCallback onJumpDisplay;
  final VoidCallback onJumpLearning;
  final VoidCallback onJumpPrivacy;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('settings-search-panel'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('settings-search-field'),
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '설정 검색 · 예: 테마, 문제 수, Drive',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.trim().isEmpty
                    ? null
                    : IconButton(
                        key: const Key('clear-settings-search'),
                        tooltip: '검색어 지우기',
                        onPressed: onClear,
                        icon: const Icon(Icons.close_rounded),
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (query.trim().isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '바로 이동',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _SettingsJumpButton(
                    label: '저장',
                    icon: Icons.cloud_outlined,
                    onPressed: onJumpStorage,
                  ),
                  _SettingsJumpButton(
                    label: '화면·편의',
                    icon: Icons.palette_outlined,
                    onPressed: onJumpDisplay,
                  ),
                  _SettingsJumpButton(
                    label: '학습 분량',
                    icon: Icons.school_outlined,
                    onPressed: onJumpLearning,
                  ),
                  _SettingsJumpButton(
                    label: '개인정보',
                    icon: Icons.shield_outlined,
                    onPressed: onJumpPrivacy,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const Key('reset-all-settings'),
                  onPressed: onResetAll,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('편의 설정 전체 초기화'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsJumpButton extends StatelessWidget {
  const _SettingsJumpButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 44),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _SettingsEmptySearch extends StatelessWidget {
  const _SettingsEmptySearch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('settings-search-empty'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 32),
            const SizedBox(height: 8),
            Text(
              '“${query.trim()}”에 맞는 설정이 없습니다.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '테마, 문제 수, Drive처럼 짧은 단어로 다시 검색해 보세요.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.caption,
    this.onReset,
    this.resetKey,
    super.key,
  });

  final String title;
  final String caption;
  final VoidCallback? onReset;
  final Key? resetKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (caption.isNotEmpty)
                Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        if (onReset != null)
          IconButton(
            key: resetKey,
            tooltip: '$title 초기화',
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: SizedBox.square(
              dimension: 38,
              child: Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.onOpenDetails,
    required this.privacyPolicyUrl,
    required this.connected,
    required this.onDeleteAccountBinding,
  });

  final VoidCallback onOpenDetails;
  final String privacyPolicyUrl;
  final bool connected;
  final VoidCallback onDeleteAccountBinding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const _PrivacyRow(
              icon: Icons.folder_outlined,
              title: 'Drive 접근 범위',
              detail: '사용자가 선택한 Sprache 폴더만 접근',
            ),
            const SizedBox(height: 14),
            const _PrivacyRow(
              icon: Icons.fingerprint_rounded,
              title: 'Railway API',
              detail: 'HMAC 처리된 계정 키와 폴더 연결만 저장',
            ),
            const SizedBox(height: 14),
            const _PrivacyRow(
              icon: Icons.key_rounded,
              title: '로그인 토큰',
              detail: '운영체제 보안 저장소에만 보관',
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '단어·문장·학습 기록은 Railway 데이터베이스에 복사하지 않습니다.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('open-privacy-details'),
                onPressed: onOpenDetails,
                icon: const Icon(Icons.policy_outlined),
                label: const Text('개인정보 처리 안내 자세히 보기'),
              ),
            ),
            if (privacyPolicyUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('open-privacy-web'),
                onPressed: () => _openPrivacyPolicy(context, privacyPolicyUrl),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('웹 개인정보처리방침 열기'),
              ),
            ],
            const SizedBox(height: 6),
            TextButton.icon(
              key: const Key('delete-google-account-binding'),
              onPressed: onDeleteAccountBinding,
              icon: const Icon(Icons.link_off_rounded),
              label: Text(
                connected ? '계정–Drive 연결 기록 삭제' : 'Railway 연결 기록 확인·삭제',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openPrivacyPolicy(BuildContext context, String rawUrl) async {
  final uri = Uri.tryParse(rawUrl);
  final isSafeUrl =
      uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
  if (!isSafeUrl ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('개인정보처리방침 페이지를 열 수 없습니다.')));
  }
}

Future<void> _showPrivacyDetails(
  BuildContext context, {
  required String appVersion,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('privacy-details-dialog'),
      title: const Text('Sprache 개인정보 처리 안내'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('시행일 2026년 7월 30일 · 앱 버전 $appVersion'),
              const SizedBox(height: 18),
              const _PrivacyDetailSection(
                title: '기기와 Drive에 저장하는 정보',
                body:
                    '직접 만든 단어·문장·예문, 그룹, 일정, 진도, XP, 최근 세션과 '
                    '설정은 먼저 이 기기의 로컬 데이터베이스에 저장됩니다. Google '
                    '연결을 선택하면 같은 자료의 검증된 snapshot을 사용자가 고른 '
                    'Drive 폴더에 저장합니다.',
              ),
              const _PrivacyDetailSection(
                title: 'Google 계정과 Drive 사용',
                body:
                    '로그인에는 Google 계정의 기본 프로필 범위를, 동기화에는 '
                    'drive.file 범위만 요청합니다. Sprache가 만들거나 사용자가 '
                    '선택해 연결한 앱 파일만 다루며 다른 Drive 문서를 읽지 않습니다.',
              ),
              const _PrivacyDetailSection(
                title: 'Railway에 저장하는 정보',
                body:
                    'Railway PostgreSQL에는 Google 계정 식별자를 서버 비밀값으로 '
                    'HMAC 처리한 키와 Drive 폴더 ID·표시 이름·스키마 버전만 저장합니다. '
                    '이메일, 프로필, 학습 내용, 답안, 상세 진도와 OAuth 토큰은 '
                    'Railway 데이터베이스에 저장하지 않습니다.',
              ),
              const _PrivacyDetailSection(
                title: '발음 연습',
                body:
                    '마이크 입력은 운영체제의 음성 인식 기능이 처리합니다. Sprache는 '
                    '오디오나 인식 문장을 Drive 또는 Railway에 저장하지 않고, 해당 '
                    '항목의 성공·재연습 결과만 일반 학습 진도로 기록합니다.',
              ),
              const _PrivacyDetailSection(
                title: '공유·판매',
                body:
                    '광고나 데이터 판매를 하지 않습니다. 기능 제공에 필요한 Google '
                    '인증·Drive, Railway 호스팅, 운영체제 음성 인식 외의 목적으로 '
                    'Google 사용자 데이터를 제3자에게 이전하지 않습니다.',
              ),
              const _PrivacyDetailSection(
                title: '삭제와 연결 해제',
                body:
                    '이 기기에서 연결 해제를 실행하면 이 기기의 Google 토큰만 삭제하고 '
                    'Railway의 계정–폴더 연결은 유지합니다. 개인정보 카드의 별도 '
                    '연결 기록 삭제를 실행하면 Google 계정 확인 후 Railway 연결 기록도 '
                    '삭제합니다. 로컬 학습 자료와 Drive 파일은 자동 삭제하지 않으며, '
                    'Drive 폴더와 기기 앱 데이터는 사용자가 직접 삭제할 수 있습니다.',
              ),
              const _PrivacyDetailSection(
                title: '문의',
                body:
                    '정책과 데이터 처리 문의: '
                    'github.com/youkdonghun/Sprache/issues',
                last: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

class _PrivacyDetailSection extends StatelessWidget {
  const _PrivacyDetailSection({
    required this.title,
    required this.body,
    this.last = false,
  });

  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 5),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _BackupDataCard extends StatelessWidget {
  const _BackupDataCard({
    required this.customItemCount,
    required this.recentSessionCount,
    required this.onExportBackup,
    required this.onRestoreBackup,
    required this.onExportSettings,
    required this.onImportSettings,
    required this.onExportXlsx,
    required this.onExportCsv,
  });

  final int customItemCount;
  final int recentSessionCount;
  final VoidCallback onExportBackup;
  final VoidCallback onRestoreBackup;
  final VoidCallback onExportSettings;
  final VoidCallback onImportSettings;
  final VoidCallback onExportXlsx;
  final VoidCallback onExportCsv;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('backup-data-card'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const SizedBox.square(
                    dimension: 42,
                    child: Icon(Icons.inventory_2_outlined),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '로컬 백업과 복원',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '개인 콘텐츠 $customItemCount개 · 최근 세션 $recentSessionCount개',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'JSON은 설정·진도·개인 콘텐츠·세션을 함께 보관합니다. Excel은 개인 콘텐츠를 표로 편집한 뒤 다시 가져올 수 있습니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  key: const Key('export-backup-json'),
                  onPressed: onExportBackup,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('JSON 백업'),
                ),
                OutlinedButton.icon(
                  key: const Key('restore-backup-json'),
                  onPressed: onRestoreBackup,
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('JSON 복원'),
                ),
                OutlinedButton.icon(
                  key: const Key('export-settings-json'),
                  onPressed: onExportSettings,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('설정만 내보내기'),
                ),
                OutlinedButton.icon(
                  key: const Key('import-settings-json'),
                  onPressed: onImportSettings,
                  icon: const Icon(Icons.settings_backup_restore_rounded),
                  label: const Text('설정만 가져오기'),
                ),
                OutlinedButton.icon(
                  key: const Key('export-content-xlsx'),
                  onPressed: onExportXlsx,
                  icon: const Icon(Icons.grid_on_rounded),
                  label: const Text('개인 콘텐츠 Excel'),
                ),
                OutlinedButton.icon(
                  key: const Key('export-content-csv'),
                  onPressed: onExportCsv,
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('CSV 호환본'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageMaintenanceCard extends StatelessWidget {
  const _StorageMaintenanceCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('storage-maintenance-card'),
      child: ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: const Text(
          '저장 공간 관리',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('30일 지난 복구 사본과 미참조 Drive 파일을 확인 후 직접 정리'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onOpen,
      ),
    );
  }
}

class _BackupRestoreDialog extends StatefulWidget {
  const _BackupRestoreDialog({
    required this.archive,
    required this.fileName,
    required this.previewBuilder,
  });

  final BackupArchive archive;
  final String fileName;
  final BackupRestorePreview Function(BackupRestoreSelection selection)
  previewBuilder;

  @override
  State<_BackupRestoreDialog> createState() => _BackupRestoreDialogState();
}

class _BackupRestoreDialogState extends State<_BackupRestoreDialog> {
  BackupRestoreSelection _selection = const BackupRestoreSelection();

  void _toggle(BackupRestoreCategory category, bool value) {
    setState(() {
      _selection = switch (category) {
        BackupRestoreCategory.content => _selection.copyWith(content: value),
        BackupRestoreCategory.progress => _selection.copyWith(progress: value),
        BackupRestoreCategory.sessions => _selection.copyWith(sessions: value),
        BackupRestoreCategory.settings => _selection.copyWith(settings: value),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.previewBuilder(_selection);
    final total = preview.total;
    return AlertDialog(
      title: const Text('검증된 백업을 복원할까요?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(widget.archive.selectedLanguage.koreanName)),
                  Chip(label: Text('XP ${widget.archive.totalXp}')),
                  Chip(label: Text('개인 콘텐츠 ${widget.archive.customItemCount}')),
                  Chip(label: Text('진도 ${widget.archive.progressCount}')),
                  Chip(label: Text('세션 ${widget.archive.sessions.length}')),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '복원 범주 선택',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              for (final category in BackupRestoreCategory.values)
                CheckboxListTile(
                  key: Key('restore-category-${category.name}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _selection.includes(category),
                  onChanged: (value) => _toggle(category, value ?? false),
                  title: Text(category.label),
                  subtitle: Text(
                    _restoreDeltaLabel(
                      preview.byCategory[category] ??
                          const BackupRestoreDelta(),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Container(
                key: const Key('backup-restore-preview'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '적용 미리보기 · 추가 ${total.added} · 변경 ${total.changed} · '
                  '그대로 유지 ${total.preserved}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '현재 로컬 데이터를 지우지 않고 선택한 범주만 항목별 최신값으로 병합합니다. 손상되거나 지원하지 않는 값은 복원 전에 차단됩니다.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton.icon(
          key: const Key('confirm-backup-restore'),
          onPressed: _selection.any
              ? () => Navigator.of(context).pop(_selection)
              : null,
          icon: const Icon(Icons.restore_rounded),
          label: const Text('선택 범주 병합'),
        ),
      ],
    );
  }
}

String _restoreDeltaLabel(BackupRestoreDelta value) =>
    '추가 ${value.added} · 변경 ${value.changed} · 유지 ${value.preserved}';

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 21),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const Icon(Icons.check_rounded, color: AppTheme.success, size: 19),
      ],
    );
  }
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}/${local.day} $hour:$minute';
}

String _dateStamp(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
