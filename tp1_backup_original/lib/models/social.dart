class PostComment {
  final String id;
  final String authorUsername;
  final String text;
  final DateTime createdAt;

  const PostComment({
    required this.id,
    required this.authorUsername,
    required this.text,
    required this.createdAt,
  });
}

class SocialPost {
  final String id;
  final String authorId;
  final String authorUsername;
  final String authorName;
  final String authorRoleBadge;
  final String? tiktokHandle;
  final String caption;
  final String postType; // Exercise Demo, PR Achievement, Progress, Program Check-in
  final String? exerciseName;
  final String movementPattern;
  final String? prHighlight;
  final int likesCount;
  final bool isLikedByMe;
  final bool isSavedByMe;
  final List<PostComment> comments;
  final DateTime createdAt;

  const SocialPost({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    required this.authorName,
    required this.authorRoleBadge,
    this.tiktokHandle,
    required this.caption,
    required this.postType,
    this.exerciseName,
    required this.movementPattern,
    this.prHighlight,
    required this.likesCount,
    this.isLikedByMe = false,
    this.isSavedByMe = false,
    this.comments = const [],
    required this.createdAt,
  });

  SocialPost copyWith({
    int? likesCount,
    bool? isLikedByMe,
    bool? isSavedByMe,
    List<PostComment>? comments,
  }) {
    return SocialPost(
      id: id,
      authorId: authorId,
      authorUsername: authorUsername,
      authorName: authorName,
      authorRoleBadge: authorRoleBadge,
      tiktokHandle: tiktokHandle,
      caption: caption,
      postType: postType,
      exerciseName: exerciseName,
      movementPattern: movementPattern,
      prHighlight: prHighlight,
      likesCount: likesCount ?? this.likesCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isSavedByMe: isSavedByMe ?? this.isSavedByMe,
      comments: comments ?? this.comments,
      createdAt: createdAt,
    );
  }
}

class LeaderboardEntry {
  final String userId;
  final String username;
  final String displayName;
  final String? tiktokHandle;
  final int xpPoints;
  final int weeklySessionsCompleted; // Capped at 5 for XP calculation
  final int streakDays;
  final int coursesCompleted;
  final double powerliftingStrengthIndex; // Relative progress %, NOT raw body weight
  final String bestPrSummary;
  final bool hidePersonalRecords;
  final int rankDelta; // +2, -1, 0
  final bool isFriend;
  final String experienceLevel;
  final String trainingInterest;

  const LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.displayName,
    this.tiktokHandle,
    required this.xpPoints,
    required this.weeklySessionsCompleted,
    required this.streakDays,
    required this.coursesCompleted,
    required this.powerliftingStrengthIndex,
    required this.bestPrSummary,
    this.hidePersonalRecords = false,
    this.rankDelta = 0,
    this.isFriend = true,
    this.experienceLevel = 'Intermediate',
    this.trainingInterest = 'Hybrid',
  });

  int get level => (xpPoints ~/ 500) + 1;
  int get cappedWeeklySessions =>
      weeklySessionsCompleted > 5 ? 5 : weeklySessionsCompleted;

  LeaderboardEntry copyWith({
    int? xpPoints,
    int? weeklySessionsCompleted,
    int? streakDays,
    int? coursesCompleted,
    bool? hidePersonalRecords,
    int? rankDelta,
    bool? isFriend,
  }) {
    return LeaderboardEntry(
      userId: userId,
      username: username,
      displayName: displayName,
      tiktokHandle: tiktokHandle,
      xpPoints: xpPoints ?? this.xpPoints,
      weeklySessionsCompleted:
          weeklySessionsCompleted ?? this.weeklySessionsCompleted,
      streakDays: streakDays ?? this.streakDays,
      coursesCompleted: coursesCompleted ?? this.coursesCompleted,
      powerliftingStrengthIndex: powerliftingStrengthIndex,
      bestPrSummary: bestPrSummary,
      hidePersonalRecords: hidePersonalRecords ?? this.hidePersonalRecords,
      rankDelta: rankDelta ?? this.rankDelta,
      isFriend: isFriend ?? this.isFriend,
      experienceLevel: experienceLevel,
      trainingInterest: trainingInterest,
    );
  }
}

class FitnessChallenge {
  final String id;
  final String title;
  final String description;
  final String category; // Weekly Consistency, Monthly Challenge, Friend-vs-Friend, Community
  final int currentProgress;
  final int targetValue;
  final String unit;
  final int rewardXp;
  final int participantsCount;
  final bool isJoined;
  final int daysRemaining;

  const FitnessChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.currentProgress,
    required this.targetValue,
    required this.unit,
    required this.rewardXp,
    required this.participantsCount,
    this.isJoined = true,
    required this.daysRemaining,
  });

  double get progressRatio =>
      targetValue > 0 ? (currentProgress / targetValue).clamp(0.0, 1.0) : 0.0;

  FitnessChallenge copyWith({
    int? currentProgress,
    int? participantsCount,
    bool? isJoined,
  }) {
    return FitnessChallenge(
      id: id,
      title: title,
      description: description,
      category: category,
      currentProgress: currentProgress ?? this.currentProgress,
      targetValue: targetValue,
      unit: unit,
      rewardXp: rewardXp,
      participantsCount: participantsCount ?? this.participantsCount,
      isJoined: isJoined ?? this.isJoined,
      daysRemaining: daysRemaining,
    );
  }
}

class AbuseReport {
  final String id;
  final String reporterUsername;
  final String targetType; // Post, User, Course
  final String targetId;
  final String targetSummary;
  final String reason;
  final String status; // Open, Resolved, Dismissed
  final DateTime createdAt;

  const AbuseReport({
    required this.id,
    required this.reporterUsername,
    required this.targetType,
    required this.targetId,
    required this.targetSummary,
    required this.reason,
    this.status = 'Open',
    required this.createdAt,
  });

  AbuseReport copyWith({String? status}) {
    return AbuseReport(
      id: id,
      reporterUsername: reporterUsername,
      targetType: targetType,
      targetId: targetId,
      targetSummary: targetSummary,
      reason: reason,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

