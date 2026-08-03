import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class GlobalAppErrorNotice {
  const GlobalAppErrorNotice({
    required this.source,
    required this.message,
    required this.actionRoute,
  });

  final String source;
  final String message;
  final String actionRoute;
}

class GlobalAppErrorController extends StateNotifier<GlobalAppErrorNotice?> {
  GlobalAppErrorController() : super(null);

  void report({
    required String source,
    required String message,
    required String actionRoute,
  }) {
    final normalized = message.trim();
    if (normalized.isEmpty) {
      clearSource(source);
      return;
    }
    final current = state;
    if (current?.source == source &&
        current?.message == normalized &&
        current?.actionRoute == actionRoute) {
      return;
    }
    state = GlobalAppErrorNotice(
      source: source,
      message: normalized,
      actionRoute: actionRoute,
    );
  }

  void clearSource(String source) {
    if (state?.source == source) state = null;
  }

  void dismiss() => state = null;
}

final globalAppErrorProvider =
    StateNotifierProvider<GlobalAppErrorController, GlobalAppErrorNotice?>(
      (ref) => GlobalAppErrorController(),
    );
