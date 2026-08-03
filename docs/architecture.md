# 아키텍처

## 현재 시스템 경계

```text
Flutter Android / Windows
  ├─ UI + Riverpod
  ├─ 순수 Dart 학습 엔진
  ├─ Drift SQLite: 유일한 실시간 작업 원본
  ├─ 플랫폼 TTS·음성 인식
  ├─ 로컬 보관 어댑터
  │   ├─ Windows 파일시스템
  │   └─ Android Storage Access Framework
  ├─ Google OAuth 공개 클라이언트
  │   ├─ Windows: 시스템 브라우저 + loopback + PKCE
  │   └─ Android: Google Identity 네이티브 흐름
  └─ OS 보안 저장소
          │
          ├── 사용자 지정 로컬 Sprache 폴더: 백업·미러
          ├── Google Drive WordStudyData: 선택적 기기 간 동기화
          └── Google Drive appDataFolder: WordStudyData 연결 포인터

GitHub Pages (/docs)
  └── 앱 소개·개인정보처리방침·서비스 이용약관 정적 파일
```

Sprache가 운영하는 API, Railway 서비스 또는 중앙 PostgreSQL은 현재 시스템
경계에 포함되지 않는다. GitHub Pages는 정적 문서만 전달하며 로그인 callback,
OAuth 토큰, 계정 정보나 학습 데이터를 받지 않는다.

## Local-First 저장

SQLite는 Google 또는 로컬 폴더 연결 상태와 관계없이 유일한 실시간 작업
원본이다. 문제 응답은 SQLite에 즉시 기록하고 세션 종료, 앱 비활성화, 수동
요청과 같은 안전한 시점에 미러 또는 Drive 동기화를 예약한다.

Google 연결 전에는 설정에서 사용자가 고른 로컬 `Sprache` 폴더에
`segmented-v1` 데이터셋과 전체 복원 백업을 미러할 수 있다. 이 경로는
Windows 폴더 선택기 또는 Android SAF로 명시적으로 바꾸며, 설정 화면에 실제
표시 경로와 `변경` 동작을 함께 제공한다.

Google을 처음 연결할 때 사용자가 Drive Picker에서 상위 폴더를 고르면 앱이 그
아래에 `WordStudyData`를 만들거나 기존 앱 폴더를 재사용한다. 학습 snapshot과
manifest는 이 일반 Drive 폴더에 저장한다. 설정에는 선택한 폴더 이름과
`Drive 위치 다시 선택` 동작을 함께 제공한다. 로컬 폴더 설정과 기존 파일은
삭제하지 않고 수동 백업과 연결 해제 시의 보존 대상으로 유지한다.

네트워크 단절, Drive API 오류, 토큰 갱신 실패는 SQLite의 `pending_syncs`와
가져오기 staging을 유지한 채 재시도한다. 일시적인 Drive 오류 때문에 서로 다른
저장 대상을 자동으로 오가거나 정상 로컬 데이터를 삭제하지 않는다. 로컬 형식,
manifest와 복원 충돌 규칙은 [로컬 저장과 저장 대상 전환](local-storage.md)을
참고한다.

## Google OAuth와 토큰 경계

Windows는 시스템 브라우저의 `127.0.0.1` 동적 loopback callback과 매 요청마다
새로 만든 PKCE `S256` verifier/challenge, 무작위 `state`를 사용한다. 받은
인증 코드는 앱이 Google의 `https://oauth2.googleapis.com/token`으로 직접
교환한다. 데스크톱 앱은 비밀을 안전하게 보관할 수 없는 공개 클라이언트이므로
client secret을 EXE, 저장소, 빌드 변수 또는 별도 서버에 두지 않는다.

Android는 같은 Google Cloud 프로젝트의 Android OAuth 클라이언트와 Google
Identity 네이티브 흐름을 사용한다. 두 플랫폼의 client ID는 공개 식별자지만,
토큰과 PKCE verifier는 로그에 남기지 않는다. refresh/access token과 계정 연결
메타데이터는 OS 보안 저장소에만 저장하며 연결 해제 시 이 기기의 자격 증명을
제거한다.

## Drive 학습 폴더와 `appDataFolder` 연결 포인터

두 플랫폼은 같은 Google Cloud 프로젝트의 공개 OAuth 클라이언트와 다음 두
범위를 함께 사용한다.

- `drive.file`: 사용자가 Picker로 고른 위치와 Sprache가 만든 `WordStudyData`
  폴더의 학습 파일만 읽고 쓴다.
- `drive.appdata`: 숨겨진 `sprache-binding-v1.json` 연결 포인터만 읽고 쓴다.

연결 포인터에는 `WordStudyData`의 폴더 ID, 폴더 이름, 포인터 schema와 갱신
시각만 둔다. snapshot, 단어, 진도, 계정 프로필이나 토큰은 넣지 않는다. 새
기기는 포인터의 폴더 ID로 일반 Drive의 앱 폴더를 다시 열고 manifest를 검증한다.
포인터가 없거나 구버전 권한이라면 `drive.file`로 접근 가능한 `WordStudyData`
후보를 검색하고, 검증 가능한 폴더가 정확히 하나일 때만 복원한다. 중복·손상·
미래 schema는 정상 로컬 자료를 덮어쓰지 않는다.

Drive 동기화 자료는 `WordStudyData` 안의 `canonical-v1` manifest가 가리키는
단일 snapshot 파일 ID를 사용한다. 프로필·설정·진도·사용자 콘텐츠와 세션을
한 검증 단위로 다루되, 이전 schema와 로컬 백업은 정상 병합과 새 manifest
커밋이 끝나기 전에 자동 삭제하지 않는다.

## 가져오기와 복구

Excel·CSV·JSON·JSONL 가져오기는 파일·행·열·셀·생성 항목 한도를 먼저
검사하고 별도 실행 스레드에서 파싱한다. 검토가 끝난 항목은 전체를 다시 검증한
뒤 사용자 콘텐츠, tombstone과 가져오기 이력을 한 SQLite transaction으로
저장한다. 실패하면 같은 검토 결과를 안전하게 재시도할 수 있다.

앱 시작 시 SQLite 헤더와 `user_version`을 먼저 확인한다. migration 전 DB,
WAL과 SHM을 보존하며 미래 schema, 손상 헤더 또는 migration 실패 시 원본을
초기화하지 않고 읽기 전용 복구 화면과 checksummed 복구 ZIP만 제공한다.

## 다국어 코스와 플랫폼 UI

- 기본 언어는 `ko`이며 코스는 `ko-en`, `ko-ja`, `ko-de`, `ko-fr`, `ko-es`,
  `ko-zh-Hans`다.
- 진도, 오늘의 큐와 일일 목표는 코스별이고 XP, 계정 레벨, 연속 학습일과
  배지는 전체 코스에 걸쳐 합산한다.
- Android는 큰 터치 목표, 짧은 세션, 애니메이션 피드백과 XP를 강조한다.
- Windows는 크기 조절 가능한 창, 사이드바와 키보드 중심 조작을 제공한다.
