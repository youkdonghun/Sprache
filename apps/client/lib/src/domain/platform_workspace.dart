import 'package:flutter/foundation.dart';

enum PlatformCompletionAction { share, openFile, openFolder, copyPath }

bool usesDesktopWorkspace(TargetPlatform platform) =>
    platform == TargetPlatform.windows ||
    platform == TargetPlatform.macOS ||
    platform == TargetPlatform.linux;

bool usesCommandModifier(TargetPlatform platform) =>
    platform == TargetPlatform.macOS;

/// Keeps the master pane useful on tablets and narrow desktop windows without
/// forcing the phone layout onto macOS.
bool usesAdaptiveTwoPane({
  required TargetPlatform platform,
  required double width,
}) {
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.android) {
    return width >= 760;
  }
  return usesDesktopWorkspace(platform) && width >= 720;
}

List<PlatformCompletionAction> completionActionsFor(TargetPlatform platform) {
  if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
    return const [
      PlatformCompletionAction.share,
      PlatformCompletionAction.openFile,
    ];
  }
  if (usesDesktopWorkspace(platform)) {
    return const [
      PlatformCompletionAction.openFolder,
      PlatformCompletionAction.copyPath,
    ];
  }
  return const [PlatformCompletionAction.copyPath];
}

/// Returns the inclusive range in visual order. Missing anchors safely fall
/// back to the current item so stale selections never select unrelated rows.
Set<String> inclusiveSelectionRange({
  required List<String> orderedIds,
  required String? anchorId,
  required String currentId,
}) {
  final current = orderedIds.indexOf(currentId);
  final anchor = anchorId == null ? -1 : orderedIds.indexOf(anchorId);
  if (current < 0) return const {};
  if (anchor < 0) return {currentId};
  final start = current < anchor ? current : anchor;
  final end = current > anchor ? current : anchor;
  return orderedIds.sublist(start, end + 1).toSet();
}
