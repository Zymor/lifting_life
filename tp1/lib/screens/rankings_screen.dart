import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/social.dart';
import '../services/data_service.dart';
import '../widgets/exercise_3d_viewer.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedLeaderboardCategory = 'Friends Ranking';

  static const List<String> _leaderboardCategories = [
    'Friends Ranking',
    'Weekly Consistency',
    'Monthly Challenge',
    'Workout Achievement',
    'Powerlifting Progress',
    'Community Challenge',
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

  List<LeaderboardEntry> _sortedEntries(DataService data) {
    final entries = List<LeaderboardEntry>.from(data.leaderboardEntries);
    if (_selectedLeaderboardCategory == 'Friends Ranking') {
      entries.retainWhere((e) => e.isFriend);
      entries.sort((a, b) => b.xpPoints.compareTo(a.xpPoints));
    } else if (_selectedLeaderboardCategory == 'Weekly Consistency') {
      entries.sort((a, b) {
        final cmp = b.cappedWeeklySessions.compareTo(a.cappedWeeklySessions);
        if (cmp != 0) return cmp;
        return b.streakDays.compareTo(a.streakDays);
      });
    } else if (_selectedLeaderboardCategory == 'Powerlifting Progress') {
      entries.sort(
        (a, b) => b.powerliftingStrengthIndex.compareTo(
          a.powerliftingStrengthIndex,
        ),
      );
    } else {
      entries.sort((a, b) => b.xpPoints.compareTo(a.xpPoints));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DataService.instance,
      builder: (context, _) {
        final data = DataService.instance;
        final user = data.currentUser;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Rankings & Social Feed'),
            actions: [
              IconButton(
                tooltip: 'Add Friend / Search Username or TikTok',
                icon: const Icon(Icons.person_add_alt_1),
                onPressed: () => _showAddFriendDialog(context),
              ),
              IconButton(
                tooltip: 'Share QR / TikTok Invite Link',
                icon: const Icon(Icons.qr_code_2),
                onPressed: () => _showInviteQrDialog(context),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(icon: Icon(Icons.leaderboard), text: 'Leaderboards'),
                Tab(icon: Icon(Icons.flag_outlined), text: 'Challenges'),
                Tab(icon: Icon(Icons.play_circle_outline), text: 'Social Feed'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildLeaderboardsTab(context, data, user?.hidePersonalRecords ?? false),
              _buildChallengesTab(context, data),
              _buildSocialFeedTab(context, data),
            ],
          ),
        );
      },
    );
  }

  // ============================================================================
  // TAB 1: LEADERBOARDS & FRIEND RANKINGS
  // ============================================================================
  Widget _buildLeaderboardsTab(
    BuildContext context,
    DataService data,
    bool hidePrs,
  ) {
    final entries = _sortedEntries(data);
    final user = data.currentUser;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // User XP & Level Progress Banner
        if (user != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.2),
                  AppTheme.surfaceColor,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        'L${user.level}',
                        style: const TextStyle(
                          color: AppTheme.backgroundColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${user.name} • ${user.xpPoints} XP',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${user.streakDays}-Day Streak • Fair-Play Cap: Max 5 XP Sessions/Wk',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: !user.hidePersonalRecords,
                      activeThumbColor: AppTheme.primaryColor,
                      onChanged: (showPr) {
                        data.updateProfile(
                          user.copyWith(hidePersonalRecords: !showPr),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      user.hidePersonalRecords
                          ? 'Personal Records: Hidden from Leaderboard'
                          : 'Personal Records: Visible to Friends',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${((user.levelProgress) * 100).toInt()}% to Level ${user.level + 1}',
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: user.levelProgress,
                  backgroundColor: AppTheme.borderColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),

        // 6 Leaderboard Category Selector Chips
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _leaderboardCategories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _leaderboardCategories[index];
              final selected = _selectedLeaderboardCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: selected,
                onSelected: (_) =>
                    setState(() => _selectedLeaderboardCategory = cat),
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
        const SizedBox(height: 12),

        // Ethical Ranking Safeguard Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: AppTheme.secondaryAccent,
                size: 16,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fair Ranking Policy: Points are awarded for consistency (capped at 5 sessions/wk) & learning milestones—never body weight or extreme volume.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Leaderboard Rows or Empty State
        if (entries.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: const [
                  Icon(
                    Icons.group_outlined,
                    color: AppTheme.primaryColor,
                    size: 36,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No friends added.',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Add friends by username or complete your first workout to appear on the leaderboard.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(entries.length, (i) {
          final entry = entries[i];
          final rank = i + 1;
          final isMe = entry.userId == data.currentUser?.id;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isMe ? AppTheme.primaryColor : AppTheme.borderColor,
                width: isMe ? 1.5 : 1.0,
              ),
            ),
            child: ListTile(
              onTap: () => _showFriendProfileSheet(context, entry),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        color: rank <= 3
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: rank == 1
                        ? AppTheme.powerliftingAmber.withValues(alpha: 0.25)
                        : AppTheme.cardColor,
                    child: Text(
                      entry.displayName.substring(0, 1),
                      style: TextStyle(
                        color: rank == 1
                            ? AppTheme.powerliftingAmber
                            : AppTheme.primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      entry.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (entry.rankDelta != 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (entry.rankDelta > 0
                                ? AppTheme.successColor
                                : AppTheme.errorColor)
                            .withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.rankDelta > 0
                            ? '▲${entry.rankDelta}'
                            : '▼${entry.rankDelta.abs()}',
                        style: TextStyle(
                          color: entry.rankDelta > 0
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                '${entry.cappedWeeklySessions}/5 wk sessions • ${entry.streakDays}d streak • '
                '${entry.hidePersonalRecords ? "PRs Private" : entry.bestPrSummary}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _selectedLeaderboardCategory == 'Powerlifting Progress'
                        ? '${entry.powerliftingStrengthIndex.toStringAsFixed(1)} idx'
                        : '${entry.xpPoints} XP',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Level ${entry.level}',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ============================================================================
  // TAB 2: CHALLENGES (VOLUNTARY JOIN / LEAVE AT ANY TIME)
  // ============================================================================
  Widget _buildChallengesTab(BuildContext context, DataService data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...data.challenges.map((chal) {
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
                          color: AppTheme.primaryColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          chal.category.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '+${chal.rewardXp} XP • ${chal.daysRemaining}d left',
                        style: const TextStyle(
                          color: AppTheme.powerliftingAmber,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    chal.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chal.description,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress: ${chal.currentProgress} / ${chal.targetValue} ${chal.unit}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${chal.participantsCount} Lifters Joined',
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: chal.progressRatio,
                    backgroundColor: AppTheme.borderColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () =>
                          data.toggleChallengeParticipation(chal.id),
                      child: Text(
                        chal.isJoined
                            ? 'Leave Competition'
                            : 'Join Challenge',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ============================================================================
  // TAB 3: TIKTOK-STYLE SHORT-FORM FITNESS FEED
  // ============================================================================
  Widget _buildSocialFeedTab(BuildContext context, DataService data) {
    final posts = data.socialPosts;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.backgroundColor,
        onPressed: () => _showCreatePostDialog(context),
        icon: const Icon(Icons.videocam),
        label: const Text(
          'Post Progress / Exercise',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 84),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final exercise = data.findExerciseByNameOrDefault(
            post.exerciseName ?? 'Barbell Back Squat',
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 18),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Creator Header
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.2,
                    ),
                    child: Text(
                      post.authorName.substring(0, 1),
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryAccent.withValues(
                            alpha: 0.16,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          post.authorRoleBadge,
                          style: const TextStyle(
                            color: AppTheme.secondaryAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '@${post.authorUsername} ${post.tiktokHandle != null ? "• TikTok ${post.tiktokHandle}" : ""}',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'report') {
                        data.reportContent(
                          targetType: 'Post',
                          targetId: post.id,
                          targetSummary: post.caption,
                          reason: 'Reported by user from social feed',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Post reported to Admin Moderation Queue.',
                            ),
                          ),
                        );
                      } else if (action == 'block') {
                        data.blockUser(post.authorId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Blocked @${post.authorUsername}. Their posts are now hidden.',
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'report',
                        child: Text('Report Inappropriate Content'),
                      ),
                      PopupMenuItem(
                        value: 'block',
                        child: Text('Block User'),
                      ),
                    ],
                  ),
                ),

                // Interactive 3D Demonstration Viewport inside the Feed Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Exercise3DViewer(
                    exercise: exercise,
                    height: 220,
                    compactMode: true,
                  ),
                ),

                // PR Highlight & Caption
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.prHighlight != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.16,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${post.postType.toUpperCase()}: ${post.prHighlight}',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        post.caption,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Social Interaction Bar: Like, Comment, Save, Share to TikTok
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => data.toggleLikePost(post.id),
                                icon: Icon(
                                  post.isLikedByMe
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: post.isLikedByMe
                                      ? AppTheme.musclePrimaryRed
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                '${post.likesCount}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _showCommentsModal(context, post),
                                icon: const Icon(
                                  Icons.mode_comment_outlined,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                '${post.comments.length}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => data.toggleSavePost(post.id),
                                icon: Icon(
                                  post.isSavedByMe
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: post.isSavedByMe
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.primaryColor,
                                  content: Text(
                                    'Prepared Achievement Card for TikTok Share (${post.prHighlight ?? post.exerciseName})!',
                                    style: const TextStyle(
                                      color: AppTheme.backgroundColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.ios_share, size: 14),
                            label: const Text(
                              'Share to TikTok',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCommentsModal(BuildContext context, SocialPost post) {
    final commentCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comments (${post.comments.length})',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...post.comments.map(
              (c) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '@${c.authorUsername}',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  c.text,
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Add an encouraging comment...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    DataService.instance.addCommentToPost(
                      post.id,
                      commentCtrl.text,
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Post'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context) {
    final captionCtrl = TextEditingController();
    final prCtrl = TextEditingController(text: '185 kg × 1 @ RPE 8.5');
    String selectedEx = 'Barbell Back Squat';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Share Workout Achievement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedEx,
              dropdownColor: AppTheme.cardColor,
              items: const [
                DropdownMenuItem(
                  value: 'Barbell Back Squat',
                  child: Text('Barbell Back Squat'),
                ),
                DropdownMenuItem(
                  value: 'Barbell Bench Press',
                  child: Text('Barbell Bench Press'),
                ),
                DropdownMenuItem(
                  value: 'Conventional Barbell Deadlift',
                  child: Text('Conventional Barbell Deadlift'),
                ),
                DropdownMenuItem(
                  value: 'Barbell Overhead Press (OHP)',
                  child: Text('Barbell Overhead Press (OHP)'),
                ),
              ],
              onChanged: (v) {
                if (v != null) selectedEx = v;
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: prCtrl,
              decoration: const InputDecoration(
                labelText: 'Achievement Highlight',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: captionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Caption & Technique Notes',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (captionCtrl.text.trim().isNotEmpty) {
                DataService.instance.createSocialPost(
                  caption: captionCtrl.text.trim(),
                  postType: 'PR Achievement',
                  exerciseName: selectedEx,
                  prHighlight: prCtrl.text.trim(),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Publish Post'),
          ),
        ],
      ),
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Connect with Friends'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search by Lifting Life username or opted-in TikTok handle (we never scrape private TikTok data or request passwords).',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'e.g. kai_strength or @kai_barbell',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              DataService.instance.addFriendByUsernameOrTikTok(ctrl.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Friend added to Leaderboard!')),
              );
            },
            child: const Text('Add Friend'),
          ),
        ],
      ),
    );
  }

  void _showInviteQrDialog(BuildContext context) {
    final user = DataService.instance.currentUser;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Invite Friends to Private Leaderboard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.qr_code_2,
                size: 140,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'liftinglife.app/invite/${user?.username ?? "alex_titan"}',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showFriendProfileSheet(BuildContext context, LeaderboardEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  child: Text(
                    entry.displayName.substring(0, 1),
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displayName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '@${entry.username} • ${entry.experienceLevel} • ${entry.trainingInterest}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Level ${entry.level} (${entry.xpPoints} XP) • ${entry.streakDays}-Day Streak • ${entry.coursesCompleted} Courses Completed',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.hidePersonalRecords
                  ? 'Personal Records: Hidden by athlete privacy settings'
                  : 'Best Lifts: ${entry.bestPrSummary}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  DataService.instance.toggleFriendConnection(entry.userId);
                  Navigator.pop(ctx);
                },
                child: Text(
                  entry.isFriend ? 'Following / Friend ✓' : 'Add Friend',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

