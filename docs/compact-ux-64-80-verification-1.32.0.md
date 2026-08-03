# Sprache 1.32.0 컴팩트 UX 검증 — 64~80

## 목표

학습 허브와 세션 설정을 짧게 훑고 바로 시작할 수 있도록 17개 개선을 적용했다. Duolingo Practice Hub의 추천 우선 구조, Drops의 짧은 세션 진입, Babbel의 복습 형식 선택 원칙을 Sprache의 Local-First 데이터와 기존 사용자 설정에 맞게 재구성했다. 모든 실행 컨트롤은 최소 44px 목표를 유지한다.

## 64~80 구현 및 증거

| 번호 | 개선 목표 | 코드 증거 | 테스트 증거 |
|---:|---|---|---|
| 64 | 모바일 학습 헤더에서 설명 문단을 없애고 제목·코스·자료 수를 두 줄로 압축 | `LearningHubScreen`의 compact header와 12px gutter | `navigation_compaction_test.dart`의 주제 전환 검증 |
| 65 | 고정 컬렉션을 제목+목록 대신 44px 의미론적 가로 레일로 축소 | `_PinnedCollectionsRow`, `learning-hub-pinned-collections` | `navigation_compaction_test.dart`의 pinned collection 흐름 |
| 66 | 최근 세션을 짧은 2줄 요약과 명시적 `다시` 동작으로 변경 | `_RecentSubjectSessionCard`, `reopen-recent-subject-session` | 기존 recent configuration 회귀 테스트 |
| 67 | 일반 퀴즈 목록보다 개인화 추천을 먼저 표시 | `_PracticeCatalogState.build`의 `PersonalizedPracticeHub` 선행 배치 | `compact_practice_64_80_test.dart`의 요소 Y축 순서 검증 |
| 68 | Practice Hub 추천 캐러셀을 98px에서 88px로 줄이고 중복 설명을 제거 | `_PersonalizedPracticeHub`, `personalized-practice-hub` | `practice_catalog_workflow_test.dart`의 88px 검증 |
| 69 | 오늘의 도전을 34px 아이콘과 한 줄 보조 문구로 압축 | `_DailyChallengeCard` | daily challenge 지속성 회귀 테스트 |
| 70 | 최근 게임을 44px 한 줄 레일로 올리고 마지막 규칙으로 즉시 재실행 | `_RecentPracticeRow`, `recent-practice-*` | `practice_autonomy_test.dart`의 recent relaunch 검증 |
| 71 | 즐겨찾는 게임을 큰 중복 카드 대신 44px 한 줄 레일로 올리고 저장 규칙으로 실행 | `_FavoritePracticeRow`, `favorite-practice-*` | `compact_practice_64_80_test.dart`의 우선 배치, 기존 즐겨찾기 지속성 테스트 |
| 72 | 게임 검색을 44px dense 입력으로 축소하고 한 번에 지울 수 있게 유지 | `practice-game-search`의 dense constraints와 suffix clear | `practice_catalog_workflow_test.dart`의 검색·지우기 흐름 |
| 73 | 적용 중인 시간·기술·정렬 조건 수를 필터 제목에 표시 | `_PracticeDiscoveryControls.activeFilterCount` | `compact_practice_64_80_test.dart`의 비기본 정렬 초기 상태 |
| 74 | 필터·정렬을 펼치지 않고 한 번에 기본값으로 복구 | `reset-practice-filters` | `compact_practice_64_80_test.dart`의 세 필드 기본값 검증 |
| 75 | 검색/필터 결과 개수를 live region으로 즉시 알림 | `practice-search-result-summary` | `compact_practice_64_80_test.dart`의 결과 요약 존재 검증 |
| 76 | 모바일 카테고리 설명을 생략하고 활성 활동 카드를 100px로 축소한다. 비활성 카드는 사용 불가 사유를 읽을 수 있도록 120px를 유지한다. | `_PracticeSectionHeader`, `_ActivityCard` | compact practice 및 navigation catalog 회귀 테스트 |
| 77 | 실행 시트 헤더를 줄이고 상단에 현재 규칙 `바로 시작`을 제공 | `practice-launch-use-current-rules`, `_finish` | `compact_practice_64_80_test.dart`의 above-the-fold 위치·실행 검증 |
| 78 | 자료 현황을 44px 레일로 합치고 3·5·10·15분 프리셋을 문제 수보다 먼저 표시 | `practice-launch-inventory-strip`, `practice-time-options` | `compact_practice_64_80_test.dart`의 44px·5분 추천 검증, 15분 회귀 테스트 |
| 79 | 게임별 고급 규칙을 한 번에 안전한 기본값으로 되돌림 | `reset-practice-rules`, `_resetRules` | `compact_practice_64_80_test.dart`의 난이도·이력 기본값 검증 |
| 80 | 맞춤 세션의 모바일 요약·빠른 프리셋 순서를 압축하고 적용된 세부 조건을 세어 한 번에 초기화 | `_MobileSessionSummary`, `_QuickSessionPresets`, `reset-session-advanced-settings` | `compact_practice_64_80_test.dart`의 높이·순서·세부 조건 초기화 검증 |

## 검증 명령

```powershell
dart analyze apps/client/lib/src/screens/learning_hub_screen.dart apps/client/lib/src/screens/session_builder_screen.dart apps/client/test/widget/compact_practice_64_80_test.dart
flutter test test/widget/compact_practice_64_80_test.dart test/widget/practice_catalog_workflow_test.dart test/widget/practice_autonomy_test.dart test/widget/session_builder_test.dart test/widget/navigation_compaction_test.dart
```

## 결과

- 관련 Dart 정적 분석: 오류·경고 없음
- 신규 64~80 위젯 검증: 3개 통과
- navigation compaction 회귀 검증: 11개 통과
- practice catalog/autonomy/session builder 인접 검증: 통과
- 라우트, 저장 포맷, Local-First 진도 데이터 계약 변경 없음
