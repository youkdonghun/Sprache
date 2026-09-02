import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/language.dart';
import '../services/language_pack_catalog_service.dart';
import '../state/app_state.dart';
import '../state/connection_state.dart';
import '../state/pending_import_state.dart';

class LanguagePackScreen extends ConsumerStatefulWidget {
  const LanguagePackScreen({this.service, super.key});

  final LanguagePackCatalogService? service;

  @override
  ConsumerState<LanguagePackScreen> createState() => _LanguagePackScreenState();
}

class _LanguagePackScreenState extends ConsumerState<LanguagePackScreen> {
  late final LanguagePackCatalogService _service;
  LanguagePackCatalog? _catalog;
  LanguageTag? _languageFilter;
  String? _errorMessage;
  String? _downloadingPackId;
  var _loading = true;
  var _showLanguageChooser = false;

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ??
        LanguagePackCatalogService(
          catalogUri: Uri.parse(
            ref.read(appConfigProvider).languagePackCatalogUrl,
          ),
        );
    _languageFilter = ref.read(appControllerProvider).selectedLanguage;
    unawaited(_loadCatalog());
  }

  @override
  void dispose() {
    if (widget.service == null) _service.close();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    if (!_loading && mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final catalog = await _service.fetchCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loading = false;
        _errorMessage = null;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.message.toString();
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '언어팩 목록을 불러오지 못했습니다. 인터넷 연결을 확인해 주세요.';
      });
    }
  }

  Future<void> _download(LanguagePackDescriptor descriptor) async {
    if (_downloadingPackId != null) return;
    setState(() => _downloadingPackId = descriptor.id);
    try {
      final downloaded = await _service.downloadPack(descriptor);
      if (!mounted) return;
      ref.read(pendingImportFileProvider.notifier).state = PendingImportFile(
        name: downloaded.fileName,
        bytes: downloaded.bytes,
      );
      await context.push('/import?source=language-pack&pack=${descriptor.id}');
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message.toString());
    } on Object {
      if (mounted) {
        _showMessage('언어팩을 받지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _downloadingPackId = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    final catalog = _catalog;
    final packs =
        catalog?.packs
            .where(
              (pack) =>
                  _languageFilter == null || pack.language == _languageFilter,
            )
            .toList(growable: false) ??
        const <LanguagePackDescriptor>[];
    final availableLanguages =
        {
          for (final pack in catalog?.packs ?? const <LanguagePackDescriptor>[])
            pack.language,
        }.toList()..sort(
          (left, right) => left.koreanName.compareTo(right.koreanName),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('무료 학습 자료'),
        leading: IconButton(
          tooltip: '자료실로 돌아가기',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            key: const Key('refresh-language-packs'),
            tooltip: '목록 새로고침',
            onPressed: _loading ? null : () => unawaited(_loadCatalog()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadCatalog,
          child: ListView(
            key: const Key('language-pack-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LanguagePackIntro(
                        language: _languageFilter,
                        driveConnected: appState.driveConnected,
                      ),
                      if (availableLanguages.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Card(
                          margin: EdgeInsets.zero,
                          child: Column(
                            children: [
                              ListTile(
                                key: const Key(
                                  'toggle-language-pack-languages',
                                ),
                                leading: Text(
                                  (_languageFilter ?? availableLanguages.first)
                                      .symbol,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                title: Text(
                                  '${(_languageFilter ?? availableLanguages.first).koreanName} 자료를 보고 있어요',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: const Text('다른 언어로 바꾸려면 여기를 누르세요.'),
                                trailing: Icon(
                                  _showLanguageChooser
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                ),
                                onTap: () => setState(
                                  () => _showLanguageChooser =
                                      !_showLanguageChooser,
                                ),
                              ),
                              if (_showLanguageChooser) ...[
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final language in availableLanguages)
                                        ChoiceChip(
                                          key: Key(
                                            'language-pack-filter-${language.code}',
                                          ),
                                          avatar: Text(language.symbol),
                                          label: Text(language.koreanName),
                                          selected: _languageFilter == language,
                                          onSelected: (_) => setState(() {
                                            _languageFilter = language;
                                            _showLanguageChooser = false;
                                          }),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_loading)
                        const _LanguagePackLoading()
                      else if (_errorMessage case final message?)
                        _LanguagePackError(
                          message: message,
                          onRetry: () => unawaited(_loadCatalog()),
                        )
                      else if (packs.isEmpty)
                        _LanguagePackEmpty(
                          filtered: (catalog?.packs.isNotEmpty ?? false),
                          onShowAll: () =>
                              setState(() => _showLanguageChooser = true),
                        )
                      else
                        for (final pack in packs) ...[
                          _LanguagePackCard(
                            descriptor: pack,
                            installation: _installationFor(pack, appState),
                            busy: _downloadingPackId == pack.id,
                            blocked: _downloadingPackId != null,
                            onDownload: () => unawaited(_download(pack)),
                          ),
                          const SizedBox(height: 10),
                        ],
                      if (catalog?.updatedAt case final updatedAt?) ...[
                        const SizedBox(height: 6),
                        Text(
                          '목록 갱신 ${_dateLabel(updatedAt.toLocal())}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _PackInstallation _installationFor(
    LanguagePackDescriptor pack,
    AppState state,
  ) {
    final installed = state.customItems
        .where((item) => item.source.sourceId == pack.sourceId)
        .toList(growable: false);
    if (installed.isEmpty) return const _PackInstallation.notInstalled();
    final currentCount = installed
        .where((item) => item.source.sourceVersion == pack.version)
        .length;
    if (currentCount == installed.length &&
        installed.length >= pack.itemCount) {
      return _PackInstallation.current(installed.length);
    }
    return _PackInstallation.updateAvailable(installed.length);
  }

  String _dateLabel(DateTime value) =>
      '${value.year}.${value.month.toString().padLeft(2, '0')}.'
      '${value.day.toString().padLeft(2, '0')}';
}

class _LanguagePackIntro extends StatelessWidget {
  const _LanguagePackIntro({
    required this.language,
    required this.driveConnected,
  });

  final LanguageTag? language;
  final bool driveConnected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.translate_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${language?.koreanName ?? '현재 언어'} 학습 자료를 준비해 두었어요',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text('버튼을 누르고 추가될 자료 수만 확인하면 바로 학습할 수 있어요.'),
                  const SizedBox(height: 8),
                  Text(
                    driveConnected
                        ? '추가한 자료는 Google Drive에 함께 저장돼요.'
                        : '자료를 저장하려면 Google Drive 연결이 필요해요.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguagePackLoading extends StatelessWidget {
  const _LanguagePackLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('추천 학습 자료를 불러오고 있어요…'),
          ],
        ),
      ),
    );
  }
}

class _LanguagePackError extends StatelessWidget {
  const _LanguagePackError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 36),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const Key('retry-language-pack-catalog'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 확인'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguagePackEmpty extends StatelessWidget {
  const _LanguagePackEmpty({required this.filtered, required this.onShowAll});

  final bool filtered;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 38),
            const SizedBox(height: 10),
            Text(
              filtered ? '이 언어의 추천 자료는 준비 중이에요.' : '아직 받을 수 있는 학습 자료가 없어요.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text('잠시 후 목록을 다시 확인해 주세요.', textAlign: TextAlign.center),
            if (filtered) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onShowAll, child: const Text('다른 언어 선택')),
            ],
          ],
        ),
      ),
    );
  }
}

class _LanguagePackCard extends StatelessWidget {
  const _LanguagePackCard({
    required this.descriptor,
    required this.installation,
    required this.busy,
    required this.blocked,
    required this.onDownload,
  });

  final LanguagePackDescriptor descriptor;
  final _PackInstallation installation;
  final bool busy;
  final bool blocked;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: Key('language-pack-${descriptor.id}'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Text(descriptor.language.symbol)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        descriptor.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${descriptor.language.koreanName} · ${descriptor.itemCount}개',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (installation.label case final label?)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      installation.current
                          ? Icons.check_circle_outline_rounded
                          : Icons.update_rounded,
                      size: 17,
                      color: installation.current
                          ? colors.primary
                          : colors.tertiary,
                    ),
                    label: Text(label),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(descriptor.description),
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('출처·파일 정보'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'v${descriptor.version} · ${_sizeLabel(descriptor.sizeBytes)}\n'
                    '${descriptor.license} · ${descriptor.attribution}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: Key('download-language-pack-${descriptor.id}'),
                onPressed: blocked ? null : onDownload,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        installation.current
                            ? Icons.refresh_rounded
                            : Icons.download_rounded,
                      ),
                label: Text(
                  busy
                      ? '확인 중…'
                      : installation.current
                      ? '최신 자료 확인'
                      : installation.installedCount > 0
                      ? '업데이트 확인'
                      : '${descriptor.itemCount}개 추가하기',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sizeLabel(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class _PackInstallation {
  const _PackInstallation._({
    required this.installedCount,
    required this.current,
    required this.label,
  });

  const _PackInstallation.notInstalled()
    : this._(installedCount: 0, current: false, label: null);

  const _PackInstallation.current(int count)
    : this._(installedCount: count, current: true, label: '사용 중');

  const _PackInstallation.updateAvailable(int count)
    : this._(installedCount: count, current: false, label: '업데이트');

  final int installedCount;
  final bool current;
  final String? label;
}
