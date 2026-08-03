import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef NavigationGuardCallback = Future<bool> Function();

class NavigationGuardController {
  Object? _owner;
  NavigationGuardCallback? _callback;

  void register(Object owner, NavigationGuardCallback callback) {
    _owner = owner;
    _callback = callback;
  }

  void unregister(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _callback = null;
  }

  Future<bool> canNavigate() async {
    final callback = _callback;
    return callback == null || await callback();
  }
}

final navigationGuardProvider = Provider<NavigationGuardController>(
  (ref) => NavigationGuardController(),
);
