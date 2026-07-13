import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final xp = Xp.of(context);
    final tools = data.tools;
    int by(String s) => tools.where((t) => t['status'] == s).length;
    final avail = by('AVAILABLE'), issued = by('ISSUED');
    final regr = by('REGRINDING') + by('REPAIR'), scrap = by('SCRAP');
    final low = data.stock.where((s) => (s['qty'] as num) <= 5).length;
    final lifecycle = tools.fold<num>(0, (a, t) => a + (t['cost'] as num) + (t['regrindCost'] as num));

    final cards = <List<dynamic>>[
      ['Total inventory value', money(data.invValue()), Brand.blue],
      ['Tools tracked', '${tools.length}', null],
      ['Available', '$avail', Brand.green],
      ['Issued', '$issued', Brand.amber],
      ['In regrind / repair', '$regr', Brand.purple],
      ['Pending QC', '${data.qcQueue.length}', null],
      ['Scrapped', '$scrap', Brand.red],
      ['Low-stock consumables', '$low', Brand.amber],
      ['Consumable lines', '${data.stock.length}', null],
      ['Total lifecycle cost', money(lifecycle), Brand.green],
    ];

    Widget card(String label, String num, Color? accent) => Container(
          width: 200,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: xp.panel,
            border: Border(left: BorderSide(color: accent ?? xp.border, width: accent != null ? 4 : 1), top: BorderSide(color: xp.border), right: BorderSide(color: xp.border), bottom: BorderSide(color: xp.border)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: xp.mutedInk, fontSize: 11.5)),
            const SizedBox(height: 6),
            Text(num, style: TextStyle(color: xp.ink, fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
        );

    final recent = data.events.take(6).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 10, runSpacing: 10, children: [for (final c in cards) card(c[0], c[1], c[2] as Color?)]),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (ctx, cons) {
        final twoCol = cons.maxWidth > 720;
        final left = XpPanel(
          title: 'Recent activity',
          padded: false,
          child: Column(children: [
            if (recent.isEmpty) xpEmpty(context, 'No activity yet'),
            for (final e in recent)
              ListTile(
                dense: true,
                title: Text('${e['text']}', style: TextStyle(color: xp.ink, fontSize: 12.5)),
                trailing: Text('${e['code']}', style: TextStyle(color: xp.mutedInk, fontSize: 11, fontFamily: 'monospace')),
              ),
          ]),
        );
        final right = XpPanel(
          title: 'Attention required',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (data.qcQueue.isNotEmpty) _line(xp, Brand.blue, '${data.qcQueue.length} item(s) pending inventory QC'),
            if (low > 0) _line(xp, Brand.amber, '$low consumable(s) at/below reorder level'),
            if (issued > 0) _line(xp, Brand.amber, '$issued tool(s) currently issued'),
            if (regr > 0) _line(xp, Brand.purple, '$regr tool(s) out for regrind/repair'),
            if (data.qcQueue.isEmpty && low == 0 && issued == 0 && regr == 0) xpEmpty(context, 'Nothing needs attention'),
          ]),
        );
        if (twoCol) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)]);
        }
        return Column(children: [left, right]);
      }),
    ]);
  }

  Widget _line(Xp xp, Color dot, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: xp.ink, fontSize: 12.5))),
        ]),
      );
}
