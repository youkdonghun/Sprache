import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/app_platform.dart';

void main() {
  test('Android and iOS use the mobile study experience', () {
    expect(usesMobileStudyExperience(TargetPlatform.android), isTrue);
    expect(usesMobileStudyExperience(TargetPlatform.iOS), isTrue);
    expect(usesMobileStudyExperience(TargetPlatform.windows), isFalse);
  });

  test('platform descriptions do not label iOS as Android', () {
    expect(appPlatformName(TargetPlatform.iOS), 'iOS');
    expect(appPlatformDescription(TargetPlatform.iOS), 'iOS · 모바일 학습 모드');
    expect(
      appPlatformDescription(TargetPlatform.android),
      'Android · 모바일 학습 모드',
    );
    expect(
      appPlatformDescription(TargetPlatform.windows),
      'Windows x64 · 크기 조절 지원',
    );
  });
}
