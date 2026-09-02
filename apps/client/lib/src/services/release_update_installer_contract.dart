import 'release_update_service.dart';

typedef ReleaseDownloadProgress = void Function(int received, int total);

class ReleaseInstallResult {
  const ReleaseInstallResult({required this.message, this.downloadedPath});

  final String message;
  final String? downloadedPath;
}

abstract interface class ReleaseUpdateInstaller {
  String get platformKey;

  Future<ReleaseInstallResult> downloadAndOpen(
    ReleaseArtifact artifact, {
    required Uri releasePageUrl,
    required ReleaseDownloadProgress onProgress,
  });

  Future<ReleaseInstallResult> openReleasePage(Uri releasePageUrl);
}
