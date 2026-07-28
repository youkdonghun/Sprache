import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

abstract interface class WindowWorkspaceDriver {
  Future<void> setCompact(bool compact);

  Future<void> setAlwaysOnTop(bool enabled);

  Future<void> minimize();
}

class SystemWindowWorkspaceDriver implements WindowWorkspaceDriver {
  Size? _sizeBeforeCompact;
  Offset? _positionBeforeCompact;

  @override
  Future<void> setCompact(bool compact) async {
    if (compact) {
      _sizeBeforeCompact = await windowManager.getSize();
      _positionBeforeCompact = await windowManager.getPosition();
      await windowManager.setSize(const Size(420, 640), animate: true);
      await windowManager.center(animate: true);
    } else {
      await windowManager.setSize(
        _sizeBeforeCompact ?? const Size(1040, 760),
        animate: true,
      );
      if (_positionBeforeCompact case final position?) {
        await windowManager.setPosition(position, animate: true);
      } else {
        await windowManager.center(animate: true);
      }
      _sizeBeforeCompact = null;
      _positionBeforeCompact = null;
    }
    await windowManager.focus();
  }

  @override
  Future<void> setAlwaysOnTop(bool enabled) =>
      windowManager.setAlwaysOnTop(enabled);

  @override
  Future<void> minimize() => windowManager.minimize();
}

class WindowWorkspaceState {
  const WindowWorkspaceState({
    this.compact = false,
    this.alwaysOnTop = false,
    this.busy = false,
    this.errorMessage,
  });

  final bool compact;
  final bool alwaysOnTop;
  final bool busy;
  final String? errorMessage;
}

class WindowWorkspaceController extends StateNotifier<WindowWorkspaceState> {
  WindowWorkspaceController(this._driver) : super(const WindowWorkspaceState());

  final WindowWorkspaceDriver _driver;

  Future<void> toggleCompact() async {
    if (state.busy) return;
    final nextCompact = !state.compact;
    await _run(
      action: () => _driver.setCompact(nextCompact),
      compact: nextCompact,
      alwaysOnTop: state.alwaysOnTop,
    );
  }

  Future<void> toggleAlwaysOnTop() async {
    if (state.busy) return;
    final nextAlwaysOnTop = !state.alwaysOnTop;
    await _run(
      action: () => _driver.setAlwaysOnTop(nextAlwaysOnTop),
      compact: state.compact,
      alwaysOnTop: nextAlwaysOnTop,
    );
  }

  Future<void> minimize() async {
    if (state.busy) return;
    await _run(
      action: _driver.minimize,
      compact: state.compact,
      alwaysOnTop: state.alwaysOnTop,
    );
  }

  Future<void> _run({
    required Future<void> Function() action,
    required bool compact,
    required bool alwaysOnTop,
  }) async {
    state = WindowWorkspaceState(
      compact: state.compact,
      alwaysOnTop: state.alwaysOnTop,
      busy: true,
    );
    try {
      await action();
      if (!mounted) return;
      state = WindowWorkspaceState(compact: compact, alwaysOnTop: alwaysOnTop);
    } catch (error) {
      if (!mounted) return;
      state = WindowWorkspaceState(
        compact: state.compact,
        alwaysOnTop: state.alwaysOnTop,
        errorMessage: '창 설정을 변경하지 못했습니다: $error',
      );
    }
  }
}

final windowWorkspaceDriverProvider = Provider<WindowWorkspaceDriver>(
  (ref) => SystemWindowWorkspaceDriver(),
);

final windowWorkspaceControllerProvider =
    StateNotifierProvider<WindowWorkspaceController, WindowWorkspaceState>((
      ref,
    ) {
      return WindowWorkspaceController(
        ref.watch(windowWorkspaceDriverProvider),
      );
    });
