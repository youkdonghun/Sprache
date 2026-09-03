import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/study_store.dart';
import '../domain/exam_library.dart';
import '../domain/exam_pack.dart';
import '../domain/exam_session.dart';
import '../services/exam_pack_catalog_service.dart';
import 'app_state.dart';
import 'connection_state.dart';

class ExamStudyState {
  const ExamStudyState({
    this.library = const ExamLibrary(),
    this.catalog,
    this.loading = true,
    this.busy = false,
    this.errorMessage,
  });

  final ExamLibrary library;
  final ExamPackCatalog? catalog;
  final bool loading;
  final bool busy;
  final String? errorMessage;

  ExamPack? get activePack {
    final sessionPackId = library.activeSession?.packId;
    if (sessionPackId != null) return library.installedPacks[sessionPackId];
    return library.primaryPack;
  }

  ExamStudyState copyWith({
    ExamLibrary? library,
    ExamPackCatalog? catalog,
    bool? loading,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
  }) => ExamStudyState(
    library: library ?? this.library,
    catalog: catalog ?? this.catalog,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

class ExamStudyController extends StateNotifier<ExamStudyState> {
  ExamStudyController(this._store, this._catalogService)
    : super(const ExamStudyState()) {
    unawaited(prepare());
  }

  final StudyStore _store;
  final ExamPackCatalogService _catalogService;
  final ExamSessionBuilder _sessionBuilder = const ExamSessionBuilder();

  Future<void> prepare({bool forceRefresh = false}) async {
    if (state.busy) return;
    state = state.copyWith(loading: true, busy: true, clearError: true);
    try {
      final library = forceRefresh
          ? state.library
          : await _store.loadExamLibrary();
      var nextLibrary = library;
      final catalog = await _catalogService.fetchCatalog();
      final descriptor = catalog.packs.firstOrNull;
      if (descriptor != null) {
        final installed = library.installedPacks[descriptor.id];
        if (installed == null || installed.revision < descriptor.revision) {
          final downloaded = await _catalogService.downloadPack(descriptor);
          nextLibrary = library.copyWith(
            installedPacks: Map.unmodifiable({
              ...library.installedPacks,
              downloaded.pack.id: downloaded.pack,
            }),
          );
          await _store.saveExamLibrary(nextLibrary);
        }
      }
      state = state.copyWith(
        library: nextLibrary,
        catalog: catalog,
        loading: false,
        busy: false,
        clearError: true,
      );
    } on FormatException catch (error) {
      state = state.copyWith(
        loading: false,
        busy: false,
        errorMessage: error.message.toString(),
      );
    } on Object {
      state = state.copyWith(
        loading: false,
        busy: false,
        errorMessage: '시험 자료를 준비하지 못했습니다. 인터넷 연결을 확인해 주세요.',
      );
    }
  }

  Future<ActiveExamSession> startSession({
    required ExamSessionMode mode,
    ExamPart? part,
    int quickCount = 10,
    DateTime? now,
  }) async {
    final pack = state.library.primaryPack;
    if (pack == null) throw StateError('설치된 시험팩이 없습니다.');
    final session = _sessionBuilder.build(
      pack: pack,
      mode: mode,
      part: part,
      quickCount: quickCount,
      wrongQuestionIds: state.library.wrongQuestionIds,
      now: (now ?? DateTime.now()).toUtc(),
    );
    final library = state.library.copyWith(activeSession: session);
    await _store.saveExamLibrary(library);
    state = state.copyWith(library: library);
    return session;
  }

  Future<void> answerCurrent(int selectedIndex, {DateTime? now}) async {
    final session = state.library.activeSession;
    final pack = state.activePack;
    if (session == null || pack == null) return;
    final questionId = session.questionIds[session.currentIndex];
    final question = pack.questions.firstWhere(
      (value) => value.id == questionId,
    );
    if (selectedIndex < 0 || selectedIndex >= question.choices.length) return;
    final answers = <String, ExamAnswerRecord>{
      ...session.answers,
      questionId: ExamAnswerRecord(
        questionId: questionId,
        selectedIndex: selectedIndex,
        correct: selectedIndex == question.correctIndex,
        answeredAt: (now ?? DateTime.now()).toUtc(),
      ),
    };
    await _saveActive(session.copyWith(answers: Map.unmodifiable(answers)));
  }

  Future<void> goToQuestion(int index) async {
    final session = state.library.activeSession;
    if (session == null || index < 0 || index >= session.questionIds.length) {
      return;
    }
    await _saveActive(session.copyWith(currentIndex: index));
  }

  Future<void> toggleFlag() async {
    final session = state.library.activeSession;
    if (session == null) return;
    final id = session.questionIds[session.currentIndex];
    final flags = {...session.flaggedQuestionIds};
    if (!flags.remove(id)) flags.add(id);
    await _saveActive(
      session.copyWith(flaggedQuestionIds: Set.unmodifiable(flags)),
    );
  }

  Future<ExamAttemptSummary?> finish({DateTime? now}) async {
    final session = state.library.activeSession;
    if (session == null) return null;
    final completedAt = (now ?? DateTime.now()).toUtc();
    final summary = ExamAttemptSummary(
      id: session.id,
      packId: session.packId,
      mode: session.mode,
      startedAt: session.startedAt,
      completedAt: completedAt,
      questionIds: session.questionIds,
      answers: session.answers,
    );
    final attempts = [
      summary,
      ...state.library.attempts,
    ].take(100).toList(growable: false);
    final library = state.library.copyWith(
      attempts: List.unmodifiable(attempts),
      clearActiveSession: true,
    );
    await _store.saveExamLibrary(library);
    state = state.copyWith(library: library);
    return summary;
  }

  Future<void> discardActiveSession() async {
    final library = state.library.copyWith(clearActiveSession: true);
    await _store.saveExamLibrary(library);
    state = state.copyWith(library: library);
  }

  Future<void> _saveActive(ActiveExamSession session) async {
    final library = state.library.copyWith(activeSession: session);
    await _store.saveExamLibrary(library);
    state = state.copyWith(library: library);
  }
}

final examStudyControllerProvider =
    StateNotifierProvider.autoDispose<ExamStudyController, ExamStudyState>((
      ref,
    ) {
      final service = ExamPackCatalogService(
        catalogUri: Uri.parse(ref.watch(appConfigProvider).examPackCatalogUrl),
      );
      ref.onDispose(service.close);
      return ExamStudyController(ref.watch(studyStoreProvider), service);
    });
