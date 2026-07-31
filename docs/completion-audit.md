# Sprache 고도화 완료 조건 감사

기준일: 2026-07-30

이 문서는 목표 문장을 현재 코드와 테스트에 대조한 작업 목록이다. `완료`는 현재 저장소에 구현과 검증 증거가 모두 있는 경우에만 사용한다.

| 영역 | 상태 | 현재 증거 | 남은 작업 |
| --- | --- | --- | --- |
| 6개 언어와 언어별 진도 | 완료 | 언어별 120개·총 720개 카탈로그, 구조·출처·중복 테스트 | 원어민 감수는 별도 품질 작업 |
| 여섯 언어 읽기 표기 품질 | 완료 | 내장 720개 전부의 한국어 발음 보조표기, 대표 문장 6개 정확값과 NFKC 형식 검사, 언어별 오프라인 생성, 직접 입력·CSV/JSON/Excel 가져오기·백업 복원 검증 | 한국어 발음 표기의 원어민·한국어 화자 감수는 별도 품질 작업 |
| 범용 학습 주제 | 완료 | 사용자 주제 생성·수정·격리·항목 이동, Android 실측과 Windows UI 테스트 | 없음 |
| 범용 주제 발견성 | 완료 | 선택 주제 바로 옆 `새 주제` 고정 배치, 모바일 실측·라이트/다크 골든 | 없음 |
| Android·Windows 반응형 UI | 완료 | 375·390·412·430px 위젯/시각 테스트, Android 설정 라이트·다크·1.3배 글자와 412×915 연결 화면 실측, 실제 Windows 엔진 380×520·420×640·1040×760 홈·연습·설정 PNG와 release EXE 네이티브 크기·응답 검증 | 물리 기기 접근성 점검은 배포 단계에서 반복 |
| Windows 집중창·항상 위 | 완료 | `window_workspace_service.dart`, Windows 위젯 테스트 | 없음 |
| Windows 키보드 학습·검색 | 완료 | `Ctrl+F` 자료 검색, 선택형 방향키·숫자, 입력형 `Ctrl+Space`, 문장 배열 숫자·Backspace, 플래시카드 숫자키패드 위젯 테스트 | 없음 |
| 직접 단어·문장 CRUD | 완료 | `item_editor_screen.dart`, 편집·삭제 위젯 테스트 | 없음 |
| Excel·CSV·JSON·JSONL 가져오기 | 완료 | 간편 17열·전체 37열 Excel 자산, 여섯 언어 한국어 발음·예문 발음·중복 읽기 병합, 10,000행 CSV, 통합 파일·행·열·셀·생성 항목 한도와 가져오기 검토 UI 테스트 | Android 시스템 선택기의 1.22.2 템플릿 실기기 반복은 배포 단계에서 수행 |
| 대용량 가져오기·중단 복구 | 완료 | 백그라운드 분석 진행 표시, 전체 사전 검증, 메모리·SQLite 원자 저장, 실패 무반영·동일 검토 재시도 테스트 | 없음 |
| 로컬 DB 마이그레이션 복구 | 완료 | SQLite 헤더·미래 schema 선차단, migration 전 DB·WAL·SHM 보존, 읽기 전용 Android·Windows 복구 UI, checksummed ZIP과 실패 주입 테스트 | 자동 사본 보존 기간은 아래 정책 항목과 함께 결정 |
| 저장 공간 보존·사용자 정리 | 완료 | 자동 삭제 없음, 30일 기준, 로컬 크기·수정 시각 재검증, Drive manifest 참조 제외·삭제 직전 fingerprint 재검증·휴지통 이동, 모바일 UI 테스트 | 없음 |
| 출처 ID·URL·저자·표시 문구 보존 | 완료 | 도메인·가져오기·내보내기·Drift·Drive snapshot 테스트, Android 상세 화면 실측 | 없음 |
| 라이선스 웹 예문 팩 | 완료 | Tatoeba CC BY 2.0 FR 24개를 기초·출퇴근/학습 팩으로 검토 후 가져오기, 6개 언어 그룹 생성, 팩 사이 중복·재가져오기 방지·출처·읽기 테스트 | 추가 팩은 같은 검수 절차 반복 |
| 일반 지식 샘플 팩 | 완료 | MLB 참고 야구 13개·Korea.net/문체부 참고 팬덤 15개를 검토 후 가져오기, 항목별 URL·표시문 보존 | 추가 팩은 같은 검수 절차 반복 |
| 동일 표현 뜻·그룹 병합 | 완료 | 실제 간편 `.xlsx`의 `reservation`·`OPS` 다중 행과 번들/사용자 항목 병합 테스트 | 없음 |
| 여러 예문의 독립 문장화 | 완료 | 단어 행의 여러 예문을 문장 항목으로 확장하는 파서·가져오기 테스트 | 없음 |
| 그룹 생성·복사·이동 | 완료 | 독립 `LearningGroupDefinition`, 빈 그룹, 설명·색상·고정·사용자 순서, Windows 드래그앤드롭과 모바일 선택 흐름, 상태·UI 테스트 | 없음 |
| 그룹 이름 변경·삭제 | 완료 | `renameLearningGroup`, `deleteLearningGroup`, 영향 미리보기·안전한 연결 해제·8초 실행 취소, 상태·UI 테스트 | 없음 |
| 그룹 수·진도·정확도 | 완료 | `LearningGroupSummary`, 모바일 UI·오버플로 회귀 테스트 | 없음 |
| 직접 선택형 학습 | 완료 | `StudyDeckScope.selected`, 도메인·UI 테스트 | 없음 |
| 문제 방식·수·문장 비율 | 완료 | `StudySessionPlan`, 세션 빌더 테스트 | 없음 |
| 학습 이름·예정 시간 저장 | 완료 | 최대 20개 저장·수정·불러오기·삭제, 언어·사용자 주제별 분리, 홈 예약 카드, 시작 후 템플릿 유지, 구버전 이전과 SQLite·Drive snapshot 테스트 | 없음 |
| Android·Windows 일정 알림 | 완료 | 사용자 저장 동작에서 Android 권한 요청, Windows Toast, 시간대 변환, 재부팅 복원, 일정 수정·삭제·시작·Drive 병합 재조정, 설정의 대상 수·재연결 관리, 두 플랫폼 네이티브 예약·취소 통합 테스트 | Android 제조사 절전 정책에 따라 지연될 수 있음 |
| 오답 다시 풀기 | 완료 | 활성 세션 분기와 위젯 테스트 | 없음 |
| 취약 항목 학습 | 완료 | 자동 `취약`·`최근 오답` 묶음과 바로 학습 UI·상태 테스트 | 없음 |
| 직접 선택 발음 학습 | 완료 | 세션 빌더의 그룹·태그·레벨·단계·직접 선택 필터를 발음 큐와 연결, Android·Windows 공통 저장 일정과 복귀 흐름 테스트 | Windows 비영어 마이크는 OS 언어팩 제약 안내 유지 |
| Google 로그인 전 로컬 학습 | 완료 | 샘플 학습과 로컬 저장 테스트 | 없음 |
| Windows·Android 플랫폼별 Google 인증 | 에뮬레이터·Windows 실계정 완료 | Railway 무저장 토큰 중계 `ready`, Windows 동의·loopback·토큰 교환·Drive Picker E2E, Android 계정 선택·동의·`drive.file` 권한 E2E 통과 | Android 물리 기기에서 같은 흐름 반복 |
| Drive 폴더 ID 연결 | 양 플랫폼 실계정 완료 | Windows가 연결한 `WordStudyData` ID를 Railway에서 조회하고 Android가 Drive metadata로 폴더를 검증·재사용, pull/merge/push 통과 | 최초 계정의 Android Picker 폴더 반환은 물리 기기에서 반복 검증 |
| 자동·수동 동기화와 재시도 | 완료 | pending sync 영속화·백오프·상태 UI, 저장 연결의 Android·Windows 무수동 복구, 복구 불가 시 로컬·대기 작업 유지 테스트, Android 재기동 실측 | Windows 실제 계정 만료 토큰 복구는 공개 배포 전 장기 반복 |
| 장기 오프라인 충돌 자동 시험 | 완료 | 45일 Windows·Android 분기, 양방향 재연결 순서, 12회 반복 수렴, 첫 업로드 중단·재시도 통합 테스트 | 실제 OS·Drive 전파 지연은 실기기 시험 항목 |
| 설정 삭제 충돌 | 완료 | 즐겨찾기 해제·학습 제외 취소의 변경 시각, 저장 일정 삭제 tombstone, 오래된 기기 부활 방지 테스트 | 없음 |
| manifest 증분 동기화 | 완료 | 구형 snapshot 읽기, 6개 섹션 migration, 변경 섹션만 pull/push, copy-on-write·manifest 최종 교체·중단 복구, metadata-only revision 증가 시 SHA-256 재검증 테스트 | 미참조 구버전 파일은 사용자 선택 정리만 제공 |
| 손상 원격 데이터 방어·tombstone | 완료 | SHA·revision·JSON·필드 검증, Drive `quarantine` 사본, 안전 미리보기, 정상 로컬 보존·병합 테스트 | 없음 |
| 충돌 내역 표시 | 완료 | 업로드·다운로드·충돌 수와 항목별 병합 결정을 표시하는 UI·테스트 | 없음 |
| 오류 원인·해결 안내 | 완료 | 401·권한·404·429/일일 제한·저장공간·5xx별 진단 코드와 복구 순서, `Retry-After`, 통신 중단의 안전한 한국어 재시도 안내, API URL·원시 예외 제거·복사 UI 테스트 | 없음 |
| 개인정보·Google 데이터 고지 | 공개 페이지·앱 연결 완료, 소유 도메인 대기 | Railway API의 `/`, `/privacy`, `/terms`가 로그인 없이 200 응답, 앱 설정의 웹 정책 버튼과 현재 버전 고지 실측. Google 브랜딩의 홈페이지·개인정보 URL·승인 도메인은 현재 공란 | 동일 페이지를 소유 custom domain에 연결하고 OAuth 동의 화면에 URL 등록 |
| Google OAuth 게시·앱 소유권 | 테스트 상태 | 외부 사용자 유형, 테스트 사용자 1명, `openid`·`email`·`profile`·`drive.file`만 등록, 민감·제한 범위 0개 | 실계정 종단 검증 후 게시 판단, Play App Signing 클라이언트 생성·앱 소유권 확인 |
| OAuth 토큰 보안 저장·중계 | 완료 | Windows OS secure storage, Railway sealed secret, `no-store` 무저장 중계, malformed JSON 400, 민감 필드 로그 redaction, 실계정 토큰 교환 통과, 이전 Google secret 폐기 후 활성 secret 1개 확인 | 운영 로그 정기 점검 |
| 내보내기·백업 | 완료 | 엄격 검증 JSON 백업·복원, XLSX와 CSV 27열 내보내기, 한국어 발음·Excel 서식·수식 안전성·주제 ID 포함 재가져오기 테스트 | Android 시스템 저장 선택기의 1.22.2 내보내기 실기기 반복은 배포 단계에서 수행 |
| 계정 XP·레벨·연속 학습일 | 완료 | 계정 및 날짜·코스별 오늘 XP의 기기별 증가 전용 원장, 구버전 XP 승계, 양쪽 오프라인 합산·과거 기록 역행 방지와 홈·통계 테스트 | 없음 |
| 코스별 일일 목표·오늘 XP | 완료 | 주제별 목표·오늘 XP 저장과 Drive 병합, 홈·설정·통계 구분 표시 및 상태·위젯·골든 테스트 | 없음 |
| 오늘 복습량·최근 세션 | 완료 | 홈·통계 화면, 최근 전체·오답 세션 재사용 테스트 | 없음 |
| 완료 세션·오답 기기 간 연속성 | 완료 | 실제 간편 Excel 가져오기부터 그룹·직접 선택 일정·정오답·XP·최근 세션·두 번째 기기 snapshot 병합까지 단일 E2E | 실계정 전송은 아래 별도 항목 |
| Android 설치·업그레이드·로컬 연속성 | 완료 | 1.19.3 기존 데이터 보존 확인에 이어 1.20.0→1.20.1→1.20.2→1.20.3→1.20.4→1.21.0→1.22.0→1.22.1→1.22.2 `adb install -r` 성공, `firstInstallTime`·사용자 주제·항목·XP·중단 세션·Drive 연결 보존, 진행 중 세션의 무음 덮어쓰기 방지 실측 | 물리 기기 접근성·마이크는 배포 단계에서 반복 |
| Windows·Android 산출물 | 1.23.0 완료 | APK·포터블 ZIP·설치 EXE 생성, 공개 개인정보 URL·한국어 발음 Excel 포함, 해시·버전·Android ABI 3개·Windows ZIP 34개 검증 | Windows Authenticode와 Play release signing은 별도 |
| 정식 서명·배포 게이트 | 코드·실패 경로 완료 | Android 외부 keystore 4변수 완전성 검사, Windows 인증서 저장소 SignTool·RFC 3161 연결, Debug/무서명 강제 거부, 체크섬·4개 AOT 바이너리·ZIP·설치 수명주기 통합 검증 | 실제 upload key와 상용 Authenticode 인증서가 생기면 성공 경로 최종 검증 |
| 실제 Google 기기 간 연속성 | Windows↔Android 에뮬레이터 완료 | Windows 실계정으로 올린 `live-e2e-windows-android-marker-v1` 사용자 콘텐츠를 Android가 Railway 폴더 연결 재사용 후 Drive에서 다운로드, 충돌 병합·계정 XP 복원과 1.20.1 덮어쓰기 뒤 `WordStudyData` 자동 연결 확인 | Android 물리 기기에서 같은 흐름 반복 |
| 사용자 시작 안내 | 완료 | 6개 언어·하루 목표 선택, 즉시 학습, 모바일·Windows 온보딩 테스트 | 없음 |

