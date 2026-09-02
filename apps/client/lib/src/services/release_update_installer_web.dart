import 'package:web/web.dart' as web;

import 'release_update_installer_contract.dart';
import 'release_update_service.dart';

ReleaseUpdateInstaller createReleaseUpdateInstaller() =>
    const _WebReleaseUpdateInstaller();

class _WebReleaseUpdateInstaller implements ReleaseUpdateInstaller {
  const _WebReleaseUpdateInstaller();

  @override
  String get platformKey => 'pwa';

  @override
  Future<ReleaseInstallResult> downloadAndOpen(
    ReleaseArtifact artifact, {
    required Uri releasePageUrl,
    required ReleaseDownloadProgress onProgress,
  }) async {
    web.window.location.reload();
    return const ReleaseInstallResult(message: '새 버전을 불러오고 있습니다.');
  }

  @override
  Future<ReleaseInstallResult> openReleasePage(Uri releasePageUrl) async {
    web.window.location.href = releasePageUrl.toString();
    return const ReleaseInstallResult(message: '릴리스 페이지를 열었습니다.');
  }
}
