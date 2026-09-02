import 'dart:ui';

import 'package:share_plus/share_plus.dart';

import 'release_update_service.dart';

const defaultSharedPwaUrl = 'https://sprache6.github.io/app/';
const defaultSharedAndroidUrl =
    'https://github.com/youkdonghun/Sprache/releases/latest';

abstract interface class ReleaseLinkShareService {
  Future<void> shareAppLinks({ReleaseManifest? manifest, Rect? origin});
}

String appInstallShareText([ReleaseManifest? manifest]) {
  final androidArtifact = manifest?.artifactFor('android');
  final androidUrl = androidArtifact?.kind == 'apk'
      ? androidArtifact!.url.toString()
      : defaultSharedAndroidUrl;
  return 'Sprache로 함께 공부해요.\n'
      'Android 설치: $androidUrl\n'
      'iPhone·iPad에서 실행: $defaultSharedPwaUrl';
}

class DeviceReleaseLinkShareService implements ReleaseLinkShareService {
  const DeviceReleaseLinkShareService();

  @override
  Future<void> shareAppLinks({ReleaseManifest? manifest, Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Sprache 앱 설치 링크',
        text: appInstallShareText(manifest),
        sharePositionOrigin: origin,
      ),
    );
  }
}
