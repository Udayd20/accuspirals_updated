import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

Future<void> showAddToolDialog(BuildContext context) {
  return showDialog(context: context, builder: (_) => const _AddToolDialog());
}

class _AddToolDialog extends StatefulWidget {
  const _AddToolDialog();
  @override
  State<_AddToolDialog> createState() => _AddToolDialogState();
}

class _AddToolDialogState extends State<_AddToolDialog> {
  String? fam;
  String? sub;
  final name = TextEditingController();
  final supplier = TextEditingController();
  final code = TextEditingController();
  final cost = TextEditingController();
  String material = 'HSS';
  final Map<String, TextEditingController> specCtl = {};
  final Map<String, String> specSelect = {};

  @override
  void initState() {
    super.initState();
    final data = context.read<AppData>();
    fam = data.families.keys.isNotEmpty ? data.families.keys.first : null;
    sub = _subs(data).isNotEmpty ? _subs(data).first : null;
  }

  List<String> _subs(AppData data) => fam == null ? [] : List<String>.from((data.families[fam]?['subtypes'] as List?) ?? []);

  List<Map<String, dynamic>> _fields(AppData data) {
    if (fam == null) return [];
    final f = data.families[fam]!;
    final fields = List<Map<String, dynamic>>.from(f['fields'] as List);
    final sf = (f['subFields'] as Map)[sub];
    if (sf != null) fields.addAll(List<Map<String, dynamic>>.from(sf as List));
    return fields;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final xp = Xp.of(context);
    final fields = _fields(data);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [xp.titleA, xp.titleB])),
            child: Row(children: [
              const Expanded(child: Text('Add Tool — fields load by family & subtype', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white, size: 18)),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                XpField(label: 'Tool family', child: SearchableDropdown(value: fam, options: data.families.keys.toList(), onChanged: (v) => setState(() { fam = v; sub = _subs(data).isNotEmpty ? _subs(data).first : null; specCtl.clear(); specSelect.clear(); }))),
                const SizedBox(height: 8),
                XpField(label: 'Subtype', child: SearchableDropdown(value: sub, options: _subs(data), onChanged: (v) => setState(() => sub = v))),
                if (fields.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('CUTTING SPECIFICATION', style: TextStyle(color: xp.mutedInk, fontSize: 10.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (final f in fields) ...[_specField(f), const SizedBox(height: 8)],
                ],
                const SizedBox(height: 12),
                Text('IDENTITY & COMMERCIAL', style: TextStyle(color: xp.mutedInk, fontSize: 10.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                XpField(label: 'Tool name', child: XpInput(controller: name)),
                const SizedBox(height: 8),
                XpField(label: 'Supplier', child: XpInput(controller: supplier)),
                const SizedBox(height: 8),
                XpField(label: 'Supplier code', child: XpInput(controller: code)),
                const SizedBox(height: 8),
                XpField(label: 'Material grade', child: SearchableDropdown(value: material, options: const ['HSS', 'Carbide', 'PM-HSS'], onChanged: (v) => setState(() => material = v ?? 'HSS'))),
                const SizedBox(height: 8),
                XpField(label: 'Unit cost (\u20b9)', child: XpInput(controller: cost, number: true)),
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: xp.border))),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              xpBtn('Cancel', onTap: () => Navigator.pop(context)),
              const SizedBox(width: 8),
              xpBtn('+ Add tool', kind: XpBtnKind.primary, onTap: () => _save(data)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _specField(Map<String, dynamic> f) {
    final label = '${f['l']}';
    final unit = '${f['u'] ?? ''}';
    final type = '${f['t']}';
    final full = unit.isNotEmpty ? '$label ($unit)' : label;
    if (type == 'select') {
      final opts = List<String>.from(f['o'] as List);
      specSelect.putIfAbsent(label, () => opts.isNotEmpty ? opts.first : '');
      return XpField(label: full, child: SearchableDropdown(value: specSelect[label], options: opts, onChanged: (v) => setState(() => specSelect[label] = v ?? '')));
    }
    specCtl.putIfAbsent(label, () => TextEditingController());
    return XpField(label: full, child: XpInput(controller: specCtl[label]!, hint: unit, number: type == 'number'));
  }

  Future<void> _save(AppData data) async {
    if (name.text.trim().isEmpty) {
      toast(context, 'Enter a tool name');
      return;
    }
    final spec = <String, dynamic>{};
    for (final f in _fields(data)) {
      final label = '${f['l']}';
      final unit = '${f['u'] ?? ''}';
      final type = '${f['t']}';
      if (type == 'select') {
        final v = specSelect[label];
        if (v != null && v.isNotEmpty) spec[label] = v;
      } else {
        final v = specCtl[label]?.text ?? '';
        if (v.isNotEmpty) spec[label] = unit.isNotEmpty ? '$v $unit' : v;
      }
    }
    spec['Material'] = material;
    spec['Supplier code'] = code.text.trim().isEmpty ? '\u2014' : code.text.trim();
    try {
      final t = await Api.addTool({
        'family': fam,
        'subtype': sub,
        'name': name.text.trim(),
        'supplier': supplier.text.trim(),
        'material': material,
        'cost': num.tryParse(cost.text) ?? 0,
        'spec': spec,
      });
      await data.loadInventory();
      if (mounted) {
        Navigator.pop(context);
        final code = (t is Map && t['code'] != null) ? t['code'] : name.text.trim();
        toast(context, 'Added $code');
        context.read<AppNav>().go('tools');
      }
    } catch (e) {
      if (mounted) toast(context, 'Add failed');
    }
  }
}
