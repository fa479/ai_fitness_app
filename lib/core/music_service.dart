/// FitAI Gym Music Service
///
/// Manages user's workout music library including YouTube links and
/// local audio files. Persists music data using SharedPreferences.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Type of music source.
enum MusicSourceType {
  youtube,
  phoneAudio,
}

/// A single music item in the user's library.
class MusicItem {
  final String id;
  final String title;
  final MusicSourceType sourceType;
  final String url; // YouTube URL or local file path
  final DateTime addedDate;

  const MusicItem({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.url,
    required this.addedDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sourceType': sourceType.name,
        'url': url,
        'addedDate': addedDate.toIso8601String(),
      };

  factory MusicItem.fromJson(Map<String, dynamic> j) => MusicItem(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        sourceType: MusicSourceType.values.firstWhere(
          (e) => e.name == (j['sourceType'] as String?),
          orElse: () => MusicSourceType.youtube,
        ),
        url: j['url'] as String? ?? '',
        addedDate:
            DateTime.tryParse(j['addedDate'] as String? ?? '') ?? DateTime.now(),
      );
}

class MusicService {
  MusicService._();
  static final MusicService instance = MusicService._();

  static const _kMusicLibraryKey = 'gym_music_library';

  // -------------------------------------------------------------------
  // LIBRARY MANAGEMENT
  // -------------------------------------------------------------------

  Future<List<MusicItem>> loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kMusicLibraryKey);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => MusicItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to load music library: $e');
      return [];
    }
  }

  Future<void> saveLibrary(List<MusicItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(items.map((i) => i.toJson()).toList());
    await prefs.setString(_kMusicLibraryKey, json);
  }

  Future<void> addYouTubeItem(String title, String url) async {
    final items = await loadLibrary();
    final newItem = MusicItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      sourceType: MusicSourceType.youtube,
      url: url,
      addedDate: DateTime.now(),
    );
    items.add(newItem);
    await saveLibrary(items);
  }

  Future<void> addPhoneAudioItem(String title, String filePath) async {
    final items = await loadLibrary();
    final newItem = MusicItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      sourceType: MusicSourceType.phoneAudio,
      url: filePath,
      addedDate: DateTime.now(),
    );
    items.add(newItem);
    await saveLibrary(items);
  }

  Future<void> removeItem(String id) async {
    final items = await loadLibrary();
    items.removeWhere((item) => item.id == id);
    await saveLibrary(items);
  }

  Future<bool> fileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      debugPrint('Failed to check file existence: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------
  // YOUTUBE URL VALIDATION
  // -------------------------------------------------------------------

  bool isValidYouTubeUrl(String url) {
    final youtubeRegex = RegExp(
      r'^(https?:\/\/)?(www\.)?(youtube\.com\/(watch\?v=|embed\/|v\/)|youtu\.be\/)[\w-]+',
      caseSensitive: false,
    );
    return youtubeRegex.hasMatch(url);
  }

  String extractYouTubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';

    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'] ?? '';
    } else if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    }
    return '';
  }
}
