import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quote_service.dart';

class AppState extends ChangeNotifier {
  static const _kBgColor = 'bg_color';
  static const _kFavs = 'favorites_json';
  static const _kLastCategory = 'last_category';
  static const _kOnboarding = 'onboarding_done_v1';

  Color color;

  // favourites
  final List<Quote> _favorites = [];
  final Set<String> _favKeys = {};

  // last used category
  String? _lastCategoryName;

  bool _onboardingComplete = false;

  AppState._({
    required this.color,
  });

  /// Create with defaults and load persisted state asynchronously.
  factory AppState.init() {
    final s = AppState._(color: Colors.black);
    Future.microtask(() => s._load());
    return s;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final colorInt = prefs.getInt(_kBgColor);
    if (colorInt != null) color = Color(colorInt);

    _lastCategoryName = prefs.getString(_kLastCategory);
    _onboardingComplete = prefs.getBool(_kOnboarding) ?? false;
    final favStr = prefs.getString(_kFavs);
    if (favStr != null && favStr.isNotEmpty) {
      try {
        final list = (jsonDecode(favStr) as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        _favorites
          ..clear()
          ..addAll(list.map((m) => Quote(
                (m['content'] ?? '').toString(),
                (m['author'] ?? 'Unknown').toString(),
                'Local',
              )));
        _favKeys
          ..clear()
          ..addAll(_favorites.map(_keyFor));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _saveColor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBgColor, color.value);
  }

  Future<void> _saveFavs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _favorites
        .map((q) => {'content': q.content, 'author': q.author})
        .toList();
    await prefs.setString(_kFavs, jsonEncode(data));
  }

  Future<void> _saveLastCategory() async {
    final prefs = await SharedPreferences.getInstance();
    if (_lastCategoryName == null) {
      await prefs.remove(_kLastCategory);
    } else {
      await prefs.setString(_kLastCategory, _lastCategoryName!);
    }
  }

  // === PUBLIC API ===

  // Background color
  void setColor(Color c) {
    color = c;
    _saveColor();
    notifyListeners();
  }

  // Favourites
  List<Quote> get favorites => List.unmodifiable(_favorites);

  bool isFavorite(Quote q) => _favKeys.contains(_keyFor(q));

  void toggleFavorite(Quote q) {
    final k = _keyFor(q);
    if (_favKeys.contains(k)) {
      _favKeys.remove(k);
      _favorites.removeWhere((e) => _keyFor(e) == k);
    } else {
      _favKeys.add(k);
      _favorites.insert(0, Quote(q.content, q.author, 'Local'));
    }
    _saveFavs();
    notifyListeners();
  }

  // Last used category
  String? get lastCategoryName => _lastCategoryName;

  void setLastCategory(String name) {
    _lastCategoryName = name;
    _saveLastCategory();
    notifyListeners();
  }

  void clearLastCategory() {
    _lastCategoryName = null;
    _saveLastCategory();
    notifyListeners();
  }

  bool get needsOnboarding => !_onboardingComplete;

  void markOnboardingSeen() {
    if (_onboardingComplete) return;
    _onboardingComplete = true;
    _saveOnboarding();
    notifyListeners();
  }

  Future<void> _saveOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarding, _onboardingComplete);
  }

  // Contrast helpers
  bool get isDark {
    final lum = color.computeLuminance(); // W3C relative luminance
    return lum < 0.5;
  }

  Color get foreground => isDark ? Colors.white : Colors.black87;

  static String _keyFor(Quote q) =>
      '${q.content.trim().toLowerCase()}|${q.author.trim().toLowerCase()}';
}
