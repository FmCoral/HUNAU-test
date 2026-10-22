import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/route_utils.dart';
import '../../../core/services/update_service.dart';
import '../../../core/utils/l10n_extension.dart';
import 'oss_licenses_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo - 圆角矩形 + 固定大小 (80x80)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: AppRadius.cardAll,
                border: Border.all(color: colors.border),
                image: DecorationImage(
                  image: AssetImage(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/images/logo_dark.png'
                        : 'assets/images/logo.png',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // 应用名称
            Text(
              context.l10n.appTitle,
              style: AppText.pageTitle.copyWith(color: colors.text),
            ),

            // 版本号
            const SizedBox(height: AppSpacing.xs),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final versionStr = snapshot.hasData ? snapshot.data!.version : '2';
                return Text(
                  'Version $versionStr',
                  style: AppText.caption.copyWith(color: colors.textMuted),
                );
              },
            ),

            const SizedBox(height: AppSpacing.xxl),

            // 列表项分组卡片
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadius.cardAll,
                border: Border.all(color: colors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildAboutItem(
                    context,
                    title: context.l10n.visitWebsite,
                    onTap: () async {
                      final Uri url = Uri.parse('https://mou.hunau.fmcoral.com');
                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('无法打开 $url')),
                          );
                        }
                      }
                    },
                  ),
                  Divider(height: 1, color: colors.border),
                  _buildAboutItem(
                    context,
                    title: context.l10n.checkUpdate,
                    onTap: () => UpdateService().checkUpdate(context, showNoUpdate: true),
                  ),
                  Divider(height: 1, color: colors.border),
                  _buildAboutItem(
                    context,
                    title: context.l10n.openSourceLicenses,
                    onTap: () {
                      Navigator.push(
                        context,
                        createSlideUpRoute(const OssLicensesScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutItem(
    BuildContext context, {
    required String title,
    required VoidCallback onTap,
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
              Expanded(
                child: Text(
                  title,
                  style: AppText.body.copyWith(color: colors.text),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
