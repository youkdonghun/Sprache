# Sprache 1.30.0 검증 보고서

검증일: 2026-08-02 (Asia/Seoul)

## 결과

- 제품 버전: `1.30.0+54`
- 사용자 편의성 목표: 50/50 구현
- Flutter 정적 분석: 경고·오류 0건
- Flutter 기능 회귀: 658/658 통과
- Flutter 시각 회귀: 37/37 통과
- API 타입 검사: 통과
- API 테스트: 14/14 통과
- Tatoeba 출처·작성자·라이선스: 24/24 검증
- Windows 설치 스모크: 설치, 창 실행, 응답 확인, 제거 모두 통과
- 실제 Windows 설치: `Sprache 1.30.0`, 창 제목 `Sprache`, 응답 상태 정상
- 기존 1.29.0 설치 및 배포 파일: 새 릴리스 검증 후 제거
- 로컬 학습 DB: 제거하지 않았으며 업그레이드 직전 원본과 백업 SHA-256 일치

## 배포 산출물

| 파일 | 바이트 | SHA-256 |
| --- | ---: | --- |
| `Sprache-Android-1.30.0-google-debug-signed.apk` | 83,334,554 | `0eaab20de27d5dc174a209ae30202e380c9cbe282771e3dad9b729dd1f5e7cf5` |
| `Sprache-Windows-1.30.0-google-x64.zip` | 22,192,830 | `ba6d8b92d123a2629c22de975698a9038e869a299386d9ab8a8d7976730f2d53` |
| `Sprache-Windows-Setup-1.30.0-google-x64.exe` | 18,187,398 | `2286681f003dc3d862eccddd83655633b90586cabe3b8d51505f89748df3feac` |

`verify-release.ps1`은 다음을 추가로 확인했다.

- Android package `com.youkdonghun.sprache`, version code `54`, version name `1.30.0`
- APK Signature Scheme v2
- Android 3개 ABI의 `libapp.so`
- Windows ZIP 필수 실행 파일·데이터·가져오기 템플릿
- 프로덕션 API 및 개인정보 처리방침 URL 포함
- 로컬 개발 URL과 Google 데스크톱 클라이언트 시크릿 미포함
- 통합 체크섬 3개 일치

현재 로컬 APK는 배포 모드로 빌드됐지만 Android Debug 인증서로 서명됐다. Windows
실행 파일과 설치 파일도 Authenticode 인증서가 없어 서명되지 않았다. 스토어·공개 배포
전에는 별도 보관한 릴리스 키와 코드 서명 인증서를 CI 비밀값으로 연결해야 한다.

## 데이터 보존

- 원본: `C:\Users\youk9\OneDrive\문서\sprache.sqlite`
- 업그레이드 직전 크기: 102,400바이트
- SHA-256: `abaf61a2f873fdc0beea24b4312e91d49377d6c3c69a1f11daec46949f77674b8`
- 백업: `C:\Users\youk9\OneDrive\문서\Sprache-backups\1.29.0-before-1.30.0-20260802-231139\sprache.sqlite`

사용자 학습 DB는 앱 설치 폴더 밖에 있으며 1.29.0 제거, 설치 스모크, 1.30.0 설치
과정에서 삭제하거나 초기화하지 않았다.

## iOS 준비 상태

- Flutter iOS runner와 Xcode project/workspace 추가
- bundle identifier: `com.youkdonghun.sprache`
- 최소 iOS: 13.0
- 마이크·음성 인식 권한 문구 추가
- Windows 전용 통합 기능의 명시적 iOS 플랫폼 분기 추가
- macOS GitHub Actions에서 `flutter build ios --simulator --no-codesign` 실행

Apple 서명 인증서와 provisioning profile이 없는 Windows PC에서는 설치 가능한 `.ipa`를
신뢰성 있게 만들 수 없다. 이 릴리스에서는 macOS CI 시뮬레이터 빌드가 iOS 컴파일
게이트이며, 서명 IPA는 Apple Developer 자격 증명을 CI에 연결한 뒤 생성한다.

## 제품 비교 근거

- [Duolingo Practice Hub](https://blog.duolingo.com/guide-to-duolingo-practice-hub/): 추천·목적별 연습 진입
- [Quizlet 학습 세트 만들기](https://help.quizlet.com/hc/en-us/articles/360029780752-Creating-study-sets/): 빠른 세트 작성 흐름
- [Quizlet 가져오기](https://help.quizlet.com/hc/en-us/articles/360029977151-Creating-sets-by-importing-content): 다양한 대량 붙여넣기
- [Anki 편집](https://docs.ankiweb.net/editing.html): 필드 기반 정밀 입력
- [Anki 필터 덱](https://docs.ankiweb.net/filtered-decks.html): 자유로운 복습 범위
- [LingQ 모바일](https://www.lingq.com/iPhone_app/): 학습 중 표현 저장
- [Flutter 접근성](https://docs.flutter.dev/ui/accessibility): 큰 글자·키보드·의미 정보
- [Apple Reduced Motion](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria): 모션 감소 기준

세부 50개 목표와 완료 상태는 `docs/ux-50-upgrade-plan-1.30.0.md`에 기록했다.
