import 'package:flutter/foundation.dart';
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
    required this.reduceTransparency,
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
      reduceTransparency: profile.reduceTransparency,
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
  final bool reduceTransparency;
  final bool visibleSelectionControls;

  @override
  StudyAccessibilityTheme copyWith({
    double? cardScaleFactor,
    double? minimumRatingControlHeight,
    bool? highContrast,
    bool? reduceMotion,
    bool? reduceTransparency,
    bool? visibleSelectionControls,
  }) {
    return StudyAccessibilityTheme(
      cardScaleFactor: cardScaleFactor ?? this.cardScaleFactor,
      minimumRatingControlHeight:
          minimumRatingControlHeight ?? this.minimumRatingControlHeight,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      reduceTransparency: reduceTransparency ?? this.reduceTransparency,
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
      reduceTransparency: t < 0.5
          ? reduceTransparency
          : other.reduceTransparency,
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
    StudyShortcutKey.escape => LogicalKeyboardKey.escape,
    StudyShortcutKey.f6 => LogicalKeyboardKey.f6,
    StudyShortcutKey.controlH => LogicalKeyboardKey.keyH,
    StudyShortcutKey.controlG => LogicalKeyboardKey.keyG,
    StudyShortcutKey.controlL => LogicalKeyboardKey.keyL,
    StudyShortcutKey.controlK => LogicalKeyboardKey.keyK,
    StudyShortcutKey.controlN => LogicalKeyboardKey.keyN,
    StudyShortcutKey.controlSlash => LogicalKeyboardKey.slash,
    StudyShortcutKey.controlShiftF => LogicalKeyboardKey.keyF,
    StudyShortcutKey.controlShiftM => LogicalKeyboardKey.keyM,
  };

  SingleActivator? get activator => activatorFor(defaultTargetPlatform);

  SingleActivator? activatorFor(TargetPlatform platform) {
    final key = logicalKey;
    if (key == null) return null;
    final command = platform == TargetPlatform.macOS;
    return switch (this) {
      StudyShortcutKey.controlH ||
      StudyShortcutKey.controlG ||
      StudyShortcutKey.controlL ||
      StudyShortcutKey.controlK ||
      StudyShortcutKey.controlN ||
      StudyShortcutKey.controlSlash => SingleActivator(
        key,
        control: !command,
        meta: command,
      ),
      StudyShortcutKey.controlShiftF || StudyShortcutKey.controlShiftM =>
        SingleActivator(key, control: !command, meta: command, shift: true),
      _ => SingleActivator(key),
    };
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
    StudyShortcutKey.escape => 'Esc',
    StudyShortcutKey.f6 => 'F6',
    StudyShortcutKey.controlH => 'Ctrl+H',
    StudyShortcutKey.controlG => 'Ctrl+G',
    StudyShortcutKey.controlL => 'Ctrl+L',
    StudyShortcutKey.controlK => 'Ctrl+K',
    StudyShortcutKey.controlN => 'Ctrl+N',
    StudyShortcutKey.controlSlash => 'Ctrl+/',
    StudyShortcutKey.controlShiftF => 'Ctrl+Shift+F',
    StudyShortcutKey.controlShiftM => 'Ctrl+Shift+M',
  };

  String displayLabelFor(TargetPlatform platform) =>
      platform == TargetPlatform.macOS
      ? displayLabel.replaceFirst('Ctrl', '⌘')
      : displayLabel;
}

extension AccessibilityShortcutBindings on AccessibilityInputProfile {
  /// Builds conflict-free CallbackShortcuts bindings for the supplied actions.
  Map<ShortcutActivator, VoidCallback> bindingsFor(
    Map<StudyShortcutAction, VoidCallback> callbacks, {
    TargetPlatform? platform,
  }) {
    final bindings = <ShortcutActivator, VoidCallback>{};
    for (final entry in callbacks.entries) {
      final shortcut = shortcutFor(entry.key);
      final activator = shortcut.activatorFor(
        platform ?? defaultTargetPlatform,
      );
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

extension AccessibilityGlobalShortcutBindings on AccessibilityInputProfile {
  Map<ShortcutActivator, VoidCallback> globalBindingsFor(
    Map<GlobalShortcutAction, VoidCallback> callbacks, {
    TargetPlatform? platform,
  }) {
    final bindings = <ShortcutActivator, VoidCallback>{};
    for (final entry in callbacks.entries) {
      final activator = globalShortcutFor(
        entry.key,
      ).activatorFor(platform ?? defaultTargetPlatform);
      if (activator != null) bindings[activator] = entry.value;
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
