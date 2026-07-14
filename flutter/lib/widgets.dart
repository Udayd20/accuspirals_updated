import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'theme.dart';

final _rupee = NumberFormat.currency(locale: 'en_IN', symbol: '\u20b9 ', decimalDigits: 0);
String money(dynamic v) => _rupee.format((v is num) ? v : num.tryParse('$v') ?? 0);

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2200)));
}

Color _chipColor(String s) {
  switch (s) {
    case 'AVAILABLE':
      return Brand.green;
    case 'ISSUED':
      return Brand.amber;
    case 'REGRINDING':
    case 'REPAIR':
      return Brand.purple;
    case 'SCRAP':
    case 'REJECTED':
      return Brand.red;
    case 'Pass':
    case 'PASS':
      return Brand.green;
    case 'Hold':
    case 'HOLD':
      return Brand.amber;
    case 'Reject':
    case 'REJECT':
      return Brand.red;
    default:
      return Colors.blueGrey;
  }
}

Widget xpChip(String s, {Color? color}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color ?? _chipColor(s), borderRadius: BorderRadius.circular(11)),
      child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );

/// An XP task-pane style panel: header strip + body.
class XpPanel extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  final bool padded;
  const XpPanel({super.key, required this.title, required this.child, this.trailing, this.padded = true});
  @override
  Widget build(BuildContext context) {
    final xp = Xp.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      decoration: BoxDecoration(
        color: xp.panel,
        border: Border.all(color: xp.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: xp.panelHead,
            border: Border(bottom: BorderSide(color: xp.border)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
          child: Row(children: [
            Expanded(
                child: Text(title.toUpperCase(),
                    style: TextStyle(color: xp.ink, fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: .4))),
            if (trailing != null) trailing!,
          ]),
        ),
        Padding(padding: EdgeInsets.all(padded ? 12 : 0), child: child),
      ]),
    );
  }
}

/// The amber "note" info banner used above several screens.
Widget xpNote(BuildContext context, String text) {
  final xp = Xp.of(context);
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Brand.amber.withOpacity(.12),
      border: Border.all(color: Brand.amber.withOpacity(.45)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: TextStyle(color: xp.ink, fontSize: 12.5)),
  );
}

Widget xpHint(BuildContext context, String text) {
  final xp = Xp.of(context);
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(text, style: TextStyle(color: xp.mutedInk, fontSize: 11.5, fontStyle: FontStyle.italic)),
  );
}

Widget xpEmpty(BuildContext context, String text) {
  final xp = Xp.of(context);
  return Padding(
    padding: const EdgeInsets.all(18),
    child: Center(child: Text(text, style: TextStyle(color: xp.mutedInk, fontSize: 12.5))),
  );
}

/// A label + read-only value box (the many `<div class="inp ro">` cells).
class XpReadonly extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const XpReadonly(this.label, this.value, {super.key, this.mono = false});
  @override
  Widget build(BuildContext context) {
    final xp = Xp.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: TextStyle(color: xp.mutedInk, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: .3)),
      const SizedBox(height: 3),
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 34),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: xp.statusA,
          border: Border.all(color: xp.border),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(value,
            style: TextStyle(
                color: xp.ink, fontSize: 12.5, fontFamily: mono ? 'monospace' : null)),
      ),
    ]);
  }
}

/// A label above an arbitrary editable field widget.
class XpField extends StatelessWidget {
  final String label;
  final Widget child;
  const XpField({super.key, required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    final xp = Xp.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: TextStyle(color: xp.mutedInk, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: .3)),
      const SizedBox(height: 3),
      child,
    ]);
  }
}

/// Responsive grid used for header field blocks (grid2 / grid3 / grid4).
class XpGrid extends StatelessWidget {
  final int columns;
  final List<Widget> children;
  final double gap;
  const XpGrid({super.key, required this.columns, required this.children, this.gap = 12});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (c, cons) {
      final cols = cons.maxWidth < 560 ? 1 : (cons.maxWidth < 860 ? (columns > 2 ? 2 : columns) : columns);
      final w = (cons.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w > 0 ? w : cons.maxWidth, child: ch)],
      );
    });
  }
}

// ------- buttons matching the web .btn variants -------
enum XpBtnKind { normal, primary, green, amber, red, purple, del }

