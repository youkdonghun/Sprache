import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PlatformCompletionService {
  const PlatformCompletionService();

  Future<void> shareFile({
    required String fileName,
    required Uint8List bytes,
    Rect? origin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, name: fileName, mimeType: 'application/json'),
        ],
        fileNameOverrides: [fileName],
        subject: 'Sprache 학습 자료',
        sharePositionOrigin: origin,
      ),
    );
  }

  Future<bool> openFile(String path) => launchUrl(
    Uri.file(path, windows: Platform.isWindows),
    mode: LaunchMode.externalApplication,
  );

  Future<bool> openContainingFolder(String path) => launchUrl(
    Uri.directory(p.dirname(path), windows: Platform.isWindows),
    mode: LaunchMode.externalApplication,
  );
}
