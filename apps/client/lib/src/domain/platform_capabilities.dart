import 'package:flutter/foundation.dart';

enum PlatformFeature {
  driveSync,
  notifications,
  textToSpeech,
  speechRecognition,
  fileOpen,
  fileShare,
  nativeMenu,
  fileDrop,
}

enum PlatformCapabilityLevel { supported, degraded, unavailable }

class PlatformCapability {
  const PlatformCapability({required this.level, required this.reason});

  final PlatformCapabilityLevel level;
  final String reason;

  bool get available => level != PlatformCapabilityLevel.unavailable;
  bool get fullySupported => level == PlatformCapabilityLevel.supported;
}

class PlatformCapabilityRegistry {
  const PlatformCapabilityRegistry._(this.platform, this._values);

  factory PlatformCapabilityRegistry.forPlatform(
    TargetPlatform platform, {
    bool mockMode = false,
  }) {
    PlatformCapability supported(String reason) => PlatformCapability(
      level: PlatformCapabilityLevel.supported,
      reason: reason,
    );
    PlatformCapability degraded(String reason) => PlatformCapability(
      level: PlatformCapabilityLevel.degraded,
      reason: reason,
    );
    PlatformCapability unavailable(String reason) => PlatformCapability(
      level: PlatformCapabilityLevel.unavailable,
      reason: reason,
    );

    final mobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    final desktop =
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
    final drive = switch (platform) {
      TargetPlatform.android || TargetPlatform.windows when !mockMode =>
        supported('Google 계정과 사용자가 고른 Drive 폴더를 연결할 수 있어요.'),
      TargetPlatform.android ||
      TargetPlatform.windows => degraded('미리보기 빌드에서는 Drive 대신 기기 로컬 저장만 사용해요.'),
      TargetPlatform.iOS || TargetPlatform.macOS => unavailable(
        '현재 Apple 미리보기 빌드는 Drive 연결을 제공하지 않아요.',
      ),
      _ => unavailable('이 플랫폼에서는 Drive 연결을 지원하지 않아요.'),
    };
    final notifications = switch (platform) {
      TargetPlatform.android ||
      TargetPlatform.windows => supported('저장한 학습 일정의 기기 알림을 사용할 수 있어요.'),
      TargetPlatform.iOS || TargetPlatform.macOS => degraded(
        'Apple 알림 권한과 예약 기능을 준비 중이며 앱 안 일정은 유지돼요.',
      ),
      _ => unavailable('이 플랫폼에서는 기기 알림을 지원하지 않아요.'),
    };
    final speech = switch (platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS => supported('설치된 기기 음성 인식기를 사용할 수 있어요.'),
      TargetPlatform.windows => degraded('Windows에서는 영어 음성 인식을 우선 지원해요.'),
      TargetPlatform.macOS => degraded('설치된 음성 언어팩에 따라 자기 평가로 전환할 수 있어요.'),
      _ => unavailable('이 플랫폼에서는 음성 인식을 지원하지 않아요.'),
    };
    return PlatformCapabilityRegistry._(platform, {
      PlatformFeature.driveSync: drive,
      PlatformFeature.notifications: notifications,
      PlatformFeature.textToSpeech: supported('설치된 기기 음성을 사용해요.'),
      PlatformFeature.speechRecognition: speech,
      PlatformFeature.fileOpen: mobile || desktop
          ? supported('지원 파일을 안전한 가져오기 미리보기로 열 수 있어요.')
          : unavailable('파일 열기를 지원하지 않아요.'),
      PlatformFeature.fileShare: mobile
          ? supported('시스템 공유 화면을 사용할 수 있어요.')
          : degraded('데스크톱에서는 저장 폴더 열기를 사용해요.'),
      PlatformFeature.nativeMenu:
          platform == TargetPlatform.macOS || platform == TargetPlatform.windows
          ? supported('데스크톱 메뉴와 키보드 명령을 사용할 수 있어요.')
          : unavailable('모바일에서는 앱 안 탐색을 사용해요.'),
      PlatformFeature.fileDrop: desktop
          ? supported('파일을 창에 놓아 가져오기 미리보기를 열 수 있어요.')
          : unavailable('모바일에서는 파일 열기와 공유를 사용해요.'),
    });
  }

  final TargetPlatform platform;
  final Map<PlatformFeature, PlatformCapability> _values;

  PlatformCapability capability(PlatformFeature feature) =>
      _values[feature] ??
      const PlatformCapability(
        level: PlatformCapabilityLevel.unavailable,
        reason: '지원 여부를 확인할 수 없어요.',
      );

  Map<PlatformFeature, PlatformCapability> get values =>
      Map.unmodifiable(_values);
}
