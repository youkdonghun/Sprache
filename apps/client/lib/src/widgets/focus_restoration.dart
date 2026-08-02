import 'package:flutter/material.dart';

/// Opens a dialog and restores keyboard focus to its launcher afterwards.
///
/// When the launcher disappeared while the dialog was open, [fallbackFocus]
/// receives focus instead. This keeps keyboard and screen-reader users from
/// being dropped at the start of the route after a modal action.
Future<T?> showFocusRestoringDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  FocusNode? fallbackFocus,
  bool barrierDismissible = true,
}) async {
  final launcher = FocusManager.instance.primaryFocus;
  final result = await showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: builder(dialogContext),
    ),
  );
  _restoreFocus(launcher, fallbackFocus);
  return result;
}

Future<T?> showFocusRestoringBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  FocusNode? fallbackFocus,
  bool isScrollControlled = false,
  bool showDragHandle = true,
}) async {
  final launcher = FocusManager.instance.primaryFocus;
  final result = await showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    builder: (sheetContext) => FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: builder(sheetContext),
    ),
  );
  _restoreFocus(launcher, fallbackFocus);
  return result;
}

void _restoreFocus(FocusNode? launcher, FocusNode? fallbackFocus) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_tryRequestFocus(launcher)) return;
    _tryRequestFocus(fallbackFocus);
  });
}

bool _tryRequestFocus(FocusNode? node) {
  if (node == null) return false;
  try {
    if (node.context == null || !node.canRequestFocus) return false;
    node.requestFocus();
    return true;
  } catch (_) {
    return false;
  }
}
