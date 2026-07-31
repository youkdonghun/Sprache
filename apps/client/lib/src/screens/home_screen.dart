import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/active_study_session.dart';
import '../domain/language.dart';
import '../domain/onboarding_profile.dart';
import '../domain/progress.dart';
import '../domain/session_enhancements.dart';
import '../domain/smart_collection.dart';
import '../domain/study_limits.dart';
import '../domain/study_preferences.dart';
import '../services/window_workspace_service.dart';
import '../services/app_clock.dart';
import '../state/app_state.dart';
import '../state/app_state_view.dart';
import '../state/connection_state.dart';
import '../state/local_storage_state.dart';
import '../theme/app_theme.dart';
import '../widgets/learning_data_flow_card.dart';
import '../widgets/quick_content_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final localStorage = ref.watch(localStorageControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final activeSubject = controller.activeSubject;
    final activeSession =
        state.activeStudySession?.courseId == state.activeCourseId
        ? state.activeStudySession
        : null;
    final activeSessionSubject = activeSession == null
        ? null
        : controller.availableSubjects.firstWhere(
            (subject) => subject.courseId == activeSession.courseId,
            orElse: () => activeSubject,
          );
    final now = ref.watch(appClockProvider)();
    final calendarDay = ref.watch(calendarDayProvider);
    final coursePath = controller.coursePath;
    final recommendedUnit = coursePath.recommendedUnit;
    final queue = controller.queue(now);
    final selectedItems = controller.selectedItems;
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final windowWorkspace = ref.watch(windowWorkspaceControllerProvider);
    if (isWindows) {
      ref.listen(windowWorkspaceControllerProvider, (previous, next) {
        if (next.errorMessage != null &&
            next.errorMessage != previous?.errorMessage) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
        }
      });
    }
    final forecast = controller.reviewForecast(now);
    final reviewCount = forecast.dueNow;
    final newCount = min(
      state.preferences.newItemLimit,
      selectedItems
          .where(
            (item) =>
                state.progress[item.id] == null ||
                state.progress[item.id]!.status == LearningStatus.newItem,
          )
          .length,
    );
    final weakCount = state.progress.values.where((progress) {
      return progress.attempts > 0 &&
          progress.accuracy < 0.7 &&
          selectedItems.any((item) => item.id == progress.itemId);
    }).length;
    final scheduledPlans = controller.activeSubjectScheduledSessionPlans;
    final primaryScheduledPlan =
        activeSession == null && reviewCount == 0 && scheduledPlans.isNotEmpty
        ? scheduledPlans.first
        : null;
    final secondaryScheduledPlans = primaryScheduledPlan == null
        ? scheduledPlans
        : scheduledPlans.skip(1).toList(growable: false);
    final localCopyCount = state.customItems
        .where((item) => item.effectiveSubjectId == activeSubject.id)
        .length;
    final groupCount = controller.availableLearningGroups.length;
    final pinnedCollections = controller.smartCollections
        .where((collection) => collection.pinned)
        .toList(growable: false);
    final recommendedRoute =
        state.preferences.preferredMode == StudyMode.pronunciation
        ? '/pronunciation'
        : '/study?mode=${state.preferences.preferredMode.name}';
    late final _HomeNextAction nextAction;
    if (selectedItems.isEmpty) {
      nextAction = _HomeNextAction(
        eyebrow: '${activeSubject.name} · 학습 준비',
        title: '첫 학습 자료를 추가해 보세요',
        description: '단어·문장 또는 원하는 개념을 하나 추가하면 바로 학습을 시작할 수 있어요.',
        buttonLabel: '첫 자료 추가',
        icon: Icons.add_rounded,
        onPressed: () => context.go('/library/new'),
      );
    } else if (reviewCount > 0) {
      nextAction = _HomeNextAction(
        eyebrow: '${activeSubject.name} · 다음 학습',
        title: '복습할 표현 $reviewCount개',
        description: '기억이 흐려지기 전에 예정된 복습부터 짧게 끝내세요.',
        buttonLabel: '복습 시작',
        icon: Icons.replay_rounded,
        onPressed: () => context.push('/study?mode=review'),
      );
    } else if (primaryScheduledPlan case final plan?) {
      nextAction = _HomeNextAction(
        eyebrow: '${activeSubject.name} · 예약한 다음 학습',
        title: plan.title,
        description:
            '${_homeScheduleLabel(plan.scheduledAt!, now)} · '
            '${plan.mode.label} ${plan.itemLimit}문제',
        buttonLabel: '일정 열기',
        icon: Icons.event_available_rounded,
        onPressed: () {
          final loaded = controller.useSavedSessionPlan(plan);
          if (loaded != null) {
            context.push('/session-builder');
          }
        },
      );
    } else {
      final unitTitle = activeSubject.isLanguage
          ? 'Unit ${recommendedUnit.index + 1} · ${recommendedUnit.title}'
          : '${activeSubject.name} · 자료 ${selectedItems.length}개';
      nextAction = _HomeNextAction(
        eyebrow: '${activeSubject.name} · 다음 학습',
        title: queue.isEmpty ? '오늘 목표를 마쳤어요' : unitTitle,
        description: queue.isEmpty
            ? '${state.preferences.preferredMode.label}로 가볍게 더 연습할 수 있어요.'
            : '${state.preferences.preferredMode.label} · 새 표현 $newCount개',
        buttonLabel: isWindows ? '다음 학습' : '다음 레슨',
        icon: Icons.play_arrow_rounded,
        onPressed: () => context.push(recommendedRoute),
      );
    }

    void resumeActiveSession() {
      final subject = activeSessionSubject;
      if (subject == null) return;
      controller.selectSubject(subject.id);
      context.push('/study?resume=true');
    }

    void discardActiveSession() {
      final session = activeSession;
      if (session == null) return;
      controller.clearActiveStudySession(expectedSessionId: session.sessionId);
      if (state.driveConnected) {
        unawaited(
          ref.read(connectionControllerProvider.notifier).syncAutomatically(),
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('중단한 세션을 종료했습니다. 학습 진도는 유지됩니다.')),
      );
    }

    void completeScheduledPlan(StudySessionPlan plan) {
      controller.completeExamPlanForToday(plan.planId, completedAt: now);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오늘 학습을 완료로 기록했어요.')));
    }

    void snoozeScheduledPlan(StudySessionPlan plan) {
      controller.snoozeSessionPlan(plan.planId, now: now);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('학습 일정을 10분 미뤘어요.')));
    }

    void deferScheduledPlan(StudySessionPlan plan) {
      controller.deferSessionPlanUntilTomorrow(plan.planId, now: now);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('학습 일정을 내일로 옮겼어요.')));
    }

    Future<void> changeScheduledPlanTime(StudySessionPlan plan) async {
      final local = plan.scheduledAt?.toLocal() ?? now.toLocal();
      final selected = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(local),
        helpText: '매일 학습할 시간',
      );
      if (selected == null || !context.mounted) return;
      controller.changeSessionPlanTime(
        plan.planId,
        minuteOfDay: selected.hour * 60 + selected.minute,
        now: now,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('학습 시간을 ${selected.format(context)}로 바꿨어요.')),
      );
    }

    void openPinnedCollection(SmartCollectionDefinition collection) {
      final collectionItems = controller.itemsForSmartCollection(collection);
      if (collectionItems.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('현재 조건에 맞는 자료가 없습니다.')));
        return;
      }
      controller.updateSessionPlan(
        controller.activeSessionPlan.copyWith(
          planId: '',
          subjectId: activeSubject.id,
          title: collection.name,
          deck: StudyDeckScope.selected,
          difficulty: StudyDifficulty.all,
          historyFilter: StudyHistoryFilter.all,
          groupIds: {},
          tags: {},
          levels: {},
          selectedItemIds: collectionItems.map((item) => item.id).toSet(),
          includeWords: true,
          includeSentences: true,
          itemLimit: collectionItems.length.clamp(
            StudyLimits.minSessionItems,
            StudyLimits.maxSessionItems,
          ),
          lengthMode: StudySessionLengthMode.itemCount,
          scheduledAt: null,
        ),
      );
      context.push('/session-builder');
    }

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final officeCompact = isWindows && constraints.maxWidth < 560;
          final mobile = constraints.maxWidth < 720;
          final wide = constraints.maxWidth >= 1020;
          final padding = officeCompact
              ? 14.0
              : mobile
              ? 16.0
              : 28.0;
          Widget primaryStudyCard({required bool compact}) {
            final active = activeSession;
            if (active != null && activeSessionSubject != null) {
              return _ResumeSessionCard(
                session: active,
                cloudConnected: state.driveConnected,
                subjectName: activeSessionSubject.name,
                subjectSymbol: activeSessionSubject.symbol,
                onResume: resumeActiveSession,
                onDiscard: discardActiveSession,
              );
            }
            return _DailyHero(
              compact: compact,
              action: nextAction,
              dailyXp: state.activeCourseDailyXpAt(calendarDay),
              dailyGoal: state.dailyGoal,
              level: state.level,
              accountTotalXp: state.totalXp,
            );
          }

          Widget primaryStudyArea({required bool compact}) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                primaryStudyCard(compact: compact),
                if (primaryScheduledPlan case final plan?) ...[
                  const SizedBox(height: 8),
                  _ScheduleQuickActions(
                    plan: plan,
                    onComplete: () => completeScheduledPlan(plan),
                    onSnooze: () => snoozeScheduledPlan(plan),
                    onDefer: () => deferScheduledPlan(plan),
                    onChangeTime: () => changeScheduledPlanTime(plan),
                  ),
                ],
              ],
            );
          }

          return CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  padding,
                  officeCompact
                      ? 14
                      : mobile
                      ? 16
                      : 22,
                  padding,
                  mobile ? 24 : 32,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HomeHeader(
                            compact: officeCompact,
                            now: now,
                            subjectName: activeSubject.name,
                            subjectSymbol: activeSubject.symbol,
                            generalTopic: !activeSubject.isLanguage,
                            subtitle: activeSubject.isLanguage
                                ? activeSubject.contentLanguage.nativeName
                                : '나만의 학습 주제',
                            streakDays: state.streakDays,
                            connected: state.driveConnected,
                            windowWorkspace: isWindows ? windowWorkspace : null,
                            onToggleCompact: isWindows
                                ? () => unawaited(
                                    ref
                                        .read(
                                          windowWorkspaceControllerProvider
                                              .notifier,
                                        )
                                        .toggleCompact(),
                                  )
                                : null,
                            onMinimize: isWindows
                                ? () => unawaited(
                                    ref
                                        .read(
                                          windowWorkspaceControllerProvider
                                              .notifier,
                                        )
                                        .minimize(),
                                  )
                                : null,
                            onSettings: () => context.go('/settings'),
                          ),
                          if (!state.preferences.onboardingCompleted) ...[
                            SizedBox(height: officeCompact ? 12 : 16),
                            _GettingStartedCard(
                              compact: officeCompact || mobile,
                              language: state.selectedLanguage,
                              dailyGoal: state.dailyGoal,
                              onPressed: () => _showFirstRunSetup(
                                context: context,
                                language: state.selectedLanguage,
                                dailyGoal: state.dailyGoal,
                                onComplete: (selection) {
                                  controller.completeOnboarding(
                                    language: selection.language,
                                    dailyGoal: selection.dailyGoal,
                                  );
                                  final completed = ref.read(
                                    appControllerProvider,
                                  );
                                  controller.updatePreferences(
                                    completed.preferences.copyWith(
                                      preferredMode: selection.preferredMode,
                                      newItemLimit: selection.newItemLimit,
                                      sessionItemLimit:
                                          selection.sessionItemLimit,
                                      onboardingProfile:
                                          selection.onboardingProfile,
                                    ),
                                  );
                                  if (selection.entry ==
                                      _FirstRunEntry.importData) {
                                    context.push('/import');
                                  } else {
                                    context.push(
                                      '/study?mode=${selection.preferredMode.name}',
                                    );
                                  }
                                },
                              ),
                              onDismiss: () => controller.updatePreferences(
                                state.preferences.copyWith(
                                  onboardingCompleted: true,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(
                            height: officeCompact
                                ? 14
                                : mobile
                                ? 14
                                : 20,
                          ),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: primaryStudyArea(compact: false),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 4,
                                  child: _TodayPlan(
                                    reviewCount: reviewCount,
                                    newCount: newCount,
                                    weakCount: weakCount,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            primaryStudyArea(compact: officeCompact || mobile),
                            SizedBox(height: officeCompact ? 12 : 16),
                            _TodayPlan(
                              compact: officeCompact || mobile,
                              reviewCount: reviewCount,
                              newCount: newCount,
                              weakCount: weakCount,
                            ),
                          ],
                          if (pinnedCollections.isNotEmpty) ...[
                            SizedBox(height: mobile ? 12 : 16),
                            _HomePinnedCollections(
                              collections: pinnedCollections,
                              itemCountFor: (collection) => controller
                                  .itemsForSmartCollection(collection)
                                  .length,
                              onOpen: openPinnedCollection,
                              onManage: () => context.go('/library'),
                            ),
                          ],
                          if (!officeCompact) ...[
                            SizedBox(height: mobile ? 12 : 16),
                            LearningDataFlowCard(
                              totalCount: selectedItems.length,
                              localCopyCount: localCopyCount,
                              groupCount: groupCount,
                              driveConnected: state.driveConnected,
                              currentStep: selectedItems.isEmpty
                                  ? LearningDataStep.add
                                  : localCopyCount > 0 && groupCount == 0
                                  ? LearningDataStep.organize
                                  : LearningDataStep.learn,
                              onAdd: () => unawaited(
                                showQuickContentSheet(context: context),
                              ),
                              onOrganize: () => context.go('/library/groups'),
                              onLearn: () => context.go('/learn'),
                              localFolderConfigured: localStorage.configured,
                              localFolderName:
                                  localStorage.settings.displayName,
                              onManageStorage: () => context.go('/settings'),
                              syncLabel: state.driveConnected
                                  ? 'Drive 연결됨'
                                  : localStorage.configured
                                  ? '로컬 · ${localStorage.settings.displayName}'
                                  : '로컬 폴더 선택 필요',
                            ),
                          ],
                          if (localStorage.requiresSetup ||
                              localStorage.errorMessage != null) ...[
                            SizedBox(height: mobile ? 10 : 14),
                            _LocalStoragePromptCard(
                              compact: officeCompact || mobile,
                              errorMessage: localStorage.errorMessage,
                              onPressed: () => context.go('/settings'),
                            ),
                          ],
                          if (secondaryScheduledPlans.isNotEmpty) ...[
                            SizedBox(height: officeCompact ? 12 : 16),
                            _ScheduledPlansCard(
                              plans: secondaryScheduledPlans,
                              now: now,
                              compact: officeCompact || mobile,
                              onOpen: (plan) {
                                final loaded = controller.useSavedSessionPlan(
                                  plan,
                                );
                                if (loaded != null) {
                                  context.push('/session-builder');
                                }
                              },
                              onManage: () => context.push('/session-builder'),
                              onComplete: completeScheduledPlan,
                              onSnooze: snoozeScheduledPlan,
                              onDefer: deferScheduledPlan,
                              onChangeTime: changeScheduledPlanTime,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HomePinnedCollections extends StatelessWidget {
  const _HomePinnedCollections({
    required this.collections,
    required this.itemCountFor,
    required this.onOpen,
    required this.onManage,
  });

  final List<SmartCollectionDefinition> collections;
  final int Function(SmartCollectionDefinition) itemCountFor;
  final ValueChanged<SmartCollectionDefinition> onOpen;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('home-pinned-collections'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.push_pin_rounded, size: 19, color: colors.primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '고정 컬렉션',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('manage-home-pinned-collections'),
                  onPressed: onManage,
                  child: const Text('자료실에서 관리'),
                ),
              ],
            ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: collections.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final collection = collections[index];
                  final count = itemCountFor(collection);
                  return ActionChip(
                    key: Key('home-pinned-collection-${collection.id}'),
                    avatar: const Icon(Icons.bolt_rounded, size: 18),
                    label: Text('${collection.name} · $count개'),
                    tooltip: count == 0
                        ? '현재 조건에 맞는 자료 없음'
                        : '${collection.name} 바로 학습',
                    onPressed: count == 0 ? null : () => onOpen(collection),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalStoragePromptCard extends StatelessWidget {
  const _LocalStoragePromptCard({
    required this.compact,
    required this.errorMessage,
    required this.onPressed,
  });

  final bool compact;
  final String? errorMessage;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null;
    final accent = hasError ? AppTheme.danger : AppTheme.warning;
    return Material(
      key: const Key('local-storage-setup-prompt'),
      color: accent.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 11 : 14),
        side: BorderSide(color: accent.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.all(compact ? 11 : 14),
          child: Row(
            children: [
              Icon(
                hasError
                    ? Icons.folder_off_outlined
                    : Icons.create_new_folder_outlined,
                color: accent,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasError ? '로컬 보관 폴더를 다시 연결하세요' : '학습 데이터 보관 폴더를 선택하세요',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasError
                          ? errorMessage!
                          : 'Google 미연결 상태에서는 선택한 폴더에 검증된 사본을 자동 저장합니다.',
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onPressed,
                child: Text(hasError ? '다시 연결' : '폴더 선택'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showFirstRunSetup({
  required BuildContext context,
  required LanguageTag language,
  required int dailyGoal,
  required ValueChanged<_FirstRunSelection> onComplete,
}) async {
  final mobile =
      defaultTargetPlatform != TargetPlatform.windows ||
      MediaQuery.sizeOf(context).width < 720;

  if (mobile) {
    final selection = await showModalBottomSheet<_FirstRunSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: _FirstRunSetupPanel(
          language: language,
          dailyGoal: dailyGoal,
          onComplete: (selection) => Navigator.of(sheetContext).pop(selection),
        ),
      ),
    );
    if (selection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          onComplete(selection);
        }
      });
    }
    return;
  }

  final selection = await showDialog<_FirstRunSelection>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: _FirstRunSetupPanel(
          language: language,
          dailyGoal: dailyGoal,
          onComplete: (selection) => Navigator.of(dialogContext).pop(selection),
        ),
      ),
    ),
  );
  if (selection != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        onComplete(selection);
      }
    });
  }
}

enum _FirstRunPurpose { routine, conversation, vocabulary, exam }

enum _FirstRunLevel { beginner, intermediate, advanced }

enum _FirstRunEntry { sample, importData }

extension on _FirstRunPurpose {
  String get label => switch (this) {
    _FirstRunPurpose.routine => '매일 꾸준히',
    _FirstRunPurpose.conversation => '회화·여행',
    _FirstRunPurpose.vocabulary => '단어 확장',
    _FirstRunPurpose.exam => '시험 대비',
  };

  IconData get icon => switch (this) {
    _FirstRunPurpose.routine => Icons.calendar_today_rounded,
    _FirstRunPurpose.conversation => Icons.forum_rounded,
    _FirstRunPurpose.vocabulary => Icons.auto_stories_rounded,
    _FirstRunPurpose.exam => Icons.fact_check_rounded,
  };

  StudyMode get mode => switch (this) {
    _FirstRunPurpose.routine => StudyMode.mixed,
    _FirstRunPurpose.conversation => StudyMode.sentences,
    _FirstRunPurpose.vocabulary => StudyMode.words,
    _FirstRunPurpose.exam => StudyMode.review,
  };
}

extension on _FirstRunLevel {
  String get label => switch (this) {
    _FirstRunLevel.beginner => '처음',
    _FirstRunLevel.intermediate => '기초 경험 있음',
    _FirstRunLevel.advanced => '중급 이상',
  };

  int get newItemLimit => switch (this) {
    _FirstRunLevel.beginner => 10,
    _FirstRunLevel.intermediate => 8,
    _FirstRunLevel.advanced => 5,
  };
}

class _FirstRunSelection {
  const _FirstRunSelection({
    required this.language,
    required this.dailyGoal,
    required this.purpose,
    required this.level,
    required this.entry,
  });

  final LanguageTag language;
  final int dailyGoal;
  final _FirstRunPurpose purpose;
  final _FirstRunLevel level;
  final _FirstRunEntry entry;

  StudyMode get preferredMode => purpose.mode;
  int get newItemLimit => level.newItemLimit;
  int get sessionItemLimit => switch (dailyGoal) {
    <= 50 => 5,
    <= 100 => 10,
    <= 150 => 15,
    _ => 20,
  };

  OnboardingProfile get onboardingProfile => OnboardingProfile(
    purpose: switch (purpose) {
      _FirstRunPurpose.routine => LearningPurpose.dailyConversation,
      _FirstRunPurpose.conversation => LearningPurpose.travel,
      _FirstRunPurpose.vocabulary => LearningPurpose.hobby,
      _FirstRunPurpose.exam => LearningPurpose.exam,
    },
    level: switch (level) {
      _FirstRunLevel.beginner => SelfAssessedLevel.beginner,
      _FirstRunLevel.intermediate => SelfAssessedLevel.elementary,
      _FirstRunLevel.advanced => SelfAssessedLevel.advanced,
    },
    dailyMinutes: switch (dailyGoal) {
      <= 50 => 3,
      <= 100 => 5,
      <= 150 => 10,
      _ => 15,
    },
    entryChoice: switch (entry) {
      _FirstRunEntry.sample => OnboardingEntryChoice.sampleLesson,
      _FirstRunEntry.importData => OnboardingEntryChoice.importMyData,
    },
  );
}

class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard({
    required this.compact,
    required this.language,
    required this.dailyGoal,
    required this.onPressed,
    required this.onDismiss,
  });

  final bool compact;
  final LanguageTag language;
  final int dailyGoal;
  final VoidCallback onPressed;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final veryNarrow = width < 360;
    final compactSummary = width < 480;
    final content = [
      if (!veryNarrow) ...[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.rocket_launch_rounded, color: colors.primary),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              veryNarrow
                  ? '첫 학습 루틴'
                  : compact
                  ? '첫 학습 루틴 설정'
                  : '내 학습 루틴을 1분 안에 설정해 보세요',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              compactSummary
                  ? '${language.koreanName} · $dailyGoal XP · 바로 시작'
                  : compact
                  ? '${language.koreanName} · 하루 $dailyGoal XP · 로그인 없이 시작'
                  : '${language.koreanName} · 하루 $dailyGoal XP · 로그인 없이 바로 체험',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ];

    return Material(
      key: const Key('first-run-setup-card'),
      color: colors.primaryContainer.withValues(alpha: 0.34),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
        side: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 16,
            compact ? 10 : 13,
            compact ? 8 : 10,
            compact ? 10 : 13,
          ),
          child: Row(
            children: [
              ...content,
              const SizedBox(width: 8),
              if (compact)
                IconButton.filledTonal(
                  key: const Key('open-first-run-setup'),
                  tooltip: '시작 설정',
                  onPressed: onPressed,
                  icon: const Icon(Icons.arrow_forward_rounded),
                )
              else
                FilledButton.tonal(
                  key: const Key('open-first-run-setup'),
                  onPressed: onPressed,
                  child: const Text('시작 설정'),
                ),
              IconButton(
                key: const Key('dismiss-first-run-setup'),
                tooltip: '나중에 설정',
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstRunSetupPanel extends StatefulWidget {
  const _FirstRunSetupPanel({
    required this.language,
    required this.dailyGoal,
    required this.onComplete,
  });

  final LanguageTag language;
  final int dailyGoal;
  final ValueChanged<_FirstRunSelection> onComplete;

  @override
  State<_FirstRunSetupPanel> createState() => _FirstRunSetupPanelState();
}

class _FirstRunSetupPanelState extends State<_FirstRunSetupPanel> {
  late LanguageTag _language = widget.language;
  late int _dailyGoal = widget.dailyGoal;
  _FirstRunPurpose _purpose = _FirstRunPurpose.routine;
  _FirstRunLevel _level = _FirstRunLevel.beginner;

  static const _dailyGoals = [50, 100, 150, 200];

  void _complete(_FirstRunEntry entry) {
    widget.onComplete(
      _FirstRunSelection(
        language: _language,
        dailyGoal: _dailyGoal,
        purpose: _purpose,
        level: _level,
        entry: entry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      key: const Key('first-run-setup-panel'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sprache 시작 설정', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text(
                      '5가지만 고르면 로그인 없이 내 학습 루틴을 바로 시작합니다.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '닫기',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _OnboardingStepHeader(
            step: 1,
            title: '공부할 언어',
            description: '언어별 자료와 진도는 서로 섞이지 않습니다.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final language in LanguageTag.values.where(
                (value) => value.available,
              ))
                ChoiceChip(
                  key: Key('onboarding-language-${language.code}'),
                  selected: _language == language,
                  onSelected: (_) => setState(() => _language = language),
                  avatar: CircleAvatar(
                    child: Text(
                      language.symbol,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  label: Text(
                    '${language.koreanName} · ${language.nativeName}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const _OnboardingStepHeader(
            step: 2,
            title: '학습 목적',
            description: '첫 화면에서 가장 잘 맞는 학습 방식을 먼저 추천합니다.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final purpose in _FirstRunPurpose.values)
                ChoiceChip(
                  key: Key('onboarding-purpose-${purpose.name}'),
                  selected: _purpose == purpose,
                  onSelected: (_) => setState(() => _purpose = purpose),
                  avatar: Icon(purpose.icon, size: 17),
                  label: Text(purpose.label),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const _OnboardingStepHeader(
            step: 3,
            title: '현재 수준',
            description: '처음에 보여 줄 새 자료의 양을 알맞게 조절합니다.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final level in _FirstRunLevel.values)
                ChoiceChip(
                  key: Key('onboarding-level-${level.name}'),
                  selected: _level == level,
                  onSelected: (_) => setState(() => _level = level),
                  label: Text(level.label),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const _OnboardingStepHeader(
            step: 4,
            title: '하루 학습 시간',
            description: '나중에 설정에서 문제 수와 목표를 따로 바꿀 수 있습니다.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final goal in _dailyGoals)
                ChoiceChip(
                  key: Key('onboarding-goal-$goal'),
                  selected: _dailyGoal == goal,
                  onSelected: (_) => setState(() => _dailyGoal = goal),
                  label: Text(switch (goal) {
                    50 => '3분 · $goal XP',
                    100 => '5분 · $goal XP',
                    150 => '10분 · $goal XP',
                    _ => '15분 · $goal XP',
                  }),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const _OnboardingStepHeader(
            step: 5,
            title: '시작 방식',
            description: '샘플을 먼저 체험하거나 내 자료를 곧바로 가져오세요.',
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.55,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '학습은 로그인 없이 시작할 수 있습니다. Google 연결은 백업과 기기 간 동기화가 필요할 때만 설정하세요.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('complete-first-run-setup'),
            onPressed: () => _complete(_FirstRunEntry.sample),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('${_language.koreanName} 샘플로 시작'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('onboarding-import-data'),
            onPressed: () => _complete(_FirstRunEntry.importData),
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('내 Excel·CSV 자료 가져오기'),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStepHeader extends StatelessWidget {
  const _OnboardingStepHeader({
    required this.step,
    required this.title,
    required this.description,
  });

  final int step;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: Text(
            '$step',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.compact,
    required this.now,
    required this.subjectName,
    required this.subjectSymbol,
    required this.generalTopic,
    required this.subtitle,
    required this.streakDays,
    required this.connected,
    required this.onSettings,
    this.windowWorkspace,
    this.onToggleCompact,
    this.onMinimize,
  });

  final bool compact;
  final DateTime now;
  final String subjectName;
  final String subjectSymbol;
  final bool generalTopic;
  final String subtitle;
  final int streakDays;
  final bool connected;
  final VoidCallback onSettings;
  final WindowWorkspaceState? windowWorkspace;
  final VoidCallback? onToggleCompact;
  final VoidCallback? onMinimize;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final date = '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일';
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        final veryNarrow = constraints.maxWidth < 370;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    compact
                        ? generalTopic
                              ? '$subjectSymbol $subjectName'
                              : veryNarrow
                              ? '오늘 학습'
                              : '오늘 체크리스트'
                        : veryNarrow && generalTopic
                        ? subjectName
                        : '오늘의 $subjectName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: veryNarrow && generalTopic ? 20 : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    compact ? '$subtitle · 빠른 복습' : date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _HeaderBadge(
              icon: Icons.local_fire_department_rounded,
              label: '$streakDays일',
              color: AppTheme.warning,
              tooltip: '연속 학습 $streakDays일',
              showLabel: !narrow,
            ),
            if (windowWorkspace != null && onToggleCompact != null) ...[
              const SizedBox(width: 8),
              _HeaderBadge(
                key: const Key('window-compact-toggle'),
                icon: windowWorkspace!.compact
                    ? Icons.open_in_full_rounded
                    : Icons.picture_in_picture_alt_rounded,
                label: windowWorkspace!.compact ? '확장' : '집중',
                color: Theme.of(context).colorScheme.primary,
                tooltip: windowWorkspace!.compact
                    ? '기본 창으로 복원 (Ctrl+Shift+F)'
                    : '집중 창으로 전환 (Ctrl+Shift+F)',
                showLabel: !compact,
                onTap: windowWorkspace!.busy ? null : onToggleCompact,
              ),
            ],
            if (windowWorkspace != null && onMinimize != null) ...[
              const SizedBox(width: 8),
              _HeaderBadge(
                key: const Key('window-quick-minimize'),
                icon: Icons.minimize_rounded,
                label: '최소화',
                color: Theme.of(context).colorScheme.outline,
                tooltip: '빠르게 최소화 (Ctrl+Shift+M)',
                showLabel: false,
                onTap: windowWorkspace!.busy ? null : onMinimize,
              ),
            ],
            const SizedBox(width: 8),
            _HeaderBadge(
              key: const Key('home-settings'),
              icon: connected
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_off_rounded,
              label: connected ? '저장됨' : '설정',
              color: connected
                  ? AppTheme.success
                  : Theme.of(context).colorScheme.outline,
              tooltip: connected ? 'Google Drive 및 설정 열기' : '로컬 저장 및 설정 열기',
              showLabel: !compact && !narrow,
              onTap: onSettings,
            ),
          ],
        );
      },
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.tooltip,
    this.showLabel = true,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;
  final bool showLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.symmetric(horizontal: showLabel ? 11 : 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: color),
          if (showLabel) ...[
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
    return Tooltip(
      message: tooltip,
      child: onTap == null
          ? badge
          : Semantics(
              button: true,
              label: tooltip,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: badge,
                ),
              ),
            ),
    );
  }
}

class _ResumeSessionCard extends StatelessWidget {
  const _ResumeSessionCard({
    required this.session,
    required this.subjectName,
    required this.subjectSymbol,
    required this.cloudConnected,
    required this.onResume,
    required this.onDiscard,
  });

  final ActiveStudySession session;
  final String subjectName;
  final String subjectSymbol;
  final bool cloudConnected;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progressLabel =
        '${session.completedCount}/${session.itemIds.length}문제';
    final accuracy = (session.accuracy * 100).round();
    return Card(
      key: const Key('resume-study-card'),
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final veryNarrow = constraints.maxWidth < 300;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '다음 학습',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onTertiaryContainer.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.restore_rounded, color: colors.tertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session.phase == ActiveStudySessionPhase.paused
                            ? veryNarrow
                                  ? '중단한 학습 이어하기'
                                  : '일시정지한 학습 이어하기'
                            : veryNarrow
                            ? '학습 이어하기'
                            : '진행 중인 학습 이어하기',
                        style:
                            (veryNarrow
                                    ? Theme.of(context).textTheme.titleSmall
                                    : Theme.of(context).textTheme.titleMedium)
                                ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      progressLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '$subjectSymbol $subjectName · ${session.mode.label}'
                  '${session.unitIndex == null ? '' : ' · Unit ${session.unitIndex! + 1}'}'
                  ' · ${session.origin.label}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  session.attempts == 0
                      ? '아직 푼 문제는 없습니다. 같은 문제 순서로 다시 시작합니다.'
                      : '정답 ${session.correctCount} · 오답 ${session.wrongCount} · 정확도 $accuracy% · +${session.earnedXp} XP',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (session.pauseCount + session.resumeCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '일시정지 ${session.pauseCount}회 · 이어하기 ${session.resumeCount}회'
                    '${session.generation == 0 ? '' : ' · ${session.generation}단계 분기'}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      cloudConnected
                          ? Icons.cloud_sync_rounded
                          : Icons.save_outlined,
                      size: 16,
                      color: colors.onTertiaryContainer.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cloudConnected
                            ? 'Drive 연결 시 Android·Windows에서 같은 지점을 이어갑니다.'
                            : '현재 이 기기에 자동 저장 중입니다.',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: session.progress,
                    minHeight: 7,
                    backgroundColor: colors.surface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  key: const Key('discard-active-session'),
                  onPressed: onDiscard,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(78, 48),
                  ),
                  child: const Text('종료'),
                ),
                KeyedSubtree(
                  key: const Key('home-primary-study-button'),
                  child: FilledButton.icon(
                    key: const Key('resume-active-session'),
                    onPressed: onResume,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(126, 48),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(session.remainingCount == 0 ? '결과 보기' : '이어하기'),
                  ),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  copy,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 18),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeNextAction {
  const _HomeNextAction({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.icon,
    required this.onPressed,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String buttonLabel;
  final IconData icon;
  final VoidCallback onPressed;
}

class _DailyHero extends StatelessWidget {
  const _DailyHero({
    required this.compact,
    required this.action,
    required this.dailyXp,
    required this.dailyGoal,
    required this.level,
    required this.accountTotalXp,
  });

  final bool compact;
  final _HomeNextAction action;
  final int dailyXp;
  final int dailyGoal;
  final int level;
  final int accountTotalXp;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = dailyGoal == 0 ? 0.0 : min(1.0, dailyXp / dailyGoal);
    return Card(
      key: const Key('home-next-study-card'),
      color: colors.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 14 : 20),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 22),
        child: Row(
          children: [
            if (!compact) ...[
              _ProgressDial(progress: progress, xp: dailyXp, goal: dailyGoal),
              const SizedBox(width: 20),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action.eyebrow,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    action.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      height: 1.18,
                    ),
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action.description,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onPrimaryContainer.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '오늘 $dailyXp/$dailyGoal XP · 계정 레벨 $level · '
                    '누적 $accountTotalXp XP',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onPrimaryContainer.withValues(alpha: 0.78),
                    ),
                  ),
                  if (compact) ...[
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: colors.onPrimaryContainer.withValues(
                          alpha: 0.14,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      key: const Key('home-primary-study-button'),
                      onPressed: action.onPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.onPrimaryContainer,
                        foregroundColor: colors.primaryContainer,
                        minimumSize: Size(compact ? 0 : 150, compact ? 44 : 48),
                      ),
                      icon: Icon(action.icon),
                      label: Text(action.buttonLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDial extends StatelessWidget {
  const _ProgressDial({
    required this.progress,
    required this.xp,
    required this.goal,
  });

  final double progress;
  final int xp;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: 88,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: colors.onPrimaryContainer.withValues(
                alpha: 0.14,
              ),
              color: colors.onPrimaryContainer,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$xp',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
              Text(
                '/ $goal XP',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onPrimaryContainer.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayPlan extends StatelessWidget {
  const _TodayPlan({
    required this.reviewCount,
    required this.newCount,
    required this.weakCount,
    this.compact = false,
  });

  final int reviewCount;
  final int newCount;
  final int weakCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) ...[
              Text('오늘의 학습', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '다음 학습을 고르는 데 쓰이는 현재 수치입니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            _PlanRow(
              icon: Icons.replay_rounded,
              label: '복습 예정',
              count: reviewCount,
              color: AppTheme.desktopPrimary,
            ),
            if (!compact) const Divider(height: 16),
            _PlanRow(
              icon: Icons.auto_awesome_rounded,
              label: '새 표현',
              count: newCount,
              color: AppTheme.mobilePrimary,
            ),
            if (!compact) const Divider(height: 16),
            _PlanRow(
              icon: Icons.bolt_rounded,
              label: '집중 필요',
              count: weakCount,
              color: AppTheme.warning,
            ),
          ],
        ),
      ),
    );
  }
}

enum _SchedulePlanAction { complete, snooze, tomorrow, changeTime }

class _ScheduleQuickActions extends StatelessWidget {
  const _ScheduleQuickActions({
    required this.plan,
    required this.onComplete,
    required this.onSnooze,
    required this.onDefer,
    required this.onChangeTime,
  });

  final StudySessionPlan plan;
  final VoidCallback onComplete;
  final VoidCallback onSnooze;
  final VoidCallback onDefer;
  final VoidCallback onChangeTime;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${plan.title} 일정 빠른 작업',
      child: Wrap(
        key: const Key('home-schedule-quick-actions'),
        spacing: 6,
        runSpacing: 6,
        children: [
          FilledButton.tonalIcon(
            key: const Key('schedule-complete-today'),
            onPressed: onComplete,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('완료'),
          ),
          OutlinedButton(
            key: const Key('schedule-snooze-ten-minutes'),
            onPressed: onSnooze,
            child: const Text('10분 미루기'),
          ),
          OutlinedButton(
            key: const Key('schedule-defer-tomorrow'),
            onPressed: onDefer,
            child: const Text('내일'),
          ),
          IconButton.outlined(
            key: const Key('schedule-change-time'),
            tooltip: '학습 시간 변경',
            onPressed: onChangeTime,
            icon: const Icon(Icons.schedule_rounded),
          ),
        ],
      ),
    );
  }
}

class _ScheduledPlansCard extends StatelessWidget {
  const _ScheduledPlansCard({
    required this.plans,
    required this.now,
    required this.compact,
    required this.onOpen,
    required this.onManage,
    required this.onComplete,
    required this.onSnooze,
    required this.onDefer,
    required this.onChangeTime,
  });

  final List<StudySessionPlan> plans;
  final DateTime now;
  final bool compact;
  final ValueChanged<StudySessionPlan> onOpen;
  final VoidCallback onManage;
  final ValueChanged<StudySessionPlan> onComplete;
  final ValueChanged<StudySessionPlan> onSnooze;
  final ValueChanged<StudySessionPlan> onDefer;
  final ValueChanged<StudySessionPlan> onChangeTime;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visiblePlans = plans.take(compact ? 1 : 3).toList(growable: false);
    return Card(
      key: const Key('home-scheduled-plans'),
      color: colors.tertiaryContainer.withValues(alpha: 0.42),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: compact ? 34 : 40,
                  height: compact ? 34 : 40,
                  decoration: BoxDecoration(
                    color: colors.tertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.event_available_rounded,
                    size: compact ? 19 : 22,
                    color: colors.tertiary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        compact ? '다음 학습 일정' : '내 학습 일정',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (!compact)
                        Text(
                          '${plans.length}개 예약 · 시작하면 일정만 완료되고 설정은 남습니다.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                TextButton(
                  key: const Key('home-manage-scheduled-plans'),
                  onPressed: onManage,
                  child: Text(compact ? '관리' : '전체 관리'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final (index, plan) in visiblePlans.indexed) ...[
              if (index > 0) const Divider(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_homeScheduleLabel(plan.scheduledAt!, now)} · '
                          '${plan.mode.label} ${plan.itemLimit}문제',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.tonal(
                        key: Key('home-open-session-plan-${plan.planId}'),
                        onPressed: () => onOpen(plan),
                        style: FilledButton.styleFrom(
                          minimumSize: Size(compact ? 60 : 76, 44),
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 12 : 16,
                          ),
                        ),
                        child: Text(compact ? '열기' : '불러오기'),
                      ),
                      PopupMenuButton<_SchedulePlanAction>(
                        tooltip: '일정 빠른 작업',
                        onSelected: (action) {
                          switch (action) {
                            case _SchedulePlanAction.complete:
                              onComplete(plan);
                            case _SchedulePlanAction.snooze:
                              onSnooze(plan);
                            case _SchedulePlanAction.tomorrow:
                              onDefer(plan);
                            case _SchedulePlanAction.changeTime:
                              onChangeTime(plan);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _SchedulePlanAction.complete,
                            child: Text('오늘 완료'),
                          ),
                          PopupMenuItem(
                            value: _SchedulePlanAction.snooze,
                            child: Text('10분 미루기'),
                          ),
                          PopupMenuItem(
                            value: _SchedulePlanAction.tomorrow,
                            child: Text('내일로 미루기'),
                          ),
                          PopupMenuItem(
                            value: _SchedulePlanAction.changeTime,
                            child: Text('시간 변경'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
            if (compact && plans.length > visiblePlans.length) ...[
              const SizedBox(height: 6),
              Text(
                '이외 ${plans.length - visiblePlans.length}개 일정은 관리에서 확인',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _homeScheduleLabel(DateTime value, DateTime now) {
  final local = value.toLocal();
  final localNow = now.toLocal();
  final scheduledDay = DateUtils.dateOnly(local);
  final today = DateUtils.dateOnly(localNow);
  final tomorrow = today.add(const Duration(days: 1));
  final minute = local.minute.toString().padLeft(2, '0');
  final time = '${local.hour.toString().padLeft(2, '0')}:$minute';
  if (scheduledDay.isBefore(today)) {
    return '놓친 일정 · ${local.month}월 ${local.day}일 $time';
  }
  if (scheduledDay == today) {
    return local.isAfter(localNow) ? '오늘 $time' : '지금 시작 가능';
  }
  if (scheduledDay == tomorrow) return '내일 $time';
  return '${local.month}월 ${local.day}일 $time';
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: '$count개',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$count',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
