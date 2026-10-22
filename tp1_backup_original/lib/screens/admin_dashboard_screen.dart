import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/course.dart';
import '../models/exercise.dart';
import '../services/data_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        final isAuthorized = user?.role.canApproveCourses ?? false;

        if (!isAuthorized) {
          return Scaffold(
            appBar: AppBar(title: const Text('Restricted Area')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: AppTheme.errorColor,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '403 Forbidden — Owner / Admin Role Required',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your current role is "${user?.role.label ?? "User"}". Course creators and standard users cannot access the Owner Approval Dashboard.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Owner Admin Dashboard'),
                Text(
                  'Role: ${user!.role.label} • Server-Side RBAC Enforced',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: [
                Tab(
                  icon: Badge(
                    isLabelVisible: data.pendingCoursesCount > 0,
                    label: Text('${data.pendingCoursesCount}'),
                    child: const Icon(Icons.fact_check_outlined),
                  ),
                  text: 'Course Approvals',
                ),
                const Tab(
                  icon: Icon(Icons.report_problem_outlined),
                  text: 'Moderation & Reports',
                ),
                const Tab(
                  icon: Icon(Icons.fitness_center),
                  text: 'Exercise DB Manager',
                ),
                const Tab(
                  icon: Icon(Icons.receipt_long_outlined),
                  text: 'Admin Audit Logs',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildCourseApprovalsTab(context, data),
              _buildModerationTab(context, data),
              _buildExerciseManagerTab(context, data),
              _buildAuditLogsTab(context, data),
            ],
          ),
        );
      },
    );
  }

  // ============================================================================
  // TAB 1: MANDATORY OWNER COURSE APPROVAL QUEUE
  // ============================================================================
  Widget _buildCourseApprovalsTab(BuildContext context, DataService data) {
    final courses = data.courses;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
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
                        color: course.status == CourseStatus.pendingReview
                            ? AppTheme.powerliftingAmber.withValues(alpha: 0.2)
                            : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        course.status.label.toUpperCase(),
                        style: TextStyle(
                          color: course.status == CourseStatus.pendingReview
                              ? AppTheme.powerliftingAmber
                              : AppTheme.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Creator: ${course.creatorName}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  course.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${course.category} • ${course.difficulty} • ${course.lessons.length} Lesson(s)',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  course.description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _openReviewDecisionDialog(
                        context,
                        course,
                        CourseStatus.approved,
                      ),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Approve & Publish'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openReviewDecisionDialog(
                        context,
                        course,
                        CourseStatus.changesRequested,
                      ),
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: const Text('Request Changes'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openReviewDecisionDialog(
                        context,
                        course,
                        CourseStatus.rejected,
                      ),
                      icon: const Icon(
                        Icons.cancel_outlined,
                        size: 16,
                        color: AppTheme.errorColor,
                      ),
                      label: const Text(
                        'Reject',
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openReviewDecisionDialog(
    BuildContext context,
    FitnessCourse course,
    CourseStatus decision,
  ) {
    final feedbackCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text('${decision.label}: ${course.title}'),
        content: TextField(
          controller: feedbackCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reviewer Explanation / Feedback for Creator',
            hintText: 'Provide clear notes for the audit log and creator...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final msg = DataService.instance.reviewCourseSubmission(
                courseId: course.id,
                decision: decision,
                feedback: feedbackCtrl.text,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg)),
              );
            },
            child: Text('Confirm ${decision.label}'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 2: ABUSE REPORTS & COMMUNITY MODERATION
  // ============================================================================
  Widget _buildModerationTab(BuildContext context, DataService data) {
    final reports = data.reports;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final r = reports[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(
              Icons.shield_outlined,
              color: AppTheme.errorColor,
            ),
            title: Text(
              '[${r.targetType}] ${r.targetSummary}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Reason: ${r.reason} • Reported by @${r.reporterUsername} • Status: ${r.status}',
            ),
            trailing: r.status == 'Open'
                ? ElevatedButton(
                    onPressed: () =>
                        data.resolveAbuseReport(r.id, 'Removed & Resolved'),
                    child: const Text('Resolve'),
                  )
                : const Text(
                    'Resolved ✓',
                    style: TextStyle(color: AppTheme.successColor),
                  ),
          ),
        );
      },
    );
  }

  // ============================================================================
  // TAB 3: EXERCISE DATABASE MANAGER
  // ============================================================================
  Widget _buildExerciseManagerTab(BuildContext context, DataService data) {
    final nameCtrl = TextEditingController();
    String category = 'Chest';
    String equipment = 'Barbell';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Master Exercise Database (${data.exercises.length} Active Exercises)',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'New Exercise Name',
                    hintText: 'e.g. Cambered Bar Bench Press',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      data.addNewExerciseAsAdmin(
                        Exercise(
                          id: data.newId(),
                          name: nameCtrl.text.trim(),
                          category: category,
                          primaryMuscles: [category],
                          secondaryMuscles: const ['Stabilizers'],
                          equipment: equipment,
                          difficulty: 'Intermediate',
                          instructions: const [
                            'Set up station and verify joint alignment.',
                            'Execute concentric & eccentric with full control.',
                          ],
                          techniqueTips: const ['Keep core braced.'],
                          commonMistakes: const ['Using excessive momentum.'],
                          alternativeNames: const ['Barbell Bench Press'],
                          movementPattern: 'bench',
                          startPositionDesc: 'Standard starting posture.',
                          endPositionDesc: 'Peak contraction.',
                          movementPathDesc: 'Controlled vertical/diagonal path.',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Added exercise to Master Library & logged in Audit Trail!',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Verified Exercise to Library'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // TAB 4: IMMUTABLE ADMIN AUDIT LOGS
  // ============================================================================
  Widget _buildAuditLogsTab(BuildContext context, DataService data) {
    final logs = data.auditLogs;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(
              Icons.verified_user,
              color: AppTheme.primaryColor,
            ),
            title: Text(
              '${log.action} — ${log.targetTitle}',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              'Actor: ${log.actorName} (${log.actorRole.label})\n${log.details}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }
}
