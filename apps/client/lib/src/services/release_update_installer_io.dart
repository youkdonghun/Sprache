import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as paths;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'release_update_installer_contract.dart';
import 'release_update_service.dart';

const _updateChannel = MethodChannel('com.youkdonghun.sprache/update');

ReleaseUpdateInstaller createReleaseUpdateInstaller() =>
    _IoReleaseUpdateInstaller();

class _IoReleaseUpdateInstaller implements ReleaseUpdateInstaller {
  _IoReleaseUpdateInstaller({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get platformKey {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isIOS) return 'ios';
    return 'unsupported';
  }

  @override
  Future<ReleaseInstallResult> downloadAndOpen(
    ReleaseArtifact artifact, {
    required Uri releasePageUrl,
    required ReleaseDownloadProgress onProgress,
  }) async {
    if (!artifact.isDownload ||
        (platformKey != 'android' && platformKey != 'windows')) {
      return openReleasePage(releasePageUrl);
    }
    final file = await _downloadVerified(artifact, onProgress);
    if (Platform.isAndroid) {
      try {
        await _updateChannel.invokeMethod<void>('openPackageInstaller', {
          'path': file.path,
        });
      } on PlatformException catch (error) {
        if (error.code == 'install_permission_required') {
          throw const ReleaseUpdateException(
            '설정에서 “이 출처 허용”을 켠 뒤 설치 버튼을 다시 눌러 주세요.',
          );
        }
        throw const ReleaseUpdateException('Android 설치 화면을 열지 못했습니다.');
      }
      return ReleaseInstallResult(
        message: 'Android 설치 화면을 열었습니다.',
        downloadedPath: file.path,
      );
    }
    late final Process process;
    try {
      process = await Process.start(
        file.path,
        const [],
        mode: ProcessStartMode.detached,
      );
    } on ProcessException {
      throw const ReleaseUpdateException('Windows 설치 프로그램을 열지 못했습니다.');
    }
    if (process.pid <= 0) {
      throw const ReleaseUpdateException('Windows 설치 프로그램을 열지 못했습니다.');
    }
    return ReleaseInstallResult(
      message: '설치 화면을 열었습니다. Sprache를 닫고 업데이트를 진행해 주세요.',
      downloadedPath: file.path,
    );
  }

  Future<File> _downloadVerified(
    ReleaseArtifact artifact,
    ReleaseDownloadProgress onProgress,
  ) async {
    final fileName = artifact.fileName!;
    final expectedSize = artifact.sizeBytes!;
    final expectedHash = artifact.sha256!;
    final root = Directory(
      paths.join((await getTemporaryDirectory()).path, 'sprache-updates'),
    );
    await root.create(recursive: true);
    final finalFile = File(paths.join(root.path, fileName));
    final partialFile = File('${finalFile.path}.part');
    if (await partialFile.exists()) await partialFile.delete();

    final request = http.Request('GET', artifact.url)
      ..headers['Accept'] = 'application/octet-stream';
    http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const ReleaseUpdateException('업데이트 다운로드를 시작하지 못했습니다.');
    }
    if (response.statusCode != 200) {
      throw ReleaseUpdateException(
        '업데이트 파일이 ${response.statusCode} 응답을 반환했습니다.',
      );
    }
    if (response.contentLength case final contentLength?) {
      if (contentLength != expectedSize) {
        throw const ReleaseUpdateException('업데이트 파일 크기가 배포 정보와 다릅니다.');
      }
    }

    final digestValues = <Digest>[];
    final digestOutput = ChunkedConversionSink<Digest>.withCallback(
      digestValues.addAll,
    );
    final digestInput = sha256.startChunkedConversion(digestOutput);
    final sink = partialFile.openWrite();
    var received = 0;
    var digestClosed = false;
    var sinkClosed = false;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 45),
      )) {
        received += chunk.length;
        if (received > expectedSize) {
          throw const ReleaseUpdateException('업데이트 파일이 예상 크기를 넘었습니다.');
        }
        digestInput.add(chunk);
        sink.add(chunk);
        onProgress(received, expectedSize);
      }
      digestInput.close();
      digestClosed = true;
      await sink.flush();
      await sink.close();
      sinkClosed = true;
      if (received != expectedSize ||
          digestValues.length != 1 ||
          digestValues.single.toString() != expectedHash) {
        throw const ReleaseUpdateException('업데이트 파일 무결성 확인에 실패했습니다.');
      }
      if (await finalFile.exists()) await finalFile.delete();
      return partialFile.rename(finalFile.path);
    } catch (error) {
      if (!digestClosed) {
        try {
          digestInput.close();
        } catch (_) {
          // Preserve the original download error.
        }
      }
      if (!sinkClosed) {
        try {
          await sink.close();
        } catch (_) {
          // Preserve the original download error.
        }
      }
      if (await partialFile.exists()) await partialFile.delete();
      if (error is ReleaseUpdateException) rethrow;
      throw const ReleaseUpdateException('업데이트 다운로드가 중단됐습니다.');
    }
  }

  @override
  Future<ReleaseInstallResult> openReleasePage(Uri releasePageUrl) async {
    if (!await launchUrl(releasePageUrl, mode: LaunchMode.externalApplication)) {
      throw const ReleaseUpdateException('릴리스 페이지를 열지 못했습니다.');
    }
    return const ReleaseInstallResult(message: '릴리스 페이지를 열었습니다.');
  }
}
