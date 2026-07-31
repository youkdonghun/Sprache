enum LearningPurpose { dailyConversation, travel, work, exam, hobby }

enum SelfAssessedLevel { beginner, elementary, intermediate, advanced }

enum OnboardingEntryChoice { sampleLesson, importMyData }

class OnboardingProfile {
  const OnboardingProfile({
    this.purpose = LearningPurpose.dailyConversation,
    this.level = SelfAssessedLevel.beginner,
    this.dailyMinutes = 5,
    this.entryChoice = OnboardingEntryChoice.sampleLesson,
  });

  final LearningPurpose purpose;
  final SelfAssessedLevel level;
  final int dailyMinutes;
  final OnboardingEntryChoice entryChoice;

  Map<String, Object?> toJson() => {
    'purpose': purpose.name,
    'level': level.name,
    'dailyMinutes': dailyMinutes.clamp(3, 60),
    'entryChoice': entryChoice.name,
  };

  factory OnboardingProfile.fromJson(Map<String, Object?> json) {
    return OnboardingProfile(
      purpose: LearningPurpose.values.firstWhere(
        (value) => value.name == json['purpose'],
        orElse: () => LearningPurpose.dailyConversation,
      ),
      level: SelfAssessedLevel.values.firstWhere(
        (value) => value.name == json['level'],
        orElse: () => SelfAssessedLevel.beginner,
      ),
      dailyMinutes: ((json['dailyMinutes'] as num?)?.toInt() ?? 5).clamp(
        3,
        60,
      ),
      entryChoice: OnboardingEntryChoice.values.firstWhere(
        (value) => value.name == json['entryChoice'],
        orElse: () => OnboardingEntryChoice.sampleLesson,
      ),
    );
  }
}
