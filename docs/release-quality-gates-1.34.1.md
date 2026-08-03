# Sprache 1.34.1 품질·릴리스 게이트

## 네 플랫폼 정책

| 플랫폼 | mode | evidence | 반드시 함께 표시할 제한 |
| --- | --- | --- | --- |
| Windows | `REAL` | `RUNTIME` | Authenticode와 실계정 OAuth는 각각 별도 결과로 판정 |
| Android | `REAL` | `BUILD_ONLY` | 앱 실행·계정 로그인·Drive 왕복을 증명하지 않음 |
| iOS Simulator | `REAL` | `RUNTIME` | Simulator 전용, 실계정 OAuth 미검증, IPA 아님 |
| macOS | `REAL` | `RUNTIME` | ad-hoc·비공증, 실계정 OAuth 미검증 |

Apple에서 `REAL`은 실제 OAuth 설정을 포함했다는 뜻으로만 사용한다. iOS와
macOS runtime evidence에는 다음 세 항목이 모두 있어야 한다.

```json
{
  "googleOAuthConfigured": true,
  "googleOAuthRuntimeVerified": false,
  "googleOAuthClientId": "1054343487948-8ueu92l0ov3259rs8psun40c6iu4arel.apps.googleusercontent.com",
  "appleDistributionSigningVerified": false,
  "signing": "SIMULATOR 또는 AD_HOC",
  "limitation": "<플랫폼별 서명·설치 제한>"
}
```

`release-bundle.mjs`는 Apple Client ID 구성이 없거나, 자동화하지 않은 실계정
OAuth를 성공했다고 주장하거나, limitation이 비어 있으면 manifest 생성을
거부한다.

## Windows credential 게이트

- REAL 빌드, 실계정 E2E와 `verify-release.ps1`은 현재 프로세스의
  `SPRACHE_GOOGLE_DESKTOP_CLIENT_SECRET`이 없으면 시작하지 않는다.
- 값은 스크립트 인수, 저장소, checksum, evidence, manifest와 출력 메시지에
  기록하지 않는다.
- verifier는 Windows `app.so`에 새 Desktop Client ID와 현재 환경에서 받은
  credential이 반영됐는지만 값 비노출 방식으로 검사한다.
- PKCE verifier, 인증 코드, access/refresh token은 기존과 같이 OS 보안 저장소
  경계 밖에 보존하지 않는다.

## Android OAuth 등록 게이트

- package: `com.youkdonghun.sprache`
- 직접 설치용 Debug SHA-1:
  `EF:1E:2A:C5:22:FC:BF:65:53:DC:35:35:0E:36:04:4F:F3:BC:F3:E2`
- Debug SHA-256:
  `0D:9C:FD:91:41:3F:00:14:5A:9E:5D:BF:F6:40:56:A6:47:A5:F0:F5:17:36:32:3A:EB:FE:44:A5:37:8B:4E:68`
- 위 package·SHA-1은 Android client
  `1054343487948-v3u90fo5nmbrk4hn7ss2gnrg601phkuv.apps.googleusercontent.com`에
  2026-08-03 등록·재조회했다.
- Release/Play 서명을 사용할 때는 `verify-release.ps1`에 해당 인증서의 기대
  SHA-1을 명시하고 Google Cloud에 별도 Android client를 등록한다.

## 최종 승격

```powershell
npm run test:release-bundle
npm run verify:release
npm run create:release-bundle -- `
  --spec packaging/release-bundle-spec-1.34.1.json `
  --root <최종-산출물-폴더> `
  --out <최종-산출물-폴더>\release-manifest-1.34.1.json
npm run verify:release-bundle -- `
  --manifest <최종-산출물-폴더>\release-manifest-1.34.1.json `
  --root <최종-산출물-폴더>
```

새 manifest 검증 전에는 1.34.0 산출물을 삭제하거나 1.34.1을 최종 완료로
표시하지 않는다.
