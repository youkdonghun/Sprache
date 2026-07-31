# 아키텍처

## 시스템 경계

```text
Flutter Android / Windows
  ├─ UI + Riverpod
  ├─ 순수 Dart 학습 엔진
  ├─ 앱 전용 Drift SQLite: 유일한 작업 원본
  ├─ 플랫폼 TTS
  ├─ 로컬 보관 어댑터
  │   ├─ Windows 파일시스템
  │   └─ Android Storage Access Framework
  ├─ Google 인증 및 Drive 어댑터
  └─ OS 보안 저장소
          │
          ├── 사용자 지정 Sprache 폴더: Google 미연결 시 자동 미러
          ├── Google Drive: 연결 시 기기 간 동기화 대상
          └── Fastify API on Railway
                  ├── PostgreSQL: account_key ↔ Drive Folder ID
                  └── Windows OAuth 토큰 교환 중계(무저장)
```

학습은 네트워크와 분리한다. 문제 응답은 SQLite에 즉시 기록하고 세션 종료, 앱 비활성화, 수동 요청, 로그아웃 전에 묶어서 동기화한다.

SQLite는 Google 또는 로컬 폴더 연결 상태와 관계없이 유일한 실시간 작업 원본이다.
Google Drive가 연결되지 않았으면 사용자가 선택한 `Sprache` 폴더에
`segmented-v1` 데이터셋과 전체 복원 백업을 자동 미러한다. Drive 연결이
성공하면 Drive가 활성 동기화 대상이 되고 로컬 폴더 설정은 연결 해제 때 다시
쓸 fallback으로만 유지한다. 일시적인 Drive 오류는 로컬 폴더로 자동 전환하지
않고 SQLite의 업로드 대기열과 Drive 재시도 흐름으로 처리한다. 상세 전환·복원
규칙은 [로컬 저장과 저장 대상 전환](local-storage.md)에 기록한다.

Excel·CSV·JSON·JSONL 가져오기는 파일·행·열·셀·생성 항목 한도를 먼저
검사하고 별도 실행 스레드에서 파싱한다. 검토가 끝난 항목은 전체를 다시
검증한 뒤 사용자 콘텐츠, tombstone, 가져오기 이력을 한 SQLite transaction으로
저장한다. 실패하면 Riverpod 화면 상태도 갱신하지 않아 같은 검토 결과를 안전하게
재시도할 수 있다.

앱 시작은 일반 ProviderScope보다 앞선 DB 부트스트랩을 거친다. SQLite 헤더와
`user_version`을 먼저 확인하고, migration이 필요하면 DB·WAL·SHM을 보존한
뒤에만 Drift를 연다. 미래 schema, 손상 헤더, migration 실패는 일반 앱을 만들지
않고 읽기 전용 복구 화면으로 전환한다. 이 화면은 원본 초기화나 삭제 없이
checksummed 복구 ZIP 저장과 재시도만 제공한다.

Drive 동기화는 `canonical-v1` manifest가 가리키는 단일
`state/snapshot.json` 파일 ID를 사용한다. 프로필·설정·진도·사용자 콘텐츠와
세션은 snapshot schema v2 한 파일에 함께 저장하고, 이후 push도 같은 파일 ID를
제자리 갱신한다. 기존 단일 schema v1 snapshot과 `segmented-v1` 여섯 섹션은
계속 읽으며, 병합이 끝난 다음 정상 push에서만 canonical 레이아웃으로 전환한다.
전환 전 실패 시 기존 manifest가 계속 authoritative하고, 전환 후 manifest
커밋 실패 시 snapshot 바이트를 직전 검증본으로 복구한다.

이전 Drive 섹션과 로컬 DB 복구 사본은 자동 정리하지 않는다. 사용자가 설정에서
30일 이상 지난 후보를 직접 선택해야 하며, Drive는 삭제 직전 manifest를 다시
검증해 현재 참조 파일을 보호하고 영구 삭제 대신 휴지통으로 이동한다. 로컬 사본은
크기·수정 시각·루트 경계를 재검증한 뒤 명시적 확인을 거쳐 영구 삭제한다.

Windows는 시스템 브라우저의 경로 없는 동적 loopback과 PKCE로 인증 코드를 받는다.
Google 데스크톱 클라이언트의 Client Secret은 EXE에 포함하지 않고 Railway sealed
variable에만 둔다. Railway는 인증 코드 또는 refresh token을 Google 토큰 엔드포인트로
중계하고 응답을 즉시 클라이언트에 돌려줄 뿐, 요청·응답 토큰을 PostgreSQL이나 로그에
저장하지 않는다. 앱은 연결 전에 `/health`의 `desktopOAuthBroker` 상태를 확인하므로
서버가 준비되지 않았을 때 불필요한 Google 로그인 창을 열지 않는다.

## 다국어 코스

- 기본 언어는 `ko`이며 코스는 `ko-en`, `ko-ja`, `ko-de`, `ko-fr`, `ko-es`, `ko-zh-Hans`다.
- 진도, 오늘의 큐, 일일 목표는 코스별이다.
- XP, 계정 레벨, 연속 학습일, 배지는 전체 코스에 걸쳐 합산한다.
- UI 문자열은 첫 버전에서 한국어만 제공하며 학습 콘텐츠 언어와 분리한다.

## 플랫폼 UI

- Android는 큰 터치 목표, 짧은 세션, 애니메이션 피드백, XP와 배지를 강조한다.
- Windows는 좌측 사이드바와 키보드 중심 조작을 제공한다.
- Windows 창은 최소 compact, 일반, 확장 레이아웃으로 전환되며 항상 크기 조절 가능하다.
- compact 모드는 작은 창에서도 오늘의 문제, 답안, 진행률만 남겨 업무 도구처럼 보이도록 한다.
