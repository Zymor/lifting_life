enum CourseStatus {
  draft('Draft'),
  pendingReview('Pending Review'),
  changesRequested('Changes Requested'),
  approved('Approved'),
  rejected('Rejected'),
  archived('Archived');

  final String label;
  const CourseStatus(this.label);
}

class CourseQuizQuestion {
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;

  const CourseQuizQuestion({
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
  });
}

class CourseLesson {
  final String id;
  final String chapterTitle;
  final String title;
  final int durationMinutes;
  final String videoUrl;
  final String contentMarkdown;
  final String? relatedExerciseName;
  final String movementPattern3D;
  final List<CourseQuizQuestion> quizQuestions;

  const CourseLesson({
    required this.id,
    required this.chapterTitle,
    required this.title,
    required this.durationMinutes,
    this.videoUrl = 'https://assets.liftinglife.app/courses/lesson-hd.mp4',
    required this.contentMarkdown,
    this.relatedExerciseName,
    this.movementPattern3D = 'squat',
    this.quizQuestions = const [],
  });
}

class CourseReview {
  final String id;
  final String username;
  final int rating;
  final String comment;
  final DateTime createdAt;

  const CourseReview({
    required this.id,
    required this.username,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });
}

class FitnessCourse {
  final String id;
  final String title;
  final String description;
  final String category; // Bodybuilding Fundamentals, Powerlifting Fundamentals, Strength Training, Exercise Technique, Beginner Gym Guide, Training Programming, Nutrition Education, Recovery and Mobility, Sports Science
  final String difficulty; // Beginner, Intermediate, Advanced
  final String creatorId;
  final String creatorName;
  final String creatorCredentials;
  final CourseStatus status;
  final String? reviewerFeedback;
  final String? approvedByOwnerName;
  final DateTime? approvedAt;
  final bool isPremium;
  final double rating;
  final int enrolledCount;
  final List<CourseLesson> lessons;
  final List<CourseReview> reviews;
  final Set<String> completedLessonIds;
  final bool isEnrolled;
  final DateTime updatedAt;

  const FitnessCourse({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.creatorId,
    required this.creatorName,
    required this.creatorCredentials,
    required this.status,
    this.reviewerFeedback,
    this.approvedByOwnerName,
    this.approvedAt,
    this.isPremium = false,
    this.rating = 4.9,
    this.enrolledCount = 120,
    required this.lessons,
    this.reviews = const [],
    this.completedLessonIds = const {},
    this.isEnrolled = false,
    required this.updatedAt,
  });

  double get completionProgress => lessons.isEmpty
      ? 0.0
      : (completedLessonIds.length / lessons.length).clamp(0.0, 1.0);

  FitnessCourse copyWith({
    String? title,
    String? description,
    String? category,
    String? difficulty,
    CourseStatus? status,
    String? reviewerFeedback,
    String? approvedByOwnerName,
    DateTime? approvedAt,
    bool? isPremium,
    double? rating,
    int? enrolledCount,
    List<CourseLesson>? lessons,
    List<CourseReview>? reviews,
    Set<String>? completedLessonIds,
    bool? isEnrolled,
    DateTime? updatedAt,
  }) {
    return FitnessCourse(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorCredentials: creatorCredentials,
      status: status ?? this.status,
      reviewerFeedback: reviewerFeedback ?? this.reviewerFeedback,
      approvedByOwnerName: approvedByOwnerName ?? this.approvedByOwnerName,
      approvedAt: approvedAt ?? this.approvedAt,
      isPremium: isPremium ?? this.isPremium,
      rating: rating ?? this.rating,
      enrolledCount: enrolledCount ?? this.enrolledCount,
      lessons: lessons ?? this.lessons,
      reviews: reviews ?? this.reviews,
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

