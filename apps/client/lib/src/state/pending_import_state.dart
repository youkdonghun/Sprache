import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class PendingImportFile {
  const PendingImportFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

final pendingImportFileProvider = StateProvider<PendingImportFile?>(
  (ref) => null,
);
