import 'package:flutter/widgets.dart';

class PrivacyModeScope extends InheritedWidget {
  const PrivacyModeScope({
    required this.enabled,
    required super.child,
    super.key,
  });

  final bool enabled;

  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrivacyModeScope>()?.enabled ??
      false;

  static String redact(
    BuildContext context,
    String value, {
    String replacement = '••••••',
  }) => enabledOf(context) && value.trim().isNotEmpty ? replacement : value;

  @override
  bool updateShouldNotify(PrivacyModeScope oldWidget) =>
      enabled != oldWidget.enabled;
}
