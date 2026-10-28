import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which lessons are done and whether the intro was seen.
abstract class ProgressStore {
  Future<Set<String>> completedLessons();
  Future<void> saveCompletedLessons(Set<String> ids);
  Future<bool> introSeen();
  Future<void> saveIntroSeen();
}

class PrefsProgressStore implements ProgressStore {
  static const _lessonsKey = 'lessons.completed';
  static const _introKey = 'intro.seen';

  @override
  Future<Set<String>> completedLessons() async =>
      (await SharedPreferences.getInstance()).getStringList(_lessonsKey)?.toSet() ?? {};

  @override
  Future<void> saveCompletedLessons(Set<String> ids) async =>
      (await SharedPreferences.getInstance()).setStringList(_lessonsKey, ids.toList()..sort());

  @override
  Future<bool> introSeen() async => (await SharedPreferences.getInstance()).getBool(_introKey) ?? false;

  @override
  Future<void> saveIntroSeen() async => (await SharedPreferences.getInstance()).setBool(_introKey, true);
}

class MemoryProgressStore implements ProgressStore {
  MemoryProgressStore({Set<String>? completed, this.seen = false}) : completed = completed ?? {};

  final Set<String> completed;
  bool seen;

  @override
  Future<Set<String>> completedLessons() async => {...completed};

  @override
  Future<void> saveCompletedLessons(Set<String> ids) async => completed
    ..clear()
    ..addAll(ids);

  @override
  Future<bool> introSeen() async => seen;

  @override
  Future<void> saveIntroSeen() async => seen = true;
}
