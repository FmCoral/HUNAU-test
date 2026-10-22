// Web 端：空操作，dio_cookie.CookieManager 在 Web 端会 assert 崩溃，跳过
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';

void attachCookieManager(Dio dio, CookieJar jar) {
  // BFF 会话由 HttpOnly cookie 管理，客户端无需 CookieManager 拦截器
}
