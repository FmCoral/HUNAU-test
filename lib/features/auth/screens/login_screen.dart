import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/secure_storage_helper.dart';
import '../../../core/utils/l10n_extension.dart';
import 'package:logger/logger.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  /// 带有下往上淡入动画的路由
  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
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
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final Logger _logger = Logger();
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadStoredCredentials();
  }

  Future<void> _loadStoredCredentials() async {
    try {
      final storage = SecureStorageHelper();
      final username = await storage.getUsername();
      final password = await storage.getPassword();

      if (mounted && username != null && password != null) {
        setState(() {
          _usernameController.text = username;
          _passwordController.text = password;
        });
      }
    } catch (e) {
      _logger.e('Failed to load stored credentials: $e');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final c = context.colors;
    final isAuthenticating = authState.status == AuthStatus.authenticating;

    return PopScope(
      canPop: !isAuthenticating,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.bg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),
                  Center(
                    child: Text(
                      '一切尽在掌握',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 28 / 22,
                        letterSpacing: 6,
                        color: c.brandText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // 学号：标签在输入框上方
                  _FieldLabel(context.l10n.studentId),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _usernameController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    style: AppText.body.copyWith(color: c.text),
                    decoration: InputDecoration(
                      hintText: context.l10n.studentIdHint,
                      prefixIcon: Icon(Icons.person_outline,
                          size: 20, color: c.textMuted),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.l10n.studentIdHint;
                      }
                      return null;
                    },
                    enabled: !isAuthenticating,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 密码
                  _FieldLabel(context.l10n.password),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    style: AppText.body.copyWith(color: c.text),
                    onFieldSubmitted: (_) {
                      if (!isAuthenticating) _handleLogin();
                    },
                    decoration: InputDecoration(
                      hintText: context.l10n.passwordHint,
                      prefixIcon: Icon(Icons.lock_outline,
                          size: 20, color: c.textMuted),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: c.textMuted,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.l10n.passwordHint;
                      }
                      return null;
                    },
                    enabled: !isAuthenticating,
                  ),

                  // 错误信息：字段附近，文字说明原因
                  if (authState.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, size: 16, color: c.danger),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            authState.errorMessage!,
                            style: AppText.caption.copyWith(color: c.danger),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 40),

                  // 登录主按钮：深绿实心 + 白字 + 48 高
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isAuthenticating ? null : _handleLogin,
                      child: isAuthenticating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(context.l10n.loginButton),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      await ref.read(authStateProvider.notifier).login(username, password);

      // 登录成功后告知系统密码管理器保存/更新凭据
      TextInput.finishAutofillContext();

      // 登录成功后，如果是推入式路由则关闭当前页
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      // 错误已由 authStateProvider 处理
    }
  }
}

/// 输入框上方标签
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppText.bodyDense.copyWith(
        color: context.colors.text,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
