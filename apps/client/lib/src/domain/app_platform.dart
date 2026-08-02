import 'package:flutter/foundation.dart';

bool usesMobileStudyExperience(TargetPlatform platform) {
  return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
}

String appPlatformName(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => '현재 플랫폼',
  };
}

String appPlatformDescription(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.android => 'Android · 모바일 학습 모드',
    TargetPlatform.iOS => 'iOS · 모바일 학습 모드',
    TargetPlatform.windows => 'Windows x64 · 크기 조절 지원',
    TargetPlatform.macOS => 'macOS · 지원 준비 중',
    TargetPlatform.linux => 'Linux · 지원 준비 중',
    TargetPlatform.fuchsia => '현재 플랫폼 · 지원 준비 중',
  };
}
