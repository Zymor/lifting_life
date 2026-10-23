import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/course.dart';
import '../services/data_service.dart';
import '../widgets/exercise_3d_viewer.dart';
import 'admin_dashboard_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'All';

  static const List<String> _courseCategories = [
    'All',
    'Bodybuilding Fundamentals',
    'Powerlifting Fundamentals',
    'Strength Training',
    'Exercise Technique',
    'Beginner Gym Guide',
    'Training Programming',
    'Nutrition Education',
    'Recovery and Mobility',
    'Sports Science',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DataService.instance,
      builder: (context, _) {
        final data = DataService.instance;
        final user = data.currentUser;
        final canReview = user?.role.canApproveCourses ?? false;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Fitness Courses & Education'),
            actions: [
              if (canReview)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminDashboardScreen(),
                        ),
                      );
                    },
                    icon: Badge(
                      isLabelVisible: data.pendingCoursesCount > 0,
                      label: Text('${data.pendingCoursesCount}'),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    label: const Text(
                      'Owner Admin',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(icon: Icon(Icons.school_outlined), text: 'Approved Catalog'),
                Tab(icon: Icon(Icons.add_box_outlined), text: 'Create Course'),
                Tab(
                  icon: Icon(Icons.verified_outlined),
                  text: 'Approval Status',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildApprovedCatalogTab(context, data),
              _CreateCourseTab(
                onSubmitted: () => _tabController.animateTo(2),
              ),
              _buildApprovalStatusTab(context, data),
            ],
          ),
        );
      },
    );
  }

  // ============================================================================
  // TAB 1: PUBLICLY APPROVED COURSES CATALOG
  // ============================================================================
  Widget _buildApprovedCatalogTab(BuildContext context, DataService data) {
    final approved = data.publiclyApprovedCourses.where((c) {
      if (_selectedCategory == 'All') return true;
      return c.category == _selectedCategory;
    }).toList();

    return Column(
      children: [
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _courseCategories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _courseCategories[index];
              final selected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: selected,
                onSelected: (_) => setState(() => _selectedCategory = cat),
                selectedColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color: selected
                      ? AppTheme.backgroundColor
                      : AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        if (data.enrolledCourses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.school_outlined,
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No courses enrolled.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: approved.length,
            itemBuilder: (context, index) {
              final course = approved[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CourseDetailScreen(courseId: course.id),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${course.category.toUpperCase()} • ${course.difficulty.toUpperCase()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.star,
                              color: AppTheme.powerliftingAmber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${course.rating.toStringAsFixed(1)} (${course.enrolledCount})',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          course.title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          course.description,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.verified,
                              color: AppTheme.secondaryAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Instructor: ${course.creatorName} • Approved by ${course.approvedByOwnerName ?? "App Owner"}',
                                style: const TextStyle(
                                  color: AppTheme.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Text(
                              '${course.lessons.length} Lessons',
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (course.isEnrolled) ...[
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: course.completionProgress,
                            backgroundColor: AppTheme.borderColor,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor,
                            ),
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // TAB 3: COURSE SUBMISSION & APPROVAL STATUS TRACKER
  // ============================================================================
  Widget _buildApprovalStatusTab(BuildContext context, DataService data) {
    final allCourses = data.courses;

    Color statusColor(CourseStatus status) {
      switch (status) {
        case CourseStatus.approved:
          return AppTheme.successColor;
        case CourseStatus.pendingReview:
          return AppTheme.powerliftingAmber;
        case CourseStatus.changesRequested:
          return AppTheme.secondaryAccent;
        case CourseStatus.rejected:
          return AppTheme.errorColor;
        case CourseStatus.draft:
        case CourseStatus.archived:
          return AppTheme.textTertiary;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: const Row(
            children: [
              Icon(Icons.security, color: AppTheme.primaryColor),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mandatory Owner Approval Policy: No user-created course is published publicly until reviewed and approved by the App Owner or an authorized Admin. Material edits to an approved course automatically require re-review.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...allCourses.map((c) {
          final badgeColor = statusColor(c.status);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: badgeColor),
                        ),
                        child: Text(
                          c.status.label.toUpperCase(),
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'By ${c.creatorName}',
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (c.reviewerFeedback != null &&
                      c.reviewerFeedback!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Admin / Owner Review Note: "${c.reviewerFeedback}"',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (c.status == CourseStatus.draft ||
                          c.status == CourseStatus.changesRequested)
                        ElevatedButton.icon(
                          onPressed: () {
                            data.submitOrSaveCourse(
                              existingCourseId: c.id,
                              title: c.title,
                              description: c.description,
                              category: c.category,
                              difficulty: c.difficulty,
                              lessons: c.lessons,
                              submitForApproval: true,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Submitted to Pending Review queue for Owner approval!',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.send, size: 15),
                          label: const Text('Submit for Approval'),
                        ),
                      if (c.status == CourseStatus.approved)
                        OutlinedButton.icon(
                          onPressed: () {
                            // Demonstrate Rule 12: Material edits revert Approved -> Pending Review
                            data.submitOrSaveCourse(
                              existingCourseId: c.id,
                              title: '${c.title} (Updated Edition)',
                              description: c.description,
                              category: c.category,
                              difficulty: c.difficulty,
                              lessons: c.lessons,
                              submitForApproval: true,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Material edit detected: Course moved back to Pending Review for Owner re-approval.',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_note, size: 16),
                          label: const Text('Edit (Triggers Re-Review)'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _CreateCourseTab extends StatefulWidget {
  final VoidCallback onSubmitted;

  const _CreateCourseTab({required this.onSubmitted});

  @override
  State<_CreateCourseTab> createState() => _CreateCourseTabState();
}

class _CreateCourseTabState extends State<_CreateCourseTab> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _lessonTitleCtrl = TextEditingController(
    text: 'Lesson 1: Biomechanical Setup & Safety Cues',
  );
  final _lessonContentCtrl = TextEditingController(
    text:
        '### Key Coaching Points\n1. Maintain neutral spinal alignment.\n2. Control the eccentric phase for 2-3 seconds.',
  );
  String _category = 'Exercise Technique';
  String _difficulty = 'Intermediate';
  final String _relatedExercise = 'Barbell Back Squat';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _lessonTitleCtrl.dispose();
    _lessonContentCtrl.dispose();
    super.dispose();
  }

  void _saveCourse({required bool submitForApproval}) {
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a course title and description.'),
        ),
      );
      return;
    }

    final data = DataService.instance;
    final ex = data.findExerciseByNameOrDefault(_relatedExercise);
    data.submitOrSaveCourse(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category,
      difficulty: _difficulty,
      submitForApproval: submitForApproval,
      lessons: [
        CourseLesson(
          id: data.newId(),
          chapterTitle: 'Chapter 1: Core Foundations',
          title: _lessonTitleCtrl.text.trim(),
          durationMinutes: 15,
          relatedExerciseName: ex.name,
          movementPattern3D: ex.movementPattern,
          contentMarkdown: _lessonContentCtrl.text.trim(),
          quizQuestions: const [
            CourseQuizQuestion(
              question: 'What is the primary safety rule during heavy compound movements?',
              options: [
                'Maintain a braced neutral spine and full control',
                'Bounce the weight at the bottom of every rep',
                'Skip warm-up sets entirely',
              ],
              correctOptionIndex: 0,
              explanation:
                  'Spinal bracing and controlled eccentric loading protect connective tissue and maximize force output.',
            ),
          ],
        ),
      ],
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.primaryColor,
        content: Text(
          submitForApproval
              ? 'Course submitted! Status is now PENDING REVIEW awaiting App Owner approval.'
              : 'Course saved as DRAFT.',
          style: const TextStyle(
            color: AppTheme.backgroundColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    widget.onSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Creator Studio — Submit a Fitness Course',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Creators can save drafts and submit courses for review. Creators cannot self-approve their own courses.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Course Title',
            hintText: 'e.g. Mastering Overhead Pressing & Shoulder Health',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Course Description & Learning Outcomes',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                dropdownColor: AppTheme.cardColor,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(
                    value: 'Bodybuilding Fundamentals',
                    child: Text(
                      'Bodybuilding Fundamentals',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Powerlifting Fundamentals',
                    child: Text(
                      'Powerlifting Fundamentals',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Exercise Technique',
                    child: Text(
                      'Exercise Technique',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Nutrition Education',
                    child: Text(
                      'Nutrition Education',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Sports Science',
                    child: Text(
                      'Sports Science',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _difficulty,
                isExpanded: true,
                dropdownColor: AppTheme.cardColor,
                decoration: const InputDecoration(labelText: 'Difficulty'),
                items: const [
                  DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
                  DropdownMenuItem(
                    value: 'Intermediate',
                    child: Text('Intermediate'),
                  ),
                  DropdownMenuItem(value: 'Advanced', child: Text('Advanced')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _difficulty = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _lessonTitleCtrl,
          decoration: const InputDecoration(labelText: 'First Lesson Title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lessonContentCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Lesson Educational Content & Video Notes',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _saveCourse(submitForApproval: false),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save as Draft'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _saveCourse(submitForApproval: true),
                icon: const Icon(Icons.send),
                label: const Text('Submit for Approval'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  int _selectedLessonIndex = 0;
  int? _selectedQuizOption;
  bool _quizSubmitted = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DataService.instance,
      builder: (context, _) {
        final data = DataService.instance;
        final course = data.courses.firstWhere(
          (c) => c.id == widget.courseId,
          orElse: () => data.courses.first,
        );
        final lesson = course.lessons[_selectedLessonIndex];
        final relatedEx = data.findExerciseByNameOrDefault(
          lesson.relatedExerciseName ?? 'Barbell Back Squat',
        );
        final isCompleted = course.completedLessonIds.contains(lesson.id);

        return Scaffold(
          appBar: AppBar(title: Text(course.title)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course Header & Progress
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${course.category} • Instructor: ${course.creatorName} (${course.creatorCredentials})',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          course.description,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Completion: ${(course.completionProgress * 100).toInt()}%',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (!course.isEnrolled)
                              ElevatedButton(
                                onPressed: () =>
                                    data.enrollInCourse(course.id),
                                child: const Text('Enroll Free'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: course.completionProgress,
                          backgroundColor: AppTheme.borderColor,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor,
                          ),
                          minHeight: 6,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Lesson Selector Tabs
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: course.lessons.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final les = course.lessons[i];
                      final done = course.completedLessonIds.contains(les.id);
                      final active = _selectedLessonIndex == i;
                      return ChoiceChip(
                        avatar: Icon(
                          done ? Icons.check_circle : Icons.play_circle_outline,
                          size: 16,
                          color: active
                              ? AppTheme.backgroundColor
                              : AppTheme.primaryColor,
                        ),
                        label: Text('Lesson ${i + 1}: ${les.title}'),
                        selected: active,
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: active
                              ? AppTheme.backgroundColor
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedLessonIndex = i;
                            _selectedQuizOption = null;
                            _quizSubmitted = false;
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Embedded 3D Demonstration for the Lesson
                Exercise3DViewer(exercise: relatedEx, height: 320),
                const SizedBox(height: 16),

                // Lesson Content Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${lesson.chapterTitle} • ${lesson.durationMinutes} min read/watch',
                          style: const TextStyle(
                            color: AppTheme.secondaryAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lesson.title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          lesson.contentMarkdown,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Interactive Lesson Quiz
                if (lesson.quizQuestions.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Knowledge Check Quiz',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lesson.quizQuestions.first.question,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(
                            lesson.quizQuestions.first.options.length,
                            (optIdx) {
                              final optText =
                                  lesson.quizQuestions.first.options[optIdx];
                              final isSelected = _selectedQuizOption == optIdx;
                              return InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () =>
                                    setState(() => _selectedQuizOption = optIdx),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : AppTheme.textSecondary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          optText,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          if (_quizSubmitted) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (_selectedQuizOption ==
                                            lesson.quizQuestions.first
                                                .correctOptionIndex
                                        ? AppTheme.successColor
                                        : AppTheme.errorColor)
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                lesson.quizQuestions.first.explanation,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          ElevatedButton(
                            onPressed: () {
                              setState(() => _quizSubmitted = true);
                              data.markLessonCompleted(course.id, lesson.id);
                            },
                            child: Text(
                              isCompleted
                                  ? 'Lesson Completed ✓ (+75 XP)'
                                  : 'Submit Quiz & Complete Lesson',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}
