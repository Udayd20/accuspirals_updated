import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../widgets.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  String? fCat, fStatus, fLoc, fEmp;
  final q = TextEditingController();

  bool _match(Map<String, dynamic> it) {
    if ((fStatus ?? '').isNotEmpty && it['status'] != fStatus) return false;
    if ((fCat ?? '').isNotEmpty && it['cat'] != fCat) return false;
    if ((fLoc ?? '').isNotEmpty && it['location'] != fLoc) return false;
    if ((fEmp ?? '').isNotEmpty && (it['issuedTo'] ?? '\u2014') != fEmp) return false;
    final query = q.text.toLowerCase();
    if (query.isEmpty) return true;
    final spec = (it['spec'] as Map?)?.entries.map((e) => '${e.key} ${e.value}').join(' ') ?? '';
    final hay = '${it['code']} ${it['name']} ${it['cat']} ${it['mfr'] ?? ''} ${it['issuedTo'] ?? ''} ${it['location'] ?? ''} $spec'.toLowerCase();
    return hay.contains(query);
  }

  String _loc(Map<String, dynamic> it) {
    if (it['kind'] == 'stock') return '${it['location']}';
    if (it['status'] == 'ISSUED') {
      final u = it['unit'];
      if (u != null && u != '\u2014') {
        final m = it['machine'];
        return '\u2192 $u${m != null && m != '\u2014' ? ' / $m' : ''}';
      }
    }
    return '${it['location']}';
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final all = data.allItems();
    final items = all.where(_match).toList();
    final locs = {for (final i in all) if (i['location'] != null && i['location'] != '\u2014') '${i['location']}'}.toList()..sort();
    final emps = {for (final i in all) if (i['issuedTo'] != null && i['issuedTo'] != '\u2014') '${i['issuedTo']}'}.toList()..sort();

    final rows = <List<Widget>>[];
    for (final it in items) {
      final issuedTo = it['kind'] == 'stock'
          ? '\u2014'
          : (it['issuedTo'] != '\u2014'
              ? '${it['issuedTo']}${it['unit'] != '\u2014' ? ' · ${it['unit']}' : ''}'
              : '\u2014');
      rows.add([
        InkWell(
          onTap: it['kind'] == 'stock'
              ? () => toast(context, 'Consumables are tracked by quantity, not individual detail')
              : () => context.read<AppNav>().openDetail('${it['code']}'),
          child: cellText(context, '${it['code']}', mono: true),
        ),
        cellText(context, '${it['name']}'),
        cellText(context, '${it['cat']}'),
        cellText(context, it['kind'] == 'stock' ? '${it['qty']}' : '1', mono: true),
        xpChip('${it['status']}'),
        cellText(context, _loc(it)),
        cellText(context, issuedTo),
        cellText(context, money(it['kind'] == 'stock' ? (it['qty'] as num) * (it['cost'] as num) : it['cost']), mono: true),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      XpPanel(
        title: 'Tools & consumables',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 200, child: SearchableDropdown(value: fCat, options: ['', ...data.cats.keys], hint: 'All categories', labelFor: (v) => v.isEmpty ? 'All categories' : v, onChanged: (v) => setState(() => fCat = v))),
            SizedBox(width: 160, child: SearchableDropdown(value: fStatus, options: const ['', 'AVAILABLE', 'ISSUED', 'REGRINDING', 'REPAIR', 'SCRAP', 'STOCK'], hint: 'All statuses', labelFor: (v) => v.isEmpty ? 'All statuses' : v, onChanged: (v) => setState(() => fStatus = v))),
            SizedBox(width: 180, child: SearchableDropdown(value: fLoc, options: ['', ...locs], hint: 'All locations', labelFor: (v) => v.isEmpty ? 'All locations' : v, onChanged: (v) => setState(() => fLoc = v))),
            SizedBox(width: 200, child: SearchableDropdown(value: fEmp, options: ['', ...emps], hint: 'All employees', labelFor: (v) => v.isEmpty ? 'All employees' : v, onChanged: (v) => setState(() => fEmp = v))),
            SizedBox(width: 260, child: XpInput(controller: q, hint: 'search ID / name / category / spec / employee', onChanged: (_) => setState(() {}))),
            xpBtn('Clear', small: true, onTap: () => setState(() {
                  fCat = fStatus = fLoc = fEmp = null;
                  q.clear();
                })),
          ]),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 300),
              child: XpTable(
                columns: const ['Tool ID', 'Tool', 'Category', 'Qty', 'Status', 'Location', 'Issued to', 'Cost'],
                flex: const [3, 4, 4, 1, 2, 3, 4, 2],
                rows: rows,
                emptyText: 'No items match — accept a delivery at QC to populate inventory',
              ),
            ),
          ),
          xpHint(context, 'Showing ${items.length} of ${all.length} item(s). Click a Tool ID to open its full detail & timeline.'),
        ]),
      ),
    ]);
  }
}
