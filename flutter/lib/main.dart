import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'api.dart';
import 'state.dart';
import 'widgets.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard.dart';
import 'screens/gate.dart';
import 'screens/qc.dart';
import 'screens/tools.dart';
import 'screens/detail.dart';
import 'screens/issue.dart';
import 'screens/returns.dart';
import 'screens/regrind.dart';
import 'screens/reports.dart';
import 'screens/admin.dart';
import 'screens/add_tool.dart';

void main() {
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => ThemeController()),
    ChangeNotifierProvider(create: (_) => Session()),
    ChangeNotifierProvider(create: (_) => AppData()),
    ChangeNotifierProvider(create: (_) => AppNav()),
  ], child: const App()));
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return MaterialApp(
      title: 'ACCUSPIRALS Inventory',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: theme.mode,
      home: const Boot(),
    );
  }
}

/// Restores any saved session on launch, then shows login or the shell.
class Boot extends StatefulWidget {
  const Boot({super.key});
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  bool ready = false;
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final session = context.read<Session>();
    final data = context.read<AppData>();
    // Any 401 anywhere -> drop back to the login screen (mirrors on401()).
    Api.onUnauthorized = () {
      if (mounted && session.loggedIn) {
        session.logout();
        toast(context, 'Session expired — please log in again');
      }
    };
    await session.restore();
    if (session.loggedIn) {
      await data.loadAll(session);
    }
    if (mounted) setState(() => ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final session = context.watch<Session>();
    return session.loggedIn ? const HomeShell() : const LoginScreen();
  }
}

// ================================================================= HOME SHELL
class NavEntry {
  final String id;
  final String label;
  final IconData icon;
  final String section;
  const NavEntry(this.id, this.label, this.icon, this.section);
}

const _navEntries = <NavEntry>[
  NavEntry('dash', 'Dashboard', Icons.dashboard, 'MANAGEMENT'),
  NavEntry('gate', 'Gate Entry', Icons.input, 'RECEIVING'),
  NavEntry('qc', 'Pending Inventory QC', Icons.verified, 'RECEIVING'),
  NavEntry('tools', 'Tools & Consumables', Icons.folder, 'INVENTORY'),
  NavEntry('detail', 'Tool Details', Icons.search, 'INVENTORY'),
  NavEntry('issue', 'Issue', Icons.north_east, 'MOVEMENT'),
  NavEntry('return', 'Return', Icons.south_west, 'MOVEMENT'),
  NavEntry('regrind', 'Regrinding / Repair', Icons.build, 'MOVEMENT'),
  NavEntry('reports', 'Reports', Icons.insights, 'SETUP'),
  NavEntry('admin', 'Admin', Icons.settings, 'SETUP'),
];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    // Land on the first screen the role may open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<Session>();
      final nav = context.read<AppNav>();
      final allow = s.allowedScreens();
      nav.go(allow.contains('dash') ? 'dash' : (allow.isNotEmpty ? allow.first : 'dash'));
    });
  }

  void _go(String s) {
    final allow = context.read<Session>().allowedScreens();
    if (!allow.contains(s)) {
      toast(context, "Your role doesn't have access to that screen");
      s = allow.contains('dash') ? 'dash' : (allow.isNotEmpty ? allow.first : 'dash');
    }
    context.read<AppNav>().go(s);
  }

  Widget _screenFor(String id) {
    switch (id) {
      case 'gate':
        return const GateScreen();
      case 'qc':
        return const QcScreen();
      case 'tools':
        return const ToolsScreen();
      case 'detail':
        return const ToolDetailScreen();
      case 'issue':
        return const IssueScreen();
      case 'return':
        return const ReturnScreen();
      case 'regrind':
        return const RegrindScreen();
      case 'reports':
        return const ReportsScreen();
      case 'admin':
        return const AdminScreen();
      case 'dash':
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final xp = Xp.of(context);
    final nav = context.watch<AppNav>();
    final narrow = MediaQuery.of(context).size.width < 820;
    return Scaffold(
      backgroundColor: xp.desktop,
      drawer: narrow ? _MobileNav(go: _go) : null,
      body: SafeArea(
        child: Column(children: [
          const _TitleBar(),
          _Toolbar(go: _go),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!narrow) _Sidebar(go: _go),
              Expanded(
                child: Container(
                  color: xp.chrome,
                  child: Column(children: [
                    _HeaderStrip(screen: nav.screen, showMenu: narrow),
                    Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(14), child: _screenFor(nav.screen))),
                  ]),
                ),
              ),
            ]),
          ),
          const _StatusBar(),
        ]),
      ),
    );
  }
}

