import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

// 复用 Flutter 项目已验证的 CAS 登录逻辑（纯 Dart，无 Flutter 依赖）
import '../../lib/core/constants/app_constants.dart';
import '../../lib/core/exceptions/app_exceptions.dart';
import '../../lib/features/auth/services/http_login_service.dart';

final _logger = Logger(printer: PrettyPrinter(methodCount: 0));
const _sessionTtl = Duration(hours: 2); // session 2 小时过期

// 内存 session 存储：sessionId -> _Session
final _sessions = <String, _Session>{};
final _uuid = Uuid();

class _Session {
  final String username;
  final HttpLoginResult result;
  final DateTime createdAt;
  DateTime lastAccessed;
  // 把 HttpLoginResult.cookies 扁平化成 String(name=value; ...) 形式
  final Map<String, String> cookieHeaderValues = {}; // origin -> Cookie header value

  _Session({
    required this.username,
    required this.result,
  })  : createdAt = DateTime.now(),
        lastAccessed = DateTime.now() {
    _flattenCookies();
  }

  void _flattenCookies() {
    for (final entry in result.cookies.entries) {
      final parts = <String>[];
      for (final c in entry.value) {
        if (!_isExpired(c)) {
          parts.add('${c.name}=${c.value}');
        }
      }
      if (parts.isNotEmpty) {
        final key = '${entry.key.scheme}://${entry.key.host}'
            '${entry.key.hasPort ? ':${entry.key.port}' : ''}';
        cookieHeaderValues[key] = parts.join('; ');
      }
    }
  }

  bool get isExpired => DateTime.now().difference(lastAccessed) > _sessionTtl;

  bool _isExpired(Cookie cookie) =>
      cookie.expires != null && !cookie.expires!.isAfter(DateTime.now());

  void touch() => lastAccessed = DateTime.now();
}

// ---------------------------------------------------------------------------
// CORS middleware（开发期允许任意 origin，支持 credentials）
// ---------------------------------------------------------------------------
Middleware _cors() => (Handler inner) => (Request request) async {
      final origin = request.headers['origin'] ?? '*';
      final headers = <String, String>{
        'Access-Control-Allow-Origin': origin,
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Cookie, Authorization',
        'Access-Control-Allow-Credentials': 'true',
        'Access-Control-Max-Age': '86400',
      };
      if (request.method == 'OPTIONS') {
        return Response(204, headers: headers);
      }
      final response = await inner(request);
      return response.change(headers: {...response.headers, ...headers});
    };

// ---------------------------------------------------------------------------
// Session helpers（cookie 名: chill_east_session）
// ---------------------------------------------------------------------------
String? _extractSessionId(Request request) {
  final raw = request.headers['cookie'];
  if (raw == null) return null;
  for (final part in raw.split(';')) {
    final trimmed = part.trim();
    if (trimmed.startsWith('chill_east_session=')) {
      return trimmed.substring('chill_east_session='.length);
    }
  }
  return null;
}

_Session? _lookupSession(Request request) {
  final id = _extractSessionId(request);
  if (id == null) return null;
  final s = _sessions[id];
  if (s == null || s.isExpired) {
    if (s != null) _sessions.remove(id);
    return null;
  }
  s.touch();
  return s;
}

String _buildSetCookie(String sessionId, {int? maxAgeSec}) {
  final buffer = StringBuffer('chill_east_session=$sessionId; ');
  if (maxAgeSec != null) {
    buffer.write('Max-Age=$maxAgeSec; ');
  }
  buffer.write('HttpOnly; Path=/; SameSite=Lax');
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// HTTP helpers
// ---------------------------------------------------------------------------
Response _json(int status, Object body, {Map<String, String>? headers}) {
  return Response(
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      if (headers != null) ...headers,
    },
    body: jsonEncode(body),
  );
}

