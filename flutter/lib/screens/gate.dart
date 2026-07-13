import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

const _otherSentinel = 'Other (add new)\u2026';

String _nowStr() {
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final d = DateTime.now();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(d.day)} ${mo[d.month - 1]} ${p(d.hour)}:${p(d.minute)}';
}

// ============================================================== GATE SCREEN
class GateScreen extends StatefulWidget {
  const GateScreen({super.key});
  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  String? unit;
  String? supplier; // selected supplier value, or typed "other"
  bool supOther = false;
  final supOtherCtl = TextEditingController();
  String? recvId;
  final invNo = TextEditingController();
  String? invDate;
  final invVal = TextEditingController();
  final List<Map<String, dynamic>> drafts = [];

  String get _supplierValue => supOther ? supOtherCtl.text.trim() : (supplier ?? '');

  Future<void> _addLine() async {
    final d = await showGateEditor(context, supplier: _supplierValue, recvId: recvId, invNo: invNo.text);
    if (d != null) setState(() => context.read<AppData>().gateLines.add(d));
  }

  Future<void> _editLine(int i) async {
    final data = context.read<AppData>();
    final d = await showGateEditor(context, item: data.gateLines[i], supplier: _supplierValue, recvId: recvId, invNo: invNo.text);
    if (d != null) setState(() => data.gateLines[i] = d);
  }

