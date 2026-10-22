enum UserRole {
  user('User'),
  creator('Course Creator'),
  moderator('Moderator'),
  admin('Admin'),
  owner('Owner');

  final String label;
  const UserRole(this.label);

  bool get canApproveCourses => this == UserRole.owner || this == UserRole.admin;
  bool get canModerate =>
      this == UserRole.owner ||
      this == UserRole.admin ||
      this == UserRole.moderator;
}

class AchievementBadge {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final int xpReward;
  final DateTime unlockedAt;

  const AchievementBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.xpReward,
    required this.unlockedAt,
  });
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String category; // workout, friend, challenge, ranking, pr, course
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      category: category,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

class AdminAuditLog {
  final String id;
  final String actorId;
  final String actorName;
  final UserRole actorRole;
  final String action;
  final String targetTitle;
  final String details;
  final DateTime timestamp;

  const AdminAuditLog({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.targetTitle,
    required this.details,
    required this.timestamp,
  });
}

class UserProfile {
  final String id;
  final String email;
  final bool emailVerified;
  final String username;
  final String name;
  final int? age;
  final double? height; // in cm
  final double? weight; // in kg
  final String experienceLevel; // Beginner, Intermediate, Advanced
  final String trainingInterest; // Bodybuilding, Powerlifting, Hybrid Training, General Fitness
  final String workoutFrequency; // 2 days per week, 3 days per week, 4 days per week, 5 days per week, Custom schedule
  final List<String> preferredDays; // Mon, Tue, Wed, etc.
  final List<String> trainingGoals; // Learn gym techniques, Improve strength, Build muscle, etc.
  final List<String> linkedProviders; // email, facebook, apple
  final String? tiktokUsername;
  final String units; // metric (kg) or imperial (lb)
  final bool isPublicProfile;
  final bool hidePersonalRecords;
  final bool isPremium;
  final int xpPoints;
  final int streakDays;
  final UserRole role;
  final bool notificationsEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;
  final List<String> friendIds;
  final List<String> followerIds;
  final List<String> followingIds;
  final List<String> blockedUserIds;
  final List<AchievementBadge> achievements;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    this.email = '',
    this.emailVerified = false,
    this.username = 'athlete',
    required this.name,
    this.age,
    this.height,
    this.weight,
    this.experienceLevel = 'Beginner',
    this.trainingInterest = 'Hybrid Training',
    this.workoutFrequency = '4 days per week',
    this.preferredDays = const ['Mon', 'Tue', 'Thu', 'Fri'],
    this.trainingGoals = const ['Build muscle', 'Improve strength'],
    this.linkedProviders = const ['email'],
    this.tiktokUsername,
    this.units = 'metric',
    this.isPublicProfile = true,
    this.hidePersonalRecords = false,
    this.isPremium = false,
    this.xpPoints = 0,
    this.streakDays = 0,
    this.role = UserRole.user,
    this.notificationsEnabled = true,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '07:00',
    this.friendIds = const [],
    this.followerIds = const [],
    this.followingIds = const [],
    this.blockedUserIds = const [],
    this.achievements = const [],
    required this.createdAt,
  });

  int get level => (xpPoints ~/ 500) + 1;
  double get levelProgress => (xpPoints % 500) / 500.0;

  UserProfile copyWith({
    String? email,
    bool? emailVerified,
    String? username,
    String? name,
    int? age,
    double? height,
    double? weight,
    String? experienceLevel,
    String? trainingInterest,
    String? workoutFrequency,
    List<String>? preferredDays,
    List<String>? trainingGoals,
    List<String>? linkedProviders,
    String? tiktokUsername,
    String? units,
    bool? isPublicProfile,
    bool? hidePersonalRecords,
    bool? isPremium,
    int? xpPoints,
    int? streakDays,
    UserRole? role,
    bool? notificationsEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    List<String>? friendIds,
    List<String>? followerIds,
    List<String>? followingIds,
    List<String>? blockedUserIds,
    List<AchievementBadge>? achievements,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      username: username ?? this.username,
      name: name ?? this.name,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      trainingInterest: trainingInterest ?? this.trainingInterest,
      workoutFrequency: workoutFrequency ?? this.workoutFrequency,
      preferredDays: preferredDays ?? this.preferredDays,
      trainingGoals: trainingGoals ?? this.trainingGoals,
      linkedProviders: linkedProviders ?? this.linkedProviders,
      tiktokUsername: tiktokUsername ?? this.tiktokUsername,
      units: units ?? this.units,
      isPublicProfile: isPublicProfile ?? this.isPublicProfile,
      hidePersonalRecords: hidePersonalRecords ?? this.hidePersonalRecords,
      isPremium: isPremium ?? this.isPremium,
      xpPoints: xpPoints ?? this.xpPoints,
      streakDays: streakDays ?? this.streakDays,
      role: role ?? this.role,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      friendIds: friendIds ?? this.friendIds,
      followerIds: followerIds ?? this.followerIds,
      followingIds: followingIds ?? this.followingIds,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
      achievements: achievements ?? this.achievements,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'emailVerified': emailVerified,
      'username': username,
      'name': name,
      'age': age,
      'height': height,
      'weight': weight,
      'experienceLevel': experienceLevel,
      'trainingInterest': trainingInterest,
      'workoutFrequency': workoutFrequency,
      'preferredDays': preferredDays,
      'trainingGoals': trainingGoals,
      'linkedProviders': linkedProviders,
      'tiktokUsername': tiktokUsername,
      'units': units,
      'isPublicProfile': isPublicProfile,
      'hidePersonalRecords': hidePersonalRecords,
      'isPremium': isPremium,
      'xpPoints': xpPoints,
      'streakDays': streakDays,
      'role': role.name,
      'notificationsEnabled': notificationsEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'friendIds': friendIds,
      'followerIds': followerIds,
      'followingIds': followingIds,
      'blockedUserIds': blockedUserIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final roleName = (map['role'] ?? 'user').toString();
    final matchedRole = UserRole.values.firstWhere(
      (r) => r.name == roleName,
      orElse: () => UserRole.user,
    );
    return UserProfile(
      id: (map['id'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      emailVerified: map['emailVerified'] == true,
      username: (map['username'] ?? 'athlete').toString(),
      name: (map['name'] ?? map['username'] ?? 'Athlete').toString(),
      age: (map['age'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toDouble(),
      weight: (map['weight'] as num?)?.toDouble(),
      experienceLevel: (map['experienceLevel'] ?? 'Beginner').toString(),
      trainingInterest: (map['trainingInterest'] ?? 'Hybrid Training').toString(),
      workoutFrequency: (map['workoutFrequency'] ?? '4 days per week').toString(),
      preferredDays: (map['preferredDays'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['Mon', 'Tue', 'Thu', 'Fri'],
      trainingGoals: (map['trainingGoals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      linkedProviders: (map['linkedProviders'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['email'],
      tiktokUsername: map['tiktokUsername']?.toString(),
      units: (map['units'] ?? 'metric').toString(),
      isPublicProfile: map['isPublicProfile'] != false,
      hidePersonalRecords: map['hidePersonalRecords'] == true,
      isPremium: map['isPremium'] == true,
      xpPoints: (map['xpPoints'] as num?)?.toInt() ?? 0,
      streakDays: (map['streakDays'] as num?)?.toInt() ?? 0,
      role: matchedRole,
      notificationsEnabled: map['notificationsEnabled'] != false,
      quietHoursStart: (map['quietHoursStart'] ?? '22:00').toString(),
      quietHoursEnd: (map['quietHoursEnd'] ?? '07:00').toString(),
      friendIds: (map['friendIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      followerIds: (map['followerIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      followingIds: (map['followingIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      blockedUserIds: (map['blockedUserIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