Future<Response> _proxyRequest(_Session session, String targetUrl,
    String method, Map<String, String>? headers, Uint8List? body) async {
  final uri = Uri.parse(targetUrl);
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    // 从 session 里取出该 origin 的 cookie
    final originKey = '${uri.scheme}://${uri.host}'
        '${uri.hasPort ? ':${uri.port}' : ''}';
    final cookies = <String>[];
    // 先精确匹配 origin
    if (session.cookieHeaderValues.containsKey(originKey)) {
      cookies.add(session.cookieHeaderValues[originKey]!);
    }
    // 再尝试父域名匹配（如 portal.hunau.edu.cn 需要 hunau.edu.cn 的 cookie）
    for (final entry in session.cookieHeaderValues.entries) {
      final hostOfKey = Uri.parse(entry.key).host;
      if (hostOfKey != uri.host && uri.host.endsWith('.${hostOfKey}')) {
        cookies.add(entry.value);
      }
    }
    if (cookies.isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, cookies.join('; '));
    }
    // 转发请求头
    if (headers != null) {
      headers.forEach((key, value) {
        if (key.toLowerCase() != 'host' && key.toLowerCase() != 'cookie') {
          request.headers.set(key, value);
        }
      });
    }
    if (body != null) {
      request.contentLength = body.length;
      request.add(body);
    }
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    final responseHeaders = <String, String>{};
    response.headers.forEach((key, values) {
      if (key.toLowerCase() != 'set-cookie') {
        responseHeaders[key] = values.join(', ');
      }
    });
    // 把新收到的 cookie 也并入 session
    final newCookies = response.headers[HttpHeaders.setCookieHeader];
    if (newCookies != null && newCookies.isNotEmpty) {
      final parts = <String>[];
      if (session.cookieHeaderValues.containsKey(originKey)) {
        parts.add(session.cookieHeaderValues[originKey]!);
      }
      for (final raw in newCookies) {
        final cookie = Cookie.fromSetCookieValue(raw);
        if (!_isExpired(cookie)) {
          parts.add('${cookie.name}=${cookie.value}');
        }
      }
      if (parts.isNotEmpty) {
        session.cookieHeaderValues[originKey] = parts.join('; ');
      }
    }
    client.close();
    return Response(
      response.statusCode,
      headers: {
        'Content-Type': responseHeaders['content-type'] ??
            'text/html; charset=utf-8',
        ...responseHeaders,
      },
      body: responseBody,
    );
  } catch (e) {
    client.close();
    _logger.w('proxy error: $e');
    return _json(502, {'error': 'proxy_failed', 'message': e.toString()});
  }
}

bool _isExpired(Cookie cookie) =>
    cookie.expires != null && !cookie.expires!.isAfter(DateTime.now());

// ---------------------------------------------------------------------------
// 移动教务（njwhd）Token 获取 —— 服务端复刻 App 里 HeadlessWebView 的 OAuth 流程
// ---------------------------------------------------------------------------

const _browserUA =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// 取可注册主域（用于跨子域共享 cookie）
/// 例：passport2.chaoxing.com / auth.chaoxing.com → chaoxing.com
///     sso.hunau.edu.cn / portal.hunau.edu.cn → hunau.edu.cn
String _registrableDomain(String host) {
  final parts = host.split('.');
  if (parts.length <= 2) return host;
  const multiPartTlds = {'edu.cn', 'com.cn', 'net.cn', 'org.cn', 'gov.cn'};
  final lastTwo = parts.sublist(parts.length - 2).join('.');
  if (multiPartTlds.contains(lastTwo) && parts.length >= 3) {
    return parts.sublist(parts.length - 3).join('.');
  }
  return lastTwo;
}

const _ydjwxtOAuthUrl =
    'https://auth.chaoxing.com/connect/oauth2/authorize'
    '?appid=ccf57937af7e40dcbdef0523e05e5ddd'
    '&redirect_uri=https%3A%2F%2Fydjwxt.hunau.edu.cn%2Fnjwhd%2Flogin%2Foauth2'
    '%3FappId%3Dccf57937af7e40dcbdef0523e05e5ddd'
    '%26appKey%3D1D13d6neUcz6c20f'
    '%26uid%3D22073114'
    '%26fidEnc%3Da915b52ee0aa18ad'
    '%26mappId%3D6127153'
    '%26formid%3D'
    '&response_type=code&scope=snsapi_base&state=128516';

