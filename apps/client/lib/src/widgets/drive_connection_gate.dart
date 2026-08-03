import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import '../state/connection_state.dart';

class DriveConnectionGate extends ConsumerWidget {
  const DriveConnectionGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    // Widget tests and the explicit mock/demo build keep their deterministic
    // in-memory workflow. Every production artifact is built with mock mode
    // disabled and therefore always enters through this Drive gate.
    if (config.mockMode) return child;
    final app = ref.watch(appControllerProvider);
    final connection = ref.watch(connectionControllerProvider);
    final ready =
        app.isHydrated &&
        app.driveConnected &&
        connection.phase == ConnectionPhase.connected;
    if (ready) return child;

    final busy = connection.busy || !app.isHydrated;
    final stage = connection.stage;
    final error = connection.diagnostic;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.add_to_drive_rounded,
                            size: 34,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Google Drive로 시작하기',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Sprache는 학습 자료와 진도를 내 Google Drive에 보관합니다. 연결을 마치면 어느 기기에서든 같은 자료로 이어서 학습할 수 있어요.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.verified_user_outlined, size: 20),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'PDF 원본은 업로드하지 않습니다. Sprache가 만든 학습 데이터만 선택한 Drive 폴더에 저장합니다.',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!kIsWeb &&
                          defaultTargetPlatform == TargetPlatform.windows) ...[
                        const SizedBox(height: 10),
                        const Text(
                          '로그인 중 주소창에 127.0.0.1이 보여도 괜찮아요. 이 PC의 Sprache로 결과를 돌려주는 주소이며 별도 중계 서버를 거치지 않습니다.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (busy) ...[
                        const SizedBox(height: 18),
                        const LinearProgressIndicator(
                          key: Key('google-connection-progress'),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          !app.isHydrated
                              ? '학습 데이터를 준비하고 있어요.'
                              : stage == null
                              ? 'Google Drive 연결을 준비하고 있어요.'
                              : stage.label,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (error != null && !busy) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            error.message,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const Key('required-google-drive-connect'),
                        onPressed: busy
                            ? null
                            : () => ref
                                  .read(connectionControllerProvider.notifier)
                                  .connect(),
                        icon: const Icon(Icons.login_rounded),
                        label: Text(error == null ? 'Google로 계속' : '다시 연결'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
