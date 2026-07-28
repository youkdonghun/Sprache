import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef AppNow = DateTime Function();

final appClockProvider = Provider<AppNow>((ref) => DateTime.now);
