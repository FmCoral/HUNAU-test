import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/network/dio_client.dart';
import 'core/theme/app_theme.dart';
import 'features/home/screens/main_scaffold.dart';
import 'features/auth/screens/login_screen.dart';
import 'core/state/auth_state.dart';
import 'core/services/notification_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/app_navigator.dart';
import 'core/services/background_worker.dart';
import 'core/services/live_scheduler.dart';
import 'core/services/update_service.dart';
import 'core/services/webview_cache_service.dart';
import 'core/state/locale_provider.dart';
import 'core/utils/l10n_extension.dart';
import 'core/utils/fallback_localizations_delegate.dart';
import 'l10n/app_localizations.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Web 端跳过原生 splash：FlutterNativeSplash 会尝试执行 JS 命令抛 PlatformException
  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  }

  if (!kIsWeb && Platform.isAndroid) {
    final ImagePickerPlatform picker = ImagePickerPlatform.instance;
    if (picker is ImagePickerAndroid) {
      picker.useAndroidPhotoPicker = true;
    }
  }

  // Only keep the lightweight dependencies needed before the first frame.
  await Future.wait([
    initializeDateFormatting('zh_CN', null),
    initializeDateFormatting('en', null),
    initializeDateFormatting('ja', null),
    initializeDateFormatting('es', null),
    initializeDateFormatting('fr', null),
    initializeDateFormatting('pt', null),
    initializeDateFormatting('ru', null),
  ]);
  try {
    await DioClient().initialize().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('⚠️ Network initialization failed: $e');
  }

  runApp(const ProviderScope(child: LiveHunauApp()));

  // These plugins are not required to render or authenticate. Initializing
  // them after runApp removes their platform-channel work from the splash.
  unawaited(_initializeAfterFirstFrame());
}

Future<void> _initializeAfterFirstFrame() async {
  await Future.wait([
    _initializeBackgroundWorker(),
    _initializeNotifications(),
  ]);
  // 自动清理历史 APK 安装包，释放存储空间
  unawaited(UpdateService.cleanHistoricalApks());
  // 自动轻量维护并清理 WebView 磁盘缓存
  unawaited(WebViewCacheService.autoPruneCacheOnStartup());
  // 匿名活跃度打点（每次启动在用户同意下向 analysis.hunau.fmcoral.com 叮一下）
  unawaited(AnalyticsService.ping());
  // 实时卡：前台 tick + 原生闹钟编排（内部自带 try/catch，不阻塞启动）
  try {
    LiveScheduler().start();
  } catch (e) {
    debugPrint('⚠️ LiveScheduler start failed: $e');
  }
  try {
    await BackgroundWorker.ensurePeriodicReschedule()
        .timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('⚠️ Workmanager register failed: $e');
  }
}

Future<void> _initializeBackgroundWorker() async {
  try {
    await BackgroundWorker.initialize().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('⚠️ Workmanager initialization failed: $e');
  }
}

Future<void> _initializeNotifications() async {
  try {
    await NotificationService().init().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('⚠️ Notification initialization failed: $e');
  }
}

class LiveHunauApp extends ConsumerWidget {
  const LiveHunauApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      navigatorKey: AppNavigator.navigatorKey,
      title: 'ChillEast',
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Builder(
        builder: (context) => Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: _buildHome(context, ref, authState),
          ),
        ),
      ),
    );
  }

  Widget _buildHome(BuildContext context, WidgetRef ref, AuthState authState) {
    if (!authState.isInitialized && authState.status == AuthStatus.authenticating) {
      return const _SplashTransition();
    }

    if (!authState.hasAccount) {
      return const LoginScreen(key: ValueKey('login'));
    }

    return const MainScaffold(key: ValueKey('main'));
  }
}

/// Native splash 移除后、主界面渲染前的丝滑过渡页。
/// 小牛 logo 淡入 + 轻微缩放，背景渐变和原生 splash 一致。
class _SplashTransition extends StatefulWidget {
  const _SplashTransition();

  @override
  State<_SplashTransition> createState() => _SplashTransitionState();
}

class _SplashTransitionState extends State<_SplashTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5CE9A0),
            Color(0xFF0A8B7C),
          ],
        ),
      ),
      child: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/app_icon.png',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 20),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
