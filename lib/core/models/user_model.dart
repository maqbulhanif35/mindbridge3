import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String email;
  final String name;
  final String? preferredName;
  final String? university;
  final int? yearOfStudy;
  final String? faculty;
  final String? profileImageUrl;
  final bool onboardingCompleted;
  final List<String> goals;
  final List<String> stressors;
  final String mayaPersonality; // 'warm' | 'direct' | 'playful'
  final String checkInTime; // 'morning' | 'afternoon' | 'evening' | 'any'
  final String therapyExperience; // 'never' | 'apps' | 'therapy'
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.preferredName,
    this.university,
    this.yearOfStudy,
    this.faculty,
    this.profileImageUrl,
    this.onboardingCompleted = false,
    this.goals = const [],
    this.stressors = const [],
    this.mayaPersonality = 'warm',
    this.checkInTime = 'any',
    this.therapyExperience = 'never',
    required this.createdAt,
  });

  String get displayName => preferredName ?? name.split(' ').first;

  String get yearLabel {
    switch (yearOfStudy) {
      case 1: return 'Freshman';
      case 2: return 'Sophomore';
      case 3: return 'Junior';
      case 4: return 'Senior';
      case 5: return '5th Year';
      case 6: return 'Graduate';
      default: return '';
    }
  }

  String get mayaPersonalityLabel {
    switch (mayaPersonality) {
      case 'direct': return 'Direct & Practical';
      case 'playful': return 'Light & Playful';
      default: return 'Warm & Supportive';
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        preferredName: json['preferred_name'] as String?,
        university: json['university'] as String?,
        yearOfStudy: json['year_of_study'] as int?,
        faculty: json['faculty'] as String?,
        profileImageUrl: json['profile_image_url'] as String?,
        onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
        goals: (json['goals'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        stressors: (json['stressors'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        mayaPersonality: json['maya_personality'] as String? ?? 'warm',
        checkInTime: json['check_in_time'] as String? ?? 'any',
        therapyExperience: json['therapy_experience'] as String? ?? 'never',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'preferred_name': preferredName,
        'university': university,
        'year_of_study': yearOfStudy,
        'faculty': faculty,
        'profile_image_url': profileImageUrl,
        'onboarding_completed': onboardingCompleted,
        'goals': goals,
        'stressors': stressors,
        'maya_personality': mayaPersonality,
        'check_in_time': checkInTime,
        'therapy_experience': therapyExperience,
        'created_at': createdAt.toIso8601String(),
      };

  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'email': email,
        'name': name,
        'preferred_name': preferredName,
        'university': university,
        'year_of_study': yearOfStudy,
        'faculty': faculty,
        'profile_image_url': profileImageUrl,
        'onboarding_completed': onboardingCompleted,
        'goals': goals,
        'stressors': stressors,
        'maya_personality': mayaPersonality,
        'check_in_time': checkInTime,
        'therapy_experience': therapyExperience,
      };

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? preferredName,
    String? university,
    int? yearOfStudy,
    String? faculty,
    String? profileImageUrl,
    bool? onboardingCompleted,
    List<String>? goals,
    List<String>? stressors,
    String? mayaPersonality,
    String? checkInTime,
    String? therapyExperience,
    DateTime? createdAt,
  }) =>
      UserModel(
        id: id ?? this.id,
        email: email ?? this.email,
        name: name ?? this.name,
        preferredName: preferredName ?? this.preferredName,
        university: university ?? this.university,
        yearOfStudy: yearOfStudy ?? this.yearOfStudy,
        faculty: faculty ?? this.faculty,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        goals: goals ?? this.goals,
        stressors: stressors ?? this.stressors,
        mayaPersonality: mayaPersonality ?? this.mayaPersonality,
        checkInTime: checkInTime ?? this.checkInTime,
        therapyExperience: therapyExperience ?? this.therapyExperience,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props => [
        id, email, name, preferredName, university, yearOfStudy, faculty,
        profileImageUrl, onboardingCompleted, goals, stressors,
        mayaPersonality, checkInTime, therapyExperience, createdAt,
      ];
}