Widget xpBtn(String label, {required VoidCallback? onTap, XpBtnKind kind = XpBtnKind.normal, bool small = false, IconData? icon}) {
  return Builder(builder: (context) {
    final xp = Xp.of(context);
    Color bg, fg = Colors.white;
    switch (kind) {
      case XpBtnKind.primary:
        bg = Brand.blue;
        break;
      case XpBtnKind.green:
        bg = Brand.green;
        break;
      case XpBtnKind.amber:
        bg = Brand.amber;
        break;
      case XpBtnKind.red:
      case XpBtnKind.del:
        bg = Brand.red;
        break;
      case XpBtnKind.purple:
        bg = Brand.purple;
        break;
      case XpBtnKind.normal:
        bg = xp.panelHead;
        fg = xp.ink;
        break;
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: small ? 9 : 13, vertical: small ? 5 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: kind == XpBtnKind.normal ? Border.all(color: xp.border) : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: small ? 13 : 15, color: fg), const SizedBox(width: 5)],
            Text(label, style: TextStyle(color: fg, fontSize: small ? 11.5 : 12.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  });
}

/// A searchable dropdown, matching the web app's "type to search" selects.
/// [options] holds the underlying values; [labelFor] maps a value to its display.
class SearchableDropdown extends StatelessWidget {
  final String? value;
  final List<String> options;
  final String hint;
  final ValueChanged<String?> onChanged;
  final String Function(String)? labelFor;
  const SearchableDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint = 'Select\u2026',
    this.labelFor,
  });

  String _label(String v) => labelFor?.call(v) ?? v;

  Future<void> _pick(BuildContext context) async {
    final xp = Xp.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        var query = '';
        return StatefulBuilder(builder: (ctx, setLocal) {
          final filtered = options.where((o) => _label(o).toLowerCase().contains(query.toLowerCase())).toList();
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Type to search\u2026', prefixIcon: Icon(Icons.search)),
                    onChanged: (v) => setLocal(() => query = v),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: filtered.isEmpty
                      ? Padding(padding: const EdgeInsets.all(20), child: Text('No matches', style: TextStyle(color: xp.mutedInk)))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (c, i) {
                            final o = filtered[i];
                            return ListTile(
                              dense: true,
                              selected: o == value,
                              title: Text(_label(o)),
                              onTap: () => Navigator.pop(ctx, o),
                            );
                          },
                        ),
                ),
              ]),
            ),
          );
        });
      },
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final xp = Xp.of(context);
    final display = (value != null && value!.isNotEmpty) ? _label(value!) : hint;
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        decoration: BoxDecoration(
          color: xp.panel,
          border: Border.all(color: xp.border),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(children: [
          Expanded(
              child: Text(display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: (value != null && value!.isNotEmpty) ? xp.ink : xp.mutedInk, fontSize: 12.5))),
          Icon(Icons.arrow_drop_down, size: 20, color: xp.mutedInk),
        ]),
      ),
    );
  }
}

/// A styled single-line text input matching `.inp`.
class XpInput extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final bool number;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  const XpInput({super.key, required this.controller, this.hint, this.number = false, this.keyboardType, this.onChanged});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType ?? (number ? const TextInputType.numberWithOptions(decimal: true) : null),
      onChanged: onChanged,
      decoration: InputDecoration(hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10)),
    );
  }
}

/// A lightweight dense table (header row + data rows), horizontally scrollable.
class XpTable extends StatelessWidget {
  final List<String> columns;
  final List<List<Widget>> rows;
  final String emptyText;
  final List<int>? flex; // relative column widths
  const XpTable({super.key, required this.columns, required this.rows, this.emptyText = 'No data', this.flex});
  @override
  Widget build(BuildContext context) {
    final xp = Xp.of(context);
    List<int> f = flex ?? List.filled(columns.length, 1);
    Widget headerCell(String c, int i) => Expanded(
          flex: f[i],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(c, style: TextStyle(color: xp.mutedInk, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        decoration: BoxDecoration(color: xp.panelHead, border: Border(bottom: BorderSide(color: xp.border))),
        child: Row(children: [for (var i = 0; i < columns.length; i++) headerCell(columns[i], i)]),
      ),
      if (rows.isEmpty)
        xpEmpty(context, emptyText)
      else
        for (var r = 0; r < rows.length; r++)
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: xp.border.withOpacity(.5)))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < columns.length; i++)
                  Expanded(
                    flex: f[i],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      child: i < rows[r].length ? rows[r][i] : const SizedBox(),
                    ),
                  ),
              ],
            ),
          ),
    ]);
  }
}

Widget cellText(BuildContext context, String s, {bool mono = false, double size = 12}) {
  final xp = Xp.of(context);
  return Text(s,
      style: TextStyle(color: xp.ink, fontSize: size, fontFamily: mono ? 'monospace' : null));
}

/// Paired employee ID + Name dropdowns that stay in sync (matches empPair()).
/// Reports the selected employee **id** via [onChanged].
class EmpPair extends StatefulWidget {
  final String labelPrefix; // e.g. "EMPLOYEE", "ISSUE TO", "ISSUED BY"
  final String? initialId;
  final ValueChanged<String?> onChanged;
  final List<Map<String, String>> records; // from AppData.empRecords()
  const EmpPair(
      {super.key, required this.records, required this.onChanged, this.labelPrefix = 'EMPLOYEE', this.initialId});
  @override
  State<EmpPair> createState() => _EmpPairState();
}

class _EmpPairState extends State<EmpPair> {
  String? id;
  @override
  void initState() {
    super.initState();
    id = widget.initialId ?? (widget.records.isNotEmpty ? widget.records.first['id'] : null);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onChanged(id));
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.records.map((r) => r['id']!).toList();
    String nameFor(String v) {
      final r = widget.records.firstWhere((x) => x['id'] == v, orElse: () => {});
      return (r['name']?.isNotEmpty ?? false) ? r['name']! : v;
    }

    void set(String? v) {
      setState(() => id = v);
      widget.onChanged(v);
    }

    return XpGrid(columns: 2, children: [
      XpField(
        label: '${widget.labelPrefix} ID',
        child: SearchableDropdown(value: id, options: ids, onChanged: set),
      ),
      XpField(
        label: '${widget.labelPrefix} NAME',
        child: SearchableDropdown(value: id, options: ids, labelFor: nameFor, onChanged: set),
      ),
    ]);
  }
}
