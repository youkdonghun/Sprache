import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/services/window_workspace_service.dart';

void main() {
  test('window workspace toggles compact, pin, and minimize states', () async {
    final driver = _FakeWindowWorkspaceDriver();
    final controller = WindowWorkspaceController(driver);

    await controller.toggleCompact();
    await controller.toggleAlwaysOnTop();
    await controller.minimize();

    expect(driver.compact, isTrue);
    expect(driver.alwaysOnTop, isTrue);
    expect(driver.minimizeCount, 1);
    expect(controller.state.compact, isTrue);
    expect(controller.state.alwaysOnTop, isTrue);
    expect(controller.state.busy, isFalse);

    await controller.toggleCompact();
    await controller.toggleAlwaysOnTop();

    expect(driver.compact, isFalse);
    expect(driver.alwaysOnTop, isFalse);
    expect(controller.state.compact, isFalse);
    expect(controller.state.alwaysOnTop, isFalse);
  });

  test(
    'window workspace surfaces driver failures without changing mode',
    () async {
      final driver = _FakeWindowWorkspaceDriver(failCompact: true);
      final controller = WindowWorkspaceController(driver);

      await controller.toggleCompact();

      expect(controller.state.compact, isFalse);
      expect(controller.state.busy, isFalse);
      expect(controller.state.errorMessage, contains('창 설정을 변경하지 못했습니다'));
    },
  );
}

class _FakeWindowWorkspaceDriver implements WindowWorkspaceDriver {
  _FakeWindowWorkspaceDriver({this.failCompact = false});

  final bool failCompact;
  bool compact = false;
  bool alwaysOnTop = false;
  int minimizeCount = 0;

  @override
  Future<void> minimize() async {
    minimizeCount++;
  }

  @override
  Future<void> setAlwaysOnTop(bool enabled) async {
    alwaysOnTop = enabled;
  }

  @override
  Future<void> setCompact(bool compact) async {
    if (failCompact) throw StateError('fake failure');
    this.compact = compact;
  }
}