/// 跟随超星 OAuth 重定向链，从落地 URL 中取 code，
/// 再用这个 code 请求 njwhd 的 oauth2 接口换 JWT。
Future<Map<String, dynamic>> _acquireYdjwxtToken(_Session session) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  final steps = <Map<String, dynamic>>[];
  final jar = <String, Map<String, String>>{};

  // 用 session 里已存的 cookie 填充本地 jar
  for (final entry in session.cookieHeaderValues.entries) {
    final host = Uri.parse(entry.key).host;
    final bucket = jar.putIfAbsent(host, () => <String, String>{});
    for (final pair in entry.value.split('; ')) {
      final idx = pair.indexOf('=');
      if (idx > 0) bucket[pair.substring(0, idx)] = pair.substring(idx + 1);
    }
  }

  String cookieHeader(String host) {
    final parts = <String>[];
    final targetBase = _registrableDomain(host);
    jar.forEach((h, cookies) {
      final related = host == h ||
          host.endsWith('.$h') ||
          _registrableDomain(h) == targetBase;
      if (related) {
        cookies.forEach((k, v) => parts.add('$k=$v'));
      }
    });
    return parts.join('; ');
  }

  var current = Uri.parse(_ydjwxtOAuthUrl);
  String? code;
  var lastBody = '';
  var lastHeaders = <String, String>{};

  for (var hop = 0; hop < 12; hop++) {
    final request = await client.openUrl('GET', current);
    request.followRedirects = false;
    final ck = cookieHeader(current.host);
    if (ck.isNotEmpty) request.headers.set(HttpHeaders.cookieHeader, ck);
    request.headers.set(HttpHeaders.userAgentHeader, _browserUA);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    final headers = <String, String>{};
    response.headers.forEach((key, values) {
      headers[key] = values.join(', ');
    });
    final setCookies =
        response.headers[HttpHeaders.setCookieHeader] ?? const <String>[];
    for (final raw in setCookies) {
      try {
        final cookie = Cookie.fromSetCookieValue(raw);
        if (!_isExpired(cookie)) {
          jar.putIfAbsent(current.host, () => <String, String>{})[cookie.name] =
              cookie.value;
        }
      } catch (_) {}
    }

    final location = headers['location'];
    steps.add({
      'url': current.toString(),
      'status': response.statusCode,
      'location': location,
      'bodyLength': body.length,
      'bodyPreview': body.length > 300 ? body.substring(0, 300) : body,
    });
    lastBody = body;
    lastHeaders = headers;

    if (current.queryParameters['code'] != null) {
      code = current.queryParameters['code'];
    }
    if (location == null || location.isEmpty) break;
    current = current.resolve(location);
    if (current.queryParameters['code'] != null) {
      code = current.queryParameters['code'];
    }
  }

  client.close();

  final token = _extractToken(lastBody) ??
      _extractToken(lastHeaders['token'] ?? '') ??
      _extractToken(lastHeaders['authorization'] ?? '');

  return {
    'code': code,
    'token': token,
    'steps': steps,
    'lastBodyPreview':
        lastBody.length > 800 ? lastBody.substring(0, 800) : lastBody,
    'lastContentType': lastHeaders['content-type'],
  };
}

/// 从任意响应体里捞出 JWT / token 字段
String? _extractToken(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final jwt = RegExp(
    r'eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}',
  ).firstMatch(text);
  if (jwt != null) return jwt.group(0);
  try {
    return _deepFindToken(jsonDecode(text));
  } catch (_) {
    return null;
  }
}

