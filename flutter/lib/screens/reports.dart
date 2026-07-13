import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final xp = Xp.of(context);
    final tools = data.tools;

    final byCat = <String, num>{};
    for (final t in tools) {
      if (t['status'] != 'SCRAP') byCat['${t['cat']}'] = (byCat['${t['cat']}'] ?? 0) + (t['cost'] as num);
    }
    final life = tools.where((t) => (t['regrindCost'] as num) > 0).toList();
    final scrapVal = tools.where((t) => t['status'] == 'SCRAP').fold<num>(0, (a, t) => a + (t['cost'] as num));
    final lifecycle = tools.fold<num>(0, (a, t) => a + (t['cost'] as num) + (t['regrindCost'] as num));
    final byUnit = <String, int>{};
    for (final t in tools) {
      if (t['status'] == 'ISSUED') byUnit['${t['unit']}'] = (byUnit['${t['unit']}'] ?? 0) + 1;
    }

    Widget card(String label, String num, Color accent) => Container(
          width: 240,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: xp.panel,
            border: Border(left: BorderSide(color: accent, width: 4), top: BorderSide(color: xp.border), right: BorderSide(color: xp.border), bottom: BorderSide(color: xp.border)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: xp.mutedInk, fontSize: 11.5)),
            const SizedBox(height: 6),
            Text(num, style: TextStyle(color: xp.ink, fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
        );

    final lifePanel = XpPanel(
      title: 'Lifecycle cost (tools with regrinding)',
      padded: false,
      child: XpTable(
        columns: const ['Tool ID', 'Tool', 'Purchase', 'Regrind', 'Lifecycle'],
        flex: const [3, 4, 2, 2, 2],
        rows: [
          for (final t in life)
            [
              cellText(context, '${t['code']}', mono: true),
              cellText(context, '${t['name']}'),
              cellText(context, money(t['cost']), mono: true),
              cellText(context, money(t['regrindCost']), mono: true),
              cellText(context, money((t['cost'] as num) + (t['regrindCost'] as num)), mono: true),
            ],
        ],
        emptyText: 'No regrinding cost recorded yet',
      ),
    );
    final catPanel = XpPanel(
      title: 'Inventory value by category',
      padded: false,
      child: XpTable(
        columns: const ['Category', 'Value'],
        flex: const [3, 2],
        rows: [for (final e in byCat.entries) [cellText(context, e.key), cellText(context, money(e.value), mono: true)]],
        emptyText: 'No data',
      ),
    );
    final unitPanel = XpPanel(
      title: 'Currently issued — by unit',
      padded: false,
      child: XpTable(
        columns: const ['Unit', 'Count'],
        flex: const [3, 2],
        rows: [for (final e in byUnit.entries) [cellText(context, e.key), cellText(context, '${e.value} issued', mono: true)]],
        emptyText: 'Nothing issued',
      ),
    );
    final exportPanel = XpPanel(
      title: 'Export',
      child: Wrap(spacing: 8, children: [
        xpBtn('Export PDF', onTap: () => toast(context, 'Exported to PDF (demo)')),
        xpBtn('Export Excel', onTap: () => toast(context, 'Exported to Excel (demo)')),
      ]),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 10, runSpacing: 10, children: [
        card('Total inventory value', money(data.invValue()), Brand.blue),
        card('Total lifecycle cost', money(lifecycle), Brand.green),
        card('Scrap value (lost)', money(scrapVal), Brand.red),
      ]),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (ctx, cons) {
        final left = Column(children: [lifePanel, catPanel]);
        final right = Column(children: [unitPanel, exportPanel]);
        if (cons.maxWidth > 820) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)]);
        }
        return Column(children: [left, right]);
      }),
    ]);
  }
}
