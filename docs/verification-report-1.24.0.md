# Sprache 1.24.0 검증 보고서

검증일: 2026-07-30

## 저장 대상 정책

- 앱 전용 Drift SQLite를 Android와 Windows의 유일한 실시간 작업 원본으로
  유지한다.
- Google이 연결되지 않았으면 홈과 설정에서 사용자 관리 로컬 폴더 선택을
  안내한다.
- Windows는 사용자가 고른 파일시스템 폴더, Android는 지속 권한을 받은 SAF
  문서 트리 아래의 `Sprache` 폴더를 사용한다.
- 로컬 폴더에는 SHA-256과 바이트 길이를 검증한 `segmented-v1` 사본, 전체 복원
  archive와 실제로 반영한 가져오기 원본을 보관한다.
- Google Drive 연결과 최초 pull·merge·push가 성공한 뒤에는 Drive를 활성
  동기화 대상으로 사용한다. 로컬 폴더는 연결 해제 시 복귀할 기기별 fallback으로
  남기며 Drive 일시 오류 때 자동 분기하지 않는다.
- Railway PostgreSQL에는 HMAC 처리한 계정 키와 Drive 폴더 연결 정보만 저장하고
  단어, 문장, 그룹, 답안, 상세 진도와 OAuth 토큰은 저장하지 않는다.

## 데이터 유실 방지

- 기존 로컬 archive가 발견되면 `나중에`, `현재 데이터 사용`, `기존 저장본
  병합` 중 사용자가 선택하기 전까지 새 generation을 쓰지 않는다.
- 보류 결정은 재시작 뒤에도 유지하며 일시적인 폴더 읽기 오류로 자동 해제하지
  않는다.
- current/previous manifest가 참조하는 generation을 함께 보호한다. Android에서
  manifest 읽기·JSON·필드 구조가 하나라도 불완전하면 오래된 파일 정리를 전부
  건너뛴다.
- Drive 가져오기 원본은 원격 metadata 크기를 먼저 확인하고 기대 크기일 때만
  내려받아 SHA-256을 검증한다. 중단된 placeholder나 손상 파일은 같은 파일 ID에
  다시 올리고 업로드 후 재검증한다.
- Drive 또는 로컬 대상이 준비되지 않았으면 반영된 가져오기 원본을 앱 지원
  디렉터리 staging에 보관하고, 활성 대상이 준비된 뒤 성공한 항목만 제거한다.

## 연결 해제와 삭제

- `이 기기에서 연결 해제`: 이 기기의 Google 인증만 정리하고 로컬 폴더 미러를
  다시 활성화한다. Railway 바인딩과 Drive·로컬 파일은 유지한다.
- `계정–Drive 연결 기록 삭제`: Google 계정을 다시 확인한 뒤 이 기기의 인증과
  Railway의 HMAC 계정–Drive 폴더 매핑을 삭제한다. Drive·로컬 파일과 앱 DB는
  자동 삭제하지 않는다.
- 먼저 기기 연결을 해제한 상태에서도 Railway 연결 기록 확인·삭제에 접근할 수
  있다.

## 검증 결과

| 검사 | 결과 |
| --- | --- |
| Flutter 전체 테스트 | 433개 통과 |
| API Vitest | 14개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| API lint·build | 통과 |
| 시각 회귀 | 37개 통과 |
| 모바일 반응형 | 320·360·375·390·412·430px, 라이트·다크 통과 |
| Android 네이티브 | SAF Kotlin 컴파일 통과 |
| Windows 엔진 E2E | 380×520, 420×640, 1040×760 실행·전환·화면 이동 통과 |
| Windows 설치 smoke | 설치 0, 실행 응답 정상, 제거 0, 설치 폴더 제거 확인 |
| Railway·Google 준비 상태 | API 정상, `desktopOAuthBroker=ready`, Windows 로그인 준비 `True` |
| 릴리스 무결성 | Android ABI 3개, Windows ZIP 34개, 체크섬 3개, 정책 URL 포함 |

## 산출물

| 파일 | 크기 | SHA-256 |
| --- | ---: | --- |
| `Sprache-Android-1.24.0-google-debug-signed.apk` | 79,425,634 bytes | `e694e8502b4c2ad7421fea34720a09051587f0493ecc59664b26f249117d7068` |
| `Sprache-Windows-1.24.0-google-x64.zip` | 21,469,638 bytes | `0964de4fe66bc262c49a1c6213c99189bdecffe1a3dfb6ab72c5772bb333154e` |
| `Sprache-Windows-Setup-1.24.0-google-x64.exe` | 17,714,882 bytes | `1ef4f234b661643c1b2e6644e31ec2a7173ceb9dc96073ecbf7cf2ab8427bef6` |

## 남은 외부 검증

- APK는 실제 Google·Railway 설정이 들어간 직접 설치용 빌드지만 현재 Android
  Debug 인증서로 서명됐다. Play 배포 전 release keystore와 해당 OAuth SHA
  지문을 등록해야 한다.
- Windows 실행 파일과 설치본은 Authenticode 서명이 없다. 외부 배포 전 코드
  서명 인증서가 필요하다.
- Android SAF 제공자 권한 철회·재부팅·USB/SD 저장소 분리 오류 주입과 실제
  Google 계정의 Android↔Windows 교차 동기화는 물리 기기에서 최종 반복해야 한다.
- 운영 Railway의 실제 계정 바인딩 DELETE는 사용자 계정 확인이 필요한
  파괴적 동작이므로 자동 테스트에서 실행하지 않았다.
