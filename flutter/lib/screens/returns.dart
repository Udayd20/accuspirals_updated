import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class ReturnScreen extends StatefulWidget {
  const ReturnScreen({super.key});
  @override
  State<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  final search = TextEditingController();
  String? code;
  String condition = conds.first;
  final damage = TextEditingController();
  String? location;

  String _now() {
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)} ${mo[d.month - 1]} ${p(d.hour)}:${p(d.minute)}';
  }

  Future<void> _decide(String dec) async {
    final data = context.read<AppData>();
    if (code == null) return;
    try {
      await Api.returnTool(code!, {'decision': dec, 'condition': condition, 'location': location ?? ''});
      await data.loadInventory();
      if (mounted) {
        toast(context, '$code: $dec');
        setState(() => code = null);
      }
    } catch (e) {
      if (mounted) toast(context, 'Return failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final xp = Xp.of(context);
    final q = search.text.toLowerCase();
    final issued = data.tools.where((t) => t['status'] == 'ISSUED').toList();
    final filtered = issued.where((t) => q.isEmpty || '${t['code']} ${t['name']} ${t['issuedTo']}'.toLowerCase().contains(q)).toList();
    location ??= data.locations.isNotEmpty ? data.locations.first : null;

    if (issued.isEmpty) {
      return XpPanel(title: 'Return a tool', child: xpEmpty(context, 'No tools are currently issued. Issue a tool first.'));
    }
    code ??= filtered.isNotEmpty ? '${filtered.first['code']}' : null;
    final sel = data.tools.firstWhere((t) => t['code'] == code, orElse: () => {});
    final spec = Map<String, dynamic>.from(sel['spec'] as Map? ?? {});

    return XpPanel(
      title: 'Return a tool',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        XpField(label: 'SEARCH ISSUED TOOLS', child: XpInput(controller: search, hint: 'filter by ID / name / person', onChanged: (_) => setState(() {
              if (!filtered.any((t) => t['code'] == code)) code = null;
            }))),
        const SizedBox(height: 8),
        XpField(
          label: 'SELECT / SCAN AN ISSUED TOOL',
          child: SearchableDropdown(
            value: code,
            options: [for (final t in filtered) '${t['code']}'],
            labelFor: (v) {
              final t = data.tools.firstWhere((x) => x['code'] == v, orElse: () => {});
              return t.isEmpty ? v : '${t['code']} — ${t['name']} (${t['issuedTo']})';
            },
            onChanged: (v) => setState(() => code = v),
          ),
        ),
        const SizedBox(height: 10),
        XpGrid(columns: 3, children: [
          XpReadonly('RETURN DATE / TIME', _now()),
          XpReadonly('RETURNED BY', sel.isEmpty ? '\u2014' : '${sel['issuedTo']}'),
          XpReadonly('ISSUED BY (gave the tool)', sel.isEmpty ? '\u2014' : '${sel['issuedBy']}'),
          XpReadonly('RECEIVED BY', 'EMP087'),
          XpField(label: 'PHYSICAL CONDITION', child: SearchableDropdown(value: condition, options: conds, onChanged: (v) => setState(() => condition = v ?? condition))),
          XpField(label: 'DAMAGE NOTED', child: XpInput(controller: damage, hint: 'none')),
          XpField(label: 'STORAGE (if reused)', child: SearchableDropdown(value: location, options: data.locations, onChanged: (v) => setState(() => location = v))),
        ]),
        const SizedBox(height: 12),
        Text('TOOL SPECIFICATION', style: TextStyle(color: xp.mutedInk, fontSize: 10.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(spec.isEmpty ? 'No spec recorded for this tool.' : spec.entries.map((e) => '${e.key}: ${e.value}').join('  ·  '),
            style: TextStyle(color: xp.mutedInk, fontSize: 12)),
        const SizedBox(height: 14),
        Text('RETURN INSPECTION DECISION', style: TextStyle(color: xp.mutedInk, fontSize: 10.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          xpBtn('Available for reuse', kind: XpBtnKind.green, onTap: () => _decide('reuse')),
          xpBtn('Send for regrinding', kind: XpBtnKind.purple, onTap: () => _decide('regrind')),
          xpBtn('Send for repair', kind: XpBtnKind.amber, onTap: () => _decide('repair')),
          xpBtn('Damaged / Scrap', kind: XpBtnKind.red, onTap: () => _decide('scrap')),
        ]),
      ]),
    );
  }
}
