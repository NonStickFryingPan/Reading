import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/feed_source.dart';
import '../models/article.dart';

class StorageService {
  static const String _feedsBox = 'feeds';
  static const String _bookmarksBox = 'bookmarks';
  static const String _settingsBox = 'settings';
  static const String _feedsKey = 'feed_sources';
  static const String _bookmarksKey = 'bookmarks_list';
  static const String _darkModeKey = 'dark_mode';

  Box? _feeds;
  Box? _bookmarks;
  Box? _settings;

  Future<void> init() async {
    try {
      await Hive.initFlutter();
      _feeds = await _openBox(_feedsBox);
      _bookmarks = await _openBox(_bookmarksBox);
      _settings = await _openBox(_settingsBox);
    } catch (error, stackTrace) {
      debugPrint('Storage init failed: $error\n$stackTrace');
    }
  }

  Future<Box?> _openBox(String name) async {
    try {
      return await Hive.openBox(name);
    } catch (error, stackTrace) {
      debugPrint('Failed to open Hive box "$name": $error\n$stackTrace');
      try {
        await Hive.deleteBoxFromDisk(name);
        return await Hive.openBox(name);
      } catch (retryError, retryStackTrace) {
        debugPrint(
          'Failed to recover Hive box "$name": $retryError\n$retryStackTrace',
        );
        return null;
      }
    }
  }

  Future<List<FeedSource>> loadFeeds() async {
    try {
      final stored = _feeds?.get(_feedsKey);
      if (stored is String && stored.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(stored);
        final feeds = jsonList
            .whereType<Map<String, dynamic>>()
            .map(FeedSource.fromMap)
            .toList();
        if (feeds.isNotEmpty) return feeds;
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to load stored feeds: $error\n$stackTrace');
    }
    return _loadDefaultFeeds();
  }

  Future<List<FeedSource>> _loadDefaultFeeds() async {
    try {
      final jsonString = await rootBundle.loadString('assets/feeds.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final feeds = <FeedSource>[];

      for (int i = 0; i < jsonList.length; i++) {
        final item = jsonList[i];
        if (item is Map<String, dynamic>) {
          feeds.add(FeedSource.fromMap(item).copyWith(order: i));
        }
      }

      await saveFeeds(feeds);
      return feeds;
    } catch (error, stackTrace) {
      debugPrint('Failed to load default feeds: $error\n$stackTrace');
      return [];
    }
  }

  Future<void> saveFeeds(List<FeedSource> feeds) async {
    try {
      final box = _feeds;
      if (box == null) return;
      final jsonList = feeds.map((f) => f.toMap()).toList();
      await box.put(_feedsKey, jsonEncode(jsonList));
    } catch (error, stackTrace) {
      debugPrint('Failed to save feeds: $error\n$stackTrace');
    }
  }

  List<Article> loadBookmarks() {
    try {
      final stored = _bookmarks?.get(_bookmarksKey);
      if (stored is String && stored.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(stored);
        return jsonList
            .whereType<Map<String, dynamic>>()
            .map(Article.fromMap)
            .where((article) => article.url.isNotEmpty)
            .toList();
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to load bookmarks: $error\n$stackTrace');
    }
    return [];
  }

  Future<void> saveBookmarks(List<Article> bookmarks) async {
    try {
      final box = _bookmarks;
      if (box == null) return;
      final jsonList = bookmarks.map((b) => b.toMap()).toList();
      await box.put(_bookmarksKey, jsonEncode(jsonList));
    } catch (error, stackTrace) {
      debugPrint('Failed to save bookmarks: $error\n$stackTrace');
    }
  }

  bool isDarkMode() {
    try {
      return _settings?.get(_darkModeKey, defaultValue: false) == true;
    } catch (error, stackTrace) {
      debugPrint('Failed to load dark mode setting: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> setDarkMode(bool value) async {
    try {
      await _settings?.put(_darkModeKey, value);
    } catch (error, stackTrace) {
      debugPrint('Failed to save dark mode setting: $error\n$stackTrace');
    }
  }
}
