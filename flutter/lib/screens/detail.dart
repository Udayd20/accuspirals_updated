import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class ToolDetailScreen extends StatelessWidget {
  const ToolDetailScreen({super.key});

  String _fmtTs(dynamic x) {
    if (x == null) return '\u2014';
    final d = DateTime.tryParse('$x');
    if (d == null) return '\u2014';
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)} ${mo[d.month - 1]} ${d.year} ${p(d.hour)}:${p(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final nav = context.watch<AppNav>();
    final xp = Xp.of(context);
    Map<String, dynamic>? t;
    if (nav.selectedCode != null) {
      t = data.tools.firstWhere((x) => x['code'] == nav.selectedCode, orElse: () => {});
      if (t.isEmpty) t = null;
    }
    t ??= data.tools.firstWhere((x) => x['status'] != 'SCRAP', orElse: () => {});
    if (t.isEmpty) {
      return XpPanel(title: 'Tool details', child: xpEmpty(context, 'No tool selected. Open one from Tools & Consumables.'));
    }
    final spec = Map<String, dynamic>.from(t['spec'] as Map? ?? {});
    final timeline = data.events.where((e) => e['code'] == t!['code']).toList();
    final cost = t['cost'] as num, regrind = t['regrindCost'] as num;

    final identity = XpPanel(
      title: 'Identity — ${t['code']}',
      child: XpGrid(columns: 2, children: [
        XpReadonly('TOOL NAME', '${t['name']}'),
        XpReadonly('CATEGORY', '${t['cat']}'),
        XpReadonly('MANUFACTURER', '${t['mfr']}'),
        XpReadonly('TRACKING', '${t['tracking']}'.toUpperCase(), mono: true),
      ]),
    );
    final specification = XpPanel(
      title: 'Specification',
      child: spec.isEmpty
          ? xpEmpty(context, 'No structured spec captured yet')
          : XpGrid(columns: 3, children: [for (final e in spec.entries) XpReadonly(e.key, '${e.value}', mono: true)]),
    );
    final commercial = XpPanel(
      title: 'Commercial & lifecycle',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        XpGrid(columns: 4, children: [
          XpReadonly('ORIGINAL COST', money(cost), mono: true),
          XpReadonly('REGRIND COST', money(regrind), mono: true),
          XpReadonly('TIMES ISSUED', '${t['timesIssued']}', mono: true),
          XpReadonly('TIMES REGROUND', '${t['timesRegrind']}', mono: true),
        ]),
        const SizedBox(height: 8),
        xpNote(context, 'Lifecycle cost = ${money(cost)} + ${money(regrind)} = ${money(cost + regrind)}'),
      ]),
    );

    final status = XpPanel(
      title: 'Status',
      child: Center(
        child: Column(children: [
          xpChip('${t['status']}'),
          const SizedBox(height: 8),
          Text(
            t['status'] == 'ISSUED'
                ? '${t['issuedTo']} · ${t['machine']} · ${t['unit']}\ndue back ${t['expReturn']}'
                : (t['location'] != '\u2014' ? '${t['location']}' : ''),
            textAlign: TextAlign.center,
            style: TextStyle(color: xp.mutedInk, fontSize: 12),
          ),
        ]),
      ),
    );
    final movement = XpPanel(
      title: 'Movement & timing',
      child: XpGrid(columns: 2, children: [
        XpReadonly('ISSUED TO', '${t['issuedTo']}'),
        XpReadonly('ISSUED BY', '${t['issuedBy']}'),
        XpReadonly('ISSUE DATE', t['issueDate'] != '\u2014' ? '${t['issueDate']}' : '\u2014'),
        XpReadonly('EXPECTED RETURN', '${t['expReturn']}'),
        XpReadonly('ISSUED AT', _fmtTs(t['issuedAt'])),
        XpReadonly('RETURNED AT', _fmtTs(t['returnedAt'])),
        XpReadonly('UNIT / MACHINE', '${t['unit']} / ${t['machine']}'),
        XpReadonly('ISSUED FROM (unit / shelf)', t['issuedFrom'] != '\u2014' ? '${t['issuedFrom']}' : '\u2014'),
      ]),
    );
    final tl = XpPanel(
      title: 'Complete timeline',
      padded: false,
      child: Column(children: [
        if (timeline.isEmpty) xpEmpty(context, 'No events recorded yet'),
        for (final e in timeline)
          ListTile(
            dense: true,
            title: Text('${e['text']}', style: TextStyle(color: xp.ink, fontSize: 12.5)),
            subtitle: Text('${e['ts']}', style: TextStyle(color: xp.mutedInk, fontSize: 11)),
          ),
      ]),
    );

    return LayoutBuilder(builder: (ctx, cons) {
      final left = Column(children: [identity, specification, commercial]);
      final right = Column(children: [status, movement, tl]);
      if (cons.maxWidth > 820) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)]);
      }
      return Column(children: [left, right]);
    });
  }
}