// -------- title bar with live clock --------
class _TitleBar extends StatefulWidget {
  const _TitleBar();
  @override
  State<_TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<_TitleBar> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _clock() {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${wd[d.weekday - 1]}, ${p(d.day)} ${mo[d.month - 1]} ${d.year}  \u00b7  ${p(d.hour)}:${p(d.minute)}:${p(d.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final xp = Xp.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [xp.titleA, xp.titleB], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: Row(children: [
        Container(
            width: 20, height: 20,
            decoration: BoxDecoration(color: Brand.brass, borderRadius: BorderRadius.circular(4)),
            child: const Icon(Icons.settings, size: 13, color: Color(0xFF5A3D05))),
        const SizedBox(width: 9),
        const Text('ACCUSPIRALS Tool & Consumables Inventory — v1.0',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
        const Spacer(),
        Text(_clock(), style: const TextStyle(color: Color(0xFFD8E6FA), fontSize: 12, fontFamily: 'monospace')),
        const SizedBox(width: 10),
        _winBtn(Icons.remove), _winBtn(Icons.crop_square), _winBtn(Icons.close, close: true),
      ]),
    );
  }

  Widget _winBtn(IconData i, {bool close = false}) => Container(
        margin: const EdgeInsets.only(left: 4),
        width: 26, height: 20,
        decoration: BoxDecoration(
          color: close ? const Color(0xFFC0392B) : Colors.white24,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white38),
        ),
        child: Icon(i, size: 12, color: Colors.white),
      );
}

// -------- toolbar --------
class _Toolbar extends StatelessWidget {
  final void Function(String) go;
  const _Toolbar({required this.go});
  @override
  Widget build(BuildContext context) {
    final xp = Xp.of(context);
    final theme = context.watch<ThemeController>();
    Widget btn(IconData i, String label, Color g, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: Row(children: [
              Container(width: 22, height: 22, decoration: BoxDecoration(color: g, borderRadius: BorderRadius.circular(5)), child: Icon(i, size: 13, color: Colors.white)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: xp.ink, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ]),
          ),
        );
    final sep = Container(width: 1, height: 26, color: xp.chromeLine, margin: const EdgeInsets.symmetric(horizontal: 5));
    return Container(
      decoration: BoxDecoration(color: xp.chrome, border: Border(bottom: BorderSide(color: xp.chromeLine))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(children: [
          btn(Icons.add, 'New Gate Entry', Brand.blue, () => go('gate')),
          sep,
          btn(Icons.save, 'Save', Colors.blueGrey, () => toast(context, 'Saved')),
          btn(Icons.print, 'Print', Colors.blueGrey, () => toast(context, 'Sent to printer (demo)')),
          sep,
          btn(Icons.search, 'Search', Brand.amber, () => go('tools')),
          btn(Icons.north_east, 'Issue', Brand.purple, () => go('issue')),
          btn(Icons.close, 'Delete', Brand.red, () => toast(context, 'Select a tool, then Delete')),
          sep,
          btn(theme.isDark ? Icons.light_mode : Icons.dark_mode, theme.isDark ? 'Light mode' : 'Dark mode', Brand.amber, theme.toggle),
          sep,
          btn(Icons.logout, 'Logout', Brand.red, () => context.read<Session>().logout()),
        ]),
      ),
    );
  }
}

// -------- sidebar (permission gated) --------
class _Sidebar extends StatelessWidget {
  final void Function(String) go;
  const _Sidebar({required this.go});
  @override
  Widget build(BuildContext context) {
    final xp = Xp.of(context);
    final session = context.watch<Session>();
    final data = context.watch<AppData>();
    final nav = context.watch<AppNav>();
    final allow = session.allowedScreens();
    final sections = ['MANAGEMENT', 'RECEIVING', 'INVENTORY', 'MOVEMENT', 'SETUP'];
    return Container(
      width: 224,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [xp.paneA, xp.paneB], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        border: Border(right: BorderSide(color: xp.chromeLine)),
      ),
      child: ListView(padding: const EdgeInsets.all(8), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ACCUSPIRALS', style: TextStyle(color: xp.titleB, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: .5)),
            Text('TOOL & CONSUMABLES INVENTORY', style: TextStyle(color: xp.mutedInk, fontSize: 8.5, letterSpacing: .5)),
          ]),
        ),
        for (final sec in sections) ...[
          if (_navEntries.any((e) => e.section == sec && allow.contains(e.id)))
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
              child: Text(sec, style: TextStyle(color: xp.mutedInk, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          for (final e in _navEntries.where((e) => e.section == sec && allow.contains(e.id)))
            _tile(context, xp, e, nav.screen == e.id, e.id == 'qc' ? data.qcQueue.length : 0),
        ],
      ]),
    );
  }

  Widget _tile(BuildContext context, Xp xp, NavEntry e, bool selected, int badge) {
    return InkWell(
      onTap: () => go(e.id),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(color: selected ? xp.navSel : Colors.transparent, borderRadius: BorderRadius.circular(5)),
        child: Row(children: [
          Icon(e.icon, size: 18, color: selected ? xp.navSelInk : xp.ink),
          const SizedBox(width: 9),
          Expanded(child: Text(e.label, style: TextStyle(color: selected ? xp.navSelInk : xp.ink, fontSize: 12.6))),
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Brand.red, borderRadius: BorderRadius.circular(9)),
              child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ]),
      ),
    );
  }
}

