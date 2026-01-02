import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gvl_comments/gvl_comments.dart';

const _kGuestIdKey = 'gvl_demo_guest_id';
const _kGuestNameKey = 'gvl_demo_guest_name';

Future<UserProfile> loadGuestUser() async {
  final prefs = await SharedPreferences.getInstance();

  var id = prefs.getString(_kGuestIdKey);
  var name = prefs.getString(_kGuestNameKey);

  if (id == null || name == null) {
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

/// Optional: call this from a button to reroll.
Future<UserProfile> regenerateGuestUser() async {
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
  const animals = [
    'Falcon',
    'Wolf',
    'Panther',
    'Raven',
    'Tiger',
    'Cobra',
    'Orca',
    'Lynx',
  ];
  const adjectives = [
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
