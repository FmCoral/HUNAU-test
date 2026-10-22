import 'package:flutter/material.dart';
import '../widgets/download_timetable_screen.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_extension.dart';

class TimetableSyncPromptScreen extends StatelessWidget {
  final VoidCallback? onSkip;
  const TimetableSyncPromptScreen({super.key, this.onSkip});

  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const TimetableSyncPromptScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.1); 
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        
        var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
        var fadeAnimation = animation.drive(fadeTween);

        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: offsetAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textMuted),
          onPressed: () {
            if (onSkip != null) {
              onSkip!();
            } else {
              Navigator.maybePop(context);
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xxl),
            Text(
              context.l10n.fetchTimetable,
              style: AppText.pageTitle.copyWith(
                fontSize: 28,
                color: colors.text,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.syncTimetablePrompt,
              style: AppText.bodyDense.copyWith(color: colors.textMuted, height: 1.5),
              textAlign: TextAlign.left,
            ),

            const Spacer(),

            // 底部操作按钮 (右对齐)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      if (onSkip != null) {
                        onSkip!();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(context.l10n.skip, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // 1. 跳转到导入详情页
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DownloadTimetableScreen()),
                      );

                      // 2. 如果导入成功 (返回了 true)
                      if (result == true) {
                        if (onSkip != null) {
                          onSkip!(); // 触发 Root Switcher 切换到主界面
                        } else if (context.mounted) {
                          Navigator.pop(context); // 兜底：直接关闭当前页
                        }
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(context.l10n.syncNow),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
