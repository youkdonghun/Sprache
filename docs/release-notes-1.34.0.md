# Sprache 1.34.0 릴리스 안내

빌드 번호는 58입니다. 이번 버전은 별도 서버에 학습 데이터를 맡기지 않는
Local-First 구조로 정리하고, 처음 쓰는 사람도 길을 잃지 않도록 화면과 문구를
전반적으로 다듬었습니다.

## 달라진 점

- Railway 서버 없이 앱만으로 단어 등록, 학습, 복습과 진도 저장을 사용할 수 있습니다.
- Google 연결은 선택 사항입니다. 연결하면 사용자가 고른 Google Drive 폴더에 백업하고,
  연결하지 않아도 로컬 저장으로 계속 사용할 수 있습니다.
- 설정의 `저장 및 동기화`에서 Google Drive 연결 상태와 로컬 저장 위치를 한곳에서
  확인할 수 있습니다.
- 단어 직접 등록, 빠른 붙여넣기, 파일 가져오기와 학습 목록 진입 흐름을 짧게 정리했습니다.
- Practice Hub의 작은 창과 긴 목록에서도 가로·세로 이동이 막히지 않도록 레이아웃을
  보완했습니다.
- 학습, 퀴즈, 게임, 라이브러리와 설정의 안내 문구를 자연스럽고 짧은 한국어로
  다시 썼습니다.
- 키보드 도움말은 작업 화면을 가리지 않도록 설정에서 찾아볼 수 있게 정리했습니다.
- 기존 Drive 백업은 표시 이름이 아니라 폴더 ID로 다시 찾으며, 정상 로컬 데이터는
  손상된 원격 데이터로 덮어쓰지 않습니다.

## 파일 선택

- Windows: `Sprache-Windows-Setup-1.34.0-google-x64.exe`
- Windows 무설치 묶음: `Sprache-Windows-1.34.0-google-x64.zip`
- Android: `Sprache-Android-1.34.0-google-debug-signed.apk`
- iOS Simulator: `Sprache-iOS-Simulator-1.34.0-mock.zip`
- macOS 미리보기: `Sprache-macOS-1.34.0-mock.zip`

## 알아둘 점

- Windows 설치 파일은 현재 코드 서명이 없어 Windows가 경고를 보여줄 수 있습니다.
- Android APK는 테스트용 Debug 인증서로 서명했습니다. Play 스토어 배포본이 아니라
  직접 설치해 확인하는 빌드입니다.
- iOS 파일은 실제 iPhone 설치용 IPA가 아니라 macOS의 iOS Simulator에서 실행하는
  개발 미리보기입니다.
- macOS 파일은 ad-hoc 서명된 비공증 미리보기입니다. 일반 배포에는 Apple Developer
  서명과 notarization이 추가로 필요합니다.
- iOS와 macOS 미리보기는 실제 Google 인증 대신 MOCK 모드로 첫 화면 실행을 검증했습니다.

설치 전에 중요한 학습 자료는 앱의 내보내기나 Google Drive 백업으로 한 번 더 보관하는
것이 좋습니다. 각 파일의 무결성은 `release-manifest-1.34.0.json`과
`SHA256SUMS-1.34.0-all.txt`에서 확인할 수 있습니다.
