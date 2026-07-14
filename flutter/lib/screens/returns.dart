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
  final Set<String> selected = {};
  String condition = conds.first;
  final damage = TextEditingController();
  String? location;
  bool busy = false;

  String _now() {
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)} ${mo[d.month - 1]} ${p(d.hour)}:${p(d.minute)}';
  }

  Future<void> _decide(String dec, String label) async {
    final data = context.read<AppData>();
    if (selected.isEmpty) {
      toast(context, 'Tick the item(s) being returned first');
      return;
    }
    setState(() => busy = true);
    try {
      for (final code in selected) {
        await Api.returnTool(code, {'decision': dec, 'condition': condition, 'location': location ?? ''});
      }
      final n = selected.length;
      selected.clear();
      await data.loadInventory();
      if (mounted) {
        toast(context, '$n tool(s): $label');
        setState(() => busy = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        toast(context, 'Return failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final xp = Xp.of(context);
    final q = search.text.toLowerCase();
    final issued = data.tools.where((t) => t['status'] == 'ISSUED').toList();
    final shown = issued
        .where((t) => q.isEmpty || '${t['code']} ${t['name']} ${t['issuedTo']} ${t['unit']} ${t['machine']}'.toLowerCase().contains(q))
        .toList();
    location ??= data.locations.isNotEmpty ? data.locations.first : null;

    if (issued.isEmpty) {
      return XpPanel(title: 'Return tools', child: xpEmpty(context, 'No tools are currently issued. Issue a tool first.'));
    }

    final rows = <List<Widget>>[];
    for (final t in shown) {
      final code = '${t['code']}';
      rows.add([
        Checkbox(
          value: selected.contains(code),
          visualDensity: VisualDensity.compact,
          onChanged: (v) => setState(() => v == true ? selected.add(code) : selected.remove(code)),
        ),
        cellText(context, code, mono: true),
        cellText(context, '${t['name']}'),
        cellText(context, '${t['issuedTo']}'),
        cellText(context, '${t['unit']} / ${t['machine']}'),
        cellText(context, '${t['expReturn']}', mono: true),
      ]);
    }
    final allSelected = shown.isNotEmpty && shown.every((t) => selected.contains('${t['code']}'));

    return XpPanel(
      title: 'Return tools',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        xpHint(context, 'Search the issued tools, tick the ones the employee is handing back, then choose what happens to them.'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 320, child: XpInput(controller: search, hint: 'search issued tools by ID / name / person / machine', onChanged: (_) => setState(() {}))),
          xpBtn('Clear', small: true, onTap: () => setState(() => search.clear())),
        ]),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 320),
                child: XpTable(
                  columns: const ['', 'Tool ID', 'Tool', 'Issued to', 'Unit / Machine', 'Due back'],
                  flex: const [1, 3, 4, 4, 4, 3],
                  rows: rows,
                  emptyText: 'No issued tools match your search',
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            xpBtn(allSelected ? 'Unselect all' : 'Select all', small: true, onTap: () => setState(() {
                  if (allSelected) {
                    selected.removeAll(shown.map((t) => '${t['code']}'));
                  } else {
                    selected.addAll(shown.map((t) => '${t['code']}'));
                  }
                })),
            const SizedBox(width: 10),
            Text('${selected.length} selected', style: TextStyle(color: xp.mutedInk, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 12),
        XpGrid(columns: 3, children: [
          XpReadonly('RETURN DATE / TIME', _now()),
          XpReadonly('RECEIVED BY', 'EMP087'),
          XpField(label: 'PHYSICAL CONDITION', child: SearchableDropdown(value: condition, options: conds, onChanged: (v) => setState(() => condition = v ?? condition))),
          XpField(label: 'DAMAGE NOTED', child: XpInput(controller: damage, hint: 'none')),
          XpField(label: 'STORAGE (if reused)', child: SearchableDropdown(value: location, options: data.locations, onChanged: (v) => setState(() => location = v))),
        ]),
        const SizedBox(height: 14),
        Text('RETURN INSPECTION DECISION (applies to all selected)', style: TextStyle(color: xp.mutedInk, fontSize: 10.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          xpBtn(busy ? 'Working…' : 'Available for reuse', kind: XpBtnKind.green, onTap: busy ? null : () => _decide('reuse', 'available for reuse')),
          xpBtn('Send for regrinding', kind: XpBtnKind.purple, onTap: busy ? null : () => _decide('regrind', 'sent for regrinding')),
          xpBtn('Send for repair', kind: XpBtnKind.amber, onTap: busy ? null : () => _decide('repair', 'sent for repair')),
          xpBtn('Damaged / Scrap', kind: XpBtnKind.red, onTap: busy ? null : () => _decide('scrap', 'scrapped')),
        ]),
      ]),
    );
  }
}
