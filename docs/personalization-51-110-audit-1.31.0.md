# Sprache 1.31.0 목표 51–110 구현 감사

## 감사 결과

- 범위: 등록 템플릿·대량 입력, 검색·자료실, 게임 자율성, 온보딩, 적응형 세션, 통계 목표 60개
- 결과: **60/60 구현 확인, 60/60 targeted 검증 통과**
- 감사 중 보강: 목표 55, 57, 58, 59, 79, 106, 107의 부분 구현을 계획 문구와 일치하도록 최소 보강했다.
- 데이터 원칙: 검색 기록·등록 템플릿은 기기 로컬 설정에 유지하며, 도전 점수는 SRS 진도나 XP를 변경하지 않는다.

## 목표별 증빙

| # | 확인한 동작 | 구현 증빙 | 검증 증빙 |
|---:|---|---|---|
| 51 | 종류·그룹·태그·품사·즐겨찾기·우선순위 템플릿을 주제별 로컬 저장 | `quick_content_preferences.dart`의 `QuickContentTemplate`, `QuickContentLocalPreferences.saveTemplate`; `study_store.dart` 로컬 설정 저장 | `quick_content_preferences_test.dart`의 `named templates persist metadata...` |
| 52 | 생성·이름 변경·복제·삭제·고정·정렬 순서를 제공 | `renameTemplate`, `duplicateTemplate`, `toggleTemplatePinned`, `deleteTemplate`, `orderedTemplates`; `quick_content_sheet.dart` 템플릿 메뉴·정렬 컨트롤 | `quick_content_preferences_test.dart`의 `templates can be renamed...`; `quick_content_workbench_test.dart` 템플릿 메뉴 테스트 |
| 53 | 템플릿 적용 시 표현과 뜻을 보존 | `quick_content_sheet.dart`의 `_applyTemplate`은 메타데이터 컨트롤만 갱신 | `quick_content_workbench_test.dart`의 `template applies metadata, preserves source fields...` |
| 54 | 최대 50개 로컬 등록 바구니와 일괄 저장 | `_basket`, `_addToBasket`, `_saveBasket`, `_QuickRegistrationWorkbench` | `quick_content_workbench_test.dart`의 바구니 6개 저장 테스트 |
| 55 | 각 바구니 항목에 필수·읽기·토큰·중복 상태 배지 | `_BasketStatusBadge`, `quick-content-basket-status-*`; 검증된 토큰 수와 신규/병합 상태 표시 | `quick_content_workbench_test.dart`의 `필수 완료`, `읽기 없음`, `단어`, `신규` 배지 검증 |
| 56 | 그룹·태그·즐겨찾기·우선순위를 바구니 전체에 적용 | `_applyCurrentOptionsToBasket` | `quick_content_workbench_test.dart`의 6개 항목 메타데이터 일괄 적용 검증 |
| 57 | 기존/신규 뜻·읽기·예문·태그를 나란히 비교 | `_DuplicateNotice`, `_DuplicateSide`, `_DuplicateField` | `quick_content_workbench_test.dart`의 중복 양쪽 카드와 네 필드 검증 |
| 58 | 병합 전 추가·유지·충돌 필드 요약 | `_duplicateMergeSummary`, `_MergeSummaryChip`, `quick-content-merge-summary-*` | `quick_content_workbench_test.dart`의 뜻 추가 및 예문 충돌 검증 |
| 59 | Enter 다음, Shift+Enter 이전, 마지막 필드 Enter 저장 | `_detailsExpanded`, 각 입력의 `TextInputAction.next`, 전역 Shift+Enter, 태그 `done` 저장 | `quick_content_workbench_test.dart`의 포커스 왕복 및 `Enter on the last detail field...` |
| 60 | 최근 등록·병합 5회 세션 실행 취소 | `_sessionUndo.take(5)`, `AppController.undoQuickContentSave`의 충돌 안전 토큰 | `quick_content_workbench_test.dart`의 5개 undo chip 및 복원 검증 |
| 61 | 전체/주제별 최근 검색 최대 20개, 개별 삭제 | `search_preferences.dart`의 `SearchLocalPreferences`, `_safeRecentSearches`, remove 메서드 | `search_preferences_test.dart`의 제한·중복 제거·삭제·손상 복구 테스트 |
| 62 | 빈 검색창의 최근 검색·자주 쓰는 태그 제안 | `library_screen.dart`의 `recentSearches`, `availableTags`; `global_search_palette.dart` 추천 패널 | `search_ux_widget_test.dart`의 자료실/전역 palette 제안 테스트 |
| 63 | `tag:`·`type:`·`state:`·`group:` 연산자 | `local_search_query.dart`의 `LocalSearchQuery.parse`, `localSearchItemMatches` | `local_search_query_test.dart`의 quoted operator 및 조합 필터 테스트 |
| 64 | 표현·뜻·읽기·태그 일치 구간 강조 | `searchHighlightRanges`; `highlighted_search_text.dart`; 자료실·전역 결과 적용 | `local_search_query_test.dart`의 원문 위치 보존, `search_ux_widget_test.dart` 강조 검증 |
| 65 | 결과 없음 시 로컬 카탈로그 유사어 제안 | `suggestSimilarSearches`의 제한된 Levenshtein 후보 계산 | `local_search_query_test.dart` 및 `search_ux_widget_test.dart` typo recovery 테스트 |
| 66 | 전역 결과 점수순/주제별 묶음 전환 | `GlobalSearchResultLayout`, `global_search_palette.dart`의 결과 layout 선택·저장 | `search_ux_widget_test.dart`의 grouping 전환 검증 |
| 67 | 데스크톱 목록–상세 2단 구조와 선택 보존 | `library_screen.dart`의 `_detailItemId`, `desktopMasterDetail`, 상세 pane | `library_multiview_workflow_test.dart`의 Windows/macOS view mode별 선택 보존 테스트 |
| 68 | 모바일 상세에서 필터 결과 이전·다음 이동 | `mobile-detail-previous`, `mobile-detail-next`와 현재 filtered item 목록 | `library_multiview_workflow_test.dart`의 모바일 이전·다음 테스트 |
| 69 | 필터 전체·현재 페이지·반전·숨은 선택 수 | `_selectItems`, `_invertItems`, `hiddenSelectedCount`, bulk selection bar | `library_multiview_workflow_test.dart`의 page/filter/inversion/hidden count 테스트 |
| 70 | 여유·컴팩트·격자 보기 저장 | `LibraryViewMode`, `_setLibraryViewMode`, `_LibraryViewModeControl` | `search_preferences_test.dart` round-trip 및 `library_multiview_workflow_test.dart` 3모드 테스트 |
| 71 | 3·5·10분·무제한 게임 필터 | `PracticeDurationFilter`, 학습 허브 duration filter | `practice_catalog_preferences_test.dart` round-trip 및 `practice_autonomy_test.dart` 필터 테스트 |
| 72 | 읽기·쓰기·듣기·말하기·암기 기술 필터 | `PracticeSkillFilter`, 활동 skill metadata | `practice_autonomy_test.dart` discovery filter 테스트 |
| 73 | 추천·최근·실행 횟수·이름 정렬과 횟수 저장 | `PracticeCatalogSort`, `launchCountByActivityId`, `recordActivity` | `practice_catalog_preferences_test.dart` bounded counts; `practice_autonomy_test.dart` 정렬 검증 |
| 74 | 추천을 오늘/7일 숨기고 복원 | `snoozeRecommendation`, `recommendationSnoozedUntilByActivityId`, 허브 메뉴 | `practice_catalog_preferences_test.dart` snooze round-trip; `practice_autonomy_test.dart` 추천 제어 |
| 75 | 더 보기/덜 보기 추천 가중치 | `adjustRecommendationWeight`의 -3…3 제한과 허브 추천 ranking | 동일 두 practice 테스트의 weight 저장·UI 반영 검증 |
| 76 | 깜짝 게임 기술·시간·최근/즐겨찾기 조건 | `surpriseDurationFilter`, `surpriseSkillFilter`, `surpriseFavoritesOnly`, `surpriseAvoidRecent`, `_openSurpriseGame` | `practice_catalog_preferences_test.dart` round-trip; `practice_autonomy_test.dart` surprise rule 테스트 |
| 77 | 최근 게임의 마지막 규칙 즉시 재실행 | `recentActivityIds`, `launchFor`, 허브 최근 실행 action | `practice_autonomy_test.dart`의 `recent game relaunches with its last rules...` |
| 78 | 매치·시간형 최고 점수/시간 로컬 저장 | `PracticeBestRecord`, `recordBest`, 허브 `_bestRecordLabel` | `practice_catalog_preferences_test.dart` 최고 점수·최단 시간 갱신 테스트 |
| 79 | 선택 도전 점수를 정확도 70·속도 20·힌트 10으로 계산·표시 | `PracticeChallengeScore.calculate`; `study_screen.dart`의 `completion-challenge-score`; 최고 기록에 합산 점수 저장 | `adaptive_study_session_test.dart`의 `challenge score combines...`; targeted analyze 통과 |
| 80 | 2–5개 게임 플레이리스트 저장·순차 실행 | `PracticePlaylist`, route allowlist, `_PracticePlaylistPanel`, playlist query/index | `practice_catalog_preferences_test.dart` allowlist/경계; `practice_autonomy_test.dart` 순차 시작 테스트 |
| 81 | 온보딩 6단계와 진행률 | `OnboardingProfile.stepCount`, `onboarding-progress`, 단계 panel | `onboarding_adaptive_flow_test.dart`의 short step/progress 테스트 |
| 82 | 미완료 선택 로컬 저장·재시작 복원 | `draftStep`, `saveOnboardingDraft`, `StudyPreferences.onboardingProfile` | `onboarding_profile_test.dart` round-trip; `onboarding_adaptive_flow_test.dart` saved draft resume |
| 83 | 이전·나중에·완료 결과·계정 없는 샘플 설명 | `onboarding-previous`, `onboarding-later`, 검토 단계의 account-free 문구 | `onboarding_adaptive_flow_test.dart` short flow 및 review result 테스트 |
| 84 | 언어·목적·수준·시간·시작 방식 최종 검토 | `onboarding_setup_dialog.dart`의 `_reviewAndPreview` | `onboarding_adaptive_flow_test.dart` review 단계 테스트 |
| 85 | 큰 버튼·고대비·무제한 시간 접근성 프로필 | `OnboardingAccessibilityProfile.easyAccess`; 완료 시 large text/high contrast/large controls 적용 | `onboarding_home_integration_test.dart` 완료 설정 적용 테스트 |
| 86 | 화면 모드·강조색 실제 미리보기 | `_accessibilityAndTheme`, `AppTheme.mobileFor`, `onboarding-theme-preview` | `onboarding_adaptive_flow_test.dart` saved appearance preview 테스트 |
| 87 | 시작 전 샘플 3개와 예상 시간 | `onboarding-sample-1..3`, 검토 단계 예상 시간 표시 | `onboarding_adaptive_flow_test.dart`의 `review shows three samples, estimate...` |
| 88 | 목적·수준을 첫 큐·그룹·게임 추천에 반영 | `recommendedActivityId`, `recommendedStarterGroupLabel`, `_FirstRunSelection.preferredMode/newItemLimit`; 완료 callback | `onboarding_profile_test.dart` 추천 매핑; `onboarding_home_integration_test.dart` 큐·게임 적용 |
| 89 | 학습일/휴식일을 홈 계획·알림에 반영 | `isStudyDay`, `nextStudyDate(Time)`; 홈 `home-rest-day-banner`; 알림 reconcile | `onboarding_profile_test.dart` rest-day 계산; `onboarding_home_integration_test.dart` 홈 휴식일 |
| 90 | 홈 빠른 행동 정확히 3개 선택·재배치 | `_normalizeQuickActions`, onboarding up/down, 홈 `home-custom-quick-actions` | 두 onboarding widget 테스트의 순서 변경·홈 반영 검증 |
| 91 | 응답 시간 메트릭을 선택 필드로 호환 저장 | `StudyAttemptMetric.responseTimeMs`; `StudySessionSummary`/`ActiveStudySession` JSON의 optional `attemptMetrics` | `adaptive_study_session_test.dart`의 legacy summary 및 metric round-trip |
| 92 | 뜻·쓰기·듣기·문장·발음 숙련도 집계 | `StudySkill`, `StudyMasterySnapshot.fromAttempts` | `adaptive_study_session_test.dart`의 five-skill aggregate 테스트 |
| 93 | 오답·응답 시간·숙련도로 다음 큐 선택 | `AdaptiveStudySessionEngine._adaptiveScore`, `_recommendedSkill`, `_reason` | `adaptive_study_session_test.dart`의 recent error/slow/weak 우선 테스트 |
| 94 | 적응형·균형·사용자 지정 전략과 이유 | `StudySessionStrategy`, runtime option sheet, `reasonByItemId` | `adaptive_study_session_test.dart` 전략 테스트; `adaptive_session_workflow_test.dart` UI 선택 |
| 95 | 정답 없이 유형·단어/문장 비율·이유 큐 미리보기 | `StudyQueuePreview`, `_StudyQueuePreviewSheet` | `adaptive_study_session_test.dart`의 answer-safe preview; widget workflow |
| 96 | 10·20·30분 휴식 알림과 안전한 pause | `StudyBreakSchedule`, `_scheduleBreakReminder`, active session pause | adaptive domain/runtime widget tests의 break 설정·pause 검증 |
| 97 | 읽기 보조를 현재 세션에만 변경 | `StudySessionRuntimeOptions.showKoreanReading/showNativeReading`; 세션 option sheet | `adaptive_session_workflow_test.dart`의 session-only reading 테스트 |
| 98 | TTS 속도를 현재 세션에만 변경 | `StudySessionRuntimeOptions.ttsRate`, `_speak`의 runtime rate | 동일 widget 테스트에서 전역 설정 불변 검증 |
| 99 | 입력 답안·선택·토큰 순서를 체크포인트 저장 | `StudyInputCheckpoint`, `_currentInputCheckpoint`, active session persistence | `adaptive_study_session_test.dart` checkpoint JSON; widget unfinished typed answer 테스트 |
| 100 | 재개 시 저장 시각과 입력/토큰 복원 또는 폐기 | `_showDraftRestoreChoice`, `inputCheckpoint.savedAt`, restore/discard 경로 | `adaptive_session_workflow_test.dart`의 restore/discard 테스트 |
| 101 | 7·30·90일·전체 기록 필터 | `LearningInsightRange`, `stats-range-filter` | `learning_insights_test.dart` range 경계; `stats_insights_workflow_test.dart` 필터 UI |
| 102 | 날짜별 학습·강도 접근 가능 캘린더 | `LearningInsightDay.intensityFor`, `accessible-study-calendar`의 Semantics/Tooltip | `learning_insights_test.dart` 7일 calendar; stats widget 테스트 |
| 103 | 기간별 XP 추세와 일일 목표 기준 | `_LearningTrendCard`의 최근 일별 XP progress와 `dailyGoal` | stats widget 테스트의 trend card 및 range 전환 검증 |
| 104 | 정확도 추세와 날짜별 표본 수 | `LearningInsightDay.accuracy/attempts`; 최근 추세에 `% (표본수)` 표시 | `learning_insights_test.dart` 정확도; stats widget trend 검증 |
| 105 | 실제 시작·종료로 학습 시간 계산 | `_MutableInsight.add`의 `endedAt.difference(startedAt)` 및 12시간 안전 경계 | `learning_insights_test.dart` 20분 합계·주간 분량 테스트 |
| 106 | 유형별 숙련도와 최근 정확도 변화 | `SkillLearningInsight.recentAccuracyChange`, `_MutableInsight._recentAccuracyChange`, UI `%p` | `learning_insights_test.dart`의 `reports recent skill change...`; stats widget 카드 |
| 107 | 주제별 학습량·정확도·복습량 비교 | `SubjectLearningInsight.reviewSessionCount`; subject card의 세션·분·문제·XP·정확도·복습 표시 | 동일 domain 테스트의 review count 및 stats widget subject card |
| 108 | 어려운 항목 이유·최근일·즉시 복습 | `HardestLearningItem`, `hardestItems`, `_HardestItemsCard` review action | `learning_insights_test.dart` 순위/이유/날짜; stats widget hard review route |
| 109 | 주간 일수·분량 목표와 홈/기록 달성률 | `weeklySessionGoalProgress`, `weeklyDurationGoalProgress`, `weeklyCombinedGoalProgress`; 홈/통계 목표 카드 | `learning_insights_test.dart`, `stats_insights_workflow_test.dart`, `daily_goal_scope_test.dart` |
| 110 | 학습 원문·ID 없는 개인정보 안전 CSV | `StudySummaryExporter.exportCsv`; stats `export-private-summary` | `learning_insights_test.dart`의 CSV metrics 포함 및 secret text/ID 미포함 검증 |

## 실행한 검증

```text
flutter analyze <이번 감사에서 변경한 lib/test 8개 파일>
→ No issues found

flutter test \
  test/domain/quick_content_preferences_test.dart \
  test/widget/quick_content_workbench_test.dart \
  test/domain/search_preferences_test.dart \
  test/domain/local_search_query_test.dart \
  test/widget/search_ux_widget_test.dart \
  test/widget/library_multiview_workflow_test.dart \
  test/domain/practice_catalog_preferences_test.dart \
  test/widget/practice_autonomy_test.dart \
  test/domain/onboarding_profile_test.dart \
  test/widget/onboarding_adaptive_flow_test.dart \
  test/widget/onboarding_home_integration_test.dart \
  test/domain/adaptive_study_session_test.dart \
  test/widget/adaptive_session_workflow_test.dart \
  test/domain/learning_insights_test.dart \
  test/widget/stats_insights_workflow_test.dart \
  test/widget/daily_goal_scope_test.dart
→ 70 tests passed
```

전체 visual/golden, 전체 Flutter suite, 플랫폼 빌드는 이 감사 범위에서 중복 실행하지 않고 상위 릴리스 검증 단계에 맡긴다.
