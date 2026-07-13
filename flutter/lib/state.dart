import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

/// Fallback screen access by role, used only when the login response doesn't
/// carry an explicit `screens` list. Mirrors ROLE_ACCESS in the web app.
const roleAccess = <String, List<String>>{
  'Gate staff': ['gate'],
  'Inventory staff': ['qc', 'tools', 'detail', 'issue', 'return', 'regrind'],
  'Admin': ['dash', 'gate', 'qc', 'tools', 'detail', 'issue', 'return', 'regrind', 'reports', 'admin'],
};

/// Screen order + titles/crumbs/sheet numbers (matches TITLES in the web app).
const screenOrder = ['dash', 'gate', 'qc', 'tools', 'detail', 'issue', 'return', 'regrind', 'reports', 'admin'];
const screenTitles = <String, List<String>>{
  'dash': ['Dashboard', 'HOME / DASHBOARD'],
  'gate': ['Gate Entry', 'RECEIVING / GATE ENTRY'],
  'qc': ['Pending Inventory QC', 'RECEIVING / INVENTORY QC'],
  'tools': ['Tools & Consumables', 'INVENTORY / TOOLS'],
  'detail': ['Tool Details', 'INVENTORY / TOOL DETAILS'],
  'issue': ['Issue', 'MOVEMENT / ISSUE'],
  'return': ['Return', 'MOVEMENT / RETURN'],
  'regrind': ['Regrinding / Repair', 'MOVEMENT / REGRIND'],
  'reports': ['Reports', 'MANAGEMENT / REPORTS'],
  'admin': ['Admin', 'MANAGEMENT / ADMIN'],
};

const conds = ['Good', 'Minor damage', 'Damaged'];
const qcDecisions = ['Pass', 'Hold', 'Reject'];
const trackings = ['individual', 'quantity', 'batch'];
const roles = ['Admin', 'Gate staff', 'Inventory staff'];

// =================================================================== SESSION
class Session extends ChangeNotifier {
  String? id, name, role;
  List<String>? screens;
  String? token;

  bool get loggedIn => id != null && token != null;

  List<String> allowedScreens() {
    if (screens != null && screens!.isNotEmpty) return screens!;
    return roleAccess[role] ?? ['dash'];
  }

  String get userChip =>
      loggedIn ? '${id ?? ''}${name != null && name!.isNotEmpty ? ' · $name' : ''} · $role' : '—';

  Future<String?> login(String userId, String password) async {
    Map<String, dynamic> res;
    try {
      res = await Api.login(userId, password);
    } catch (e) {
      return 'Cannot reach server — is the backend running?';
    }
    if (res['ok'] != true) return (res['error'] as String?) ?? 'Invalid employee ID or password';
    final u = Map<String, dynamic>.from(res['user'] as Map);
    id = u['id'] as String?;
    name = u['name'] as String?;
    role = u['role'] as String?;
    screens = (u['screens'] is List) ? List<String>.from(u['screens']) : null;
    token = res['token'] as String?;
    Api.token = token;
    await _persist();
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    id = name = role = token = null;
    screens = null;
    Api.token = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('accuspiralsSession');
    notifyListeners();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('accuspiralsSession',
        jsonEncode({'id': id, 'name': name, 'role': role, 'screens': screens, 'token': token}));
  }

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('accuspiralsSession');
    if (raw == null) return;
    try {
      final d = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      id = d['id'] as String?;
      name = d['name'] as String?;
      role = d['role'] as String?;
      screens = (d['screens'] is List) ? List<String>.from(d['screens']) : null;
      token = d['token'] as String?;
      Api.token = token;
    } catch (_) {}
    notifyListeners();
  }
}

// ================================================================== APP DATA
class AppData extends ChangeNotifier {
  // taxonomy
  final Map<String, List<String>> cats = {}; // "Family ▸ Sub" -> [prefix, tracking]
  final Map<String, Map<String, dynamic>> families = {}; // name -> {prefix, subtypes, fields, subFields}

  // master data lists
  final Map<String, List<String>> master = {
    'units': [], 'machines': [], 'employees': [], 'suppliers': [], 'locations': []
  };

  // inventory (normalised maps, keys match the web app's mapTool/mapStock/...)
  List<Map<String, dynamic>> tools = [];
  List<Map<String, dynamic>> stock = [];
  List<Map<String, dynamic>> qcQueue = [];
  List<Map<String, dynamic>> events = [];

  // admin-only
  List<Map<String, dynamic>> users = [];
  Map<String, List<String>> perms = {};
  List<Map<String, dynamic>> specFields = [];

