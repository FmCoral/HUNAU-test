// 原生（Android/iOS/Desktop）端：复用现有 HttpLoginService（直连学校服务器）
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../features/auth/services/http_login_service.dart';

/// 执行登录，返回需要持久化的 cookies（原生端直接保存到 CookieJar）
Future<HttpLoginResult> doLoginViaBackend(String username, String password) async {
  final service = HttpLoginService(
    onProgress: (_) {}, // 原生端已有进度回调，这里不额外处理
  );
  return service.login(username, password);
}
