import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/services/window_placement_service.dart';

void main() {
  test('saved window is clamped fully into the closest current monitor', () {
    final clamped = clampWindowToDisplays(
      const Rect.fromLTWH(1800, 900, 900, 800),
      const [
        Rect.fromLTWH(0, 0, 1920, 1040),
        Rect.fromLTWH(1920, 0, 1280, 984),
      ],
    );

    expect(clamped.left, 1920);
    expect(clamped.top, 184);
    expect(clamped.right, lessThanOrEqualTo(3200));
    expect(clamped.bottom, lessThanOrEqualTo(984));
  });

  test('removed monitor falls back to the primary visible workspace', () {
    final clamped = clampWindowToDisplays(
      const Rect.fromLTWH(-3000, 200, 1000, 700),
      const [Rect.fromLTWH(0, 0, 1366, 728)],
    );
    expect(clamped, const Rect.fromLTWH(0, 28, 1000, 700));
  });

  test(
    'placement store accepts valid data and ignores malformed data',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'sprache-window-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final file = File(
        '${root.path}${Platform.pathSeparator}window-placement-v1.json',
      );
      await file.writeAsString(
        jsonEncode(
          const WindowPlacement(
            bounds: Rect.fromLTWH(10, 20, 900, 700),
            maximized: true,
            focused: false,
          ).toJson(),
        ),
      );
      final service = WindowPlacementService(
        supportDirectory: () async => root,
      );
      final loaded = await service.load();
      expect(loaded?.bounds, const Rect.fromLTWH(10, 20, 900, 700));
      expect(loaded?.maximized, isTrue);
      expect(loaded?.focused, isFalse);

      await file.writeAsString('{bad');
      expect(await service.load(), isNull);
    },
  );
}
