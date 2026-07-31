# Sprache 1.19.5 검증 보고서

검증일: 2026-07-29

## 결과

| 검증 항목 | 결과 |
| --- | --- |
| API 테스트 | Vitest 12개 통과 |
| Flutter 전체 테스트 | 314개 통과 |
| Flutter 정적 분석 | 이슈 0개 |
| API 타입 검사·빌드 | 통과 |
| 시각 회귀 | Android·Windows 골든 43개 통과 |
| 직접 선택 발음 세션 | 그룹·태그·레벨·학습 단계·직접 선택 필터에서 발음 가능한 표현만 사용, 정확히 고른 1개 표현으로 `1 / 1` 발음 세션 시작 확인 |
| 발음 일정 연동 | 발음 세션 이름·예약 시간 저장, 현재 학습 주제에만 노출, 시작 후 예약 시간만 소비하고 설정은 재사용 |
| Android | APK 생성, `adb install -r`, foreground 기동, 런타임 crash 0건 |
| Windows | release ZIP·설치 EXE 생성, 설치·실행·제거와 레지스트리 정리 통과 |
| 설치 실패 정리 | 설치 직후 강제 실패를 주입해도 테스트 설치 폴더 0개, 제거 레지스트리 0개 확인 |
| 릴리스 통합 검증 | 버전·해시·APK v2 서명·3개 ABI·Windows AOT·ZIP 29개 항목 통과 |

## 1.19.5 학습 흐름

- 세션 빌더의 문제 방식에 `발음 따라하기`를 추가했다.
- 코스 전체뿐 아니라 그룹, 태그, 레벨, 취약 단계, 직접 선택한 단어·문장으로 발음 세션을 구성할 수 있다.
- 발음에 필요한 듣기 기능이 없는 항목은 시작 전에 제외한다.
- 발음 세션을 저장하거나 예약하면 현재 학습 주제에 귀속되고 Android와 Windows가 같은 설정을 사용한다.
- 발음 세션을 완료하거나 닫으면 일반 학습 화면이 아니라 세션 설계 화면으로 돌아가 선택을 바로 수정하거나 재사용할 수 있다.

## 산출물

### Android

- 파일: `artifacts/Sprache-Android-1.19.5-google-debug-signed.apk`
- 크기: 76,165,650 bytes
- SHA-256:
  `0fa71c04c02c801875b85eceaec1682c2a20d433a9ac2f4806bba4373382db14`
- 패키지: `com.youkdonghun.sprache`
- 버전: `1.19.5` (`versionCode` 27)
- 최소 SDK: 24
- 대상 SDK: 36
- ABI: `arm64-v8a`, `armeabi-v7a`, `x86_64`
- 서명: APK Signature Scheme v2, Android Debug 인증서
- 서명 인증서 SHA-256:
  `50f42478d5254ac6921811e25317833ef2db18c411dc92c7b8ef7d8b0ab2a0d2`

연결된 Android 기기에 `adb install -r`로 설치했다. 프로세스가 유지되고
`com.youkdonghun.sprache/.MainActivity`가 foreground activity였으며
`AndroidRuntime`·Flutter crash 로그는 없었다.

현재 APK는 직접 설치 검증용 Debug 인증서 서명본이며 Play 배포용 서명본은 아니다.

### Windows

- 포터블 파일: `artifacts/Sprache-Windows-1.19.5-google-x64.zip`
- 크기: 20,947,781 bytes
- SHA-256:
  `6b4e44967a00a49cb04562b4729a982f036f5322dfe37f0dcf1f1e9678385921`
- ZIP 항목 수: 29
- 설치 파일: `artifacts/Sprache-Windows-Setup-1.19.5-google-x64.exe`
- 설치 파일 크기: 17,373,864 bytes
- 설치 파일 SHA-256:
  `b62c94e77c1e2e3b9523c4539d4809034d9d1a05f02e03b9cb1594635068f217`
- 설치 파일 제품 버전: `1.19.5`
- 앱 파일 버전: `1.19.5+27`
- 실행 창 제목: `작업 보드`
- 설치 실행 상태: `Responding=True`
- 제거 결과: exit code 0, 설치 폴더 제거, HKCU 제거 항목 0개

현재 Windows 설치 파일은 Authenticode `NotSigned` 상태다. 로컬 기능 검증에는
사용할 수 있지만 공개 배포 전에는 코드 서명 인증서 적용이 필요하다.

세 산출물의 해시는 `artifacts/SHA256SUMS-1.19.5-google.txt`와 일치한다.

## 외부 연결 상태

- 이번 묶음에서는 사용자 요청에 따라 Google Console과 Railway 설정을 변경하지 않았다.
- Railway Desktop OAuth broker는 sealed client secret이 없어 `not_configured` 상태다.
- 로컬 학습, 콘텐츠 가져오기, 학습 일정, APK·Windows 실행은 Google 연결 없이 동작한다.
- 실제 계정의 Google 로그인과 Drive 기기 간 동기화는 외부 설정이 준비된 뒤 별도 실기기 검증이 필요하다.

## 배포 전에 남은 외부 작업

- Railway Desktop Client Secret sealed variable 등록
- 실제 Google 계정으로 Windows 로그인·Drive 폴더 선택 검증
- Android 로그인과 Windows↔Android Drive 연속성 검증
- Play release signing과 Windows Authenticode 서명
- 공개 도메인의 앱 홈페이지·개인정보처리방침 URL 등록
