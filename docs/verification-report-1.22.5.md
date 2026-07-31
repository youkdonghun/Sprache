# Sprache 1.22.5 검증 보고서

검증일: 2026-07-30

## 변경 범위

- 데스크톱 채점 결과가 하단 영역의 전체 높이로 늘어나던 원인을 제거했다.
- 정답·오답 결과는 현재 문제 화면 위의 모달 팝업으로 표시한다.
- 팝업 최대 폭은 420px, 최대 높이는 360px이며 긴 내용은 내부에서
  스크롤된다.
- `다음 문제`는 팝업 안에 두고 기존 Enter 키 진행도 유지한다.
- 모달 바깥은 흐리게 표시하고 눌러서 실수로 닫히지 않게 했다.

## 검증

| 검사 | 결과 |
| --- | --- |
| `npm run analyze:client` | 이슈 0개 |
| 학습·Windows 키보드 위젯 테스트 | 50개 통과 |
| 시각 회귀 테스트 | 20개 통과 |
| `npm run test:client` | 360개 통과 |
| `npm run verify:release` | 통과 |

팝업 크기는 모바일 412×915와 Windows 1024×720에서 폭 420px 이하,
높이 260px 미만으로 고정 검증한다. 모바일 라이트·다크와 Windows 팝업
골든을 직접 확인했으며 문제·선택 결과가 뒤에 유지되고 오버플로가 없었다.

## 실행

- Windows `1.22.5+43` release 앱을 다시 실행했다.
- 프로세스 ID 18604, 창 제목 `작업 보드`, `Responding=True`를 확인했다.
- 사용자 테스트 창을 유지하기 위해 설치→실행→제거 스모크는 다시
  실행하지 않았다.

## 산출물

| 파일 | SHA-256 |
| --- | --- |
| `Sprache-Android-1.22.5-google-debug-signed.apk` | `5BC781CD2DBE740B462C9DE0F96A50443A8D1ACE4344ECEA4A360F09AF6AC762` |
| `Sprache-Windows-1.22.5-google-x64.zip` | `CE27A979B9F457268D5F81BCC470BE209E76C9EC8ED19220974DB8F15D31F87E` |
| `Sprache-Windows-Setup-1.22.5-google-x64.exe` | `40CF5F7F463ABF841372957B8C90B5F47F4F11D108265731EDE8523AA53C8816` |

현재 바탕 화면의 Android 설치 파일:
`C:\Users\youk\Desktop\Sprache-Android-1.22.5.apk`