## 2026-07-30 개발 브랜치 재검증

- 1.23.0에서 Flutter 전체 테스트 379개, API Vitest 14개, 시각 회귀
  31개와 정적 분석 이슈 0개를 확인
- 700px Windows 그룹 좌우 작업판, 375·390·412·430px 모바일 라이트·다크,
  모바일 선택 바·그룹 관리 시트 골든 검증
- 대량 그룹 이동·연결 해제 영향 미리보기, 실행 취소, 현재 주제 유지와
  대상 주제 선택 열기 자동화 검증
- Railway `desktopOAuthBroker=ready`, Windows Google 로그인 준비 상태
  `True`, 1.23.0 실연동 Android·Windows 빌드와 릴리스 검증 통과
- Windows 릴리스가 380×520·420×640·1040×760 크기를 정확히 적용하고,
  Flutter Windows 엔진 홈·학습·설정 E2E가 통과
- API Vitest 14개 통과
- Flutter 전체 테스트 372개 통과, 직관적인 자료 흐름 안내·반응형 그룹 작업판·날짜형 템플릿 저장 이름·컴팩트 채점 팝업·한국어 발음 전수·Excel 왕복·진행 중 세션 보호 포함
- 시각 회귀 테스트 30개 통과, 320~430px 모바일 라이트·다크와 1280px
  Windows 그룹 작업판 포함