class _MobileNav extends StatelessWidget {
  final void Function(String) go;
  const _MobileNav({required this.go});
  @override
  Widget build(BuildContext context) {
    final xp = Xp.of(context);
    final allow = context.watch<Session>().allowedScreens();
    final nav = context.watch<AppNav>();
    return Drawer(
      child: Container(
        color: xp.paneA,
        child: ListView(children: [
          DrawerHeader(child: Center(child: Text('ACCUSPIRALS', style: TextStyle(color: xp.titleB, fontWeight: FontWeight.bold)))),
          for (final e in _navEntries.where((e) => allow.contains(e.id)))
            ListTile(
              leading: Icon(e.icon, color: nav.screen == e.id ? xp.navSel : xp.ink),
              title: Text(e.label),
              selected: nav.screen == e.id,
              onTap: () {
                go(e.id);
                Navigator.pop(context);
              },
            ),
        ]),
      ),
    );
  }
}

// -------- header context strip --------
class _HeaderStrip extends StatelessWidget {
  final String screen;
  final bool showMenu;
  const _HeaderStrip({required this.screen, required this.showMenu});
  @override
  Widget build(BuildContext context) {
    final xp = Xp.of(context);
    final session = context.watch<Session>();
    final t = screenTitles[screen] ?? [screen, ''];
    final sheet = (screenOrder.indexOf(screen) + 1).toString().padLeft(2, '0');
    Widget cell(String k, String v) => Padding(
          padding: const EdgeInsets.only(left: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(k, style: const TextStyle(color: Color(0xFFB9CEEC), fontSize: 9, letterSpacing: .8)),
            Text(v, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
          ]),
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [xp.titleA, xp.titleB])),
      child: Row(children: [
        if (showMenu)
          Builder(
              builder: (c) => IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.menu, color: Colors.white, size: 20),
                  onPressed: () => Scaffold.of(c).openDrawer())),
        if (showMenu) const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(t[0], style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            Text(t[1], style: const TextStyle(color: Color(0xFFD3E2F5), fontSize: 10.5, letterSpacing: .5)),
          ]),
        ),
        if (!showMenu) ...[
          cell('SHEET', '$sheet / 10'),
          cell('UNITS', 'U1 · U2 · U3'),
          cell('USER', session.userChip),
        ] else
          cell('SHEET', '$sheet / 10'),
      ]),
    );
  }
}

// -------- footer status bar --------
class _StatusBar extends StatelessWidget {
  const _StatusBar();
  @override
  Widget build(BuildContext context) {
    final xp = Xp.of(context);
    final session = context.watch<Session>();
    if (session.role != 'Admin') return const SizedBox.shrink();
    final data = context.watch<AppData>();
    final total = data.tools.length;
    final avail = data.tools.where((t) => t['status'] == 'AVAILABLE').length;
    final issued = data.tools.where((t) => t['status'] == 'ISSUED').length;
    Widget cell(String label, String v) => Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$label: ', style: TextStyle(color: xp.mutedInk, fontSize: 12)),
            TextSpan(text: v, style: TextStyle(color: xp.ink, fontSize: 12, fontWeight: FontWeight.bold)),
          ])),
        );
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [xp.statusA, xp.statusB]),
        border: Border(top: BorderSide(color: xp.chromeLine)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          cell('Total tools', '$total'),
          cell('Available', '$avail'),
          cell('Issued', '$issued'),
          cell('Pending QC', '${data.qcQueue.length}'),
          const SizedBox(width: 26),
          Text('Total inventory value: ${money(data.invValue())}', style: TextStyle(color: xp.ink, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

// Convenience: trigger the Add-Tool dialog from anywhere.
void openAddTool(BuildContext context) {
  showAddToolDialog(context);
}
