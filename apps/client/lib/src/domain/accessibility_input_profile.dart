/// Card sizing used by study and review surfaces.
enum AccessibilityCardScale { standard, large, extraLarge }

/// Optional Android selection gestures.
///
/// Visible controls remain available for every value. Gestures are only an
/// additional input path and are never the sole way to finish an operation.
enum AndroidSelectionGesture { buttonsOnly, tapAndButtons, swipeAndButtons }

/// Actions that study surfaces may expose as remappable Windows shortcuts.
enum StudyShortcutAction {
  revealAnswer,
  playAudio,
  rateAgain,
  rateHard,
  rateGood,
  rateEasy,
  nextItem,
}

/// A deliberately small, conflict-safe set of keys for study shortcuts.
enum StudyShortcutKey {
  none,
  digit1,
  digit2,
  digit3,
  digit4,
  space,
  enter,
  keyA,
  keyS,
  keyD,
  keyF,
  keyP,
  keyR,
  arrowLeft,
  arrowRight,
}

const _defaultStudyShortcuts = <StudyShortcutAction, StudyShortcutKey>{
  StudyShortcutAction.revealAnswer: StudyShortcutKey.space,
  StudyShortcutAction.playAudio: StudyShortcutKey.keyP,
  StudyShortcutAction.rateAgain: StudyShortcutKey.digit1,
  StudyShortcutAction.rateHard: StudyShortcutKey.digit2,
  StudyShortcutAction.rateGood: StudyShortcutKey.digit3,
  StudyShortcutAction.rateEasy: StudyShortcutKey.digit4,
  StudyShortcutAction.nextItem: StudyShortcutKey.enter,
};

/// Device-local accessibility and input preferences.
///
/// This model intentionally does not live in [StudyPreferences], because
/// keyboard layout, motion sensitivity and gesture preferences are properties
/// of a device rather than account data that should be copied through Drive.
class AccessibilityInputProfile {
  const AccessibilityInputProfile({
    this.largeRatingControls = false,
    this.cardScale = AccessibilityCardScale.standard,
    this.highContrast = false,
    this.reduceMotion = false,
    this.disableTimedChallenges = false,
    this.androidSelectionGesture = AndroidSelectionGesture.tapAndButtons,
    this.windowsShortcuts = _defaultStudyShortcuts,
  });

  final bool largeRatingControls;
  final AccessibilityCardScale cardScale;
  final bool highContrast;
  final bool reduceMotion;
  final bool disableTimedChallenges;
  final AndroidSelectionGesture androidSelectionGesture;
  final Map<StudyShortcutAction, StudyShortcutKey> windowsShortcuts;

  double get cardScaleFactor => switch (cardScale) {
    AccessibilityCardScale.standard => 1,
    AccessibilityCardScale.large => 1.14,
    AccessibilityCardScale.extraLarge => 1.28,
  };

  double get minimumRatingControlHeight => largeRatingControls ? 64 : 48;

  bool get selectionGesturesEnabled =>
      androidSelectionGesture != AndroidSelectionGesture.buttonsOnly;

  bool get allowsTimedChallenges => !disableTimedChallenges;

  /// Buttons are always shown even when an Android gesture is enabled.
  bool get requiresVisibleSelectionControls => true;

  StudyShortcutKey shortcutFor(StudyShortcutAction action) =>
      windowsShortcuts[action] ?? _defaultStudyShortcuts[action]!;

  AccessibilityInputProfile copyWith({
    bool? largeRatingControls,
    AccessibilityCardScale? cardScale,
    bool? highContrast,
    bool? reduceMotion,
    bool? disableTimedChallenges,
    AndroidSelectionGesture? androidSelectionGesture,
    Map<StudyShortcutAction, StudyShortcutKey>? windowsShortcuts,
  }) {
    return AccessibilityInputProfile(
      largeRatingControls: largeRatingControls ?? this.largeRatingControls,
      cardScale: cardScale ?? this.cardScale,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      disableTimedChallenges:
          disableTimedChallenges ?? this.disableTimedChallenges,
      androidSelectionGesture:
          androidSelectionGesture ?? this.androidSelectionGesture,
      windowsShortcuts: Map.unmodifiable(
        windowsShortcuts ?? this.windowsShortcuts,
      ),
    );
  }

  /// Remaps [action] and removes an existing conflicting assignment.
  AccessibilityInputProfile remapShortcut(
    StudyShortcutAction action,
    StudyShortcutKey key,
  ) {
    final next = Map<StudyShortcutAction, StudyShortcutKey>.from(
      windowsShortcuts,
    );
    if (key != StudyShortcutKey.none) {
      for (final entry in next.entries.toList()) {
        if (entry.key != action && entry.value == key) {
          next[entry.key] = StudyShortcutKey.none;
        }
      }
    }
    next[action] = key;
    return copyWith(windowsShortcuts: next);
  }

  Map<String, Object?> toJson() => {
    'largeRatingControls': largeRatingControls,
    'cardScale': cardScale.name,
    'highContrast': highContrast,
    'reduceMotion': reduceMotion,
    'disableTimedChallenges': disableTimedChallenges,
    'androidSelectionGesture': androidSelectionGesture.name,
    'windowsShortcuts': {
      for (final action in StudyShortcutAction.values)
        action.name: shortcutFor(action).name,
    },
  };

  factory AccessibilityInputProfile.fromJson(Map<String, Object?> json) {
    final rawShortcuts = json['windowsShortcuts'];
    final shortcuts = Map<StudyShortcutAction, StudyShortcutKey>.from(
      _defaultStudyShortcuts,
    );
    if (rawShortcuts is Map) {
      for (final action in StudyShortcutAction.values) {
        final rawKey = rawShortcuts[action.name];
        shortcuts[action] = _enumByName(
          StudyShortcutKey.values,
          rawKey,
          shortcuts[action]!,
        );
      }
    }
    return AccessibilityInputProfile(
      largeRatingControls: _boolOr(json['largeRatingControls'], false),
      cardScale: _enumByName(
        AccessibilityCardScale.values,
        json['cardScale'],
        AccessibilityCardScale.standard,
      ),
      highContrast: _boolOr(json['highContrast'], false),
      reduceMotion: _boolOr(json['reduceMotion'], false),
      disableTimedChallenges: _boolOr(json['disableTimedChallenges'], false),
      androidSelectionGesture: _enumByName(
        AndroidSelectionGesture.values,
        json['androidSelectionGesture'],
        AndroidSelectionGesture.tapAndButtons,
      ),
      windowsShortcuts: Map.unmodifiable(_deduplicate(shortcuts)),
    );
  }
}

Map<StudyShortcutAction, StudyShortcutKey> _deduplicate(
  Map<StudyShortcutAction, StudyShortcutKey> source,
) {
  final used = <StudyShortcutKey>{};
  final result = <StudyShortcutAction, StudyShortcutKey>{};
  for (final action in StudyShortcutAction.values) {
    final key = source[action] ?? StudyShortcutKey.none;
    if (key == StudyShortcutKey.none || used.add(key)) {
      result[action] = key;
    } else {
      result[action] = StudyShortcutKey.none;
    }
  }
  return result;
}

bool _boolOr(Object? value, bool fallback) => value is bool ? value : fallback;

T _enumByName<T extends Enum>(Iterable<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}
