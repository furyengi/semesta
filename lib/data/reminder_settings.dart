import 'dart:convert';

/// What to be reminded about, and how far ahead.
class ReminderSettings {
  const ReminderSettings({
    this.enabled = false,
    this.classes = true,
    this.classLeadMin = 10,
    this.exams = true,
    this.examLeadHours = 24,
    this.study = true,
    this.studyLeadMin = 10,
    this.deadlines = true,
    this.deadlineLeadHours = 24,
    this.digest = false,
    this.digestMinute = 8 * 60,
  });

  /// Master switch. Off until the user turns it on (which asks permission).
  final bool enabled;

  final bool classes;
  final int classLeadMin;

  final bool exams;
  final int examLeadHours;

  final bool study;
  final int studyLeadMin;

  final bool deadlines;
  final int deadlineLeadHours;

  /// A morning summary of the day.
  final bool digest;

  /// Minutes after midnight.
  final int digestMinute;

  static const classLeadChoices = [5, 10, 15, 30, 60];
  static const studyLeadChoices = [5, 10, 15, 30];
  static const hoursLeadChoices = [3, 12, 24, 48];

  ReminderSettings copyWith({
    bool? enabled,
    bool? classes,
    int? classLeadMin,
    bool? exams,
    int? examLeadHours,
    bool? study,
    int? studyLeadMin,
    bool? deadlines,
    int? deadlineLeadHours,
    bool? digest,
    int? digestMinute,
  }) => ReminderSettings(
    enabled: enabled ?? this.enabled,
    classes: classes ?? this.classes,
    classLeadMin: classLeadMin ?? this.classLeadMin,
    exams: exams ?? this.exams,
    examLeadHours: examLeadHours ?? this.examLeadHours,
    study: study ?? this.study,
    studyLeadMin: studyLeadMin ?? this.studyLeadMin,
    deadlines: deadlines ?? this.deadlines,
    deadlineLeadHours: deadlineLeadHours ?? this.deadlineLeadHours,
    digest: digest ?? this.digest,
    digestMinute: digestMinute ?? this.digestMinute,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'classes': classes,
    'classLeadMin': classLeadMin,
    'exams': exams,
    'examLeadHours': examLeadHours,
    'study': study,
    'studyLeadMin': studyLeadMin,
    'deadlines': deadlines,
    'deadlineLeadHours': deadlineLeadHours,
    'digest': digest,
    'digestMinute': digestMinute,
  };

  factory ReminderSettings.fromJson(Map<String, dynamic> j) {
    const d = ReminderSettings();
    return ReminderSettings(
      enabled: (j['enabled'] as bool?) ?? d.enabled,
      classes: (j['classes'] as bool?) ?? d.classes,
      classLeadMin: (j['classLeadMin'] as int?) ?? d.classLeadMin,
      exams: (j['exams'] as bool?) ?? d.exams,
      examLeadHours: (j['examLeadHours'] as int?) ?? d.examLeadHours,
      study: (j['study'] as bool?) ?? d.study,
      studyLeadMin: (j['studyLeadMin'] as int?) ?? d.studyLeadMin,
      deadlines: (j['deadlines'] as bool?) ?? d.deadlines,
      deadlineLeadHours:
          (j['deadlineLeadHours'] as int?) ?? d.deadlineLeadHours,
      digest: (j['digest'] as bool?) ?? d.digest,
      digestMinute: (j['digestMinute'] as int?) ?? d.digestMinute,
    );
  }

  String encode() => jsonEncode(toJson());

  static ReminderSettings decode(String? raw) {
    if (raw == null) return const ReminderSettings();
    try {
      return ReminderSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ReminderSettings();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}
