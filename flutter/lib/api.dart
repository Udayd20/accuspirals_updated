import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thrown when the backend returns 401 (missing / expired / invalid token).
/// The app listens for this to bounce the user back to the login screen,
/// mirroring the web app's on401() -> doLogout() behaviour.
class UnauthorizedException implements Exception {
  final String path;
  UnauthorizedException(this.path);
  @override
  String toString() => 'Unauthorized ($path)';
}

/// Talks to the NestJS API. Every non-login call carries the Bearer token.
///
/// SET THE SERVER ADDRESS HERE:
///   • Desktop / Flutter-web / iOS simulator .... http://localhost:3000/api
///   • Android emulator .......................... http://10.0.2.2:3000/api
///   • Physical device on the LAN ................ http://<PC-LAN-IP>:3000/api
class Api {
  static String base = 'http://localhost:3000/api';

  /// Current auth token. Set by [login]/session restore, cleared on logout.
  static String? token;

  /// Optional hook fired whenever a 401 comes back, so the UI can log out.
  static void Function()? onUnauthorized;

  static Map<String, String> _headers([Map<String, String>? extra]) {
    final h = <String, String>{...?extra};
    if (token != null && token!.isNotEmpty) h['Authorization'] = 'Bearer $token';
    return h;
  }

  static Never _fail(String verb, String path, int code) {
    if (code == 401) {
      onUnauthorized?.call();
      throw UnauthorizedException(path);
    }
    throw Exception('$verb $path failed: $code');
  }

  static Future<dynamic> _get(String path) async {
    final r = await http.get(Uri.parse('$base$path'), headers: _headers());
    if (r.statusCode >= 400) _fail('GET', path, r.statusCode);
    return r.body.isEmpty ? null : jsonDecode(r.body);
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final r = await http.post(Uri.parse('$base$path'),
        headers: _headers({'Content-Type': 'application/json'}), body: jsonEncode(body));
    if (r.statusCode >= 400) _fail('POST', path, r.statusCode);
    return r.body.isEmpty ? null : jsonDecode(r.body);
  }

  static Future<dynamic> _delete(String path) async {
    final r = await http.delete(Uri.parse('$base$path'), headers: _headers());
    if (r.statusCode >= 400) _fail('DELETE', path, r.statusCode);
    return r.body.isEmpty ? null : jsonDecode(r.body);
  }

  // ---- auth (public endpoint; no token required) ----
  static Future<Map<String, dynamic>> login(String userId, String password) async {
    final r = await http.post(Uri.parse('$base/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'password': password}));
    if (r.statusCode >= 500) throw Exception('Server error ${r.statusCode}');
    final body = r.body.isEmpty ? {'ok': false} : jsonDecode(r.body);
    return Map<String, dynamic>.from(body as Map);
  }

  // ---- catalog ----
  static Future<List<dynamic>> families() async => (await _get('/families') as List?) ?? [];

  // ---- tools / stock ----
  static Future<Map<String, dynamic>> tools({String? q, String? status, String? category}) async {
    final params = <String, String>{};
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (category != null && category.isNotEmpty) params['category'] = category;
    final qs = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    return Map<String, dynamic>.from(await _get('/tools$qs') as Map);
  }

  static Future<Map<String, dynamic>> toolDetail(String code) async =>
      Map<String, dynamic>.from(await _get('/tools/$code') as Map);
  static Future addTool(Map<String, dynamic> dto) => _post('/tools', dto);
  static Future issue(String code, Map<String, dynamic> dto) => _post('/tools/$code/issue', dto);
  static Future returnTool(String code, Map<String, dynamic> dto) => _post('/tools/$code/return', dto);
  static Future<List<dynamic>> regrindJobs() async => (await _get('/tools/regrind/jobs') as List?) ?? [];
  static Future regrindReceive(String code, bool pass) => _post('/tools/$code/regrind/receive', {'pass': pass});
  static Future deleteTool(String code) => _delete('/tools/$code');

  // ---- receiving ----
  static Future gate(Map<String, dynamic> dto) => _post('/gate', dto);
  static Future<List<dynamic>> qc() async => (await _get('/qc') as List?) ?? [];
  static Future qcAccept(int id, Map<String, dynamic> dto) => _post('/qc/$id/accept', dto);
  static Future qcReject(int id) => _post('/qc/$id/reject', {});
  static Future qcUpdate(int id, Map<String, dynamic> dto) => _post('/qc/$id/update', dto);

  // ---- dashboard / reports / events ----
  static Future<Map<String, dynamic>> dashboard() async => Map<String, dynamic>.from(await _get('/dashboard') as Map);
  static Future<Map<String, dynamic>> reports() async => Map<String, dynamic>.from(await _get('/reports') as Map);
  static Future<List<dynamic>> events() async => (await _get('/events') as List?) ?? [];

  // ---- admin: master data ----
  static Future<List<dynamic>> master([String? kind]) async =>
      (await _get('/admin/master${kind != null ? '/$kind' : ''}') as List?) ?? [];
  static Future addMaster(String kind, String value) => _post('/admin/master', {'kind': kind, 'value': value});
  static Future delMaster(int id) => _delete('/admin/master/$id');

  // ---- admin: users ----
  static Future<List<dynamic>> users() async => (await _get('/admin/users') as List?) ?? [];
  static Future addUser(Map<String, dynamic> dto) => _post('/admin/users', dto);
  static Future resetUser(int id, String password) => _post('/admin/users/$id/reset', {'password': password});
  static Future delUser(int id) => _delete('/admin/users/$id');

  // ---- admin: categories ----
  static Future addCategory(Map<String, dynamic> dto) => _post('/admin/categories', dto);

  // ---- admin: permissions ----
  static Future<List<dynamic>> permissions() async => (await _get('/admin/permissions') as List?) ?? [];
  static Future setPermissions(String role, List<String> screens) =>
      _post('/admin/permissions', {'role': role, 'screens': screens});

  // ---- admin: spec fields ----
  static Future<List<dynamic>> specFields() async => (await _get('/admin/spec-fields') as List?) ?? [];
  static Future addSpecField(Map<String, dynamic> dto) => _post('/admin/spec-fields', dto);
  static Future delSpecField(int id) => _delete('/admin/spec-fields/$id');
}
