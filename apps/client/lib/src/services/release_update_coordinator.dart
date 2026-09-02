import 'release_update_installer.dart';
import 'release_update_service.dart';

abstract interface class ReleaseUpdateCoordinator {
  String get platformKey;

  Future<ReleaseUpdateCheck> check(
    String currentVersion, {
    int currentBuildNumber = 0,
  });

  Future<ReleaseInstallResult> apply(
    ReleaseUpdateCheck check, {
    required ReleaseDownloadProgress onProgress,
  });
}

class DeviceReleaseUpdateCoordinator implements ReleaseUpdateCoordinator {
  DeviceReleaseUpdateCoordinator({
    required Uri manifestUri,
    ReleaseUpdateService? service,
    ReleaseUpdateInstaller? installer,
  }) : _service = service ?? ReleaseUpdateService(manifestUri: manifestUri),
       _installer = installer ?? createReleaseUpdateInstaller();

  final ReleaseUpdateService _service;
  final ReleaseUpdateInstaller _installer;

  @override
  String get platformKey => _installer.platformKey;

  @override
  Future<ReleaseUpdateCheck> check(
    String currentVersion, {
    int currentBuildNumber = 0,
  }) => _service.check(
    currentVersion: currentVersion,
    platform: platformKey,
    currentBuildNumber: currentBuildNumber,
  );

  @override
  Future<ReleaseInstallResult> apply(
    ReleaseUpdateCheck check, {
    required ReleaseDownloadProgress onProgress,
  }) {
    final artifact = check.artifact;
    if (artifact == null) {
      return _installer.openReleasePage(check.manifest.releasePageUrl);
    }
    return _installer.downloadAndOpen(
      artifact,
      releasePageUrl: check.manifest.releasePageUrl,
      onProgress: onProgress,
    );
  }
}
