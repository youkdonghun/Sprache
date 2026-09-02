import 'dart:ui';

import 'package:share_plus/share_plus.dart';

import 'release_update_service.dart';

abstract interface class ReleaseLinkShareService {
  Future<void> shareLatestAndroidApk({
    required ReleaseManifest manifest,
    Rect? origin,
  });
}

class DeviceReleaseLinkShareService implements ReleaseLinkShareService {
  const DeviceReleaseLinkShareService();

  @override
  Future<void> shareLatestAndroidApk({
    required ReleaseManifest manifest,
    Rect? origin,
  }) async {
    final artifact = manifest.artifactFor('android');
    if (artifact == null || artifact.kind != 'apk') {
      throw const ReleaseUpdateException('공유할 Android APK가 아직 준비되지 않았습니다.');
    }
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Sprache ${manifest.version} Android APK',
        text: 'Sprache ${manifest.version} Android 설치 파일\n${artifact.url}',
        sharePositionOrigin: origin,
      ),
    );
  }
}
