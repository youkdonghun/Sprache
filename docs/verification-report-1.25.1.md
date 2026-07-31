# Sprache 1.25.1 Android 검증 보고서

검증일: 2026-07-30

## 이번 변경

- `distribution_key`별 주제·그룹·언어 규칙을 `state/settings.json`에 동기화한다.
- 한 파일의 여러 키도 저장된 규칙별로 분배하며, 규칙이 없는 키는 행의
  `subject_id` 또는 현재 주제로 최초 규칙을 만든다.
- 가져온 원본 Excel·CSV·JSON·JSONL은 Drive나 로컬 미러에 복제하지 않는다.
- 정규화된 항목만 기존 `content/custom-items.json` 논리 데이터셋에 병합한다.
- 같은 주제의 동일 표현은 뜻·허용 정답·읽기·그룹을 합치고, 중복 ID의 진도를
  살아남은 ID로 옮긴다. 서로 다른 주제의 동명 항목은 분리한다.
- 한 항목에는 현재 분배 키 하나만 유지해 키 조회가 모호해지지 않게 한다.

## 검증 결과

- API Vitest: 14개 통과
- Flutter 전체 테스트: 448개 통과
- Flutter 정적 분석: 문제 0건
- Railway API health: 정상
- Desktop OAuth broker: `ready`
- Android 패키지: `com.youkdonghun.sprache`
- 버전: `1.25.1+49`
- Android SDK: min 24, target 36
- ABI: `arm64-v8a`, `armeabi-v7a`, `x86_64`
- APK Signature Scheme v2: 검증 통과
- 서명 SHA-1:
  `AB:64:24:D5:FC:BA:3F:76:2C:27:C2:BE:61:3D:1A:A9:C8:4F:1F:AE`
- 세 ABI 모두 운영 Railway URL, Android OAuth Client ID, Server OAuth Client ID,
  개인정보처리방침 URL 포함
- 세 ABI 모두 `127.0.0.1` 개발 주소 없음

## 산출물

- 저장소:
  `artifacts/Sprache-Android-1.25.1-google-debug-signed.apk`
- 바탕화면:
  `C:\Users\youk\Desktop\Sprache-Android-Connected-1.25.1.apk`
- SHA-256:
  `589078EED28C0A5529E24C80BF3A75F72C526909798D83D8D7600A7BF8E6CFC9`

## 남은 외부 검증

현재 ADB에 연결된 Android 기기가 없어 이 실행에서 실제 설치·Google 로그인·
Drive 폴더 선택은 수행하지 못했다. APK는 등록된 로컬 debug SHA-1과 일치하는
직접 설치용 테스트 빌드다. Play Store 배포 전에는 release/upload keystore와
Play App Signing SHA-1용 Android OAuth Client를 별도로 준비해야 한다.
