// 原生（Android/iOS/Desktop）端：添加 dio_cookie.CookieManager 拦截器
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

void attachCookieManager(Dio dio, CookieJar jar) {
  dio.interceptors.add(CookieManager(jar));
}