  Future<void> _pass() async {
    final data = context.read<AppData>();
    if (data.gateLines.isEmpty) {
      toast(context, 'Add at least one line item first');
      return;
    }
    final lines = data.gateLines
        .map((l) => {
              'category': l['cat'],
              'name': l['name'],
              'manufacturer': l['mfr'],
              'qty': l['qty'],
              'cost': l['cost'],
              'gate_qc': l['qc'],
              'condition': l['cond'],
              'spec': l['spec'] ?? {},
            })
        .toList();
    try {
      final r = await Api.gate({
        'supplier': _supplierValue,
        'receivedBy': data.empValue(recvId).isNotEmpty ? data.empValue(recvId) : (recvId ?? 'EMP102'),
        'invoiceNo': invNo.text,
        'invoiceDate': (invDate != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(invDate!)) ? invDate : null,
        'invoiceValue': num.tryParse(invVal.text) ?? 0,
        'unit': unit ?? '',
        'lines': lines,
      });
      data.gateLines.clear();
      invNo.clear();
      invVal.clear();
      setState(() => invDate = null);
      await data.loadInventory();
      if (!mounted) return;
      final sent = (r is Map && r['sent'] != null) ? r['sent'] : lines.length;
      toast(context, '$sent item(s) sent to Inventory QC');
      context.read<AppNav>().go('qc');
    } catch (e) {
      if (mounted) toast(context, 'Gate save failed — is the API running?');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final xp = Xp.of(context);
    final records = data.empRecords();
    final supplierOpts = [...data.suppliers, _otherSentinel];

    final rows = <List<Widget>>[];
    for (var i = 0; i < data.gateLines.length; i++) {
      final l = data.gateLines[i];
      final spec = Map<String, dynamic>.from(l['spec'] as Map? ?? {});
      rows.add([
        cellText(context, '${i + 1}', mono: true),
        cellText(context, '${l['cat']}'),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          cellText(context, '${l['name']}'),
          if (spec.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(spec.entries.map((e) => '${e.key}: ${e.value}').join(' · '),
                  style: TextStyle(color: xp.mutedInk, fontSize: 10.5)),
            ),
        ]),
        cellText(context, '${l['mfr']}'),
        cellText(context, '${l['qty']}', mono: true),
        cellText(context, money(l['cost']), mono: true),
        cellText(context, money((l['qty'] as num) * (l['cost'] as num)), mono: true),
        cellText(context, '${l['cond']}'),
        xpChip('${l['qc']}'.toUpperCase()),
        Wrap(spacing: 4, children: [
          xpBtn('Edit', small: true, onTap: () => _editLine(i)),
          xpBtn('Delete', kind: XpBtnKind.del, small: true, onTap: () => setState(() => data.gateLines.removeAt(i))),
        ]),
      ]);
    }
    final grandTotal = data.gateLines.fold<num>(0, (a, l) => a + (l['qty'] as num) * (l['cost'] as num));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      xpNote(context, 'First digital checkpoint. Gate staff log the delivery once — this carries forward so the crib never re-enters it.'),
      XpPanel(
        title: 'Gate entry — header',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          XpGrid(columns: 4, children: [
            XpField(label: 'UNIT (received at)', child: SearchableDropdown(value: unit, options: data.units, hint: 'Select unit…', onChanged: (v) => setState(() => unit = v))),
            XpReadonly('DATE & TIME', _nowStr()),
            XpField(
              label: 'SUPPLIER NAME',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SearchableDropdown(
                  value: supOther ? _otherSentinel : supplier,
                  options: supplierOpts,
                  hint: 'Select supplier…',
                  onChanged: (v) => setState(() {
                    if (v == _otherSentinel) {
                      supOther = true;
                    } else {
                      supOther = false;
                      supplier = v;
                    }
                  }),
                ),
                if (supOther)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: XpInput(controller: supOtherCtl, hint: 'Type new supplier name', onChanged: (_) => setState(() {})),
                  ),
              ]),
            ),
            EmpPair(records: records, labelPrefix: 'EMPLOYEE', initialId: recvId, onChanged: (v) => recvId = v),
            XpField(label: 'SUPPLIER INVOICE NO.', child: XpInput(controller: invNo, hint: 'e.g. INV-2026-0912')),
            XpField(
                label: 'INVOICE DATE',
                child: _DateField(value: invDate, onChanged: (v) => setState(() => invDate = v))),
            XpField(label: 'INVOICE VALUE (\u20b9)', child: XpInput(controller: invVal, number: true, hint: '0')),
            XpField(
                label: 'INVOICE PHOTO',
                child: xpBtn('Attach photo (field build)', onTap: () => toast(context, 'Invoice photo capture is available in the on-site build'))),
          ]),
        ]),
      ),
      XpPanel(
        title: 'Line items + Gate QC',
        padded: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 300),
              child: XpTable(
                columns: const ['#', 'Category', 'Tool name', 'Mfr', 'Qty', 'Unit cost', 'Total', 'Condition', 'Gate QC', ''],
                flex: const [1, 4, 4, 3, 2, 3, 3, 3, 2, 4],
                rows: rows,
                emptyText: 'No line items yet — click "+ add line item"',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: xpBtn('+ add line item', kind: XpBtnKind.primary, small: true, onTap: _addLine),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(children: [
              const Spacer(),
              xpBtn('Save draft', onTap: () {
                if (data.gateLines.isEmpty) {
                  toast(context, 'Nothing to save — add a line first');
                  return;
                }
                setState(() => drafts.add({
                      'ts': _nowStr(),
                      'sup': _supplierValue,
                      'invno': invNo.text,
                      'lines': List<Map<String, dynamic>>.from(data.gateLines.map((e) => Map<String, dynamic>.from(e))),
                    }));
                toast(context, 'Draft saved');
              }),
              const SizedBox(width: 8),
              xpBtn('Pass \u2192 send to inventory', kind: XpBtnKind.green, onTap: _pass),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text('Lines: ${data.gateLines.length} · Grand total: ${money(grandTotal)}',
                style: TextStyle(color: xp.mutedInk, fontSize: 11.5)),
          ),
        ]),
      ),
      if (drafts.isNotEmpty)
        XpPanel(
          title: 'Saved drafts',
          padded: false,
          child: XpTable(
            columns: const ['Saved', 'Supplier', 'Invoice', 'Lines', 'Total', ''],
            flex: const [3, 4, 3, 1, 2, 3],
            rows: [
              for (var i = 0; i < drafts.length; i++)
                [
                  cellText(context, '${drafts[i]['ts']}', mono: true),
                  cellText(context, '${drafts[i]['sup']?.isEmpty ?? true ? '—' : drafts[i]['sup']}'),
                  cellText(context, '${(drafts[i]['invno'] as String).isEmpty ? '—' : drafts[i]['invno']}', mono: true),
                  cellText(context, '${(drafts[i]['lines'] as List).length}', mono: true),
                  cellText(context, money((drafts[i]['lines'] as List).fold<num>(0, (a, l) => a + (l['qty'] as num) * (l['cost'] as num))), mono: true),
                  Wrap(spacing: 4, children: [
                    xpBtn('Edit', small: true, onTap: () {
                      final d = drafts[i];
                      setState(() {
                        supOther = true;
                        supOtherCtl.text = '${d['sup']}';
                        invNo.text = '${d['invno']}';
                        data.gateLines
                          ..clear()
                          ..addAll(List<Map<String, dynamic>>.from((d['lines'] as List).map((e) => Map<String, dynamic>.from(e))));
                        drafts.removeAt(i);
                      });
                      toast(context, 'Draft loaded for editing');
                    }),
                    xpBtn('Delete', kind: XpBtnKind.del, small: true, onTap: () => setState(() => drafts.removeAt(i))),
                  ]),
                ],
            ],
          ),
        ),
    ]);
  }
}