  // client-side gate draft state
  final List<Map<String, dynamic>> gateLines = [];
  final List<Map<String, dynamic>> supplierRequests = [];

  bool loading = false;
  String? loadError;

  List<String> get units => master['units'] ?? [];
  List<String> get machines => master['machines'] ?? [];
  List<String> get suppliers => master['suppliers'] ?? [];
  List<String> get locations => master['locations'] ?? [];
  List<String> get employees => master['employees'] ?? [];

  Future<void> loadAll(Session s) async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      await _loadFamilies();
      await _loadMaster(s);
      await _loadInventory();
      if (s.role == 'Admin') {
        await _loadSpecFields();
        await _loadPermissions();
      }
    } catch (e) {
      loadError = '$e';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _loadFamilies() async {
    final fams = await Api.families();
    cats.clear();
    families.clear();
    for (final f in fams) {
      final m = Map<String, dynamic>.from(f as Map);
      final name = '${m['name']}';
      final prefix = '${m['prefix']}';
      final tracking = '${m['tracking']}';
      final subtypes = List<String>.from((m['subtypes'] as List?)?.map((e) => '$e') ?? []);
      cats[name] = [prefix, tracking];
      for (final st in subtypes) {
        cats['$name \u25b8 $st'] = [prefix, tracking];
      }
      List<Map<String, dynamic>> mapFields(dynamic list) => List<Map<String, dynamic>>.from(
          (list as List?)?.map((x) {
                final f = Map<String, dynamic>.from(x as Map);
                return {
                  'l': f['label'],
                  't': f['type'] ?? 'text',
                  'u': f['unit'] ?? '',
                  'o': List<String>.from((f['options'] as List?)?.map((e) => '$e') ?? []),
                };
              }) ??
              []);
      final subFieldsRaw = Map<String, dynamic>.from(m['subFields'] as Map? ?? {});
      final subFields = <String, List<Map<String, dynamic>>>{};
      subFieldsRaw.forEach((k, v) => subFields[k] = mapFields(v));
      families[name] = {
        'prefix': prefix,
        'subtypes': subtypes,
        'fields': mapFields(m['fields']),
        'subFields': subFields,
      };
    }
  }

  Future<void> _loadMaster(Session s) async {
    try {
      final m = await Api.master();
      for (final k in master.keys) {
        master[k]!.clear();
      }
      for (final r in m) {
        final row = Map<String, dynamic>.from(r as Map);
        final kind = '${row['kind']}';
        if (master.containsKey(kind)) master[kind]!.add('${row['value']}');
      }
    } catch (_) {}
    if (s.role == 'Admin') {
      try {
        final us = await Api.users();
        users = us
            .map((u) {
              final m = Map<String, dynamic>.from(u as Map);
              return {
                'dbId': m['id'],
                'id': m['user_id'],
                'name': m['name'] ?? '',
                'role': m['role'],
                'scope': m['scope'] ?? '',
                'hasPassword': m['hasPassword'],
              };
            })
            .toList();
      } catch (_) {}
    }
  }

  Future<void> loadInventory() => _loadInventory();
  Future<void> _loadInventory() async {
    final data = await Api.tools();
    tools = ((data['tools'] as List?) ?? []).map((t) => _mapTool(Map<String, dynamic>.from(t as Map))).toList();
    stock = ((data['stock'] as List?) ?? []).map((x) {
      final m = Map<String, dynamic>.from(x as Map);
      return {
        'kind': 'stock',
        'cat': m['category'],
        'name': m['name'],
        'qty': m['qty'] ?? 0,
        'cost': _num(m['cost']),
        'location': m['location'] ?? '\u2014',
        'code': '\u2014',
        'status': 'STOCK',
      };
    }).toList();
    qcQueue = (await Api.qc()).map((q) {
      final m = Map<String, dynamic>.from(q as Map);
      return {
        'qid': m['id'],
        'gateNo': m['gate_no'],
        'cat': m['category'],
        'name': m['name'],
        'mfr': m['manufacturer'] ?? '\u2014',
        'qty': m['qty'] ?? 0,
        'cost': _num(m['cost']),
        'cond': m['condition'],
        'spec': Map<String, dynamic>.from(m['spec'] as Map? ?? {}),
        'supplier': m['supplier'] ?? '\u2014',
      };
    }).toList();
    events = (await Api.events()).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return {'code': m['tool_code'], 'type': m['type'], 'text': m['text'], 'ts': _ts(m['ts'])};
    }).toList();
    notifyListeners();
  }

  Future<void> _loadSpecFields() async {
    final rows = await Api.specFields();
    specFields = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  Future<void> loadSpecFields() => _loadSpecFields();

  Future<void> _loadPermissions() async {
    final rows = await Api.permissions();
    perms = {};
    for (final r in rows) {
      final m = Map<String, dynamic>.from(r as Map);
      perms['${m['role']}'] = List<String>.from((m['screens'] as List?)?.map((e) => '$e') ?? []);
    }
  }

  Future<void> loadPermissions() => _loadPermissions();

  Map<String, dynamic> _mapTool(Map<String, dynamic> t) => {
        'kind': 'item',
        'code': t['code'],
        'cat': t['category'],
        'name': t['name'],
        'mfr': t['manufacturer'] ?? '\u2014',
        'supplierCode': t['supplier_code'],
        'cost': _num(t['cost']),
        'tracking': 'individual',
        'status': t['status'],
        'location': t['location'] ?? '\u2014',
        'unit': t['unit'] ?? '\u2014',
        'issuedTo': t['issued_to'] ?? '\u2014',
        'machine': t['machine'] ?? '\u2014',
        'wo': t['work_order'] ?? '\u2014',
        'expReturn': t['expected_return'] ?? '\u2014',
        'condition': t['condition'] ?? 'Good',
        'regrindCost': _num(t['regrind_cost']),
        'timesIssued': t['times_issued'] ?? 0,
        'timesRegrind': t['times_reground'] ?? 0,
        'issuedBy': t['issued_by'] ?? '\u2014',
        'issueDate': t['issued_date'] ?? '\u2014',
        'issuedAt': t['issued_at'],
        'returnedAt': t['returned_at'],
        'issuedFrom': t['issued_from'] ?? '\u2014',
        'spec': Map<String, dynamic>.from(t['spec'] as Map? ?? {}),
      };

  // ------- computed -------
  List<Map<String, dynamic>> allItems() => [...tools, ...stock];

  num invValue() {
    final tv = tools
        .where((t) => t['status'] != 'SCRAP' && t['status'] != 'REJECTED')
        .fold<num>(0, (a, t) => a + (t['cost'] as num));
    final sv = stock.fold<num>(0, (a, s) => a + (s['qty'] as num) * (s['cost'] as num));
    return tv + sv;
  }

  /// Default + type-specific spec fields for a "Family ▸ Sub" category string.
  List<Map<String, dynamic>> specFieldsForCat(String cat) {
    final parts = cat.split(' \u25b8 ');
    final fam = families[parts[0]];
    if (fam == null) return [];
    final fields = List<Map<String, dynamic>>.from(fam['fields'] as List);
    if (parts.length > 1) {
      final sf = (fam['subFields'] as Map)[parts[1]];
      if (sf != null) fields.addAll(List<Map<String, dynamic>>.from(sf as List));
    }
    return fields;
  }

  static num _num(dynamic v) => (v is num) ? v : num.tryParse('$v') ?? 0;

  static String _ts(dynamic x) {
    if (x == null) return '\u2014';
    final d = DateTime.tryParse('$x');
    if (d == null) return '\u2014';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$dd ${months[d.month - 1]} $hh:$mm';
  }

  /// Parse "EMP245 — R. Kumar" style master employees into {id, name, raw}.
  List<Map<String, String>> empRecords() {
    return employees
        .map((e) {
          final str = e;
          var i = str.indexOf('\u2014');
          var dashLen = 1;
          if (i < 0) {
            i = str.indexOf(' - ');
            dashLen = 3;
          }
          final id = (i >= 0 ? str.substring(0, i) : str).trim();
          final name = (i >= 0 ? str.substring(i + dashLen) : '').trim();
          return {'id': id, 'name': name, 'raw': str};
        })
        .where((r) => (r['id']!).isNotEmpty || (r['name']!).isNotEmpty)
        .toList();
  }

  String empValue(String? id) {
    final r = empRecords().firstWhere((x) => x['id'] == id, orElse: () => {});
    if (r.isEmpty) return id ?? '';
    return (r['name']!.isNotEmpty) ? '${r['id']} \u2014 ${r['name']}' : r['id']!;
  }
}

// ================================================================ NAVIGATION
class AppNav extends ChangeNotifier {
  String screen = 'dash';
  String? selectedCode; // currently opened tool (for Detail / Edit)

  void go(String s) {
    screen = s;
    notifyListeners();
  }

  void openDetail(String code) {
    selectedCode = code;
    screen = 'detail';
    notifyListeners();
  }
}
