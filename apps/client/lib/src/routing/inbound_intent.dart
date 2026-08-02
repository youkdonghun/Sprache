sealed class AppInboundIntent {
  const AppInboundIntent();
}

class SessionPlanInboundIntent extends AppInboundIntent {
  const SessionPlanInboundIntent(this.planId);

  final String planId;
}

class RouteInboundIntent extends AppInboundIntent {
  const RouteInboundIntent(this.route);

  final String route;
}

class ImportFileInboundIntent extends AppInboundIntent {
  const ImportFileInboundIntent(this.uri, this.extension);

  final Uri uri;
  final String extension;
}

enum InboundIntentError {
  empty,
  tooLong,
  invalidEncoding,
  unsupportedScheme,
  unsupportedRoute,
  unsupportedFileType,
  unsafePath,
  invalidPlanId,
}

class InboundIntentParseResult {
  const InboundIntentParseResult({this.intent, this.error});

  final AppInboundIntent? intent;
  final InboundIntentError? error;

  bool get accepted => intent != null && error == null;
}

class InboundIntentParser {
  const InboundIntentParser();

  static const supportedExtensions = {'csv', 'tsv', 'xlsx', 'json', 'jsonl'};
  static const allowedRoutes = {
    '/learn',
    '/library',
    '/stats',
    '/settings',
    '/import',
    '/session-builder',
  };

  InboundIntentParseResult parseLaunchArgument(String raw) {
    var value = raw.trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1).trim();
    }
    final windowsPath = RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value);
    final posixPath = value.startsWith('/');
    if (windowsPath || posixPath) {
      try {
        return parse(Uri.file(value, windows: windowsPath).toString());
      } on ArgumentError {
        return const InboundIntentParseResult(
          error: InboundIntentError.invalidEncoding,
        );
      }
    }
    return parse(value);
  }

  InboundIntentParseResult parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return const InboundIntentParseResult(error: InboundIntentError.empty);
    }
    if (value.runes.length > 4096) {
      return const InboundIntentParseResult(error: InboundIntentError.tooLong);
    }
    try {
      final decoded = Uri.decodeFull(value).replaceAll('\\', '/');
      if (decoded.split('/').any((segment) => segment == '..')) {
        return const InboundIntentParseResult(
          error: InboundIntentError.unsafePath,
        );
      }
    } on Object {
      return const InboundIntentParseResult(
        error: InboundIntentError.invalidEncoding,
      );
    }
    if (value.startsWith('session-plan/')) {
      return _sessionPlan(value.substring('session-plan/'.length));
    }
    final uri = Uri.tryParse(value);
    if (uri == null) {
      return const InboundIntentParseResult(
        error: InboundIntentError.invalidEncoding,
      );
    }
    if (uri.scheme == 'sprache') return _sprache(uri);
    if (uri.scheme == 'file' || uri.scheme == 'content') return _file(uri);
    return const InboundIntentParseResult(
      error: InboundIntentError.unsupportedScheme,
    );
  }

  InboundIntentParseResult _sprache(Uri uri) {
    if (uri.host == 'session-plan') {
      return _sessionPlan(uri.pathSegments.join('/'));
    }
    if (uri.host == 'route') {
      final route = '/${uri.pathSegments.join('/')}';
      if (!allowedRoutes.contains(route) || uri.hasQuery || uri.hasFragment) {
        return const InboundIntentParseResult(
          error: InboundIntentError.unsupportedRoute,
        );
      }
      return InboundIntentParseResult(intent: RouteInboundIntent(route));
    }
    if (uri.host == 'import') {
      final encoded = uri.queryParameters['uri'];
      if (encoded == null || encoded.runes.length > 3000) {
        return const InboundIntentParseResult(
          error: InboundIntentError.unsafePath,
        );
      }
      final nested = Uri.tryParse(encoded);
      if (nested == null ||
          (nested.scheme != 'file' && nested.scheme != 'content')) {
        return const InboundIntentParseResult(
          error: InboundIntentError.unsafePath,
        );
      }
      return _file(nested);
    }
    return const InboundIntentParseResult(
      error: InboundIntentError.unsupportedRoute,
    );
  }

  InboundIntentParseResult _sessionPlan(String encoded) {
    String value;
    try {
      value = Uri.decodeComponent(encoded).trim();
    } on Object {
      return const InboundIntentParseResult(
        error: InboundIntentError.invalidEncoding,
      );
    }
    if (value.isEmpty ||
        value.runes.length > 160 ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$').hasMatch(value)) {
      return const InboundIntentParseResult(
        error: InboundIntentError.invalidPlanId,
      );
    }
    return InboundIntentParseResult(intent: SessionPlanInboundIntent(value));
  }

  InboundIntentParseResult _file(Uri uri) {
    late final String decodedPath;
    try {
      decodedPath = Uri.decodeComponent(uri.path);
    } on FormatException {
      return const InboundIntentParseResult(
        error: InboundIntentError.invalidEncoding,
      );
    }
    if (decodedPath.contains('\u0000') ||
        uri.pathSegments.any((segment) => segment == '..')) {
      return const InboundIntentParseResult(
        error: InboundIntentError.unsafePath,
      );
    }
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    if (!supportedExtensions.contains(extension)) {
      return const InboundIntentParseResult(
        error: InboundIntentError.unsupportedFileType,
      );
    }
    return InboundIntentParseResult(
      intent: ImportFileInboundIntent(uri, extension),
    );
  }
}
