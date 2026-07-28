import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/study_preferences.dart';
import '../services/window_workspace_service.dart';
import '../state/app_state.dart';
import '../state/connection_state.dart';
import '../sync/pending_sync.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final connection = ref.watch(connectionControllerProvider);
    final config = ref.watch(appConfigProvider);
    final connected = state.driveConnected;
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final windowWorkspace = ref.watch(windowWorkspaceControllerProvider);

    ref.listen(connectionControllerProvider, (previous, next) {
      if (next.phase == ConnectionPhase.failed &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? 'Google 연결에 실패했습니다.')),
        );
      }
    });

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
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
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '저장 위치와 학습 환경을 확인합니다.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      _ModePill(mock: config.mockMode),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _ConnectionCard(
                    connected: connected,
                    connection: connection,
                    pendingSync: state.pendingSync,
                    mockMode: config.mockMode,
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
                  const SizedBox(height: 20),
                  const _SectionLabel(title: '학습 환경', caption: '현재 적용 중인 기본값'),
                  const SizedBox(height: 10),
                  _LearningPreferencesCard(
                    preferences: state.preferences,
                    dailyXp: state.dailyXp,
                    onChanged: ref
                        .read(appControllerProvider.notifier)
                        .updatePreferences,
                  ),
                  if (isWindows) ...[
                    const SizedBox(height: 20),
                    const _SectionLabel(
                      title: 'Windows 창 도구',
                      caption: '작게 두고 공부하거나 필요할 때 즉시 최소화',
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
                  const SizedBox(height: 20),
                  const _SectionLabel(
                    title: '데이터와 개인정보',
                    caption: '연결 전에 저장 범위를 확인하세요',
                  ),
                  const SizedBox(height: 10),
                  const _PrivacyCard(),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _exportJson(context, ref),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('내 학습 데이터 JSON으로 내보내기'),
                  ),
                  const SizedBox(height: 20),
                  const _SectionLabel(title: '앱 정보', caption: ''),
                  const SizedBox(height: 10),
                  Card(
                    child: Column(
                      children: [
                        _SettingRow(
                          icon: Icons.translate_rounded,
                          title: 'Sprache',
                          subtitle: '한국어 기반 6개 언어 반복학습',
                          trailing: '1.10.0',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const Divider(),
                        _SettingRow(
                          icon: Icons.devices_rounded,
                          title: '현재 플랫폼',
                          subtitle:
                              defaultTargetPlatform == TargetPlatform.windows
                              ? 'Windows x64 · 크기 조절 지원'
                              : 'Android · 모바일 학습 모드',
                          trailing: config.appEnvironment,
                          color: AppTheme.desktopPrimary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    try {
      final archive = ref.read(appControllerProvider.notifier).exportArchive();
      final content = const JsonEncoder.withIndent('  ').convert(archive);
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Sprache 학습 데이터 저장',
        fileName: 'sprache-backup-$date.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(content)),
        lockParentWindow: true,
      );
      if (!context.mounted || path == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('백업을 저장했습니다: $path')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('백업 저장에 실패했습니다: $error')));
    }
  }
}

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
    required this.dailyXp,
    required this.onChanged,
  });

  final StudyPreferences preferences;
  final int dailyXp;
  final ValueChanged<StudyPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ControlHeader(
              icon: Icons.flag_rounded,
              title: '하루 목표',
              description: '오늘 $dailyXp XP 달성',
              color: AppTheme.warning,
              trailing: DropdownButton<int>(
                value: preferences.dailyGoal,
                underline: const SizedBox.shrink(),
                items:
                    ({50, 100, 150, 200, preferences.dailyGoal}.toList()
                          ..sort())
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value XP'),
                          ),
                        )
                        .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    onChanged(preferences.copyWith(dailyGoal: value));
                  }
                },
              ),
            ),
            const Divider(height: 28),
            _ControlHeader(
              icon: Icons.timer_outlined,
              title: '한 세션 문제 수',
              description: '부담 없이 끝낼 수 있는 학습 분량',
              color: AppTheme.desktopPrimary,
              trailing: DropdownButton<int>(
                key: const Key('session-item-limit'),
                value: preferences.sessionItemLimit,
                underline: const SizedBox.shrink(),
                items:
                    ({5, 10, 15, 20, 30, preferences.sessionItemLimit}.toList()
                          ..sort())
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value문제'),
                          ),
                        )
                        .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    onChanged(preferences.copyWith(sessionItemLimit: value));
                  }
                },
              ),
            ),
            const Divider(height: 28),
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
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
            const Divider(height: 28),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: preferences.showReadingAids,
              title: const Text('읽기 보조 표시'),
              subtitle: const Text('일본어 로마자와 중국어 병음을 문제에 표시'),
              secondary: const Icon(Icons.record_voice_over_rounded),
              onChanged: (value) =>
                  onChanged(preferences.copyWith(showReadingAids: value)),
            ),
            const SizedBox(height: 8),
            _PreferenceSlider(
              label: '듣기 속도',
              description: 'TTS 발음을 느리거나 빠르게 조절',
              valueLabel: '${(preferences.ttsRate * 100).round()}%',
              value: preferences.ttsRate,
              min: 0.2,
              max: 0.8,
              divisions: 6,
              onChanged: (value) =>
                  onChanged(preferences.copyWith(ttsRate: value)),
            ),
            const Divider(height: 28),
            _ControlHeader(
              icon: Icons.school_rounded,
              title: '기본 시작 모드',
              description: '홈의 큰 학습 버튼에 적용',
              color: AppTheme.desktopAccent,
              trailing: DropdownButton<StudyMode>(
                value: preferences.preferredMode,
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
            const Divider(height: 28),
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
        dimension: 38,
        child: Icon(icon, color: color, size: 20),
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
        if (constraints.maxWidth < 520) {
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

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connected,
    required this.connection,
    required this.pendingSync,
    required this.mockMode,
    required this.onConnect,
    required this.onSync,
    required this.onDisconnect,
  });

  final bool connected;
  final ConnectionState connection;
  final PendingSyncOperation? pendingSync;
  final bool mockMode;
  final VoidCallback onConnect;
  final VoidCallback onSync;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingSync != null;
    final canSync =
        connection.phase == ConnectionPhase.connected ||
        (connection.phase == ConnectionPhase.failed && connected);
    final healthy =
        connected && connection.phase != ConnectionPhase.failed && !hasPending;
    final statusColor = healthy
        ? AppTheme.success
        : hasPending && connection.phase != ConnectionPhase.failed
        ? AppTheme.warning
        : connection.phase == ConnectionPhase.failed
        ? AppTheme.danger
        : AppTheme.desktopPrimary;
    final statusLabel = switch (connection.phase) {
      ConnectionPhase.connecting => '연결 중',
      ConnectionPhase.syncing => '동기화 중',
      ConnectionPhase.disconnecting => '연결 해제 중',
      ConnectionPhase.failed => '확인 필요',
      ConnectionPhase.connected => hasPending ? '업로드 대기' : '연결됨',
      ConnectionPhase.disconnected => connected ? '연결 기록 있음' : '로컬 저장',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;
            final icon = DecoratedBox(
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SizedBox.square(
                dimension: 58,
                child: Icon(
                  healthy
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_queue_rounded,
                  color: statusColor,
                  size: 28,
                ),
              ),
            );
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        connected
                            ? 'Google Drive 백업 및 기기 간 이어하기'
                            : '현재 이 장치에 저장 중',
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
                      ? '${connection.folderName ?? 'WordStudyData'} 폴더 · '
                            '${connection.lastSyncedAt == null ? '첫 동기화 대기' : '마지막 ${_formatTime(connection.lastSyncedAt!)}'}'
                      : mockMode
                      ? 'Mock 연결로 계정 없이 전체 동기화 흐름을 시험할 수 있습니다.'
                      : '계정 로그인 후 학습 기록과 중단한 세션을 선택한 Drive 폴더에 저장합니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (connection.errorMessage != null) ...[
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppTheme.danger,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            connection.errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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
              ],
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (canSync)
                  FilledButton.icon(
                    onPressed: connection.busy ? null : onSync,
                    icon: connection.phase == ConnectionPhase.syncing
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: const Text('지금 동기화'),
                  )
                else
                  FilledButton.icon(
                    onPressed: connection.busy ? null : onConnect,
                    icon: connection.phase == ConnectionPhase.connecting
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_to_drive_rounded),
                    label: Text(
                      connected
                          ? 'Google 다시 연결'
                          : mockMode
                          ? 'Mock 연결'
                          : 'Google 연결',
                    ),
                  ),
                if (canSync)
                  TextButton(
                    onPressed: connection.busy ? null : onDisconnect,
                    child: const Text('연결 해제'),
                  ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      icon,
                      const SizedBox(width: 14),
                      Expanded(child: copy),
                    ],
                  ),
                  const SizedBox(height: 18),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.caption});

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (caption.isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
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
  const _PrivacyCard();

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
          ],
        ),
      ),
    );
  }
}

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
