import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/database_bootstrap.dart';
import 'domain/app_platform.dart';
import 'screens/database_recovery_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class SpracheBootstrap extends StatefulWidget {
  const SpracheBootstrap({super.key, required this.bootstrapper});

  final DatabaseBootstrapper bootstrapper;

  @override
  State<SpracheBootstrap> createState() => _SpracheBootstrapState();
}

class _SpracheBootstrapState extends State<SpracheBootstrap> {
  DatabaseBootstrapResult? _result;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    final previous = _result;
    setState(() => _result = null);
    if (previous case DatabaseReady(:final database)) {
      await database.close();
    }
    final result = await widget.bootstrapper.open();
    if (!mounted) {
      if (result case DatabaseReady(:final database)) {
        await database.close();
      }
      return;
    }
    setState(() => _result = result);
  }

  Future<String> _export(DatabaseRecoveryDiagnostic diagnostic) async {
    final bytes = await widget.bootstrapper.createRecoveryArchive(diagnostic);
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Sprache 읽기 전용 복구 패키지 저장',
      fileName: 'Sprache-database-recovery-$timestamp.zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      bytes: bytes,
    );
    return path == null ? '복구 패키지 저장을 취소했습니다.' : '복구 패키지를 저장했습니다.';
  }

  @override
  void dispose() {
    final result = _result;
    if (result case DatabaseReady(:final database)) {
      unawaited(database.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return switch (result) {
      null => _BootstrapLoadingApp(),
      DatabaseReady(:final database) => ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const SpracheApp(),
      ),
      DatabaseRecoveryRequired(:final diagnostic) => _RecoveryApp(
        diagnostic: diagnostic,
        onExport: () => _export(diagnostic),
        onRetry: _open,
      ),
    };
  }
}

class _BootstrapLoadingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mobile = usesMobileStudyExperience(defaultTargetPlatform);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: mobile ? AppTheme.mobile : AppTheme.desktop,
      darkTheme: mobile ? AppTheme.mobileDark : AppTheme.desktopDark,
      themeMode: ThemeMode.system,
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('로컬 학습 데이터를 안전하게 확인하고 있습니다…'),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecoveryApp extends StatelessWidget {
  const _RecoveryApp({
    required this.diagnostic,
    required this.onExport,
    required this.onRetry,
  });

  final DatabaseRecoveryDiagnostic diagnostic;
  final Future<String> Function() onExport;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final mobile = usesMobileStudyExperience(defaultTargetPlatform);
    return MaterialApp(
      title: 'Sprache 복구',
      debugShowCheckedModeBanner: false,
      theme: mobile ? AppTheme.mobile : AppTheme.desktop,
      darkTheme: mobile ? AppTheme.mobileDark : AppTheme.desktopDark,
      themeMode: ThemeMode.system,
      home: DatabaseRecoveryScreen(
        diagnostic: diagnostic,
        onExport: onExport,
        onRetry: onRetry,
      ),
    );
  }
}