- Flutter 정적 분석 이슈 0개
- 실제 XLSX 27열 내보내기와 재가져오기, OOXML 구조·서식·수식 오류 0개 검증
- Google Drive 통신 중단의 URL·원시 예외 제거와 안전한 재시도 진단 검증
- Windows 실제 엔진 380×520 홈·연습, 420×640 집중창, 1040×760 홈·설정
  이동·PNG 검증과 release EXE 세 크기 응답 검사 통과
- 실제 간편 Excel → 중복 뜻·그룹 병합 → 예문 문장 → 선택 학습·결과 →
  두 번째 기기 동기화 E2E 통과
- Windows 실계정 Google·Drive E2E 통과
- Android 실계정으로 Railway 연결 폴더 재사용·Windows 마커 복원·재기동 자동 연결 E2E 통과
- Windows x64 1.22.7 설치 EXE·포터블 ZIP 생성, release 앱 실행·응답 확인
- Android 1.22.7 APK 생성과 Debug 서명 검증
- 릴리스 무결성 검사: 체크섬 3개, APK ABI 3개, Windows AOT·ZIP 33개
  항목, 간편·전체 Excel 자산 포함 통과
- Android 에뮬레이터 1.21.0→1.22.0→1.22.1→1.22.2→1.22.3→1.22.4 덮어쓰기 후 설치 시각·사용자 자료·XP·
  중단 세션·Drive 연결 보존, 다른 학습 진입 시 기존 세션 보호 대화상자와 취소 후 보존 확인
