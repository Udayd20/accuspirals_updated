import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'gate.dart';

class QcScreen extends StatefulWidget {
  const QcScreen({super.key});
  @override
  State<QcScreen> createState() => _QcScreenState();
}

class _QcScreenState extends State<QcScreen> {
  final search = TextEditingController();
  int? inspectQid;
  final accepted = TextEditingController();
  final rejected = TextEditingController(text: '0');
  final remarks = TextEditingController();
  String? location;
  String? inspectorId;
  bool busy = false;

  Future<void> _addToQc() async {
    final data = context.read<AppData>();
    final d = await showGateEditor(context, title: 'Add tool to QC', action: '+ Add to QC');
    if (d == null) return;
    try {
      await Api.gate({
        'supplier': '',
        'receivedBy': '',
        'lines': [
          {
            'category': d['cat'],
            'name': d['name'],
            'manufacturer': d['mfr'],
            'qty': d['qty'],
            'cost': d['cost'],
            'gate_qc': 'Pass',
            'condition': d['cond'],
            'spec': d['spec'],
          }
        ],
      });
      await data.loadInventory();
      if (mounted) toast(context, 'Added to QC queue');
    } catch (e) {
      if (mounted) toast(context, 'Add failed');
    }
  }

  Future<void> _addExisting() async {
    final data = context.read<AppData>();
    final d = await showGateEditor(context, title: 'Add existing tool to inventory', action: '+ Add to inventory');
    if (d == null) return;
    final parts = '${d['cat']}'.split(' \u25b8 ');
    final fam = parts[0];
    final sub = parts.length > 1
        ? parts[1]
        : ((data.families[fam]?['subtypes'] as List?)?.isNotEmpty == true ? (data.families[fam]!['subtypes'] as List).first : 'General');
    try {
      await Api.addTool({
        'family': fam,
        'subtype': sub,
        'name': d['name'],
        'supplier': d['mfr'],
        'supplierCode': (d['spec'] as Map)['Supplier tool code'] ?? '',
        'cost': d['cost'],
        'spec': d['spec'],
        'location': 'Existing stock',
      });
      await data.loadInventory();
      if (mounted) {
        toast(context, 'Existing tool added to inventory');
        context.read<AppNav>().go('tools');
      }
    } catch (e) {
      if (mounted) toast(context, 'Add failed');
    }
  }

  Future<void> _editQc(Map<String, dynamic> item) async {
    final data = context.read<AppData>();
    final d = await showGateEditor(context, item: item, title: 'Edit QC item', action: 'Save changes');
    if (d == null) return;
    try {
      await Api.qcUpdate(item['qid'] as int, {
        'category': d['cat'],
        'name': d['name'],
        'manufacturer': d['mfr'],
        'qty': d['qty'],
        'cost': d['cost'],
        'condition': d['cond'],
        'spec': d['spec'],
      });
      await data.loadInventory();
      if (mounted) toast(context, 'Queue item updated');
    } catch (e) {
      if (mounted) toast(context, 'Update failed');
    }
  }

  void _openInspect(Map<String, dynamic> q) {
    setState(() {
      inspectQid = q['qid'] as int;
      accepted.text = '${q['qty']}';
      rejected.text = '0';
      remarks.clear();
      location = context.read<AppData>().locations.isNotEmpty ? context.read<AppData>().locations.first : null;
    });
  }

