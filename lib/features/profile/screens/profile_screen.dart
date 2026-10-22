import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/route_utils.dart';
import '../../auth/screens/login_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'help_feedback_screen.dart';
import '../../cloudisk/screens/cloud_sync_prompt_screen.dart';
import '../../../core/utils/l10n_extension.dart';



class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.status == AuthStatus.authenticated;
    final isAuthenticating = authState.status == AuthStatus.authenticating;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: Column(
          children: [
            // 用户信息区域：大留白 + 头像 + 姓名/学号
            _buildUserInfo(context, authState),

            const SizedBox(height: AppSpacing.xxl),

            // 设置项分组卡片
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadius.cardAll,
                border: Border.all(color: colors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildListTile(
                    context,
                    icon: Icons.settings_outlined,
                    title: context.l10n.settings,
                    onTap: () {
                      Navigator.push(
                        context,
                        createSlideHorizontalRoute(const SettingsScreen()),
                      );
                    },
                  ),
                  Divider(height: 1, indent: 56, color: colors.border),
                  _buildListTile(
                    context,
                    icon: Icons.help_outline_rounded,
                    title: context.l10n.helpFeedback,
                    onTap: () {
                      Navigator.push(
                        context,
                        createSlideHorizontalRoute(const HelpFeedbackScreen()),
                      );
                    },
                  ),
                  Divider(height: 1, indent: 56, color: colors.border),
                  _buildListTile(
                    context,
                    icon: Icons.rocket_launch_outlined,
                    title: context.l10n.startGuide,
                    onTap: () {
                      Navigator.push(
                        context,
                        CloudSyncPromptScreen.route(),
                      );
                    },
                  ),
                  Divider(height: 1, indent: 56, color: colors.border),
                  _buildListTile(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: context.l10n.about,
                    onTap: () {
                      Navigator.push(
                        context,
                        createSlideHorizontalRoute(const AboutScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // 退出登录（危险操作，独立卡片）
            if (isLoggedIn || isAuthenticating) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadius.cardAll,
                  border: Border.all(color: colors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildListTile(
                  context,
                  icon: Icons.logout_rounded,
                  title: context.l10n.logout,
                  titleColor: isAuthenticating
                      ? colors.textMuted
                      : colors.danger,
                  iconColor: isAuthenticating
                      ? colors.textMuted
                      : colors.danger,
                  onTap: isAuthenticating
                      ? () {}
                      : () => _handleLogout(context, ref),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo(BuildContext context, AuthState authState) {
    final colors = context.colors;
    final isUnauthenticated = authState.status == AuthStatus.unauthenticated;

    ImageProvider? avatarImage;
    if (!isUnauthenticated && authState.avatarUrl != null) {
      if (authState.avatarUrl!.startsWith('http')) {
        avatarImage = NetworkImage(authState.avatarUrl!);
      } else {
        final file = File(authState.avatarUrl!);
        if (file.existsSync()) {
          avatarImage = FileImage(file);
        }
      }
    }

    return InkWell(
      onTap: isUnauthenticated ? () => _showLoginDialog(context) : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm, AppSpacing.xxl, AppSpacing.sm, AppSpacing.xl),
        width: double.infinity,
        child: Row(
          children: [
            // 头像
            CircleAvatar(
              radius: 36,
              backgroundColor: colors.surfaceSubtle,
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? Icon(
                      Icons.person_rounded,
                      size: 36,
                      color: colors.textMuted,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.lg),
            // 姓名与学号
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    !isUnauthenticated
                        ? (authState.realName ??
                            context.l10n.defaultStudentName)
                        : context.l10n.notLoggedIn,
                    style: AppText.pageTitle.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    !isUnauthenticated
                        ? (authState.username ?? '')
                        : context.l10n.clickToLogin,
                    style: AppText.caption.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            if (isUnauthenticated)
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor ?? colors.textMuted),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  title,
                  style: AppText.body.copyWith(
                    color: titleColor ?? colors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoginDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const LoginScreen(),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.logoutConfirmTitle),
        content: Text(context.l10n.logoutConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}
