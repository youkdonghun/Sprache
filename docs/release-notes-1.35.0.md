# Sprache 1.35.0 릴리스 안내

버전은 `1.35.0+60`이다. 이번 버전부터 운영 빌드는 Google Drive 연결을 마친
뒤에만 학습 화면으로 들어간다. Railway·Cloudflare·Sprache 전용 서버는
사용하지 않으며, 앱 데이터는 기기 DB와 사용자의 Google Drive 사이에서만
이동한다.

## 주요 변경

- iPhone에서 무료로 설치해 쓸 수 있는 Flutter PWA를 GitHub Pages
  `/Sprache/app/` 경로에 제공한다.
- Web은 Drift SQLite WASM과 브라우저 영구 저장소를 사용하고 오프라인 학습을
  지원한다.
- Web Google OAuth는 공개 Web Client ID만 사용하며 access token은 메모리에만
  둔다. OAuth secret, refresh token, 사용자 자료를 웹 번들에 넣지 않는다.
- PDF를 고르기 전에 학습 대상·언어·분배 키·그룹을 정하고, 분석 뒤 단어·뜻·
  문맥·페이지·빈도·중복 상태를 직접 검토한다.
- `단어 - 뜻`, `단어: 뜻`, 탭·다중 공백 2열 자료는 명확한 쌍만 기본 선택한다.
  일반 문서에서 찾은 단어는 뜻을 직접 적어야 저장할 수 있다.
- PDF 원본은 Drive에 올리지 않는다. 파일명, SHA-256, 페이지 번호와 짧은 문맥만
  출처로 보존한다.
- 텍스트가 없는 스캔 PDF는 OCR 미지원으로 안내하고, 암호화 PDF의 비밀번호는
  현재 분석 세션에서만 사용한다.
- PDF 20MB·500페이지·본문 200만 자·후보 5,000개 제한과 분석 취소를 적용한다.

## 플랫폼 결과물 이름

최종 바탕 화면 폴더에서는 파일을 바로 구분할 수 있도록 다음 이름을 사용한다.

- `Sprache-안드로이드용-1.35.0.apk`
- `Sprache-윈도우용-1.35.0.exe`
- `Sprache-맥용-1.35.0.zip`
- `Sprache-아이폰용-1.35.0.zip`
- `Sprache-iPhone-PWA-바로가기.url`

iPhone ZIP은 Simulator 검증용이며 일반 iPhone에 직접 설치하는 IPA가 아니다.
비용 없는 실제 iPhone 배포 경로는 PWA다. 서명된 Ad Hoc IPA는 Apple Developer
Program과 등록된 기기가 필요하고, 무료 계정 sideload IPA는 주기적인 재서명이
필요하다.

## 알려진 범위

- 첫 PDF 버전은 텍스트가 포함된 PDF만 지원한다. 스캔 이미지 OCR, 외부 AI 뜻
  생성, 자동 번역은 포함하지 않는다.
- Apple 네이티브 결과물은 Xcode가 있는 macOS 빌드 호스트에서 만든다.
- Google OAuth 콘솔에는 배포 주소를 허용된 JavaScript 출처로 등록해야 한다.