  Future<void> _accept(Map<String, dynamic> q) async {
    final data = context.read<AppData>();
    final acc = int.tryParse(accepted.text) ?? 0;
    if (acc <= 0) {
      toast(context, 'Accepted quantity must be at least 1');
      return;
    }
    setState(() => busy = true);
    try {
      final r = await Api.qcAccept(q['qid'] as int, {
        'accepted': acc,
        'location': (location ?? 'Unassigned'),
        'inspector': data.empValue(inspectorId),
      });
      await data.loadInventory();
      if (mounted) {
        final created = (r is Map && r['created'] is List) ? (r['created'] as List) : [];
        toast(context, created.isNotEmpty ? 'Accepted — created ${created.length} ID(s): ${created.first}' : 'Accepted $acc');
        setState(() {
          inspectQid = null;
          busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        toast(context, 'Accept failed');
      }
    }
  }

  Future<void> _reject(Map<String, dynamic> q) async {
    final data = context.read<AppData>();
    try {
      await Api.qcReject(q['qid'] as int);
      await data.loadInventory();
      if (mounted) {
        toast(context, 'Item rejected');
        setState(() => inspectQid = null);
      }
    } catch (e) {
      if (mounted) toast(context, 'Reject failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final q = search.text.toLowerCase();
    final shown = data.qcQueue
        .where((x) => q.isEmpty || '${x['gateNo']} ${x['name']} ${x['cat']} ${x['mfr']}'.toLowerCase().contains(q))
        .toList();
    final rows = <List<Widget>>[];
    for (final qi in shown) {
      rows.add([
        cellText(context, '${qi['gateNo']}', mono: true),
        cellText(context, '${qi['supplier']}'),
        cellText(context, '${qi['name']}'),
        cellText(context, '${qi['cat']}'),
        cellText(context, '${qi['mfr']}'),
        cellText(context, '${qi['qty']}', mono: true),
        cellText(context, money(qi['cost']), mono: true),
        Wrap(spacing: 4, children: [
          xpBtn('Inspect', kind: XpBtnKind.primary, small: true, onTap: () => _openInspect(qi)),
          xpBtn('Edit', small: true, onTap: () => _editQc(qi)),
        ]),
      ]);
    }
    final inspecting = inspectQid == null ? null : data.qcQueue.firstWhere((x) => x['qid'] == inspectQid, orElse: () => {});

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      xpNote(context, 'Everything that passed the gate waits here. The crib verifies against invoice and decides — including partial acceptance.'),
      XpPanel(
        title: 'Pending inventory QC queue',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 280, child: XpInput(controller: search, hint: 'search queue by gate / item / category', onChanged: (_) => setState(() {}))),
            xpBtn('Clear', small: true, onTap: () => setState(() => search.clear())),
            xpBtn('+ Add tool to QC', kind: XpBtnKind.green, small: true, onTap: _addToQc),
            xpBtn('+ Add existing tool', small: true, onTap: _addExisting),
          ]),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 300),
              child: XpTable(
                columns: const ['Gate no.', 'Supplier', 'Item', 'Category', 'Mfr', 'Recv qty', 'Unit cost', ''],
                flex: const [3, 4, 4, 4, 3, 2, 3, 4],
                rows: rows,
                emptyText: 'Queue is empty — log a delivery on Gate Entry, or click "Add tool to QC"',
              ),
            ),
          ),
        ]),
      ),
      if (inspecting != null && inspecting.isNotEmpty) _inspectPanel(context, data, inspecting),
    ]);
  }

  Widget _inspectPanel(BuildContext context, AppData data, Map<String, dynamic> q) {
    final tracking = data.cats['${q['cat']}']?[1] ?? 'individual';
    final spec = Map<String, dynamic>.from(q['spec'] as Map? ?? {});
    return XpPanel(
      title: 'Inspection — ${q['name']} (${q['qty']} received · $tracking tracked)',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        XpGrid(columns: 4, children: [
          XpReadonly('RECEIVED', '${q['qty']}', mono: true),
          XpField(label: 'ACCEPTED', child: XpInput(controller: accepted, number: true)),
          XpField(label: 'REJECTED', child: XpInput(controller: rejected, number: true)),
          XpField(label: 'STORAGE LOCATION', child: SearchableDropdown(value: location, options: data.locations, onChanged: (v) => setState(() => location = v))),
          EmpPair(records: data.empRecords(), labelPrefix: 'INSPECTOR', initialId: inspectorId, onChanged: (v) => inspectorId = v),
          XpField(label: 'REMARKS', child: XpInput(controller: remarks, hint: 'optional')),
        ]),
        if (spec.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('CUTTING SPECIFICATION CAPTURED AT GATE', style: TextStyle(color: Xp.of(context).mutedInk, fontSize: 10.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          XpGrid(columns: 3, children: [for (final e in spec.entries) XpReadonly(e.key, '${e.value}', mono: true)]),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          xpBtn(busy ? 'Working…' : 'Accept & generate IDs', kind: XpBtnKind.green, onTap: busy ? null : () => _accept(q)),
          xpBtn('Hold for clarification', kind: XpBtnKind.amber, onTap: () => toast(context, 'Item held for clarification')),
          xpBtn('Reject all', kind: XpBtnKind.red, onTap: () => _reject(q)),
        ]),
        xpHint(context, tracking == 'individual'
            ? 'Each accepted unit becomes a uniquely-numbered tool with the spec above.'
            : 'Accepted quantity is added to consumable stock.'),
      ]),
    );
  }
}