String? _deepFindToken(Object? node) {
  if (node is String) return _extractToken(node);
  if (node is Map) {
    for (final entry in node.entries) {
      final key = entry.key.toString().toLowerCase();
      if (key == 'token' || key == 'access_token' || key == 'accesstoken') {
        final value = entry.value;
        if (value is String && value.isNotEmpty) return value;
      }
      final found = _deepFindToken(entry.value);
      if (found != null) return found;
    }
    return null;
  }
  if (node is List) {
    for (final item in node) {
      final found = _deepFindToken(item);
      if (found != null) return found;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------
Router _createRouter() {
  final router = Router();

  router.get('/health', (Request request) {
    final debug = request.url.queryParameters['debug'] == '1';
    return _json(200, {
      'status': 'ok',
      'sessions': _sessions.length,
      if (debug) 'sessionIds': _sessions.keys.toList(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  });

  // 移动教务 Token：Web 端替代 HeadlessWebView 的 OAuth
  router.get('/api/ydjwxt/token', (Request request) async {
    final id = _extractSessionId(request);
    final session = id != null ? _sessions[id] : null;
    if (session == null) {
      return _json(401, {'error': 'no_session'});
    }
    session.lastAccessed = DateTime.now();
    try {
      final result = await _acquireYdjwxtToken(session);
      final token = result['token'] as String?;
      _logger.i(
          'ydjwxt token: code=${result['code'] != null} token=${token != null}');
      return _json(200, {
        'ok': token != null,
        'token': token,
        'code': result['code'],
        'steps': result['steps'],
        'lastBodyPreview': result['lastBodyPreview'],
      });
    } catch (e) {
      _logger.e('ydjwxt token error: $e');
      return _json(500, {'error': 'token_failed', 'message': e.toString()});
    }
  });

  // 调试：查看当前 session 里各域名持有的 cookie 名称（不含值）
  router.get('/api/debug/cookies', (Request request) {
    final id = _extractSessionId(request);
    final session = id != null ? _sessions[id] : null;
    if (session == null) return _json(401, {'error': 'no_session'});
    final origins = <String, List<String>>{};
    session.cookieHeaderValues.forEach((origin, value) {
      origins[origin] = value
          .split('; ')
          .map((pair) => pair.split('=').first)
          .toList(growable: false);
    });
    return _json(200, {'count': origins.length, 'origins': origins});
  });

  router.post('/api/login', (Request request) async {
    late final Map<String, dynamic> body;
    try {
      final raw = await request.readAsString();
      body = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      return _json(400, {'error': 'bad_request', 'message': '需要 JSON body'});
    }
    final username = body['username']?.toString() ?? '';
    final password = body['password']?.toString() ?? '';
    if (username.isEmpty || password.isEmpty) {
      return _json(400, {'error': 'missing_credentials'});
    }

    final service = HttpLoginService(
      onProgress: (m) => _logger.d('login: $m'),
    );
    try {
      final result = await service.login(username, password);
      final sessionId = _uuid.v4();
      final session = _Session(username: username, result: result);
      _sessions[sessionId] = session;
      _cleanupExpiredSessions();
      _logger.i('login ok user=$username session=$sessionId');
      final response = _json(200, {
        'ok': true,
        'username': username,
        'profile': result.profile != null
            ? {
                'realName': result.profile!.realName,
                'username': result.profile!.username,
              }
            : null,
      });
      return response.change(headers: {
        'Set-Cookie': _buildSetCookie(
          sessionId,
          maxAgeSec: _sessionTtl.inSeconds,
        ),
      });
    } on AppException catch (e) {
      _logger.w('login failed user=$username: ${e.message}');
      return _json(401, {'error': 'auth_failed', 'message': e.message});
    } catch (e) {
      _logger.e('login crash: $e');
      return _json(500, {'error': 'server_error', 'message': '登录服务异常'});
    }
  });

  router.get('/api/me', (Request request) async {
    final session = _lookupSession(request);
    if (session == null) {
      return _json(401, {'error': 'no_session'});
    }
    // 轻量验证：尝试请求 portal index，看 cookie 是否已被踢下线
    final portalIndex = Uri.parse(AppConstants.portalIndexUrl);
    final client = HttpClient();
    try {
      final req = await client.openUrl('GET', portalIndex);
      final cookies = session.cookieHeaderValues.values.join('; ');
      if (cookies.isNotEmpty) {
        req.headers.set(HttpHeaders.cookieHeader, cookies);
      }
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      client.close();
      // 检查是否已被踢到 cas/login
      if (resp.statusCode >= 300 &&
          resp.redirects.isNotEmpty &&
          resp.redirects.last.location.path.contains('/cas/login')) {
        _sessions.remove(_extractSessionId(request)!);
        return _json(401, {'error': 'session_expired'});
      }
      final hasLoggedInHtml = body.contains('menuLeft') ||
          body.contains('portal') ||
          !body.contains('CIMS.init');
      return _json(200, {
        'ok': true,
        'username': session.username,
        'authenticated': hasLoggedInHtml,
      });
    } catch (e) {
      client.close();
      return _json(502, {'error': 'verify_failed', 'message': e.toString()});
    }
  });

  router.get('/api/proxy', (Request request) async {
    final session = _lookupSession(request);
    if (session == null) {
      return _json(401, {'error': 'no_session'});
    }
    final target = request.url.queryParameters['url'];
    if (target == null || target.isEmpty) {
      return _json(400, {'error': 'missing_url'});
    }
    final targetUri = Uri.tryParse(target);
    if (targetUri == null ||
        !['http', 'https'].contains(targetUri.scheme) ||
        targetUri.host.isEmpty) {
      return _json(400, {'error': 'invalid_url'});
    }
    // 安全限制：只允许请求 hunau.edu.cn 或 chaoxing.com 的子域名
    final host = targetUri.host.toLowerCase();
    final allowed = RegExp(
      r'(?:\.hunau\.edu\.cn$|\.chaoxing\.com$|hunau\.edu\.cn$|chaoxing\.com$|^localhost$)',
    );
    if (!allowed.hasMatch(host)) {
      return _json(403, {'error': 'forbidden_host', 'host': host});
    }
    return _proxyRequest(
      session,
      target,
      'GET',
      request.headers,
      null,
    );
  });

  router.post('/api/proxy', (Request request) async {
    final session = _lookupSession(request);
    if (session == null) {
      return _json(401, {'error': 'no_session'});
    }
    final target = request.url.queryParameters['url'];
    if (target == null || target.isEmpty) {
      return _json(400, {'error': 'missing_url'});
    }
    final bodyBytes = Uint8List.fromList(await request.read().expand((e) => e).toList());
    return _proxyRequest(
      session,
      target,
      'POST',
      request.headers,
      bodyBytes,
    );
  });

  router.post('/api/logout', (Request request) async {
    final id = _extractSessionId(request);
    if (id != null) _sessions.remove(id);
    final response = _json(200, {'ok': true});
    return response.change(headers: {
      'Set-Cookie': _buildSetCookie(id ?? '', maxAgeSec: -1),
    });
  });

  return router;
}

void _cleanupExpiredSessions() {
  final now = DateTime.now();
  _sessions.removeWhere((_, s) => now.difference(s.lastAccessed) > _sessionTtl);
}

// ---------------------------------------------------------------------------
void main() async {
  final port = int.tryParse(Platform.environment['BFF_PORT'] ?? '3000') ?? 3000;
  final ip = Platform.environment['BFF_HOST'] ?? 'localhost';

  final handler = const Pipeline().addMiddleware(_cors()).addHandler(_createRouter().call);
  await shelf_io.serve(handler, ip, port);
  _logger.i('🛰️  ChillEast BFF listening on http://$ip:$port');

  // 定期清理过期 session（每 5 分钟）
  Timer.periodic(const Duration(minutes: 5), (_) => _cleanupExpiredSessions());
}
