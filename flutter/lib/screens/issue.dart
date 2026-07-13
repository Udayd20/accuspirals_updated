import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state.dart';
import '../widgets.dart';

class IssueScreen extends StatefulWidget {
  const IssueScreen({super.key});
  @override
  State<IssueScreen> createState() => _IssueScreenState();
}

class _IssueScreenState extends State<IssueScreen> {
  final search = TextEditingController();
  final Set<String> selected = {};
  String? empId, byId, unit, machine;
  final wo = TextEditingController();
  String? issueDate, expReturn;
  bool busy = false;

  String _today() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    issueDate = _today();
  }

  Future<void> _confirm() async {
    final data = context.read<AppData>();
    if (selected.isEmpty) {
      toast(context, 'Select at least one tool to issue');
      return;
    }
    setState(() => busy = true);
    final body = {
      'employee': data.empValue(empId),
      'unit': unit ?? '',
      'machine': machine ?? '',
      'workOrder': wo.text,
      'expectedReturn': (expReturn != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(expReturn!)) ? expReturn : null,
      'issuedBy': data.empValue(byId),
      'issueDate': (issueDate != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(issueDate!)) ? issueDate : null,
    };
    try {
      for (final code in selected) {
        await Api.issue(code, body);
      }
      final n = selected.length;
      selected.clear();
      await data.loadInventory();
      if (mounted) {
        toast(context, 'Issued $n tool(s) to ${data.empValue(empId)}');
        setState(() => busy = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        toast(context, 'Issue failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final q = search.text.toLowerCase();
    final avail = data.tools.where((t) => t['status'] == 'AVAILABLE').toList();
    final shown = avail.where((t) => q.isEmpty || '${t['code']} ${t['name']} ${t['cat']}'.toLowerCase().contains(q)).toList();

    if (avail.isEmpty) {
      return XpPanel(title: 'Issue tools', child: xpEmpty(context, 'No tools are currently available to issue. Accept a delivery at QC, or return an issued tool first.'));
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
        cellText(context, '${t['cat']}'),
      ]);
    }
    final allSelected = shown.isNotEmpty && shown.every((t) => selected.contains('${t['code']}'));

    return XpPanel(
      title: 'Issue tools',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 300, child: XpInput(controller: search, hint: 'search available tools by ID / name / category', onChanged: (_) => setState(() {}))),
          xpBtn('Clear', small: true, onTap: () => setState(() => search.clear())),
        ]),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            child: XpTable(
              columns: const ['', 'Tool ID', 'Tool', 'Category'],
              flex: const [1, 3, 5, 4],
              rows: rows,
              emptyText: 'No available tools match',
            ),
          ),
        ),
        // (select-all is offered via the button below to keep the header simple)
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
            Text('${selected.length} selected', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 12),
        XpGrid(columns: 3, children: [
          EmpPair(records: data.empRecords(), labelPrefix: 'ISSUE TO', initialId: empId, onChanged: (v) => empId = v),
          EmpPair(records: data.empRecords(), labelPrefix: 'ISSUED BY', initialId: byId, onChanged: (v) => byId = v),
          XpField(label: 'UNIT', child: SearchableDropdown(value: unit, options: data.units, onChanged: (v) => setState(() => unit = v))),
          XpField(label: 'MACHINE', child: SearchableDropdown(value: machine, options: data.machines, onChanged: (v) => setState(() => machine = v))),
          XpField(label: 'WORK ORDER / JOB', child: XpInput(controller: wo, hint: 'e.g. WO-5521')),
          XpField(label: 'ISSUE DATE', child: _DateBox(value: issueDate, onChanged: (v) => setState(() => issueDate = v))),
          XpField(label: 'EXPECTED RETURN', child: _DateBox(value: expReturn, onChanged: (v) => setState(() => expReturn = v))),
        ]),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: xpBtn(busy ? 'Issuing…' : 'Confirm issue (selected tools)', kind: XpBtnKind.primary, onTap: busy ? null : _confirm),
        ),
      ]),
    );
  }
}

class _DateBox extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _DateBox({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: DateTime(now.year + 5));
        if (picked != null) {
          onChanged('${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
        }
      },
      borderRadius: BorderRadius.circular(5),
      child: InputDecorator(
        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 11)),
        child: Row(children: [
          Expanded(child: Text(value ?? 'mm/dd/yyyy', style: const TextStyle(fontSize: 12.5))),
          const Icon(Icons.calendar_today, size: 15),
        ]),
      ),
    );
  }
}
