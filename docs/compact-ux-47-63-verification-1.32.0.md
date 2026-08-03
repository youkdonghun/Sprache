# Sprache 1.32.0 컴팩트 UX 47–63 검증

## 범위와 원칙

47–63번은 빠른 단어 등록, 중복 처리, 보관함 검색·필터·결과를 더 짧은 이동 거리로 다루는 17개 개선이다. Busuu의 저장 어휘 검색·복습 흐름과 Anki의 편집 화면처럼 자주 쓰는 동작은 바로 보이고, 고급 정보는 필요할 때 펼치는 점진 공개 원칙을 적용했다.

- 참고: [Busuu Vocabulary Review](https://help.busuu.com/hc/en-us/articles/16941990776593-How-can-I-review-my-vocabulary)
- 참고: [Anki Editing](https://docs.ankiweb.net/editing.html)
- Local-First 저장 구조와 기존 저장·실행 취소·중복 병합 로직은 변경하지 않았다.
- 아이콘 및 버튼의 Material 최소 터치 영역을 유지하고, 320px와 560px 경계·글자 200% 회귀 테스트를 통과했다.

## 17개 목표 및 증거

| 번호 | 완료 목표 | 코드 증거 | 테스트 증거 |
|---:|---|---|---|
| 47 | 보관함에서 메뉴를 거치지 않고 `단어 추가`를 한 번에 연다. 다른 추가 방식 메뉴는 옆에 유지한다. | `library_screen.dart`의 `_LibraryHeader.onQuickWord`, `library-quick-word-button`, `library-add-button` | `compact_registration_47_63_test.dart`의 `desktop library opens a compact word form in one tap` |
| 48 | 컴팩트 밀도에서는 빠른 등록의 설명 문장을 숨겨 헤더를 한 줄 줄인다. | `quick_content_sheet.dart`의 `if (!dense)` 헤더 설명 | 전체 직접 분석과 빠른 등록 7파일 회귀 묶음 |
| 49 | 데스크톱 모달에서 표현과 뜻을 같은 행에 배치하고 좁은 화면에서는 자동으로 세로 배치한다. | `quick-content-core-fields-inline`, 560px 적응형 분기 | 전용 테스트의 데스크톱 한 행 검증, 390px 전환 회귀 |
| 50 | 표현·뜻에 포인터로 누를 수 있는 즉시 지우기 버튼을 제공하되 키보드 포커스 순서는 방해하지 않는다. | `quick-content-clear-text`, `quick-content-clear-meaning`, `ExcludeFocus` | 전용 지우기 테스트, 기존 `Enter advances and Shift Enter moves focus backward` |
| 51 | 뜻 입력의 반복 도움말을 기본 화면에서 제거하고 필수 완료 상태를 작은 pill로 표시한다. 큰 글자에서는 문구도 축약한다. | `DelimitedChipInput.helperText`, `quick-content-required-progress`, `compactLargeText` | 기존 필수 진행 상태·320px/200% 테스트 |
| 52 | 문자·공백 정규화 제안을 최대 한 줄로 줄이고 `적용` 동작은 유지한다. | `_NormalizationNotice`의 한 줄 미리보기와 zero margin | 기존 `automatic normalization applies Unicode NFKC and whitespace` |
| 53 | 중복 감지를 긴 카드 대신 `같은 표현 · 새 뜻 N개` 한 줄 상태로 먼저 알린다. | `_DuplicateNoticeState`의 압축 헤더 | 전용 중복 점진 공개 테스트 |
| 54 | 기존/신규 자료의 상세 비교와 병합 필드 요약은 `비교`를 누를 때만 펼친다. | `quick-content-duplicate-details-toggle`, `quick-content-duplicate-details` | 전용 테스트, 갱신된 `duplicate preview compares existing and incoming meanings` |
| 55 | 뜻 병합·기존 열기·별도 저장 선택은 접지 않고 항상 보이며, 사용자의 기본 중복 정책을 함께 표시한다. | `quick-content-duplicate-default`, 기존 3개 동작 key 유지 | 전용 테스트와 기존 duplicate-default 3종 테스트 |
| 56 | 최근 그룹을 해제한 뒤 같은 그룹을 한 번에 다시 선택할 수 있다. | `quick-content-select-recent-group` | 전용 최근 그룹 테스트 |
| 57 | 선택된 그룹은 그룹 목록을 펼치지 않고 헤더에서 바로 해제한다. | `quick-content-clear-group` | 전용 최근/선택 그룹 왕복 테스트 |
| 58 | 새 그룹 이름 입력은 `새 그룹 만들기`를 누른 뒤에만 표시하고, 검색 결과가 없으면 검색어를 이름 후보로 재사용한다. | `_showNewGroupFields`, `quick-content-show-new-group`, `quick-content-new-group-fields` | 전용 점진 공개 테스트와 기존 추가→그룹→학습 흐름 |
| 59 | `추가 정보` 헤더가 실제 입력된 선택 항목 수를 보여 재확인 스크롤을 줄인다. | `detailFieldCount`, `N개 항목 입력됨` | 전용 예문 입력 후 카운트 테스트 |
| 60 | 넓은 화면에서 예문/예문 뜻과 즐겨찾기/우선순위를 각각 한 행으로 묶는다. | `quick-content-examples-inline`, `quick-content-preferences-inline` | 전용 테스트와 기존 즐겨찾기·우선순위 저장 테스트 |
| 61 | 데스크톱 하단의 학습·바구니·계속 추가·저장 동작을 세로 3단에서 한 행으로 합친다. | `quick-content-desktop-action-row`, 바구니 수 Badge | 전용 한 행 테스트와 기존 바구니·연속 등록 테스트 |
| 62 | 보관함 검색창에 결과 수와 지우기를 함께 표시하고, 검색 제안은 `복습할 자료`, `문장만`처럼 읽기 쉬운 이름을 쓴다. 필터별 자료 수와 활성 결과 학습도 한 행에서 확인한다. | `library-search-result-count`, `library-clear-search`, `library-filter-count-*`, `study-current-filter-results` | 전용 검색 문맥 테스트, 기존 검색 debounce·대량 선택 테스트 |
| 63 | 모바일 그룹 도구를 3행에서 2행으로 줄이고, 중복 수선 알림과 기본 결과 행의 높이도 낮춘다. 기존 그룹 chip key와 44px 동작 영역은 유지한다. | `_GroupToolbar` 모바일 헤더+동작 행, `_DuplicateRepairCard`, `_LibraryRow` padding/44px 아이콘 | 전용 중복 수선 높이 테스트, 기존 그룹 관리 3종·멀티뷰 테스트 |

## 검증 결과

- `dart analyze` 대상: 변경 구현·관련 테스트 — **No issues found**
- 전용 테스트: `compact_registration_47_63_test.dart` — **7/7 통과**
- 관련 회귀 묶음: 빠른 등록·개인화·중복·그룹·멀티뷰 7개 파일 — **42/42 통과**
- 전용 테스트를 포함한 전체 8개 파일 — **49/49 통과**
- 포함 회귀: Windows/macOS master-detail, Android 390px, 320px·560px 경계와 글자 200%, Shift+Enter 포커스, 45개 대량 선택·페이지 전환
