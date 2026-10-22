import 'package:dio/dio.dart';

/// Web 端专用拦截器：把所有跨域请求改写成本机 BFF 代理请求。
/// 浏览器的 fetch API 无法直接跨域请求 hunau.edu.cn（无 CORS 头），
/// 必须走 BFF（localhost:3000）转发。BFF 返回的 HttpOnly session cookie
/// 由浏览器自动附带，Flutter 端无感知。
class BffProxyInterceptor extends Interceptor {
  static const _bffBase = 'http://localhost:3000';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final originalUrl = options.uri.toString();
    // 不要代理 BFF 自己的请求（登录接口本身）
    if (originalUrl.startsWith('$_bffBase/')) {
      handler.next(options);
      return;
    }
    // 改写为 BFF 代理格式：GET 目标 → GET /api/proxy?url=<encoded>
    final proxyPath = '/api/proxy?url=${Uri.encodeComponent(originalUrl)}';
    options.baseUrl = '';
    options.path = proxyPath;
    options.queryParameters = {}; // 已编码进 url 参数，清空避免重复拼接
    // 透传必要请求头（Cookie 由浏览器自动附带，不需要手动加）
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // BFF 断开时给个更清晰的提示
    final msg = err.message ?? '';
    if (msg.contains('Connection refused') || msg.contains('Failed host lookup')) {
      err.copyWith(message: '$msg（未检测到 ChillEast BFF，请先启动 bff/bin/server.dart）');
    }
    handler.next(err);
  }
}
