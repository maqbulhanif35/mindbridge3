import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String email;
  final String name;
  final String? university;
  final int? yearOfStudy;
  final String? profileImageUrl;
  final bool onboardingCompleted;
  final List<String> goals;
  final String? preferredName;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.university,
    this.yearOfStudy,
    this.profileImageUrl,
    this.onboardingCompleted = false,
    this.goals = const [],
    this.preferredName,
    required this.createdAt,
  });

  String get displayName => preferredName ?? name.split(' ').first;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        university: json['university'] as String?,
        yearOfStudy: json['year_of_study'] as int?,
        profileImageUrl: json['profile_image_url'] as String?,
        onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
        goals: (json['goals'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        preferredName: json['preferred_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'university': university,
        'year_of_study': yearOfStudy,
        'profile_image_url': profileImageUrl,
        'onboarding_completed': onboardingCompleted,
        'goals': goals,
        'preferred_name': preferredName,
        'created_at': createdAt.toIso8601String(),
      };

  // For Supabase upsert (excludes created_at so DB default applies)
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'email': email,
        'name': name,
        'university': university,
        'year_of_study': yearOfStudy,
        'profile_image_url': profileImageUrl,
        'onboarding_completed': onboardingCompleted,
        'goals': goals,
        'preferred_name': preferredName,
      };

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? university,
    int? yearOfStudy,
    String? profileImageUrl,
    bool? onboardingCompleted,
    List<String>? goals,
    String? preferredName,
    DateTime? createdAt,
  }) =>
      UserModel(
        id: id ?? this.id,
        email: email ?? this.email,
        name: name ?? this.name,
        university: university ?? this.university,
        yearOfStudy: yearOfStudy ?? this.yearOfStudy,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        goals: goals ?? this.goals,
        preferredName: preferredName ?? this.preferredName,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        university,
        yearOfStudy,
        profileImageUrl,
        onboardingCompleted,
        goals,
        preferredName,
        createdAt,
      ];
}
