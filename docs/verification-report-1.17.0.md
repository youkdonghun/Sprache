# Sprache 1.17.0 검증 보고서

검증일: 2026-07-28

## 기능 범위

- 모바일·Windows 첫 실행 언어·하루 목표 설정과 즉시 학습
- Excel 템플릿, CSV·JSON·JSONL 가져오기와 여러 예문의 독립 문장화
- 동일 표현 뜻 추가, 단어·문장 그룹 생성·복사·이동·이름 변경·삭제
- 그룹 진도·정확도, 직접 선택형 퀴즈와 암기
- 취약 표현·최근 오답 자동 묶음, 최근 세션 전체·오답 다시 학습
- 최대 20개 이름 있는 학습 계획 저장·수정·불러오기·삭제
- 검증된 JSON 백업·복원과 Excel 호환 CSV 내보내기
- Drive 병합 전후 업로드·다운로드·충돌 수와 항목별 결정 표시
- 복사 가능한 Google·Drive 진단 코드와 재시도 안내
- 6개 언어 720개 내장 표현과 출처·읽기·문장 토큰 검증

## 자동 검증

| 검사 | 결과 |
| --- | --- |
| API TypeScript lint | 통과 |
| API Vitest | 4개 통과 |
| API production build | 통과 |
| Flutter analyze | 이슈 0개 |
| Flutter 전체 테스트 | 213개 통과 |
| Flutter 시각 회귀 | 전체 통과 |
| 내장 콘텐츠 구조 | 720개, ID·텍스트 중복 없음 |
| Excel 템플릿 앱 파서 | 6개 학습 언어 행 통과 |
| PowerShell 릴리스 스크립트 파싱 | 통과 |
| Railway `/health` | `{"status":"ok","service":"sprache-api"}` |

## 산출물 검증

### Android

- 파일: `artifacts/Sprache-Android-1.17.0-google-debug-signed.apk`
- 크기: 74,613,322 bytes
- 패키지: `com.youkdonghun.sprache`
- 버전: `1.17.0` (`versionCode` 19)
- 최소 SDK: 24
- 대상 SDK: 36
- APK Signature Scheme v2: 통과
- 서명자: Android Debug 인증서 1개
- SHA-256: `ba275e61db43743936b074877961039aafe8ead42121bd9e24e393f79a5edb43`

현재 APK는 직접 설치·기능 확인용 debug 인증서로 서명했다. Play Store
배포 전에는 release keystore와 Play App Signing SHA-1/SHA-256을 Google
Android OAuth 클라이언트에 등록해야 한다.

### Windows

- 파일: `artifacts/Sprache-Windows-1.17.0-google-x64.zip`
- 크기: 20,743,580 bytes
- ZIP 항목: 25개
- `sprache.exe`와 `flutter_windows.dll` 포함
- 릴리스 EXE 숨김 실행 후 5초 이상 정상 응답 확인
- SHA-256: `7d2ec0de4e2db9b9028fe7fda82007a0ed91ee11ae45d0203caf940a16e3e8cd`

두 파일의 재계산 SHA-256은
`artifacts/SHA256SUMS-1.17.0-google.txt`와 일치했다.

## 자동화할 수 없었던 실제 환경 검증

- 연결된 Android 기기가 없어 APK 설치·마이크·TTS를 실행하지 못했다.
- Google 로그인과 Drive 폴더 선택은 사용자 브라우저 동의가 필요해 실제
  계정 토큰 교환을 완료하지 않았다.
- Windows와 Android 사이의 실제 Drive 연속성 시나리오는 두 기기 로그인이
  끝난 뒤 확인해야 한다.

Railway 운영 API는 실제 공개 URL에서 정상 응답했다. 클라이언트 산출물은
로컬 주소가 아니라 `https://sprache-api-production.up.railway.app`을 사용한다.

## 유지보수 경고

현재 Flutter 버전에서는 두 플랫폼 모두 빌드되지만 `file_picker`,
`flutter_tts`, `speech_to_text`가 Kotlin Gradle Plugin을 직접 적용한다는
향후 호환성 경고가 있다. 다음 Flutter 주요 버전 업그레이드 전에 Built-in
Kotlin 지원 버전으로 갱신한다.
