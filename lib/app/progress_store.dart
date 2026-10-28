import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which lessons are done, whether the intro was seen, and whether
/// the field guide was closed.
abstract class ProgressStore {
  Future<Set<String>> completedLessons();
  Future<void> saveCompletedLessons(Set<String> ids);
  Future<bool> introSeen();
  Future<void> saveIntroSeen();
  Future<bool> guideHidden();
  Future<void> saveGuideHidden(bool hidden);
}

class PrefsProgressStore implements ProgressStore {
  static const _lessonsKey = 'lessons.completed';
  static const _introKey = 'intro.seen';
  static const _guideKey = 'guide.hidden';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<Set<String>> completedLessons() async => (await _prefs).getStringList(_lessonsKey)?.toSet() ?? {};

  @override
  Future<void> saveCompletedLessons(Set<String> ids) async =>
      (await _prefs).setStringList(_lessonsKey, ids.toList()..sort());

  @override
  Future<bool> introSeen() async => (await _prefs).getBool(_introKey) ?? false;

  @override
  Future<void> saveIntroSeen() async => (await _prefs).setBool(_introKey, true);

  @override
  Future<bool> guideHidden() async => (await _prefs).getBool(_guideKey) ?? false;

  @override
  Future<void> saveGuideHidden(bool hidden) async => (await _prefs).setBool(_guideKey, hidden);
}

class MemoryProgressStore implements ProgressStore {
  MemoryProgressStore({Set<String>? completed, this.seen = false, this.hideGuide = false})
    : completed = completed ?? {};

  final Set<String> completed;
  bool seen;
  bool hideGuide;

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

  @override
  Future<bool> guideHidden() async => hideGuide;

  @override
  Future<void> saveGuideHidden(bool hidden) async => hideGuide = hidden;
}
