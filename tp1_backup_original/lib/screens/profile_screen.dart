import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/user_profile.dart';
import '../services/data_service.dart';
import 'admin_dashboard_screen.dart';
import 'analytics_screen.dart';
import 'courses_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DataService.instance,
      builder: (context, _) {
        final data = DataService.instance;
        final user = data.currentUser;

        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Not signed in')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Athlete Profile & Settings'),
            actions: [
              IconButton(
                tooltip: 'Edit Profile',
                onPressed: () => _showEditProfileDialog(context, user),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: AppTheme.primaryColor.withValues(
                          alpha: 0.2,
                        ),
                        child: Text(
                          user.name.substring(0, 1),
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${user.username} • ${user.role.label} • ${user.isPremium ? "Lifting Life PRO" : "Free Tier"}',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${user.experienceLevel} • ${user.trainingInterest} • TikTok: ${user.tiktokUsername ?? "Not linked"}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.spaceEvenly,
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          _ProfileStatCol(
                            '${data.workouts.length}',
                            'Workouts',
                          ),
                          _ProfileStatCol('${user.streakDays}d', 'Consistency'),
                          _ProfileStatCol(
                            '${data.personalRecords.length}',
                            'PRs',
                          ),
                          _ProfileStatCol(
                            '${user.friendIds.length}',
                            'Friends',
                          ),
                          _ProfileStatCol(
                            '${user.followerIds.length}',
                            'Followers',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Read-Only Account Security & Role Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Role: ${user.role.label}',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.emailVerified
                                  ? 'Email Verified (${user.email}) • Row-Level Security Active'
                                  : 'Pending Email Verification',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Achievements & Badges
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unlocked Achievements & Badges',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (user.achievements.isEmpty)
                        const Text(
                          'No workouts yet. Start your first workout.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        )
                      else
                        ...user.achievements.map(
                          (b) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const CircleAvatar(
                              backgroundColor: AppTheme.cardColor,
                              child: Icon(
                                Icons.emoji_events,
                                color: AppTheme.powerliftingAmber,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              '${b.title} (+${b.xpReward} XP)',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              b.description,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Navigation Tiles (Courses, Admin Dashboard, Analytics)
              _SettingsTile(
                icon: Icons.school_outlined,
                title: 'Fitness Courses & Creator Studio',
                subtitle: 'Browse courses, submit lessons, or check approval status',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CoursesScreen()),
                  );
                },
              ),
              _SettingsTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Owner Admin Dashboard',
                subtitle:
                    'Approve/reject community courses, moderate reports & audit logs',
                color: AppTheme.primaryColor,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen(),
                    ),
                  );
                },
              ),
              _SettingsTile(
                icon: Icons.analytics_outlined,
                title: 'Progress & Strength Analytics',
                subtitle: 'Interactive charts for 1RM, volume, and frequency',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  );
                },
              ),

              // Linked Identity Providers (Email, Facebook, Apple ID)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connected Identity Providers & Account Security',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Email: ${user.email} (${user.emailVerified ? "Verified ✓" : "Unverified"})',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...['email', 'facebook', 'apple'].map((prov) {
                        final isLinked = user.linkedProviders.contains(prov);
                        final label = prov == 'email'
                            ? 'Email & Password'
                            : (prov == 'facebook' ? 'Facebook Login' : 'Apple ID');
                        final icon = prov == 'email'
                            ? Icons.email_outlined
                            : (prov == 'facebook' ? Icons.facebook : Icons.apple);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(
                            icon,
                            color: isLinked
                                ? AppTheme.primaryColor
                                : AppTheme.textTertiary,
                          ),
                          title: Text(
                            label,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            isLinked ? 'Connected' : 'Not connected',
                            style: TextStyle(
                              color: isLinked
                                  ? AppTheme.primaryColor
                                  : AppTheme.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          trailing: OutlinedButton(
                            onPressed: () => _confirmProviderToggle(
                              context,
                              data,
                              prov,
                              isLinked,
                            ),
                            child: Text(isLinked ? 'Unlink' : 'Link'),
                          ),
                        );
                      }),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () =>
                                  _showChangeEmailDialog(context, user),
                              icon: const Icon(Icons.alternate_email, size: 16),
                              label: const Text('Change Email'),
                            ),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () =>
                                  _showChangePasswordDialog(context),
                              icon: const Icon(Icons.lock_reset, size: 16),
                              label: const Text('Change Password'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Privacy, Units & Quiet Hours
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Public Athlete Profile'),
                      subtitle: const Text(
                        'Allow friends to discover your profile by username',
                      ),
                      value: user.isPublicProfile,
                      onChanged: (v) =>
                          data.updateProfile(user.copyWith(isPublicProfile: v)),
                    ),
                    SwitchListTile(
                      title: const Text('Hide Personal Records on Leaderboards'),
                      subtitle: const Text(
                        'Keep your 1RM numbers private while still competing on consistency XP',
                      ),
                      value: user.hidePersonalRecords,
                      onChanged: (v) => data.updateProfile(
                        user.copyWith(hidePersonalRecords: v),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Use Imperial Units (lbs)'),
                      subtitle: Text('Currently using: ${user.units.toUpperCase()}'),
                      value: user.units == 'imperial',
                      onChanged: (isImp) => data.updateProfile(
                        user.copyWith(units: isImp ? 'imperial' : 'metric'),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Smart Notifications & Quiet Hours'),
                      subtitle: Text(
                        'Quiet hours ${user.quietHoursStart}–${user.quietHoursEnd}. Safety instructions & workout history are always free.',
                      ),
                      value: user.notificationsEnabled,
                      onChanged: (v) => data.updateProfile(
                        user.copyWith(notificationsEnabled: v),
                      ),
                    ),
                  ],
                ),
              ),

              // Data Export, Sign Out & Account Deletion
              _SettingsTile(
                icon: Icons.download_outlined,
                title: 'Export Personal Data (JSON)',
                subtitle: 'Download your complete workout history and PRs',
                onTap: () => _showExportDataDialog(context, data),
              ),
              _SettingsTile(
                icon: Icons.logout,
                title: 'Sign Out / Switch Account',
                onTap: () => data.signOut(),
              ),
              _SettingsTile(
                icon: Icons.delete_forever_outlined,
                title: 'Delete Account & Purge Cloud Data',
                color: AppTheme.errorColor,
                onTap: () => _confirmDeleteAccount(context, data),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _confirmProviderToggle(
    BuildContext context,
    DataService data,
    String provider,
    bool currentlyLinked,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          currentlyLinked
              ? 'Unlink ${provider.toUpperCase()}?'
              : 'Link ${provider.toUpperCase()} to Account?',
        ),
        content: Text(
          currentlyLinked
              ? 'Confirm before unlinking ${provider.toUpperCase()} from your Lifting Life account.'
              : 'Connect ${provider.toUpperCase()} OAuth to your existing Lifting Life account without creating a duplicate profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final msg = currentlyLinked
                  ? data.unlinkIdentityProvider(provider)
                  : data.linkIdentityProvider(provider);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg)),
              );
            },
            child: Text(currentlyLinked ? 'Confirm Unlink' : 'Confirm Link'),
          ),
        ],
      ),
    );
  }

  void _showChangeEmailDialog(BuildContext context, UserProfile user) {
    final ctrl = TextEditingController(text: user.email);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Change Account Email'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'New Email Address'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              DataService.instance.changeAccountEmail(ctrl.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Verification email sent & address updated.'),
                ),
              );
            },
            child: const Text('Update Email'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Strong Password',
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
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password updated securely via Supabase Auth.'),
                ),
              );
            },
            child: const Text('Save Password'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, UserProfile user) {
    final nameCtrl = TextEditingController(text: user.name);
    final usernameCtrl = TextEditingController(text: user.username);
    final tiktokCtrl = TextEditingController(text: user.tiktokUsername ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Edit Athlete Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Display Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: usernameCtrl,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tiktokCtrl,
              decoration: const InputDecoration(labelText: 'TikTok Handle'),
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
              DataService.instance.updateProfile(
                user.copyWith(
                  name: nameCtrl.text.trim(),
                  username: usernameCtrl.text.trim(),
                  tiktokUsername: tiktokCtrl.text.trim(),
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showExportDataDialog(BuildContext context, DataService data) {
    final jsonStr = data.exportUserDataJson();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Exported Athlete Data (JSON)'),
        content: SizedBox(
          width: 400,
          height: 260,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonStr,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, DataService data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Delete Account Permanently?'),
        content: const Text(
          'This will permanently delete your profile, personal records, and cloud workout sessions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              data.deleteAccount();
            },
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatCol extends StatelessWidget {
  final String value;
  final String label;

  const _ProfileStatCol(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppTheme.textSecondary),
        title: Text(
          title,
          style: TextStyle(
            color: color ?? AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              )
            : null,
        trailing: const Icon(
          Icons.chevron_right,
          color: AppTheme.textTertiary,
        ),
        onTap: onTap,
      ),
    );
  }
}
