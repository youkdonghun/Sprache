import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/services/app_clock.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  final matrix = _loadMatrix();

  test('visual and semantics matrix contains every release platform', () {
    expect(matrix.format, 'sprache-visual-semantics-matrix-v1');
    expect(matrix.cases, hasLength(8));
    expect(
      matrix.cases.map((value) => value.platform).toSet(),
      TargetPlatform.values
          .where(
            (platform) => const {
              TargetPlatform.android,
              TargetPlatform.iOS,
              TargetPlatform.windows,
              TargetPlatform.macOS,
            }.contains(platform),
          )
          .toSet(),
    );
    for (final platform
        in matrix.cases.map((value) => value.platform).toSet()) {
      final platformCases = matrix.cases.where(
        (value) => value.platform == platform,
      );
      expect(
        platformCases.map((value) => value.dark),
        containsAll([true, false]),
      );
      expect(
        platformCases.map((value) => value.textScale),
        containsAll([1.0, 1.3]),
      );
    }
  });

  for (final matrixCase in matrix.cases) {
    testWidgets('${matrixCase.id} golden and semantics stay stable', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = matrixCase.platform;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(matrixCase.width, matrixCase.height);
      tester.binding.platformDispatcher.textScaleFactorTestValue =
          matrixCase.textScale;
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(
                MemoryStudyStore(
                  preferences: StudyPreferences(
                    onboardingCompleted: true,
                    experience: AppExperiencePreferences(
                      colorMode: matrixCase.dark
                          ? AppColorMode.dark
                          : AppColorMode.light,
                    ),
                  ),
                ),
              ),
              appClockProvider.overrideWithValue(
                () => DateTime(2026, 8, 3, 10, 30),
              ),
            ],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final primary = tester
            .getSemantics(find.byKey(const Key('home-primary-study-button')))
            .getSemanticsData();
        final settingsSemantics = find.descendant(
          of: find.byKey(const Key('home-settings')),
          matching: find.byType(Semantics),
        );
        expect(settingsSemantics, findsWidgets);
        final settings = tester
            .getSemantics(settingsSemantics.last)
            .getSemanticsData();
        expect(primary.hasAction(ui.SemanticsAction.tap), isTrue);
        expect(primary.label.trim(), isNotEmpty);
        expect(settings.hasAction(ui.SemanticsAction.tap), isTrue);
        expect('${settings.label} ${settings.tooltip}'.trim(), isNotEmpty);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/release-matrix-${matrixCase.id}.png'),
        );
      } finally {
        semantics.dispose();
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    });
  }
}

class _ReleaseMatrix {
  const _ReleaseMatrix(this.format, this.cases);

  final String format;
  final List<_ReleaseMatrixCase> cases;
}

class _ReleaseMatrixCase {
  const _ReleaseMatrixCase({
    required this.id,
    required this.platform,
    required this.dark,
    required this.width,
    required this.height,
    required this.textScale,
  });

  final String id;
  final TargetPlatform platform;
  final bool dark;
  final double width;
  final double height;
  final double textScale;
}

_ReleaseMatrix _loadMatrix() {
  final decoded = Map<String, Object?>.from(
    jsonDecode(
          File(
            'test/fixtures/qa/visual-semantics-matrix-v1.json',
          ).readAsStringSync(),
        )
        as Map,
  );
  final rawCases = decoded['cases']! as List<Object?>;
  return _ReleaseMatrix(
    decoded['format']! as String,
    List.unmodifiable(
      rawCases.map((raw) {
        final value = Map<String, Object?>.from(raw! as Map);
        return _ReleaseMatrixCase(
          id: value['id']! as String,
          platform: switch (value['platform']) {
            'android' => TargetPlatform.android,
            'ios' => TargetPlatform.iOS,
            'windows' => TargetPlatform.windows,
            'macos' => TargetPlatform.macOS,
            final Object? unsupported => throw FormatException(
              'Unsupported matrix platform: $unsupported',
            ),
          },
          dark: value['theme'] == 'dark',
          width: (value['width']! as num).toDouble(),
          height: (value['height']! as num).toDouble(),
          textScale: (value['textScale']! as num).toDouble(),
        );
      }),
    ),
  );
}