// ---- date field ----
class _DateField extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _DateField({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final xp = Xp.of(context);
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: now,
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) {
          onChanged('${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
        }
      },
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(color: xp.panel, border: Border.all(color: xp.border), borderRadius: BorderRadius.circular(5)),
        child: Row(children: [
          Expanded(child: Text(value ?? 'mm/dd/yyyy', style: TextStyle(color: value == null ? xp.mutedInk : xp.ink, fontSize: 12.5))),
          Icon(Icons.calendar_today, size: 15, color: xp.mutedInk),
        ]),
      ),
    );
  }
}

// ==================================================== GATE EDITOR DIALOG
/// Returns the assembled line data map, or null if cancelled.
/// Caller decides how to persist it based on the calling context.
Future<Map<String, dynamic>?> showGateEditor(
  BuildContext context, {
  Map<String, dynamic>? item,
  String? supplier,
  String? recvId,
  String? invNo,
  String title = 'Add line item',
  String action = '+ Add to list',
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _GateEditorDialog(item: item, supplier: supplier, recvId: recvId, invNo: invNo, title: title, action: action),
  );
}

class _GateEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? item;
  final String? supplier, recvId, invNo;
  final String title, action;
  const _GateEditorDialog({this.item, this.supplier, this.recvId, this.invNo, required this.title, required this.action});
  @override
  State<_GateEditorDialog> createState() => _GateEditorDialogState();
}

class _GateEditorDialogState extends State<_GateEditorDialog> {
  String? cat;
  String? mfr;
  bool mfrOther = false;
  final mfrOtherCtl = TextEditingController();
  final scode = TextEditingController();
  final qty = TextEditingController();
  final cost = TextEditingController();
  String cond = conds.first;
  String qc = qcDecisions.first;
  final Map<String, TextEditingController> specCtl = {};
  final Map<String, String> specSelect = {}; // for select fields
  final Map<String, String> dualUnit = {}; // label -> chosen option

  @override
  void initState() {
    super.initState();
    final data = context.read<AppData>();
    final it = widget.item;
    cat = it?['cat'] ?? (data.cats.keys.isNotEmpty ? data.cats.keys.first : null);
    if (it != null) {
      mfr = it['mfr'];
      qty.text = '${it['qty'] ?? ''}';
      cost.text = '${it['cost'] ?? ''}';
      cond = (it['cond'] as String?) ?? conds.first;
      qc = (it['qc'] as String?) ?? qcDecisions.first;
    }
  }

  List<Map<String, dynamic>> get _fields => cat == null ? [] : context.read<AppData>().specFieldsForCat(cat!);

