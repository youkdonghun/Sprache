# Sprache 1.32.0 컴팩트 UX 31–46 검증

## 참고 원칙

- Duolingo의 Practice Hub처럼 홈에서는 여러 설명보다 **지금 할 한 가지 행동**을 먼저 보인다.
  - https://blog.duolingo.com/guide-to-duolingo-practice-hub/
- Drops의 새 홈처럼 **이어 하기와 추천 진입점**을 짧게 유지한다.
  - https://languagedrops.com/blog/welcome-to-your-brand-new-home
- Busuu의 Vocabulary Review처럼 **복습 상태와 이동 경로**를 한눈에 찾게 한다.
  - https://help.busuu.com/hc/en-us/articles/16941990776593-How-can-I-review-my-vocabulary
- Anki의 환경설정처럼 고급 선택은 보존하되 **빠른 기본값과 점진적 공개**를 제공한다.
  - https://docs.ankiweb.net/preferences.html

모든 변경은 기존 Local-First 저장 방식, 키, 라우트와 최소 44px 조작 영역을 유지한다.

## 구현 및 검증 내역

| 번호 | 개선 목표 | 코드 근거 | 테스트 근거 |
|---:|---|---|---|
| 31 | 홈 바깥 여백을 화면 밀도와 플랫폼에 맞춰 축소 | `home_screen.dart`의 `AppLayoutDensity`, `home-page-padding` | `home_personalization_regression_test.dart`의 컴팩트 밀도 여백 검사 |
| 32 | 모바일·컴팩트 밀도에서 홈 헤더를 짧은 제목과 한 줄 부제로 전환 | `homeCompact`가 `_HomeHeader.compact`에 연결 | 같은 테스트의 `오늘 체크리스트` 검사 |
| 33 | 홈 빠른 행동 3개를 중첩 카드 대신 44px 단일 도구 띠로 압축 | `_HomeQuickActions`, `home-custom-quick-actions` | 같은 테스트의 56px 이하 높이 및 `onboarding_home_integration_test.dart`의 순서 검사 |
| 34 | 컴팩트 홈의 주 학습 카드는 설명·XP 문구·간격을 축약 | `_DailyHero`의 컴팩트 한 줄 설명과 XP 요약 | `home_personalization_regression_test.dart`의 주 행동 44px 검사, 기존 `navigation_compaction_test.dart` 우선순위 검사 |
| 35 | 주간 목표를 48px 요약 행으로 줄이고 좁은 화면의 반복 제목 제거 | `_WeeklyTargetSummaryCard.compact` | `home_personalization_regression_test.dart`의 50px 이하 높이 검사 |
| 36 | 오늘 계획을 3개 지표 한 줄로 유지하고 평상시 제목 행을 생략 | `_TodayPlan.compact`, `home-today-plan-summary-row` | 같은 테스트의 60px 이하 높이 검사 |
| 37 | 2분 복습을 한 줄 행동 행으로 바꾸고 알림·시작 조작은 44px 유지 | `_TwoMinuteStudyRow` | `study_routine_workflow_test.dart`의 높이와 두 조작 영역 검사 |
| 38 | 홈 각 섹션 사이 간격을 밀도 토큰 하나로 통일 | `layout.sectionGap`을 개요·추천·개인화 섹션에 공통 적용 | 컴팩트 홈 위젯 테스트와 전체 오버플로 회귀 테스트 |
| 39 | 최근 추가 자료 홈 미리보기는 최신 3개만 보이고 `전체` 이동 제공 | `recentCustomItems.take(3)`, `home-view-all-recent-additions` | `home_personalization_regression_test.dart`의 최신 3개 검사 |
| 40 | 고정 컬렉션 헤더를 짧은 44px 관리 아이콘과 한 줄 칩 영역으로 축소 | `_HomePinnedCollections`, `manage-home-pinned-collections` | `navigation_compaction_test.dart`의 관리 툴팁·조작 영역 검사 |
| 41 | 확장형 Windows 사이드바의 검색·추가·도움말을 한 줄 도구 모음으로 통합 | `_SidebarUtilityToolbar`, `desktop-sidebar-utility-toolbar` | `responsive_shell_personalization_test.dart`의 동일 Y축 검사 |
| 42 | 840px 미만 데스크톱 창은 사이드바 대신 하단 탐색으로 전환해 본문 폭 확보 | `showSidebar` 840px 분기 | 같은 테스트의 820px Windows 셸 검사 |
| 43 | 사이드바 하단 주제와 저장 상태를 두 줄에서 한 줄로 통합 | `_DesktopSidebar`의 `언어 · 저장 상태` | 같은 테스트의 단일 `Text` 검사 |
| 44 | 터치 기기에서 키보드 도움말 크롬을 숨기고 상단 검색·빠른 추가 실측 높이를 44px 이상으로 복구 | `_SubjectContextBar.showKeyboardHelp`, 최소 54px 컨텍스트 바 | 같은 테스트 및 `global_search_palette_test.dart`, `global_quick_add_recent_items_test.dart`의 44px 검사 |
| 45 | 컴팩트 밀도의 모바일 하단 탐색 높이를 60px로 고정 | `NavigationBar.height`의 `layout.dense` 분기 | `responsive_shell_personalization_test.dart`의 60px 검사 |
| 46 | 홈·내비게이션 섹션 안에서 관련 컴팩트 구성을 한 번에 적용 | `apply-compact-home-layout`, `apply-compact-navigation` | `personalization_panel_test.dart`의 집중 홈·선택 라벨·간단 주제 전환기 검사 |

## 집중 검증 명령

```text
flutter test test/widget/home_personalization_regression_test.dart
flutter test test/widget/responsive_shell_personalization_test.dart
flutter test test/widget/personalization_panel_test.dart
flutter test test/widget/onboarding_home_integration_test.dart
flutter test test/widget/study_routine_workflow_test.dart
flutter test test/widget/navigation_compaction_test.dart
flutter test test/widget/global_search_palette_test.dart
flutter test test/widget/global_quick_add_recent_items_test.dart
dart analyze lib test
```

## 검증 결과

- 홈·셸·개인화·온보딩·2분 복습·검색·빠른 추가 집중 묶음: **35/35 통과**
- 탐색·학습 진입 통합 묶음: **11/11 통과**
- 집중 위젯 테스트 합계: **46/46 통과**
- `dart analyze lib test`: **No issues found**
- `git diff --check`(31–46 관련 파일): **통과**
