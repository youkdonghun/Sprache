import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/active_study_session.dart';
import '../domain/app_experience_preferences.dart';
import '../domain/language.dart';
import '../domain/learning_insights.dart';
import '../domain/learning_item.dart';
import '../domain/onboarding_profile.dart';
import '../domain/progress.dart';
import '../domain/session_enhancements.dart';
import '../domain/smart_collection.dart';
import '../domain/study_limits.dart';
import '../domain/study_interaction_preferences.dart';
import '../domain/study_preferences.dart';
import '../domain/study_routines.dart';
import '../domain/study_subject.dart';
import '../services/app_clock.dart';
import '../services/study_notification_service.dart';
import '../state/app_state.dart';
import '../state/app_state_view.dart';
import '../state/connection_state.dart';
import '../theme/app_theme.dart';
import '../widgets/learning_data_flow_card.dart';
import '../widgets/onboarding_setup_dialog.dart';
import '../widgets/quick_content_result_handler.dart';
import '../widgets/quick_content_sheet.dart';
import '../widgets/privacy_mode_scope.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final reconnectSummary = ref.watch(
      connectionControllerProvider.select((value) => value.reconnectSummary),
    );
    if (reconnectSummary != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final latest = ref.read(connectionControllerProvider).reconnectSummary;
        if (latest?.id != reconnectSummary.id) return;
        ref
            .read(connectionControllerProvider.notifier)
            .dismissReconnectSummary(reconnectSummary.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('reconnect-sync-summary'),
            content: Text(reconnectSummary.message),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: '상세',
              onPressed: () => context.go('/settings?focus=storage'),
            ),
          ),
        );
      });
    }
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
    final onboardingProfile = state.preferences.onboardingProfile;
    final onboardingDisplayLanguage = LanguageTag.values.firstWhere(
      (language) =>
          language.available && language.code == onboardingProfile.languageCode,
      orElse: () => state.selectedLanguage,
    );
    final hasOnboardingDraft =
        onboardingProfile.languageCode.isNotEmpty ||
        onboardingProfile.draftStep > 0 ||
        onboardingProfile.deferred;
    final isPlannedStudyDay = onboardingProfile.isStudyDay(now.toLocal());
    final nextPlannedStudyDate = onboardingProfile.nextStudyDate(
      now.toLocal(),
      includeToday: false,
    );
    final coursePath = controller.coursePath;
    final recommendedUnit = coursePath.recommendedUnit;
    final queue = controller.queue(now);
    final selectedItems = controller.selectedItems;
    final experience = state.preferences.experience;
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final isDesktop =
        isWindows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
    final forecast = controller.reviewForecast(now);
    final weeklyInsights = LearningInsights.build(
      sessions: state.recentSessions,
      items: selectedItems,
      progress: state.progress,
      now: now,
      range: LearningInsightRange.sevenDays,
      courseId: state.activeCourseId,
    );
    final reviewCount = forecast.dueNow;
    final newCount = isPlannedStudyDay
        ? min(
            state.preferences.newItemLimit,
            selectedItems
                .where(
                  (item) =>
                      state.progress[item.id] == null ||
                      state.progress[item.id]!.status == LearningStatus.newItem,
                )
                .length,
          )
        : 0;
    final weakCount = state.progress.values.where((progress) {
      return progress.attempts > 0 &&
          progress.accuracy < 0.7 &&
          selectedItems.any((item) => item.id == progress.itemId);
    }).length;
    final quickStudyPlan = buildTwoMinuteStudyPlan(
      subjectId: activeSubject.id,
      dueItemIds: selectedItems
          .where((item) {
            final due = state.progress[item.id]?.nextReviewAt;
            return due != null && !due.isAfter(now);
          })
          .map((item) => item.id),
      weakItemIds: controller.weakItems.map((item) => item.id),
    );
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
    final hasCompletedCourseSession = state.recentSessions.any(
      (session) => session.courseId == state.activeCourseId,
    );
    final recentCustomItems =
        state.customItems
            .where((item) => item.effectiveSubjectId == activeSubject.id)
            .toList()
          ..sort(
            (left, right) =>
                (right.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                      left.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                    ),
          );

    void studyRecentItem(LearningItem item) {
      controller.updateSessionPlan(
        controller.activeSessionPlan.copyWith(
          planId: '',
          mode: StudyMode.mixed,
          deck: StudyDeckScope.selected,
          selectedItemIds: {item.id},
          groupIds: {},
          tags: {},
          levels: {},
          includeWords: item.kind == LearningItemKind.word,
          includeSentences: item.kind == LearningItemKind.sentence,
          itemLimit: 1,
          lengthMode: StudySessionLengthMode.itemCount,
          recordProgress: true,
          scheduledAt: null,
        ),
      );
      context.push('/study?mode=mixed&limit=1&custom=true');
    }

    void startTwoMinuteStudy() {
      final plan = quickStudyPlan;
      if (plan == null) return;
      controller.updateSessionPlan(plan);
      context.push('/study?mode=mixed&custom=true');
    }

    Future<void> scheduleTwoMinuteStudy() async {
      final plan = quickStudyPlan;
      if (plan == null) return;
      final localNow = now.toLocal();
      final candidate = plan.copyWith(
        routineName: '2분 복습 루틴',
        routineWeekdays: onboardingProfile.normalizedStudyWeekdays,
        routineMinuteOfDay: localNow.hour * 60 + localNow.minute,
      );
      final saved = controller.saveSessionPlan(
        candidate.copyWith(
          scheduledAt: nextRoutineOccurrence(
            candidate,
            after: now.add(const Duration(minutes: 1)),
          ),
        ),
      );
      final permission = await controller.requestStudyNotificationPermission();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            permission == StudyNotificationPermission.granted
                ? '“${saved.title}” 알림과 루틴을 저장했어요.'
                : '루틴을 저장했어요. 알림을 받으려면 기기 설정에서 권한을 켜 주세요.',
          ),
        ),
      );
    }

    Future<void> trashRecentItem(LearningItem item) async {
      final batch = await controller.trashCustomItems({item.id});
      if (!context.mounted || batch.entries.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('“${item.text}”을 휴지통으로 옮겼어요.'),
          action: SnackBarAction(
            label: '실행 취소',
            onPressed: () => unawaited(controller.restoreTrashBatch(batch.id)),
          ),
        ),
      );
    }

    Future<void> openQuickContent() async {
      final result = await showQuickContentSheet(context: context);
      if (!context.mounted) return;
      await handleQuickContentResult(
        context: context,
        ref: ref,
        result: result,
      );
    }

    final recommendedRoute =
        state.preferences.preferredMode == StudyMode.pronunciation
        ? '/pronunciation'
        : '/study?mode=${state.preferences.preferredMode.name}';

    void runHomeQuickAction(HomeQuickAction action) {
      switch (action) {
        case HomeQuickAction.study:
          context.push(recommendedRoute);
        case HomeQuickAction.quickAdd:
          unawaited(openQuickContent());
        case HomeQuickAction.practice:
          context.go('/learn');
        case HomeQuickAction.library:
          context.go('/library');
        case HomeQuickAction.importData:
          context.push('/import');
        case HomeQuickAction.stats:
          context.go('/stats');
      }
    }

    late final _HomeNextAction nextAction;
    if (selectedItems.isEmpty) {
      nextAction = _HomeNextAction(
        eyebrow: '${activeSubject.name} · 학습 준비',
        title: '첫 단어나 문장을 추가해 보세요',
        description: '표현과 뜻 하나만 입력하면 바로 학습할 수 있어요.',
        buttonLabel: '단어·문장 추가',
        icon: Icons.add_rounded,
        onPressed: () => context.go('/library/new'),
      );
    } else if (reviewCount > 0) {
      nextAction = _HomeNextAction(
        eyebrow: '${activeSubject.name} · 다음 학습',
        title: '복습할 표현 $reviewCount개',
        description: '지금 복습하면 더 오래 기억할 수 있어요.',
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
    } else if (!isPlannedStudyDay) {
      nextAction = _HomeNextAction(
        eyebrow: '${activeSubject.name} · 자율 학습',
        title: '오늘은 계획한 쉬는 날이에요',
        description:
            '새 표현은 다음 학습일에 보여 드릴게요. 원하면 ${state.preferences.preferredMode.label}로 가볍게 연습할 수 있어요.',
        buttonLabel: '가볍게 학습',
        icon: Icons.self_improvement_rounded,
        onPressed: () => context.push(recommendedRoute),
      );
    } else {
      final unitTitle = activeSubject.isLanguage
          ? 'Unit ${recommendedUnit.index + 1} · ${recommendedUnit.title}'
          : '${activeSubject.name} · 자료 ${selectedItems.length}개';
      nextAction = _HomeNextAction(
        eyebrow: '${activeSubject.name} · 다음 학습',
        title: queue.isEmpty ? '오늘 목표를 마쳤어요' : unitTitle,
        description: queue.isEmpty
            ? '원하면 ${state.preferences.preferredMode.label}로 조금 더 연습할 수 있어요.'
            : '${state.preferences.preferredMode.label} · 새 표현 $newCount개',
        buttonLabel: isDesktop ? '다음 학습' : '다음 레슨',
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
        const SnackBar(content: Text('진행하던 학습을 끝냈어요. 푼 기록은 남아 있어요.')),
      );
    }

    void completeScheduledPlan(StudySessionPlan plan) {
      controller.completeExamPlanForToday(plan.planId, completedAt: now);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오늘 학습을 완료했어요.')));
    }

    void snoozeScheduledPlan(StudySessionPlan plan) {
      controller.snoozeSessionPlan(plan.planId, now: now);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('10분 뒤에 다시 알려 드릴게요.')));
    }

    void deferScheduledPlan(StudySessionPlan plan) {
      controller.deferSessionPlanUntilTomorrow(plan.planId, now: now);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내일 학습으로 옮겼어요.')));
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('학습할 자료가 없어요. 자료실에서 조건을 바꿔 보세요.')),
        );
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
          final layout =
              Theme.of(context).extension<AppLayoutDensity>() ??
              AppLayoutDensity.fromPreference(
                experience.density,
                isDesktop: isDesktop,
              );
          final homeCompact = officeCompact || mobile || layout.dense;
          final horizontalPadding = officeCompact
              ? 12.0
              : layout.pagePadding.horizontal / 2;
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
              showXp: experience.showXp,
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
                SizedBox(height: layout.controlGap + 5),
                _WeeklyTargetSummaryCard(
                  compact: compact,
                  studiedDays: weeklyInsights.studiedDaysInLastSeven(),
                  targetDays: state.preferences.weeklyTargetDays,
                  studiedMinutes: weeklyInsights
                      .durationInLastSeven()
                      .inMinutes,
                  targetMinutes: state.preferences.weeklyTargetMinutes,
                  progress: weeklyInsights.weeklyCombinedGoalProgress(
                    targetDays: state.preferences.weeklyTargetDays,
                    targetMinutes: state.preferences.weeklyTargetMinutes,
                  ),
                  onOpen: () => context.go('/stats'),
                ),
                if (primaryScheduledPlan case final plan?) ...[
                  SizedBox(height: layout.controlGap + 5),
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

          Widget studyOverview() {
            final plan = _TodayPlan(
              compact: homeCompact,
              reviewCount: reviewCount,
              newCount: newCount,
              weakCount: weakCount,
              isStudyDay: isPlannedStudyDay,
              nextStudyDate: nextPlannedStudyDate,
            );
            if (experience.homeLayout == AppHomeLayout.focus) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880),
                      child: primaryStudyArea(compact: homeCompact),
                    ),
                  ),
                  if (experience.showTodayPlan) ...[
                    SizedBox(height: layout.sectionGap),
                    plan,
                  ],
                ],
              );
            }
            if (wide && experience.showTodayPlan) {
              final primary = Expanded(
                flex: experience.homeLayout == AppHomeLayout.insights ? 4 : 5,
                child: primaryStudyArea(compact: false),
              );
              final insights = Expanded(
                flex: experience.homeLayout == AppHomeLayout.insights ? 5 : 4,
                child: plan,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: experience.homeLayout == AppHomeLayout.insights
                    ? [insights, const SizedBox(width: 14), primary]
                    : [primary, const SizedBox(width: 14), insights],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                primaryStudyArea(compact: homeCompact),
                if (experience.showTodayPlan) ...[
                  SizedBox(height: layout.sectionGap),
                  plan,
                ],
              ],
            );
          }

          final personalizedSections = <Widget>[];
          for (final section in experience.homeSectionOrder) {
            final Widget? content = switch (section) {
              AppHomeSection.pinnedCollections =>
                experience.showPinnedCollections && pinnedCollections.isNotEmpty
                    ? _HomePinnedCollections(
                        collections: pinnedCollections,
                        itemCountFor: (collection) => controller
                            .itemsForSmartCollection(collection)
                            .length,
                        onOpen: openPinnedCollection,
                        onManage: () => context.go('/library'),
                      )
                    : null,
              AppHomeSection.recentAdditions =>
                experience.showRecentAdditions && recentCustomItems.isNotEmpty
                    ? _RecentAdditionsTray(
                        items: recentCustomItems.take(3).toList(),
                        onOpen: (item) =>
                            context.push('/library/edit/${item.id}'),
                        onStudy: studyRecentItem,
                        onTrash: (item) => unawaited(trashRecentItem(item)),
                        onViewAll: () => context.go('/library'),
                      )
                    : null,
              AppHomeSection.dataFlow =>
                experience.showDataFlow && !officeCompact
                    ? LearningDataFlowCard(
                        totalCount: selectedItems.length,
                        localCopyCount: localCopyCount,
                        groupCount: groupCount,
                        driveConnected: state.driveConnected,
                        currentStep: selectedItems.isEmpty
                            ? LearningDataStep.add
                            : localCopyCount > 0 && groupCount == 0
                            ? LearningDataStep.organize
                            : LearningDataStep.learn,
                        onAdd: () => unawaited(openQuickContent()),
                        onOrganize: () => context.go('/library/groups'),
                        onLearn: () => context.go('/learn'),
                        onConnectDrive: () =>
                            context.go('/settings?focus=storage'),
                        syncLabel: state.driveConnected
                            ? 'Drive 연결됨'
                            : 'Google Drive 연결 필요',
                      )
                    : null,
              AppHomeSection.schedules =>
                experience.showSchedules && secondaryScheduledPlans.isNotEmpty
                    ? _ScheduledPlansCard(
                        plans: secondaryScheduledPlans,
                        now: now,
                        compact: homeCompact,
                        onOpen: (plan) {
                          final loaded = controller.useSavedSessionPlan(plan);
                          if (loaded != null) context.push('/session-builder');
                        },
                        onManage: () => context.push('/session-builder'),
                        onComplete: completeScheduledPlan,
                        onSnooze: snoozeScheduledPlan,
                        onDefer: deferScheduledPlan,
                        onChangeTime: changeScheduledPlanTime,
                      )
                    : null,
            };
            if (content != null) {
              personalizedSections
                ..add(SizedBox(height: layout.sectionGap))
                ..add(content);
            }
          }

          return CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverPadding(
                key: const Key('home-page-padding'),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  layout.pagePadding.top,
                  horizontalPadding,
                  layout.pagePadding.bottom + (mobile ? 8 : 12),
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: AppTheme.contentMaxWidth(
                          experience.contentWidth,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (experience.showHomeHeader)
                            _HomeHeader(
                              compact: homeCompact || experience.simpleHome,
                              now: now,
                              subjectName: activeSubject.name,
                              subjectSymbol: activeSubject.symbol,
                              generalTopic: !activeSubject.isLanguage,
                              subtitle: activeSubject.isLanguage
                                  ? activeSubject.contentLanguage.nativeName
                                  : '나만의 학습 주제',
                              streakDays: state.streakDays,
                              connected: state.driveConnected,
                              showStreak: experience.showStreak,
                              showSyncStatus: experience.showSyncStatus,
                              onSettings: () => context.go('/settings'),
                            ),
                          if (!state.preferences.onboardingCompleted) ...[
                            SizedBox(height: layout.sectionGap),
                            _GettingStartedCard(
                              compact: homeCompact,
                              language: onboardingDisplayLanguage,
                              dailyGoal: hasOnboardingDraft
                                  ? onboardingProfile.dailyGoal
                                  : state.dailyGoal,
                              resuming: hasOnboardingDraft,
                              onPressed: () => _showFirstRunSetup(
                                context: context,
                                language: state.selectedLanguage,
                                dailyGoal: state.dailyGoal,
                                profile: state.preferences.onboardingProfile,
                                onDraft: controller.saveOnboardingDraft,
                                onComplete: (selection) {
                                  controller.completeOnboarding(
                                    language: selection.language,
                                    dailyGoal: selection.dailyGoal,
                                  );
                                  final completed = ref.read(
                                    appControllerProvider,
                                  );
                                  final profile = selection.onboardingProfile;
                                  final activityId =
                                      profile.recommendedActivityId;
                                  final currentCatalog = completed
                                      .preferences
                                      .interaction
                                      .practiceCatalog;
                                  final recommendedLaunch = currentCatalog
                                      .launchFor(activityId)
                                      .copyWith(
                                        length: PracticeSessionLength.tenItems,
                                        largeControls: profile.easyAccess,
                                      );
                                  final recommendedCatalog = currentCatalog
                                      .copyWith(
                                        quickLaunchActivityIds: {
                                          ...currentCatalog
                                              .quickLaunchActivityIds,
                                          activityId,
                                        },
                                        launchByActivityId: {
                                          ...currentCatalog.launchByActivityId,
                                          activityId: recommendedLaunch,
                                        },
                                      )
                                      .adjustRecommendationWeight(
                                        activityId,
                                        3,
                                      );
                                  controller.updatePreferences(
                                    completed.preferences.copyWith(
                                      preferredMode: selection.preferredMode,
                                      newItemLimit: selection.newItemLimit,
                                      sessionItemLimit:
                                          selection.sessionItemLimit,
                                      onboardingProfile: profile,
                                      sessionPlan: completed
                                          .preferences
                                          .sessionPlan
                                          .copyWith(
                                            planId: '',
                                            subjectId: languageSubjectId(
                                              selection.language,
                                            ),
                                            title: profile
                                                .recommendedStarterGroupLabel,
                                            mode: selection.preferredMode,
                                            itemLimit:
                                                selection.sessionItemLimit,
                                            lengthMode: StudySessionLengthMode
                                                .itemCount,
                                            largeControls: profile.easyAccess,
                                            scheduledAt: null,
                                          ),
                                      experience: completed
                                          .preferences
                                          .experience
                                          .copyWith(
                                            colorMode: profile.appColorMode,
                                            accentPalette:
                                                profile.appAccentPalette,
                                            textScale: profile.easyAccess
                                                ? AppTextScale.large
                                                : completed
                                                      .preferences
                                                      .experience
                                                      .textScale,
                                            highContrast:
                                                profile.easyAccess ||
                                                completed
                                                    .preferences
                                                    .experience
                                                    .highContrast,
                                            showFocusRing: true,
                                          ),
                                      interaction: completed
                                          .preferences
                                          .interaction
                                          .copyWith(
                                            choiceLayout: profile.easyAccess
                                                ? StudyChoiceLayout.list
                                                : completed
                                                      .preferences
                                                      .interaction
                                                      .choiceLayout,
                                            practiceCatalog: recommendedCatalog,
                                          ),
                                    ),
                                  );
                                  if (selection.entry ==
                                      _FirstRunEntry.importData) {
                                    context.push('/import');
                                  } else {
                                    context.push(
                                      '/study?mode=${selection.preferredMode.name}&limit=3',
                                    );
                                  }
                                },
                              ),
                              onDismiss: () {
                                controller.saveOnboardingDraft(
                                  state.preferences.onboardingProfile.copyWith(
                                    deferred: true,
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '지금까지 고른 내용을 저장했어요. 홈에서 언제든 이어서 설정할 수 있어요.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                          if (experience.simpleHome) ...[
                            SizedBox(height: layout.controlGap + 6),
                            primaryStudyCard(compact: true),
                            SizedBox(height: layout.controlGap + 6),
                            _HomeQuickActions(
                              actions: _simpleHomeQuickActions(),
                              compact: true,
                              maxActions: 2,
                              onSelected: runHomeQuickAction,
                            ),
                            SizedBox(height: layout.controlGap + 6),
                            _SimpleHomeDetails(
                              summary: reviewCount > 0
                                  ? '복습 $reviewCount개가 기다리고 있어요'
                                  : '계획, 기록, 최근 자료를 한곳에서 보세요',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _WeeklyTargetSummaryCard(
                                    compact: true,
                                    studiedDays: weeklyInsights
                                        .studiedDaysInLastSeven(),
                                    targetDays:
                                        state.preferences.weeklyTargetDays,
                                    studiedMinutes: weeklyInsights
                                        .durationInLastSeven()
                                        .inMinutes,
                                    targetMinutes:
                                        state.preferences.weeklyTargetMinutes,
                                    progress: weeklyInsights
                                        .weeklyCombinedGoalProgress(
                                          targetDays: state
                                              .preferences
                                              .weeklyTargetDays,
                                          targetMinutes: state
                                              .preferences
                                              .weeklyTargetMinutes,
                                        ),
                                    onOpen: () => context.go('/stats'),
                                  ),
                                  if (experience.showTodayPlan) ...[
                                    SizedBox(height: layout.controlGap + 5),
                                    _TodayPlan(
                                      compact: true,
                                      reviewCount: reviewCount,
                                      newCount: newCount,
                                      weakCount: weakCount,
                                      isStudyDay: isPlannedStudyDay,
                                      nextStudyDate: nextPlannedStudyDate,
                                    ),
                                  ],
                                  if (primaryScheduledPlan
                                      case final plan?) ...[
                                    SizedBox(height: layout.controlGap + 5),
                                    _ScheduleQuickActions(
                                      plan: plan,
                                      onComplete: () =>
                                          completeScheduledPlan(plan),
                                      onSnooze: () => snoozeScheduledPlan(plan),
                                      onDefer: () => deferScheduledPlan(plan),
                                      onChangeTime: () =>
                                          changeScheduledPlanTime(plan),
                                    ),
                                  ],
                                  if (quickStudyPlan != null) ...[
                                    SizedBox(height: layout.controlGap + 5),
                                    _TwoMinuteStudyRow(
                                      itemCount:
                                          quickStudyPlan.selectedItemIds.length,
                                      compact: true,
                                      onSchedule: () =>
                                          unawaited(scheduleTwoMinuteStudy()),
                                      onStart: startTwoMinuteStudy,
                                    ),
                                  ],
                                  ...personalizedSections,
                                ],
                              ),
                            ),
                          ] else ...[
                            if (state.preferences.onboardingCompleted) ...[
                              SizedBox(height: layout.controlGap + 6),
                              _HomeQuickActions(
                                actions: onboardingProfile.quickActions,
                                compact: homeCompact,
                                onSelected: runHomeQuickAction,
                              ),
                              if (!hasCompletedCourseSession &&
                                  onboardingProfile
                                      .languageCode
                                      .isNotEmpty) ...[
                                SizedBox(height: layout.controlGap + 6),
                                _FirstStartRecommendationCard(
                                  profile: onboardingProfile,
                                  mode: state.preferences.preferredMode,
                                  itemCount: state.preferences.sessionItemLimit,
                                  compact: homeCompact,
                                  onStart: () => context.push(recommendedRoute),
                                  onPractice: () => context.go('/learn'),
                                ),
                              ],
                            ],
                            SizedBox(height: layout.sectionGap),
                            studyOverview(),
                            if (quickStudyPlan != null) ...[
                              SizedBox(height: layout.sectionGap),
                              _TwoMinuteStudyRow(
                                itemCount:
                                    quickStudyPlan.selectedItemIds.length,
                                compact: homeCompact,
                                onSchedule: () =>
                                    unawaited(scheduleTwoMinuteStudy()),
                                onStart: startTwoMinuteStudy,
                              ),
                            ],
                            ...personalizedSections,
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

class _SimpleHomeDetails extends StatelessWidget {
  const _SimpleHomeDetails({required this.summary, required this.child});

  final String summary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('home-simple-details'),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const Key('home-simple-details-toggle'),
        initiallyExpanded: false,
        maintainState: false,
        leading: Icon(
          Icons.dashboard_customize_outlined,
          color: colors.primary,
        ),
        title: const Text(
          '내 학습 현황 더보기',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [child],
      ),
    );
  }
}

List<HomeQuickAction> _simpleHomeQuickActions() {
  return const [HomeQuickAction.quickAdd, HomeQuickAction.importData];
}

class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions({
    required this.actions,
    required this.compact,
    required this.onSelected,
    this.maxActions = 3,
  });

  final List<HomeQuickAction> actions;
  final bool compact;
  final ValueChanged<HomeQuickAction> onSelected;
  final int maxActions;

  @override
  Widget build(BuildContext context) {
    final safeActions = <HomeQuickAction>[];
    for (final action in [...actions, ...defaultHomeQuickActions]) {
      if (!safeActions.contains(action)) safeActions.add(action);
      if (safeActions.length == maxActions) break;
    }
    return Semantics(
      container: true,
      label: '내 홈 빠른 행동',
      child: Material(
        key: const Key('home-custom-quick-actions'),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 4 : 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
              final columns =
                  MediaQuery.sizeOf(context).width < 360 || largeText
                  ? 2
                  : safeActions.length;
              final width =
                  (constraints.maxWidth - (columns - 1) * 6) / columns;
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (index, action) in safeActions.indexed)
                    SizedBox(
                      width: width,
                      child: FilledButton.tonalIcon(
                        key: Key('home-quick-action-$index-${action.name}'),
                        onPressed: () => onSelected(action),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          visualDensity: VisualDensity.standard,
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 6 : 10,
                          ),
                        ),
                        icon: Icon(action.icon, size: 18),
                        label: Text(
                          action.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FirstStartRecommendationCard extends StatelessWidget {
  const _FirstStartRecommendationCard({
    required this.profile,
    required this.mode,
    required this.itemCount,
    required this.compact,
    required this.onStart,
    required this.onPractice,
  });

  final OnboardingProfile profile;
  final StudyMode mode;
  final int itemCount;
  final bool compact;
  final VoidCallback onStart;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final details = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _RecommendationChip(
          icon: Icons.playlist_play_rounded,
          label: '첫 학습 · ${mode.label} $itemCount개',
        ),
        _RecommendationChip(
          icon: Icons.folder_special_outlined,
          label: profile.recommendedStarterGroupLabel,
        ),
        _RecommendationChip(
          icon: Icons.sports_esports_rounded,
          label: _recommendedGameLabel(profile.recommendedActivityId),
        ),
      ],
    );
    return Card(
      key: const Key('home-first-recommendation'),
      color: colors.primaryContainer.withValues(alpha: 0.32),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '내 시작 설정에 맞춘 첫 추천',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            details,
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  key: const Key('open-onboarding-game-recommendation'),
                  onPressed: onPractice,
                  icon: const Icon(Icons.sports_esports_rounded, size: 18),
                  label: const Text('게임 보기'),
                ),
                FilledButton.icon(
                  key: const Key('start-onboarding-queue'),
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('추천 학습 시작'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationChip extends StatelessWidget {
  const _RecommendationChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 17),
    label: Text(label),
    visualDensity: VisualDensity.compact,
  );
}

String _recommendedGameLabel(String id) => switch (id) {
  'pronunciation' => '말하기 연습',
  'production-writing' => '직접 쓰기',
  'meaning-choice' => '뜻 고르기',
  'words-review' => '단어 게임',
  _ => '혼합 퀴즈',
};

class _RecentAdditionsTray extends StatelessWidget {
  const _RecentAdditionsTray({
    required this.items,
    required this.onOpen,
    required this.onStudy,
    required this.onTrash,
    required this.onViewAll,
  });

  final List<LearningItem> items;
  final ValueChanged<LearningItem> onOpen;
  final ValueChanged<LearningItem> onStudy;
  final ValueChanged<LearningItem> onTrash;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('recent-additions-tray'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.new_releases_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '최근 추가한 자료',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${items.length}개',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                TextButton(
                  key: const Key('home-view-all-recent-additions'),
                  onPressed: onViewAll,
                  child: const Text('전체'),
                ),
              ],
            ),
            for (final item in items)
              ListTile(
                key: Key('recent-addition-${item.id}'),
                contentPadding: EdgeInsets.zero,
                minVerticalPadding: 4,
                minTileHeight: 48,
                visualDensity: VisualDensity.compact,
                leading: CircleAvatar(
                  child: Icon(
                    item.kind == LearningItemKind.word
                        ? Icons.text_fields_rounded
                        : Icons.notes_rounded,
                  ),
                ),
                title: Text(
                  PrivacyModeScope.redact(context, item.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  PrivacyModeScope.redact(context, item.primaryTranslation),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onOpen(item),
                trailing: Wrap(
                  spacing: 2,
                  children: [
                    IconButton(
                      tooltip: PrivacyModeScope.enabledOf(context)
                          ? '숨긴 자료 바로 학습'
                          : '${item.text} 바로 학습',
                      onPressed: () => onStudy(item),
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                    IconButton(
                      tooltip: PrivacyModeScope.enabledOf(context)
                          ? '숨긴 자료 휴지통으로 이동'
                          : '${item.text} 휴지통으로 이동',
                      onPressed: () => onTrash(item),
                      icon: const Icon(Icons.delete_outline_rounded),
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
        padding: const EdgeInsets.fromLTRB(10, 4, 6, 7),
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
                IconButton(
                  key: const Key('manage-home-pinned-collections'),
                  tooltip: '고정 컬렉션 관리',
                  onPressed: onManage,
                  icon: const Icon(Icons.tune_rounded, size: 19),
                ),
              ],
            ),
            SizedBox(
              height: 44,
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
                        ? '이 모음에 맞는 자료가 없어요'
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

class _TwoMinuteStudyRow extends StatelessWidget {
  const _TwoMinuteStudyRow({
    required this.itemCount,
    required this.compact,
    required this.onSchedule,
    required this.onStart,
  });

  final int itemCount;
  final bool compact;
  final VoidCallback onSchedule;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('two-minute-study-card'),
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 6, 6, 6),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, color: colors.primary, size: 21),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: '2분 취약·복습',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    TextSpan(
                      text: compact ? ' · $itemCount개' : ' · 표현 $itemCount개',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton(
              key: const Key('schedule-two-minute-study'),
              tooltip: '2분 학습 알림 저장',
              onPressed: onSchedule,
              icon: const Icon(Icons.notifications_outlined, size: 20),
            ),
            const SizedBox(width: 2),
            FilledButton(
              key: const Key('start-two-minute-study'),
              onPressed: onStart,
              style: FilledButton.styleFrom(
                minimumSize: const Size(60, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.standard,
              ),
              child: const Text('시작'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showFirstRunSetup({
  required BuildContext context,
  required LanguageTag language,
  required int dailyGoal,
  required OnboardingProfile profile,
  required ValueChanged<OnboardingProfile> onDraft,
  required ValueChanged<_FirstRunSelection> onComplete,
}) async {
  // Fuchsia keeps the compact legacy sheet as a conservative fallback. All
  // shipped targets use the resumable, previewable step flow.
  if (defaultTargetPlatform != TargetPlatform.fuchsia) {
    final seededProfile =
        profile.languageCode.isEmpty &&
            profile.draftStep == 0 &&
            !profile.deferred
        ? profile.copyWith(
            languageCode: language.code,
            dailyGoal: dailyGoal,
            dailyMinutes: switch (dailyGoal) {
              <= 50 => 3,
              <= 100 => 5,
              <= 150 => 10,
              _ => 15,
            },
          )
        : profile;
    final result = await showOnboardingSetupDialog(
      context: context,
      initialLanguage: language,
      initialProfile: seededProfile,
      onDraft: onDraft,
    );
    if (result != null && context.mounted) {
      onComplete(_FirstRunSelection.fromResult(result));
    }
    return;
  }
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
}

extension on _FirstRunLevel {
  String get label => switch (this) {
    _FirstRunLevel.beginner => '처음',
    _FirstRunLevel.intermediate => '기초 경험 있음',
    _FirstRunLevel.advanced => '중급 이상',
  };
}

class _FirstRunSelection {
  const _FirstRunSelection({
    required this.language,
    required this.dailyGoal,
    required this.purpose,
    required this.level,
    required this.entry,
    this.savedProfile,
  });

  factory _FirstRunSelection.fromResult(OnboardingSetupResult result) {
    final profile = result.profile;
    return _FirstRunSelection(
      language: result.language,
      dailyGoal: profile.dailyGoal,
      purpose: switch (profile.purpose) {
        LearningPurpose.dailyConversation => _FirstRunPurpose.routine,
        LearningPurpose.travel => _FirstRunPurpose.conversation,
        LearningPurpose.hobby => _FirstRunPurpose.vocabulary,
        LearningPurpose.work || LearningPurpose.exam => _FirstRunPurpose.exam,
      },
      level: switch (profile.level) {
        SelfAssessedLevel.beginner => _FirstRunLevel.beginner,
        SelfAssessedLevel.elementary ||
        SelfAssessedLevel.intermediate => _FirstRunLevel.intermediate,
        SelfAssessedLevel.advanced => _FirstRunLevel.advanced,
      },
      entry: profile.entryChoice == OnboardingEntryChoice.importMyData
          ? _FirstRunEntry.importData
          : _FirstRunEntry.sample,
      savedProfile: profile,
    );
  }

  final LanguageTag language;
  final int dailyGoal;
  final _FirstRunPurpose purpose;
  final _FirstRunLevel level;
  final _FirstRunEntry entry;
  final OnboardingProfile? savedProfile;

  StudyMode get preferredMode => switch (onboardingProfile.purpose) {
    LearningPurpose.dailyConversation => StudyMode.mixed,
    LearningPurpose.travel => StudyMode.sentences,
    LearningPurpose.work => StudyMode.production,
    LearningPurpose.exam => StudyMode.meaning,
    LearningPurpose.hobby => StudyMode.words,
  };
  int get newItemLimit => switch (onboardingProfile.level) {
    SelfAssessedLevel.beginner => 10,
    SelfAssessedLevel.elementary => 8,
    SelfAssessedLevel.intermediate => 6,
    SelfAssessedLevel.advanced => 5,
  };
  int get sessionItemLimit => switch (dailyGoal) {
    <= 50 => 5,
    <= 100 => 10,
    <= 150 => 15,
    _ => 20,
  };

  OnboardingProfile get onboardingProfile =>
      savedProfile ??
      OnboardingProfile(
        languageCode: language.code,
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
        dailyGoal: dailyGoal,
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
    required this.resuming,
    required this.onPressed,
    required this.onDismiss,
  });

  final bool compact;
  final LanguageTag language;
  final int dailyGoal;
  final bool resuming;
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
                  ? resuming
                        ? '설정 이어하기'
                        : '첫 학습 루틴'
                  : compact
                  ? resuming
                        ? '첫 학습 설정 이어하기'
                        : '첫 학습 루틴 설정'
                  : resuming
                  ? '저장한 곳부터 학습 설정을 이어가세요'
                  : '1분이면 내 학습 루틴을 만들 수 있어요',
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
                    Text('처음 학습 설정', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Text(
                      '다섯 가지만 골라 주세요. 로그인 없이 바로 시작할 수 있어요.',
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
            description: '언어마다 자료와 학습 기록을 따로 관리해요.',
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
            description: '목적에 맞는 학습 방식을 먼저 추천해 드려요.',
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
            description: '처음 보여 줄 새 자료의 양을 맞춰요.',
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
            description: '문제 수와 목표는 설정에서 언제든 바꿀 수 있어요.',
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
            description: '샘플로 둘러보거나 내 자료를 바로 가져올 수 있어요.',
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
                      '로그인 없이도 학습할 수 있어요. 백업하거나 다른 기기에서 이어볼 때만 Google을 연결하세요.',
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
    required this.showStreak,
    required this.showSyncStatus,
    required this.onSettings,
  });

  final bool compact;
  final DateTime now;
  final String subjectName;
  final String subjectSymbol;
  final bool generalTopic;
  final String subtitle;
  final int streakDays;
  final bool connected;
  final bool showStreak;
  final bool showSyncStatus;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final date = '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일';
    return LayoutBuilder(
      key: const Key('home-header'),
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
            if (showStreak)
              _HeaderBadge(
                icon: Icons.local_fire_department_rounded,
                label: '$streakDays일',
                color: AppTheme.warning,
                tooltip: '연속 학습 $streakDays일',
                showLabel: !narrow,
              ),
            const SizedBox(width: 8),
            _HeaderBadge(
              key: const Key('home-settings'),
              icon: showSyncStatus
                  ? connected
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded
                  : Icons.settings_rounded,
              label: showSyncStatus && connected ? '저장됨' : '설정',
              color: showSyncStatus && connected
                  ? AppTheme.success
                  : Theme.of(context).colorScheme.outline,
              tooltip: showSyncStatus && connected
                  ? 'Google Drive 및 설정 열기'
                  : '설정 열기',
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

class _WeeklyTargetSummaryCard extends StatelessWidget {
  const _WeeklyTargetSummaryCard({
    required this.compact,
    required this.studiedDays,
    required this.targetDays,
    required this.studiedMinutes,
    required this.targetMinutes,
    required this.progress,
    required this.onOpen,
  });

  final bool compact;
  final int studiedDays;
  final int targetDays;
  final int studiedMinutes;
  final int targetMinutes;
  final double progress;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final percent = (progress * 100).round();
    return Semantics(
      key: const Key('home-weekly-target-summary'),
      button: true,
      label:
          '주간 목표 달성률 $percent퍼센트. 학습일 $studiedDays/$targetDays일. '
          '학습 분량 $studiedMinutes/$targetMinutes분.',
      child: Material(
        key: const Key('home-weekly-target-summary-row'),
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 48 : 56),
            child: Row(
              children: [
                SizedBox(width: compact ? 10 : 12),
                Icon(
                  Icons.calendar_view_week_rounded,
                  color: colors.primary,
                  size: 20,
                ),
                SizedBox(width: compact ? 7 : 9),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (!compact)
                          const TextSpan(
                            text: '이번 주  ',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        TextSpan(
                          text:
                              '$studiedDays/$targetDays일 · '
                              '$studiedMinutes/$targetMinutes분',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                SizedBox(
                  width: compact ? 56 : 76,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                SizedBox(width: compact ? 6 : 8),
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
                SizedBox(width: compact ? 2 : 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyHero extends StatelessWidget {
  const _DailyHero({
    required this.compact,
    required this.action,
    required this.showXp,
    required this.dailyXp,
    required this.dailyGoal,
    required this.level,
    required this.accountTotalXp,
  });

  final bool compact;
  final _HomeNextAction action;
  final bool showXp;
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
        padding: EdgeInsets.all(compact ? 14 : 22),
        child: Row(
          children: [
            if (!compact && showXp) ...[
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
                    maxLines: compact ? 1 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onPrimaryContainer.withValues(alpha: 0.82),
                    ),
                  ),
                  if (showXp) ...[
                    const SizedBox(height: 4),
                    Text(
                      key: const Key('home-xp-summary'),
                      compact
                          ? '오늘 $dailyXp/$dailyGoal XP · Lv.$level · 누적 $accountTotalXp'
                          : '오늘 $dailyXp/$dailyGoal XP · 계정 레벨 $level · '
                                '누적 $accountTotalXp XP',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onPrimaryContainer.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                  ],
                  if (compact && showXp) ...[
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
                  SizedBox(height: compact ? 10 : 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      key: const Key('home-primary-study-button'),
                      onPressed: action.onPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.onPrimaryContainer,
                        foregroundColor: colors.primaryContainer,
                        minimumSize: Size(compact ? 0 : 150, compact ? 44 : 48),
                        visualDensity: VisualDensity.standard,
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
    required this.compact,
    required this.reviewCount,
    required this.newCount,
    required this.weakCount,
    required this.isStudyDay,
    required this.nextStudyDate,
  });

  final bool compact;
  final int reviewCount;
  final int newCount;
  final int weakCount;
  final bool isStudyDay;
  final DateTime nextStudyDate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('home-today-plan'),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, compact ? 5 : 8, 12, compact ? 5 : 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact || !isStudyDay) ...[
              Row(
                children: [
                  if (!compact)
                    Text(
                      '오늘의 학습',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  if (!compact) const Spacer(),
                  if (!isStudyDay)
                    Container(
                      key: const Key('home-rest-day-banner'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '쉬는 날 · 다음 학습 ${nextStudyDate.month}/${nextStudyDate.day}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
            ],
            Row(
              key: const Key('home-today-plan-summary-row'),
              children: [
                Expanded(
                  child: _PlanMetric(
                    key: const Key('home-plan-review-summary'),
                    icon: Icons.replay_rounded,
                    label: '복습 예정',
                    count: reviewCount,
                    color: AppTheme.desktopPrimary,
                  ),
                ),
                _SummaryDivider(color: colors.outlineVariant),
                Expanded(
                  child: _PlanMetric(
                    key: const Key('home-plan-new-summary'),
                    icon: Icons.auto_awesome_rounded,
                    label: '새 표현',
                    count: newCount,
                    color: AppTheme.mobilePrimary,
                  ),
                ),
                _SummaryDivider(color: colors.outlineVariant),
                Expanded(
                  child: _PlanMetric(
                    key: const Key('home-plan-weak-summary'),
                    icon: Icons.bolt_rounded,
                    label: '집중 필요',
                    count: weakCount,
                    color: AppTheme.warning,
                  ),
                ),
              ],
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

class _PlanMetric extends StatelessWidget {
  const _PlanMetric({
    super.key,
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
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: color);
  }
}
