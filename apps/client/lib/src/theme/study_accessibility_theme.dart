import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/accessibility_input_profile.dart';

/// Theme tokens shared by all study surfaces.
@immutable
class StudyAccessibilityTheme extends ThemeExtension<StudyAccessibilityTheme> {
  const StudyAccessibilityTheme({
    required this.cardScaleFactor,
    required this.minimumRatingControlHeight,
    required this.highContrast,
    required this.reduceMotion,
    required this.visibleSelectionControls,
  });

  factory StudyAccessibilityTheme.fromProfile(
    AccessibilityInputProfile profile,
  ) {
    return StudyAccessibilityTheme(
      cardScaleFactor: profile.cardScaleFactor,
      minimumRatingControlHeight: profile.minimumRatingControlHeight,
      highContrast: profile.highContrast,
      reduceMotion: profile.reduceMotion,
      visibleSelectionControls: profile.requiresVisibleSelectionControls,
    );
  }

  static StudyAccessibilityTheme of(BuildContext context) {
    return Theme.of(context).extension<StudyAccessibilityTheme>() ??
        StudyAccessibilityTheme.fromProfile(const AccessibilityInputProfile());
  }

  final double cardScaleFactor;
  final double minimumRatingControlHeight;
  final bool highContrast;
  final bool reduceMotion;
  final bool visibleSelectionControls;

  @override
  StudyAccessibilityTheme copyWith({
    double? cardScaleFactor,
    double? minimumRatingControlHeight,
    bool? highContrast,
    bool? reduceMotion,
    bool? visibleSelectionControls,
  }) {
    return StudyAccessibilityTheme(
      cardScaleFactor: cardScaleFactor ?? this.cardScaleFactor,
      minimumRatingControlHeight:
          minimumRatingControlHeight ?? this.minimumRatingControlHeight,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      visibleSelectionControls:
          visibleSelectionControls ?? this.visibleSelectionControls,
    );
  }

  @override
  StudyAccessibilityTheme lerp(
    covariant StudyAccessibilityTheme? other,
    double t,
  ) {
    if (other == null) return this;
    return StudyAccessibilityTheme(
      cardScaleFactor:
          lerpDouble(cardScaleFactor, other.cardScaleFactor, t) ??
          cardScaleFactor,
      minimumRatingControlHeight:
          lerpDouble(
            minimumRatingControlHeight,
            other.minimumRatingControlHeight,
            t,
          ) ??
          minimumRatingControlHeight,
      highContrast: t < 0.5 ? highContrast : other.highContrast,
      reduceMotion: t < 0.5 ? reduceMotion : other.reduceMotion,
      visibleSelectionControls: t < 0.5
          ? visibleSelectionControls
          : other.visibleSelectionControls,
    );
  }
}

extension StudyShortcutKeyFlutter on StudyShortcutKey {
  LogicalKeyboardKey? get logicalKey => switch (this) {
    StudyShortcutKey.none => null,
    StudyShortcutKey.digit1 => LogicalKeyboardKey.digit1,
    StudyShortcutKey.digit2 => LogicalKeyboardKey.digit2,
    StudyShortcutKey.digit3 => LogicalKeyboardKey.digit3,
    StudyShortcutKey.digit4 => LogicalKeyboardKey.digit4,
    StudyShortcutKey.space => LogicalKeyboardKey.space,
    StudyShortcutKey.enter => LogicalKeyboardKey.enter,
    StudyShortcutKey.keyA => LogicalKeyboardKey.keyA,
    StudyShortcutKey.keyS => LogicalKeyboardKey.keyS,
    StudyShortcutKey.keyD => LogicalKeyboardKey.keyD,
    StudyShortcutKey.keyF => LogicalKeyboardKey.keyF,
    StudyShortcutKey.keyP => LogicalKeyboardKey.keyP,
    StudyShortcutKey.keyR => LogicalKeyboardKey.keyR,
    StudyShortcutKey.arrowLeft => LogicalKeyboardKey.arrowLeft,
    StudyShortcutKey.arrowRight => LogicalKeyboardKey.arrowRight,
  };

  SingleActivator? get activator {
    final key = logicalKey;
    return key == null ? null : SingleActivator(key);
  }

  String get displayLabel => switch (this) {
    StudyShortcutKey.none => '사용 안 함',
    StudyShortcutKey.digit1 => '1',
    StudyShortcutKey.digit2 => '2',
    StudyShortcutKey.digit3 => '3',
    StudyShortcutKey.digit4 => '4',
    StudyShortcutKey.space => 'Space',
    StudyShortcutKey.enter => 'Enter',
    StudyShortcutKey.keyA => 'A',
    StudyShortcutKey.keyS => 'S',
    StudyShortcutKey.keyD => 'D',
    StudyShortcutKey.keyF => 'F',
    StudyShortcutKey.keyP => 'P',
    StudyShortcutKey.keyR => 'R',
    StudyShortcutKey.arrowLeft => '←',
    StudyShortcutKey.arrowRight => '→',
  };
}

extension AccessibilityShortcutBindings on AccessibilityInputProfile {
  /// Builds conflict-free CallbackShortcuts bindings for the supplied actions.
  Map<ShortcutActivator, VoidCallback> bindingsFor(
    Map<StudyShortcutAction, VoidCallback> callbacks,
  ) {
    final bindings = <ShortcutActivator, VoidCallback>{};
    for (final entry in callbacks.entries) {
      final shortcut = shortcutFor(entry.key);
      final activator = shortcut.activator;
      if (activator != null) bindings[activator] = entry.value;
      final numpadKey = switch (shortcut) {
        StudyShortcutKey.digit1 => LogicalKeyboardKey.numpad1,
        StudyShortcutKey.digit2 => LogicalKeyboardKey.numpad2,
        StudyShortcutKey.digit3 => LogicalKeyboardKey.numpad3,
        StudyShortcutKey.digit4 => LogicalKeyboardKey.numpad4,
        _ => null,
      };
      if (numpadKey != null) {
        bindings[SingleActivator(numpadKey)] = entry.value;
      }
    }
    return bindings;
  }
}

double? lerpDouble(num? a, num? b, double t) {
  if (a == null && b == null) return null;
  a ??= 0;
  b ??= 0;
  return a + (b - a) * t;
}
