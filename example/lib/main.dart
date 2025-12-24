
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gvl_comments/gvl_comments.dart';
import 'package:gvl_comments/l10n/gvl_comments_l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Public demo key for the example app only (bound to example package/bundle).
const _demoInstallKey = 'cmt_live_EyuFlFVL682oiBVMealY2TfykRvJSDlF4Hbb8G2inhw';

/// Stable guest identity stored on the device/emulator.
const _kGuestIdKey = 'gvl_demo_guest_id';
const _kGuestNameKey = 'gvl_demo_guest_name';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CommentsKit.initialize(installKey: _demoInstallKey);

  final user = await _loadGuestUser();

  runApp(DemoApp(user: user));
}

class DemoApp extends StatelessWidget {
  final UserProfile user;

  const DemoApp({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GVL Comments Demo',
      localizationsDelegates: GvlCommentsL10n.localizationsDelegates,
      supportedLocales: GvlCommentsL10n.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
      ),
      home: Builder(
        // IMPORTANT: this context is below MaterialApp, so Theme.of(context)
        // is the one we configured above.
        builder: (context) => DemoHome(initialUser: user),
      ),
    );
  }
}

class DemoHome extends StatefulWidget {
  final UserProfile initialUser;

  const DemoHome({
    super.key,
    required this.initialUser,
  });

  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  late UserProfile _user = widget.initialUser;

  Future<void> _rerollGuest() async {
    final newUser = await _regenerateGuestUser();

    // Keep auth consistent when switching identities.
    CommentsKit.I().invalidateToken();
    await CommentsKit.I().identify(newUser);

    if (!mounted) return;
    setState(() => _user = newUser);
  }

  @override
  Widget build(BuildContext context) {
    final theme = GvlCommentsThemeData.bubble(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('GVL Comments · Flutter'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'New guest',
            icon: const Icon(Icons.casino),
            onPressed: _rerollGuest,
          ),
        ],
      ),
      body: CommentsList(
        threadKey: 'demo:flutter.comments.v1',
        newestAtBottom: false,
        limit: 10,
        user: _user,
        theme: theme,
      ),
    );
  }
}

Future<UserProfile> _loadGuestUser() async {
  final prefs = await SharedPreferences.getInstance();

  var id = prefs.getString(_kGuestIdKey);
  var name = prefs.getString(_kGuestNameKey);

  if (id == null || id.isEmpty || name == null || name.isEmpty) {
    final created = _createGuest();
    id = created.$1;
    name = created.$2;

    await prefs.setString(_kGuestIdKey, id);
    await prefs.setString(_kGuestNameKey, name);
  }

  return UserProfile(
    id: 'guest_$id',
    name: name,
    avatarUrl: 'https://api.dicebear.com/7.x/identicon/png?seed=$id',
  );
}

Future<UserProfile> _regenerateGuestUser() async {
  final prefs = await SharedPreferences.getInstance();

  final created = _createGuest();
  await prefs.setString(_kGuestIdKey, created.$1);
  await prefs.setString(_kGuestNameKey, created.$2);

  return UserProfile(
    id: 'guest_${created.$1}',
    name: created.$2,
    avatarUrl: 'https://api.dicebear.com/7.x/identicon/png?seed=${created.$1}',
  );
}

(String, String) _createGuest() {
  final rnd = Random();

  const animals = <String>[
    'Falcon',
    'Wolf',
    'Panther',
    'Raven',
    'Tiger',
    'Cobra',
    'Orca',
    'Lynx',
  ];

  const adjectives = <String>[
    'Swift',
    'Silent',
    'Bold',
    'Sharp',
    'Calm',
    'Fierce',
    'Brave',
    'Bright',
  ];

  final animal = animals[rnd.nextInt(animals.length)];
  final adj = adjectives[rnd.nextInt(adjectives.length)];
  final num = 10 + rnd.nextInt(90);

  final id = _randomId(10, rnd);
  final name = 'Guest $adj $animal-$num';

  return (id, name);
}

String _randomId(int len, Random rnd) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
}