  void _prefillSpec() {
    final it = widget.item;
    if (it == null) return;
    final spec = Map<String, dynamic>.from(it['spec'] as Map? ?? {});
    spec.forEach((k, v) {
      if (k == 'Supplier tool code') {
        scode.text = '$v';
        return;
      }
      final raw = '$v'.replaceAll(RegExp(r'\s*(mm/tooth|per inch|mm|°|DP)$'), '');
      specCtl[k]?.text = raw;
      specSelect[k] = '$v';
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final xp = Xp.of(context);
    final catOpts = data.cats.keys.toList();
    final mfrOpts = [...data.suppliers, _otherSentinel];
    final fields = _fields;
    final lineTotal = (num.tryParse(qty.text) ?? 0) * (num.tryParse(cost.text) ?? 0);

    // ensure controllers exist for text/number fields
    for (final f in fields) {
      if (f['t'] != 'select' && f['t'] != 'dualunit') {
        specCtl.putIfAbsent('${f['l']}', () => TextEditingController());
      }
    }
    // prefill once fields are known
    if (widget.item != null && !(widget.item!['_prefilled'] == true)) {
      widget.item!['_prefilled'] = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(_prefillSpec));
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [xp.titleA, xp.titleB])),
            width: double.infinity,
            child: Row(children: [
              Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white, size: 18)),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Supplier: ${widget.supplier?.isEmpty ?? true ? '—' : widget.supplier}  ·  Invoice: ${widget.invNo?.isEmpty ?? true ? '—' : widget.invNo}',
                    style: TextStyle(color: xp.mutedInk, fontSize: 11)),
                const SizedBox(height: 10),
                XpField(label: 'Category', child: SearchableDropdown(value: cat, options: catOpts, onChanged: (v) => setState(() => cat = v))),
                const SizedBox(height: 8),
                XpField(
                  label: 'Manufacturer',
                  child: SearchableDropdown(
                    value: mfrOther ? _otherSentinel : mfr,
                    options: mfrOpts,
                    hint: 'Select manufacturer…',
                    onChanged: (v) => setState(() {
                      if (v == _otherSentinel) {
                        mfrOther = true;
                      } else {
                        mfrOther = false;
                        mfr = v;
                      }
                    }),
                  ),
                ),
                if (mfrOther) ...[
                  const SizedBox(height: 8),
                  XpField(label: 'New manufacturer', child: XpInput(controller: mfrOtherCtl, hint: 'Type new name (admin approves once)')),
                ],
                const SizedBox(height: 8),
                XpField(label: 'Supplier tool code', child: XpInput(controller: scode, hint: 'supplier code')),
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: XpField(label: 'Quantity', child: XpInput(controller: qty, number: true, hint: '0', onChanged: (_) => setState(() {})))),
                  const SizedBox(width: 8),
                  Expanded(child: XpField(label: 'Unit cost (\u20b9)', child: XpInput(controller: cost, number: true, hint: '0', onChanged: (_) => setState(() {})))),
                ]),
                const SizedBox(height: 8),
                XpReadonly('Line total', lineTotal > 0 ? money(lineTotal) : '\u20b9 —'),
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: XpField(label: 'Condition', child: SearchableDropdown(value: cond, options: conds, onChanged: (v) => setState(() => cond = v ?? cond)))),
                  const SizedBox(width: 8),
                  Expanded(child: XpField(label: 'Gate QC decision', child: SearchableDropdown(value: qc, options: qcDecisions, onChanged: (v) => setState(() => qc = v ?? qc)))),
                ]),
                if (fields.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('CUTTING SPECIFICATION (loads by category)',
                      style: TextStyle(color: xp.mutedInk, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: .4)),
                  const SizedBox(height: 8),
                  for (final f in fields) ...[_specField(f), const SizedBox(height: 8)],
                ],
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: xp.border))),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              xpBtn('Cancel', onTap: () => Navigator.pop(context)),
              const SizedBox(width: 8),
              xpBtn(widget.action, kind: XpBtnKind.green, onTap: _submit),
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
    final fullLabel = unit.isNotEmpty ? '$label ($unit)' : label;
    if (type == 'select') {
      final opts = List<String>.from(f['o'] as List);
      specSelect.putIfAbsent(label, () => opts.isNotEmpty ? opts.first : '');
      return XpField(label: fullLabel, child: SearchableDropdown(value: specSelect[label], options: opts, onChanged: (v) => setState(() => specSelect[label] = v ?? '')));
    }
    if (type == 'dualunit') {
      final opts = (f['o'] as List).isNotEmpty ? List<String>.from(f['o'] as List) : ['Option A', 'Option B'];
      dualUnit.putIfAbsent(label, () => opts.first);
      specCtl.putIfAbsent(label, () => TextEditingController());
      return XpField(
        label: label,
        child: Row(children: [
          for (final o in opts)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Radio<String>(value: o, groupValue: dualUnit[label], onChanged: (v) => setState(() => dualUnit[label] = v ?? o), visualDensity: VisualDensity.compact),
                Text(o, style: const TextStyle(fontSize: 12)),
              ]),
            ),
          Expanded(child: XpInput(controller: specCtl[label]!, number: true, hint: 'value')),
        ]),
      );
    }
    specCtl.putIfAbsent(label, () => TextEditingController());
    return XpField(label: fullLabel, child: XpInput(controller: specCtl[label]!, hint: unit, number: type == 'number'));
  }

  void _submit() {
    final data = context.read<AppData>();
    final spec = <String, dynamic>{};
    for (final f in _fields) {
      final label = '${f['l']}';
      final unit = '${f['u'] ?? ''}';
      final type = '${f['t']}';
      if (type == 'select') {
        final v = specSelect[label];
        if (v != null && v.isNotEmpty) spec[label] = v;
      } else if (type == 'dualunit') {
        final v = specCtl[label]?.text ?? '';
        if (v.isNotEmpty) spec[label] = '${dualUnit[label]}: $v';
      } else {
        final v = specCtl[label]?.text ?? '';
        if (v.isNotEmpty) spec[label] = unit.isNotEmpty ? '$v $unit' : v;
      }
    }
    if (scode.text.trim().isNotEmpty) spec['Supplier tool code'] = scode.text.trim();
    final category = cat ?? '';
    final name = scode.text.trim().isNotEmpty ? scode.text.trim() : category;
    var manufacturer = mfrOther ? mfrOtherCtl.text.trim() : (mfr ?? '');
    if (manufacturer.isEmpty) manufacturer = '\u2014';
    if (mfrOther && manufacturer != '\u2014' && !data.suppliers.contains(manufacturer)) {
      if (!data.supplierRequests.any((r) => r['name'] == manufacturer)) {
        data.supplierRequests.add({'name': manufacturer, 'ts': _nowStr()});
      }
    }
    Navigator.pop(context, {
      'cat': category,
      'name': name,
      'mfr': manufacturer,
      'qty': num.tryParse(qty.text) ?? 0,
      'cost': num.tryParse(cost.text) ?? 0,
      'cond': cond,
      'qc': qc,
      'spec': spec,
    });
  }
}
