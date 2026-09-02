import 'package:url_launcher/url_launcher.dart';

import 'release_update_installer_contract.dart';
import 'release_update_service.dart';

ReleaseUpdateInstaller createReleaseUpdateInstaller() =>
    const _FallbackReleaseUpdateInstaller();

class _FallbackReleaseUpdateInstaller implements ReleaseUpdateInstaller {
  const _FallbackReleaseUpdateInstaller();

  @override
  String get platformKey => 'unsupported';

  @override
  Future<ReleaseInstallResult> downloadAndOpen(
    ReleaseArtifact artifact, {
    required Uri releasePageUrl,
    required ReleaseDownloadProgress onProgress,
  }) => openReleasePage(releasePageUrl);

  @override
  Future<ReleaseInstallResult> openReleasePage(Uri releasePageUrl) async {
    if (!await launchUrl(releasePageUrl, mode: LaunchMode.externalApplication)) {
      throw const ReleaseUpdateException('릴리스 페이지를 열지 못했습니다.');
    }
    return const ReleaseInstallResult(message: '릴리스 페이지를 열었습니다.');
  }
}
