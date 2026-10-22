// Web 端：登录请求走 BFF /api/login，由 BFF 直连学校服务器解决 CORS
import 'package:dio/dio.dart';

import '../../../core/exceptions/app_exceptions.dart';

const _bffBase = 'http://localhost:3000';

/// Web 端登录：POST BFF /api/login，浏览器自动带上返回的 HttpOnly session cookie
/// 返回成功的用户信息（原生端返回 HttpLoginResult，但 Web 端由 BFF 管理 session）
Future<Map<String, dynamic>> doLoginViaBackend(String username, String password) async {
  final dio = Dio(BaseOptions(
    baseUrl: _bffBase,
    connectTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    // 不要被 BffProxyInterceptor 改写：baseUrl 已经是 localhost，
    // 但我们显式请求 BFF 的 /api/login 接口，Interceptor 应该跳过
    validateStatus: (status) => status != null && status < 500,
  ));
  try {
    final response = await dio.post<Map<String, dynamic>>(
      '/api/login',
      data: {'username': username, 'password': password},
      options: Options(contentType: 'application/json'),
    );
    final body = response.data ?? {};
    if (response.statusCode == 401) {
      throw AuthException(body['message']?.toString() ?? '账号或密码错误');
    }
    if (response.statusCode != 200 || body['ok'] != true) {
      throw AuthException(body['message']?.toString() ?? '登录失败');
    }
    return body;
  } on DioException catch (e) {
    final msg = e.message ?? '';
    if (msg.contains('Connection refused')) {
      throw const AuthException('未检测到 ChillEast BFF 服务，请先启动 bff/bin/server.dart');
    }
    throw AuthException('登录网络错误：$msg');
  } finally {
    dio.close(force: true);
  }
}