- Android 1.22.3 발음 화면에서 영어 원문·한국어 발음·뜻을 함께 표시하고
  치명 예외·미처리 예외·RenderFlex overflow가 없는 것을 확인
- Android 시스템 선택기로 실제 간편 Excel을 읽어 15개 신규·행 오류 0개
  검토 화면 확인
- Android 시스템 저장창으로 간편 템플릿을 저장·회수하고 앱 자산과
  SHA-256 일치 확인
- Android 실행 로그의 치명 예외·미처리 예외·RenderFlex overflow 0개,
  crash buffer 앱 관련 항목 0개
- Android 320dp 조건에서 홈·단어장·설정 실화면을 확인하고 긴 주제명,
  중단 세션 제목, Drive 상태 문구의 잘못된 줄바꿈이 없음을 확인
- Android·Windows 내비게이션을 고정된 다섯 항목으로 통합하고 홈의 중복
  학습 진입점을 제거했으며, 학습 허브를 퀴즈·암기·실전 세 범주로 축약
- 퀴즈 연속 정답 콤보·3문제 미니 목표·오답 재출제 안내·최고 콤보 결과를
  상태·위젯·골든 테스트와 실제 Android 학습 허브 화면으로 검증

## 다음 구현 순서

1. Android 물리 기기에서 동일 계정 자동 연결·최초 Picker 폴더 선택을 반복 검증
2. Android·Windows 두 물리 기기 장시간 오프라인 충돌 실측
3. Android 실기기 마이크·TTS·알림 권한 확인
4. Play 배포용 release keystore와 App Signing OAuth 지문 등록
5. 앱 홈페이지·개인정보처리방침을 소유권 확인 도메인에 공개하고 OAuth URL 등록
6. Windows Authenticode 인증서 적용
7. 6개 언어 추가 문장 원어민 감수
