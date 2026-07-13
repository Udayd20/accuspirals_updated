import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

const _permRoles = ['Gate staff', 'Inventory staff', 'Admin'];
const _screensAll = [
  ['dash', 'Dash'], ['gate', 'Gate'], ['qc', 'QC'], ['tools', 'Tools'], ['detail', 'Detail'],
  ['issue', 'Issue'], ['return', 'Return'], ['regrind', 'Regrind'], ['reports', 'Reports'], ['admin', 'Admin'],
];

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // category add
  String? catParent;
  final catName = TextEditingController();
  final catPrefix = TextEditingController();
  String catTracking = trackings.first;
  // spec manager
  String? specFam;
  String specSub = '';
  final sfLabel = TextEditingController();
  String sfType = 'text';
  final sfUnit = TextEditingController();
  final sfOpts = TextEditingController();
  // permissions matrix
  Map<String, Set<String>>? permState;
  // users
  final uId = TextEditingController(), uName = TextEditingController(), uPw = TextEditingController();
  String uRole = roles.first;
  // master data
  String mdTab = 'units';
  final mdSearch = TextEditingController();
  final mdVal = TextEditingController(), mdEmpId = TextEditingController(), mdEmpName = TextEditingController();

  Future<void> _refresh() async => context.read<AppData>().loadAll(context.read<Session>());

  Map<String, Set<String>> _initPerms(AppData data) {
    final m = <String, Set<String>>{};
    for (final r in _permRoles) {
      final scr = data.perms[r] ?? roleAccess[r] ?? [];
      m[r] = {...scr};
    }
    m['Admin']!.add('admin');
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    specFam ??= data.families.keys.isNotEmpty ? data.families.keys.first : null;
    permState ??= _initPerms(data);

    return LayoutBuilder(builder: (ctx, cons) {
      final wide = cons.maxWidth > 900;
      final leftCol = Column(children: [_categoryTree(data), _specManager(data), _permissions(data)]);
      final rightCol = Column(children: [_users(data), _masterData(data)]);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (data.supplierRequests.isNotEmpty) _supplierRequests(data),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: leftCol), const SizedBox(width: 12), Expanded(child: rightCol)])
        else
          Column(children: [leftCol, rightCol]),
      ]);
    });
  }

  // ---------------- supplier requests ----------------
  Widget _supplierRequests(AppData data) => XpPanel(
        title: '\u{1F514} New supplier requests (${data.supplierRequests.length})',
        padded: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.all(12), child: xpHint(context, "Gate staff entered supplier names that aren't in the master list yet — review and add.")),
          XpTable(
            columns: const ['Supplier name', 'Requested', ''],
            flex: const [4, 3, 4],
            rows: [
              for (var i = 0; i < data.supplierRequests.length; i++)
                [
                  cellText(context, '${data.supplierRequests[i]['name']}'),
                  cellText(context, '${data.supplierRequests[i]['ts']}', mono: true),
                  Wrap(spacing: 4, children: [
                    xpBtn('Add to suppliers', kind: XpBtnKind.green, small: true, onTap: () async {
                      final name = '${data.supplierRequests[i]['name']}';
                      if (!data.suppliers.contains(name)) {
                        try {
                          await Api.addMaster('suppliers', name);
                        } catch (_) {}
                        data.master['suppliers']!.add(name);
                      }
                      setState(() => data.supplierRequests.removeAt(i));
                      if (mounted) toast(context, '$name added to suppliers');
                    }),
                    xpBtn('Dismiss', small: true, onTap: () => setState(() => data.supplierRequests.removeAt(i))),
                  ]),
                ],
            ],
          ),
        ]),
      );

  // ---------------- category tree ----------------
  Widget _categoryTree(AppData data) {
    final xp = Xp.of(context);
    final cats = data.cats.keys.toList();
    return XpPanel(
      title: 'Category hierarchy',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final full in cats)
          Padding(
            padding: EdgeInsets.only(left: (full.split(' \u25b8 ').length - 1) * 16.0, top: 3, bottom: 3),
            child: Row(children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: full.split(' \u25b8 ').last, style: TextStyle(color: xp.ink, fontSize: 12.5)),
                  TextSpan(text: '  · ${data.cats[full]![0]} · ${data.cats[full]![1]}', style: TextStyle(color: xp.mutedInk, fontSize: 11)),
                ])),
              ),
              xpBtn('Delete', kind: XpBtnKind.del, small: true, onTap: () => _deleteCat(data, full)),
            ]),
          ),
        const SizedBox(height: 12),
        XpGrid(columns: 2, children: [
          XpField(label: 'PARENT CATEGORY', child: SearchableDropdown(value: catParent, options: ['', ...cats], hint: '— top level —', labelFor: (v) => v.isEmpty ? '— top level —' : v, onChanged: (v) => setState(() => catParent = v))),
          XpField(label: 'NEW (SUB)CATEGORY NAME', child: XpInput(controller: catName, hint: 'e.g. Bench Grinding')),
          XpField(label: 'TRACKING METHOD', child: SearchableDropdown(value: catTracking, options: trackings, onChanged: (v) => setState(() => catTracking = v ?? catTracking))),
          XpField(label: 'ID PREFIX (auto — editable)', child: XpInput(controller: catPrefix, hint: 'auto')),
        ]),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: xpBtn('+ Add category / subcategory', kind: XpBtnKind.primary, onTap: () => _addCat(data))),
        xpHint(context, 'Pick a parent to nest a subcategory under it. New categories appear in Gate Entry & QC immediately.'),
      ]),
    );
  }

  Future<void> _addCat(AppData data) async {
    final name = catName.text.trim();
    if (name.isEmpty) {
      toast(context, 'Enter a category name');
      return;
    }
    final parent = catParent ?? '';
    final full = parent.isNotEmpty ? '$parent \u25b8 $name' : name;
    if (data.cats.containsKey(full)) {
      toast(context, 'That category already exists');
      return;
    }
    final pref = (catPrefix.text.trim().isNotEmpty
            ? catPrefix.text.trim()
            : full.split(' \u25b8 ').map((w) => w.isNotEmpty ? w[0] : '').join())
        .toUpperCase();
    try {
      await Api.addCategory({'parent': parent.isEmpty ? null : parent, 'name': name, 'tracking': catTracking, 'prefix': pref});
      catName.clear();
      catPrefix.clear();
      await _refresh();
      if (mounted) toast(context, 'Added "$full"');
    } catch (e) {
      if (mounted) toast(context, 'Add failed — admin only');
    }
  }

  void _deleteCat(AppData data, String full) {
    if (data.cats.keys.any((c) => c != full && c.startsWith('$full \u25b8 '))) {
      toast(context, 'Remove its subcategories first');
      return;
    }
    if (data.tools.any((t) => t['cat'] == full) || data.stock.any((s) => s['cat'] == full)) {
      toast(context, "Can't remove — items use this category");
      return;
    }
    setState(() => data.cats.remove(full));
    toast(context, 'Category removed');
  }

  // ---------------- spec manager ----------------
  Widget _specManager(AppData data) {
    final subs = specFam == null ? <String>[] : List<String>.from((data.families[specFam]?['subtypes'] as List?) ?? []);
    if (specSub.isNotEmpty && !subs.contains(specSub)) specSub = '';
    final scope = data.specFields.where((r) {
      if ('${r['family']}' != specFam) return false;
      final sub = r['subtype'];
      if (specSub.isEmpty) return sub == null || '$sub'.isEmpty;
      return '$sub' == specSub;
    }).toList();

    return XpPanel(
      title: 'Category specifications',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        XpGrid(columns: 2, children: [
          XpField(label: 'PARENT CATEGORY', child: SearchableDropdown(value: specFam, options: data.families.keys.toList(), onChanged: (v) => setState(() { specFam = v; specSub = ''; }))),
          XpField(label: 'TYPE', child: SearchableDropdown(value: specSub, options: ['', ...subs], labelFor: (v) => v.isEmpty ? '— $specFam defaults —' : v, onChanged: (v) => setState(() => specSub = v ?? ''))),
        ]),
        const SizedBox(height: 8),
        xpHint(context, specSub.isEmpty ? 'These default fields show for every $specFam tool.' : 'These show in addition to defaults when $specFam \u25b8 $specSub is chosen.'),
        const SizedBox(height: 8),
        XpTable(
          columns: const ['Field', 'Type', 'Unit / options', ''],
          flex: const [4, 2, 4, 2],
          rows: [
            for (final r in scope)
              [
                cellText(context, '${r['label']}'),
                xpChip('${r['type']}', color: Brand.blue),
                cellText(context, '${r['unit'] ?? ''}${(r['options'] is List && (r['options'] as List).isNotEmpty) ? '${(r['unit'] ?? '').toString().isNotEmpty ? ' · ' : ''}${(r['options'] as List).join(', ')}' : ''}', mono: true),
                xpBtn('Delete', kind: XpBtnKind.del, small: true, onTap: () => _delSpec(data, r['id'])),
              ],
          ],
          emptyText: 'No fields yet for this scope — add one below.',
        ),
        const SizedBox(height: 12),
        Text('ADD A FIELD', style: TextStyle(color: Xp.of(context).mutedInk, fontSize: 10.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        XpGrid(columns: 2, children: [
          XpField(label: 'FIELD LABEL', child: XpInput(controller: sfLabel, hint: 'e.g. Tip Radius')),
          XpField(label: 'INPUT TYPE', child: SearchableDropdown(value: sfType, options: const ['text', 'number', 'select', 'dualunit'], labelFor: (v) => {'text': 'Text', 'number': 'Number', 'select': 'Dropdown (options)', 'dualunit': 'Dual unit (Module/DP style)'}[v] ?? v, onChanged: (v) => setState(() => sfType = v ?? 'text'))),
          XpField(label: 'UNIT (optional)', child: XpInput(controller: sfUnit, hint: 'mm, °, ...')),
          XpField(label: 'OPTIONS (comma-separated)', child: XpInput(controller: sfOpts, hint: 'RH, LH — for dropdown / dual unit')),
        ]),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: xpBtn('+ Add field', kind: XpBtnKind.primary, onTap: () => _addSpec(data))),
      ]),
    );
  }

  Future<void> _addSpec(AppData data) async {
    final label = sfLabel.text.trim();
    if (label.isEmpty) {
      toast(context, 'Enter a field label');
      return;
    }
    final options = sfOpts.text.trim().isEmpty ? <String>[] : sfOpts.text.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    if ((sfType == 'select' || sfType == 'dualunit') && options.isEmpty) {
      toast(context, 'Add at least one option for a dropdown / dual-unit field');
      return;
    }
    try {
      await Api.addSpecField({'familyName': specFam, 'subtypeName': specSub.isEmpty ? null : specSub, 'label': label, 'type': sfType, 'unit': sfUnit.text.trim(), 'options': options});
      sfLabel.clear();
      sfUnit.clear();
      sfOpts.clear();
      await _refresh();
      if (mounted) toast(context, 'Field "$label" added');
    } catch (e) {
      if (mounted) toast(context, 'Add failed — admin only');
    }
  }

  Future<void> _delSpec(AppData data, dynamic id) async {
    try {
      await Api.delSpecField(id as int);
      await _refresh();
      if (mounted) toast(context, 'Field deleted');
    } catch (e) {
      if (mounted) toast(context, 'Delete failed');
    }
  }

  // ---------------- permissions ----------------
  Widget _permissions(AppData data) {
    final xp = Xp.of(context);
    return XpPanel(
      title: 'Role permissions',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 12,
            headingRowHeight: 34,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 40,
            columns: [
              const DataColumn(label: Text('Role', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              for (final s in _screensAll) DataColumn(label: Text(s[1], style: const TextStyle(fontSize: 10))),
            ],
            rows: [
              for (final role in _permRoles)
                DataRow(cells: [
                  DataCell(Text(role, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: xp.ink))),
                  for (final s in _screensAll)
                    DataCell(Checkbox(
                      visualDensity: VisualDensity.compact,
                      value: permState![role]!.contains(s[0]),
                      onChanged: (role == 'Admin' && s[0] == 'admin')
                          ? null
                          : (v) => setState(() => v == true ? permState![role]!.add(s[0]) : permState![role]!.remove(s[0])),
                    )),
                ]),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: xpBtn('Save permissions', kind: XpBtnKind.primary, onTap: () => _savePerms(data))),
        xpHint(context, 'Tick which screens each role can open. Changes take effect the next time those users log in.'),
      ]),
    );
  }

  Future<void> _savePerms(AppData data) async {
    permState!['Admin']!.add('admin');
    try {
      for (final r in _permRoles) {
        await Api.setPermissions(r, permState![r]!.toList());
      }
      await data.loadPermissions();
      if (mounted) toast(context, 'Permissions saved — users see changes on next login');
    } catch (e) {
      if (mounted) toast(context, 'Save failed — admin only');
    }
  }

  // ---------------- users ----------------
  Widget _users(AppData data) => XpPanel(
        title: 'Users & roles',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          XpTable(
            columns: const ['User ID', 'Name', 'Role', ''],
            flex: const [3, 3, 3, 4],
            rows: [
              for (final u in data.users)
                [
                  cellText(context, '${u['id']}', mono: true),
                  cellText(context, '${(u['name'] as String).isEmpty ? '—' : u['name']}'),
                  xpChip('${u['role']}'.toUpperCase(), color: u['role'] == 'Admin' ? Colors.blueGrey : Brand.blue),
                  Wrap(spacing: 4, children: [
                    xpBtn('Reset password', small: true, onTap: () => _resetUser(data, u)),
                    xpBtn('Delete', kind: XpBtnKind.del, small: true, onTap: () => _delUser(data, u)),
                  ]),
                ],
            ],
          ),
          const SizedBox(height: 12),
          XpGrid(columns: 2, children: [
            XpField(label: 'EMPLOYEE ID', child: XpInput(controller: uId, hint: 'e.g. EMP203')),
            XpField(label: 'NAME', child: XpInput(controller: uName, hint: 'e.g. A. Sharma')),
            XpField(label: 'ROLE', child: SearchableDropdown(value: uRole, options: roles, onChanged: (v) => setState(() => uRole = v ?? uRole))),
            XpField(label: 'INITIAL PASSWORD', child: XpInput(controller: uPw, hint: 'password')),
          ]),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: xpBtn('+ Add user', kind: XpBtnKind.primary, onTap: () => _addUser(data))),
        ]),
      );

  Future<void> _addUser(AppData data) async {
    final id = uId.text.trim();
    if (id.isEmpty) {
      toast(context, 'Enter an employee ID');
      return;
    }
    try {
      await Api.addUser({'userId': id, 'name': uName.text.trim(), 'role': uRole, 'scope': '', 'password': uPw.text.isEmpty ? 'accuspirals' : uPw.text});
      uId.clear();
      uName.clear();
      uPw.clear();
      await _refresh();
      if (mounted) toast(context, 'User $id added');
    } catch (e) {
      if (mounted) toast(context, 'Add failed — admin only');
    }
  }

  Future<void> _resetUser(AppData data, Map<String, dynamic> u) async {
    if (u['dbId'] == null) {
      toast(context, 'This is a seed row — reload after backend is connected');
      return;
    }
    final ctl = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('New password for ${u['id']}'),
        content: TextField(controller: ctl, decoration: const InputDecoration(hintText: 'new password')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctl.text), child: const Text('Reset')),
        ],
      ),
    );
    if (pw == null) return;
    try {
      await Api.resetUser(u['dbId'] as int, pw.isEmpty ? 'accuspirals' : pw);
      if (mounted) toast(context, "Password reset for ${u['id']}");
    } catch (e) {
      if (mounted) toast(context, 'Reset failed');
    }
  }

  Future<void> _delUser(AppData data, Map<String, dynamic> u) async {
    final ok = await _confirm('Delete user ${u['id']}? They will no longer be able to log in.');
    if (!ok) return;
    try {
      if (u['dbId'] != null) await Api.delUser(u['dbId'] as int);
      await _refresh();
      if (mounted) toast(context, 'User removed');
    } catch (e) {
      if (mounted) toast(context, 'Delete failed');
    }
  }

  // ---------------- master data ----------------
  Widget _masterData(AppData data) {
    final tabs = [['units', 'Units'], ['machines', 'Machines'], ['employees', 'Employees'], ['suppliers', 'Suppliers'], ['locations', 'Locations']];
    final q = mdSearch.text.toLowerCase();
    final list = (data.master[mdTab] ?? []);
    final rows = <List<Widget>>[];
    for (var i = 0; i < list.length; i++) {
      if (q.isNotEmpty && !list[i].toLowerCase().contains(q)) continue;
      final idx = i;
      rows.add([
        cellText(context, list[idx]),
        xpBtn('Delete', kind: XpBtnKind.del, small: true, onTap: () => setState(() {
              data.master[mdTab]!.removeAt(idx);
              toast(context, 'Removed');
            })),
      ]);
    }
    final placeholders = {'units': 'e.g. Unit 4', 'machines': 'e.g. GRIND-03', 'employees': 'e.g. EMP402 — A. Sharma', 'suppliers': 'e.g. Wendt India', 'locations': 'e.g. Rack G3 / Shelf 1'};

    return XpPanel(
      title: 'Master data',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in tabs)
            xpBtn('${t[1]} (${data.master[t[0]]!.length})', kind: mdTab == t[0] ? XpBtnKind.primary : XpBtnKind.normal, small: true, onTap: () => setState(() => mdTab = t[0])),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 240, child: XpInput(controller: mdSearch, hint: 'search $mdTab', onChanged: (_) => setState(() {}))),
          xpBtn('Clear', small: true, onTap: () => setState(() => mdSearch.clear())),
        ]),
        const SizedBox(height: 8),
        XpTable(columns: [tabs.firstWhere((t) => t[0] == mdTab)[1], ''], flex: const [4, 2], rows: rows, emptyText: q.isEmpty ? 'None yet' : 'No matches'),
        const SizedBox(height: 12),
        if (mdTab == 'employees')
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: [
            SizedBox(width: 190, child: XpField(label: 'ID', child: XpInput(controller: mdEmpId, hint: 'EMP402'))),
            SizedBox(width: 230, child: XpField(label: 'NAME', child: XpInput(controller: mdEmpName, hint: 'A. Sharma'))),
            xpBtn('+ Add', kind: XpBtnKind.primary, onTap: () => _addMaster(data)),
          ])
        else
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: [
            SizedBox(width: 320, child: XpInput(controller: mdVal, hint: placeholders[mdTab])),
            xpBtn('+ Add', kind: XpBtnKind.primary, onTap: () => _addMaster(data)),
          ]),
        xpHint(context, 'These lists feed the dropdowns on Gate Entry, Issue, Return and QC.'),
      ]),
    );
  }

  Future<void> _addMaster(AppData data) async {
    String v;
    if (mdTab == 'employees') {
      final id = mdEmpId.text.trim();
      if (id.isEmpty) {
        toast(context, 'Enter an employee ID');
        return;
      }
      v = mdEmpName.text.trim().isNotEmpty ? '$id \u2014 ${mdEmpName.text.trim()}' : id;
    } else {
      v = mdVal.text.trim();
      if (v.isEmpty) {
        toast(context, 'Enter a value');
        return;
      }
    }
    if (data.master[mdTab]!.contains(v)) {
      toast(context, 'Already in the list');
      return;
    }
    try {
      await Api.addMaster(mdTab, v);
    } catch (_) {}
    setState(() {
      data.master[mdTab]!.add(v);
      mdVal.clear();
      mdEmpId.clear();
      mdEmpName.clear();
    });
    toast(context, 'Added to $mdTab');
  }

  Future<bool> _confirm(String msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Please confirm'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    return ok ?? false;
  }
}
