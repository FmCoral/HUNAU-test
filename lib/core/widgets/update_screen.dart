import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../theme/app_tokens.dart';
import '../utils/l10n_extension.dart';

class UpdateScreen extends StatelessWidget {
  final String version;
  final String releaseNotes;
  final String downloadUrl;

  const UpdateScreen({
    super.key,
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 纯图标，左对齐
                  Icon(
                    Icons.system_update_rounded,
                    size: 38,
                    color: colors.brand,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 发现新版本标题，左对齐
                  Text(
                    context.l10n.foundNewVersion(version),
                    style: AppText.keyNumber.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 更新日志标题
                  Text(
                    context.l10n.releaseNotes,
                    style: AppText.sectionTitle.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 更新日志直接展示，不加外框，支持 Markdown 渲染
                  MarkdownBody(
                    data: releaseNotes,
                    selectable: true,
                    shrinkWrap: true,
                    onTapLink: (text, href, title) async {
                      if (href != null) {
                        final Uri uri = Uri.parse(href);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: colors.text,
                      ),
                      h1: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                      h2: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                      h3: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                      listBullet: TextStyle(
                        fontSize: 14,
                        color: colors.textMuted,
                      ),
                      a: TextStyle(
                        color: colors.brand,
                        decoration: TextDecoration.underline,
                      ),
                      code: TextStyle(
                        fontSize: 12.5,
                        backgroundColor: colors.surfaceSubtle,
                        color: colors.brand,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 底部操作栏：右对齐，去掉“以后再说”
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final route = ModalRoute.of(context);
                    await UpdateService().startDownload(context, downloadUrl, version);
                    if (route != null && nav.mounted) {
                      nav.removeRoute(route);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: 12),
                  ),
                  child: Text(context.l10n.updateNow),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
