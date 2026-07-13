import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state.dart';
import '../widgets.dart';

class RegrindScreen extends StatefulWidget {
  const RegrindScreen({super.key});
  @override
  State<RegrindScreen> createState() => _RegrindScreenState();
}

class _RegrindScreenState extends State<RegrindScreen> {
  final search = TextEditingController();

  Future<void> _receive(String code, bool pass) async {
    final data = context.read<AppData>();
    try {
      await Api.regrindReceive(code, pass);
      await data.loadInventory();
      if (mounted) toast(context, pass ? '$code back in stock' : '$code scrapped');
    } catch (e) {
      if (mounted) toast(context, 'Failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final q = search.text.toLowerCase();
    final jobs = data.tools
        .where((t) => t['status'] == 'REGRINDING' || t['status'] == 'REPAIR')
        .where((t) => q.isEmpty || '${t['code']} ${t['name']}'.toLowerCase().contains(q))
        .toList();

    final rows = <List<Widget>>[];
    for (var i = 0; i < jobs.length; i++) {
      final t = jobs[i];
      rows.add([
        cellText(context, '${t['code']}', mono: true),
        cellText(context, '${t['name']}'),
        xpChip('${t['status']}'),
        cellText(context, 'OC-00${90 + i}', mono: true),
        cellText(context, money(t['regrindCost']), mono: true),
        Wrap(spacing: 4, children: [
          xpBtn('Receive + QC pass \u2192 Available', kind: XpBtnKind.green, small: true, onTap: () => _receive('${t['code']}', true)),
          xpBtn('QC fail \u2192 Scrap', kind: XpBtnKind.red, small: true, onTap: () => _receive('${t['code']}', false)),
        ]),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      xpNote(context, "For expensive gear tools this is the most valuable module — every job's cost is tracked and added to lifecycle cost."),
      XpPanel(
        title: 'Regrinding / repair jobs',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 260, child: XpInput(controller: search, hint: 'search by tool ID / name', onChanged: (_) => setState(() {}))),
            xpBtn('Clear', small: true, onTap: () => setState(() => search.clear())),
          ]),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 300),
              child: XpTable(
                columns: const ['Tool ID', 'Tool', 'Status', 'Challan', 'Regrind cost', ''],
                flex: const [3, 4, 2, 2, 2, 6],
                rows: rows,
                emptyText: 'No tools out for service. Return a tool with "Send for regrinding/repair" to create a job.',
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}
