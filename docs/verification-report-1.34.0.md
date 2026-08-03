# Sprache 1.34.0 검증 보고서

검증 대상은 `1.34.0+58`이다. Windows와 Android는 실제 Google 설정을 포함한
REAL 빌드이고, iOS Simulator와 macOS는 Google 인증을 MOCK으로 둔 Apple
미리보기 빌드다.

## 코드와 사용자 경험

- Railway API, Fastify, Prisma와 PostgreSQL 런타임을 제거했다.
- Windows Google OAuth는 client secret 없는 direct PKCE를 사용한다.
- Drive `appDataFolder`에는 학습 데이터가 아닌 사용자가 고른 Drive 폴더 포인터만
  저장한다.
- 단어 등록, 라이브러리, Practice Hub, 퀴즈·게임, 설정과 저장 위치 안내 문구를
  짧고 자연스러운 한국어로 정리했다.
- Practice Hub의 작은 창과 긴 콘텐츠에서 가로·세로 이동을 검증했다.

## 자동·수동 검증

- Flutter 전체 테스트: 1090/1090 통과
- Flutter 정적 분석: 경고와 오류 없음
- QA 테스트: 21/21 통과
- 시각 회귀 테스트: 37/37 통과
- release bundle 도구 테스트: 5/5 통과
- Windows 설치, 실행, 응답, 첫 프레임, 제거와 재설치 통과
- Android 패키지 `com.youkdonghun.sprache`, 버전 코드 58, v2 Debug 서명,
  `arm64-v8a`·`armeabi-v7a`·`x86_64` 검증 통과
- iOS Simulator와 macOS의 Universal Mach-O(`x86_64`, `arm64`), 번들 ID,
  버전, 실행과 첫 프레임 검증 통과
- 네 플랫폼 release manifest와 19개 파일 통합 SHA-256 검증 통과

GitHub Actions run 45의 세 작업은 계정 결제 또는 지출 한도 때문에 실행 단계가
시작되지 않았다. 작업 로그와 step이 0개이므로 코드 실패로 보지 않았고, 위 로컬
검증과 Codemagic Apple 빌드로 대체했다.

## 대표 산출물

| 플랫폼 | 파일 | SHA-256 |
|---|---|---|
| Windows | `Sprache-Windows-Setup-1.34.0-google-x64.exe` | `5784e019c43455503028e6bc447cab30090cd7b04cd02a4ecb13fb6905ecd795` |
| Android | `Sprache-Android-1.34.0-google-debug-signed.apk` | `8dc950472705cc52ac0dea3f609ffd1f5824b6aec0e1ef08752659c2a8f0bf34` |
| iOS Simulator | `Sprache-iOS-Simulator-1.34.0-mock.zip` | `dd874b32df87c5fd905ae2a3140b2057b18be4fbf25b625a78d584ef5dd594df` |
| macOS | `Sprache-macOS-1.34.0-mock.zip` | `9edcbd20de9410ca85026d263a476fa07d17002cfc9e6081de3abb5d457796dc` |

Windows 파일은 코드 서명이 없고 Android는 테스트용 Debug 인증서다. iOS 파일은
실기기 IPA가 아니며, macOS 파일은 ad-hoc 서명된 비공증 미리보기다.

## 공개 문서와 Railway 종료

- 공개 문서 전용 저장소 `youkdonghun/youkdonghun.github.io`를 만들고 소스
  저장소는 비공개로 유지했다.
- 홈페이지, 개인정보처리방침과 약관 URL이 모두 HTTPS 200을 반환하고 canonical
  URL이 일치하는지 확인했다.
- Railway 프로젝트 `Sprache`(`cfb13a72-2f18-42a9-bfaa-9437079a752d`)의
  `sprache-api`와 `Postgres`를 포함한 프로젝트 삭제를 예약했다.
- Railway가 제공하던 `/health`와 `/privacy`는 삭제 예약 직후 HTTP 404를
  반환했고, GitHub Pages 개인정보처리방침은 계속 HTTP 200을 반환했다.
- Railway는 48시간 유예 기간 뒤 영구 삭제된다. 유예 중에는 Railway 대시보드의
  Deleted 목록에서 취소할 수 있다.

최종 산출물은 바탕 화면의 `Sprache-1.34.0`에 있으며, 이전 1.33 산출물은 새
manifest 검증 뒤 제거했다. 바탕 화면의 이전 폴더와 임시 빌드 폴더는 Windows
휴지통으로 보냈다.
