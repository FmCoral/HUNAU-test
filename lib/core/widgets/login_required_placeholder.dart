import 'package:flutter/material.dart';
import '../../features/auth/screens/login_screen.dart';
import '../theme/app_tokens.dart';
import '../utils/l10n_extension.dart';

class LoginRequiredPlaceholder extends StatelessWidget {
  final String? title;
  final String? message;
  final IconData icon;
  final EdgeInsetsGeometry padding;

  const LoginRequiredPlaceholder({
    super.key,
    this.title,
    this.message,
    this.icon = Icons.lock_person_outlined,
    this.padding = const EdgeInsets.all(32.0),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final displayTitle = title ?? context.l10n.loginRequiredTitle;
    final displayMessage = message ?? context.l10n.loginRequiredMessage;

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.statusBg(c.brand),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: c.brand),
            ),
            const SizedBox(height: 32),
            Text(
              displayTitle,
              textAlign: TextAlign.center,
              style: AppText.pageTitle.copyWith(color: c.text),
            ),
            const SizedBox(height: 12),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: AppText.bodyDense.copyWith(color: c.textMuted, height: 1.5),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, LoginScreen.route());
                },
                icon: const Icon(Icons.login_rounded, size: 20),
                label: Text(context.l10n.loginButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
