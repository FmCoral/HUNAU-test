// Web 端 InAppWebView stub：提供 CookieManager.instance() 占位，让编译通过
// 运行时 Web 端不真正调用 WebView 方法（BFF 会话由 HttpOnly cookie 管理）。
class CookieManager {
  static CookieManager get instance => _singleton;
  static final CookieManager _singleton = CookieManager._();
  CookieManager._();
}

// WebUri 占位
class WebUri {
  final String uri;
  WebUri(this.uri);
}

// HTTPCookieSameSitePolicy 占位（只用在非 Web 分支）
class HTTPCookieSameSitePolicy {
  const HTTPCookieSameSitePolicy._();
  static const LAX = HTTPCookieSameSitePolicy._();
  static const STRICT = HTTPCookieSameSitePolicy._();
  static const NONE = HTTPCookieSameSitePolicy._();
}

// InAppWebViewController 占位（Web 端 clearAllCache 不会被调用，有 kIsWeb 守卫）
class InAppWebViewController {
  static Future<void> clearAllCache({bool includeDiskFiles = true}) async {}
}

// WebStorageManager 占位（原代码用 WebStorageManager.instance() 工厂方法调用）
class WebStorageManager {
  static WebStorageManager instance() => _singleton;
  static final WebStorageManager _singleton = WebStorageManager._();
  WebStorageManager._();
  Future<void> deleteAllData() async {}
}
