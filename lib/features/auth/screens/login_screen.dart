import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/auth_state.dart';
import '../providers/auth_provider.dart';
import '../../../core/utils/secure_storage_helper.dart';
import '../../timetable/screens/timetable_sync_prompt_screen.dart';
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
    final theme = Theme.of(context);

    // 标准 MD2 输入框装饰样式
    InputDecoration md2InputDecoration(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF5F6368), 
        fontWeight: FontWeight.w400, 
        fontSize: 14
      ),
      floatingLabelStyle: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      prefixIcon: Icon(icon, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : const Color(0xFFDADCE0), 
          width: 1
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : const Color(0xFFDADCE0), 
          width: 1
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: theme.primaryColor, width: 2),
      ),
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.white,
    );

    final isAuthenticating = authState.status == AuthStatus.authenticating;

    return PopScope(
      canPop: !isAuthenticating,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              const SizedBox(height: 56),
              
              // 用户名输入框
              TextFormField(
                controller: _usernameController,
                decoration: md2InputDecoration(context.l10n.studentId, Icons.person_outline),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: (value) {
                  if (value == null || value.isEmpty) return context.l10n.studentIdHint;
                  return null;
                },
                enabled: authState.status != AuthStatus.authenticating,
              ),
              const SizedBox(height: 24),
              
              // 密码输入框
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) {
                  if (authState.status != AuthStatus.authenticating) {
                    _handleLogin();
                  }
                },
                decoration: md2InputDecoration(context.l10n.password, Icons.lock_outline).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return context.l10n.passwordHint;
                  return null;
                },
                enabled: authState.status != AuthStatus.authenticating,
              ),
              
              const SizedBox(height: 12),
              if (authState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    authState.errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              
              const SizedBox(height: 40),

              // 登录按钮（通栏，位于输入框下方）
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: authState.status == AuthStatus.authenticating ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: theme.primaryColor.withOpacity(0.12),
                    disabledForegroundColor: theme.primaryColor.withOpacity(0.38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    elevation: 0,
                  ),
                  child: authState.status == AuthStatus.authenticating
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.primaryColor,
                          ),
                        )
                      : Text(
                          context.l10n.loginButton,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 24),
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
