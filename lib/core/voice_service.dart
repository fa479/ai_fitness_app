/// FitAI Voice Service
///
/// Wraps speech-to-text (STT) and text-to-speech (TTS) so the AI coach
/// can be used entirely by voice. Each supported language carries STT/TTS
/// locale metadata; when a language is not supported on the device the
/// service reports that honestly instead of pretending to listen.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../app/app_localizations.dart';

/// Callback type for partial/final speech results.
typedef VoiceResult = void Function(String text, bool isFinal);

/// Callback type for status updates (listening, not listening, errors).
typedef VoiceStatus = void Function(VoiceState state);

/// High-level state of the voice pipeline.
enum VoiceState { idle, listening, thinking, speaking, error, unsupported }

class VoiceService {
  VoiceService._internal();
  static final VoiceService instance = VoiceService._internal();

  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttAvailable = false;
  bool _ttsReady = false;
  bool _listening = false;
  void Function()? _onTtsComplete;

  /// Whether STT can be used on this device right now.
  bool get isSttAvailable => _sttAvailable;

  /// Whether the current language has a known STT locale.
  bool get currentLanguageSupportsStt => L.language.supportsStt;

  /// Whether the current language has a known TTS locale.
  bool get currentLanguageSupportsTts => L.language.supportsTts;

  /// Initialize the speech engine. Returns true if STT is usable.
  Future<bool> initStt() async {
    if (_sttAvailable) return true;
    try {
      _sttAvailable = await _stt.initialize(
        onError: (SpeechRecognitionError error) {
          debugPrint('STT error: ${error.errorMsg}');
        },
        onStatus: (String status) {
          debugPrint('STT status: $status');
          if (status == 'notListening' && _listening) {
            _listening = false;
          }
        },
      );
    } catch (e) {
      debugPrint('STT init failed: $e');
      _sttAvailable = false;
    }
    return _sttAvailable;
  }

  /// Initialize the TTS engine and set up completion handler.
  Future<void> initTts() async {
    if (_ttsReady) return;
    try {
      await _tts.setSharedInstance(true);
      _tts.setCompletionHandler(() {
        if (_onTtsComplete != null) _onTtsComplete!();
      });
      _tts.setErrorHandler((dynamic message) {
        debugPrint('TTS error: $message');
        _onTtsComplete?.call();
      });
      _ttsReady = true;
    } catch (e) {
      debugPrint('TTS init failed: $e');
      _ttsReady = false;
    }
  }

  /// Start listening for speech in the current language.
  ///
  /// Calls [onResult] with recognized text (partial then final) and
  /// [onStatus] for state changes. Returns false when voice is not
  /// available for the active language so the caller can inform the user.
  Future<bool> startListening({
    required VoiceResult onResult,
    required VoiceStatus onStatus,
  }) async {
    if (!_sttAvailable) {
      final ok = await initStt();
      if (!ok) {
        onStatus(VoiceState.unsupported);
        return false;
      }
    }

    final requestedLocale = L.language.sttLocale;
    if (requestedLocale == null) {
      onStatus(VoiceState.unsupported);
      return false;
    }

    List<LocaleName> locales = <LocaleName>[];
    try {
      locales = await _stt.locales();
    } catch (_) {
      // Some platforms throw; treat as unsupported.
    }

    debugPrint(
      'STT requested locale: $requestedLocale, '
      'device locales: ${locales.map((l) => l.localeId).toList()}',
    );

    // Try exact match first, then fall back to any locale with the same
    // language prefix (e.g., 'en-US' → 'en-GB' / 'en-IN').
    String? resolvedLocale;
    if (locales.any((l) => l.localeId == requestedLocale)) {
      resolvedLocale = requestedLocale;
    } else {
      final langPrefix = requestedLocale.split('-').first;

      // Build a prioritized list: preferred variants first, then any
      // device locale matching the language prefix.
      final preferredFallbacks = <String>[];
      if (langPrefix == 'en') {
        preferredFallbacks.addAll(['en-US', 'en-GB', 'en-IN', 'en-AU', 'en']);
      }

      for (final l in locales) {
        if (l.localeId.startsWith(langPrefix) &&
            !preferredFallbacks.contains(l.localeId)) {
          preferredFallbacks.add(l.localeId);
        }
      }

      for (final candidate in preferredFallbacks) {
        if (locales.any((l) => l.localeId == candidate)) {
          resolvedLocale = candidate;
          break;
        }
      }

      // Last resort: use the first English-like locale the device offers.
      if (resolvedLocale == null && langPrefix == 'en' && locales.isNotEmpty) {
        resolvedLocale = locales.first.localeId;
      }
    }

    debugPrint('STT resolved locale: $resolvedLocale');

    if (resolvedLocale == null) {
      onStatus(VoiceState.unsupported);
      return false;
    }

    _listening = true;
    onStatus(VoiceState.listening);
    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          localeId: resolvedLocale,
          partialResults: true,
          cancelOnError: false,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('STT listen() failed: $e');
      _listening = false;
      return false;
    }
  }

  /// Stop an in-progress listening session.
  Future<void> stopListening() async {
    _listening = false;
    await _stt.stop();
  }

  /// Speak [text] aloud using TTS in the current language, when supported.
  /// Returns true if speech actually started.
  /// [onComplete] is called when TTS finishes (on supported platforms).
  Future<bool> speak(String text, {void Function()? onComplete}) async {
    if (text.trim().isEmpty) {
      onComplete?.call();
      return false;
    }
    try {
      await initTts();
      if (!_ttsReady) {
        onComplete?.call();
        return false;
      }
      _onTtsComplete = onComplete;

      final ttsLocale = L.language.ttsLocale;
      if (ttsLocale == null) {
        onComplete?.call();
        return false;
      }

      String localeToUse = ttsLocale;
      bool available = true;
      try {
        available = await _tts.isLanguageAvailable(ttsLocale);
      } catch (_) {
        available = false;
      }

      if (!available) {
        final langPrefix = ttsLocale.split('-').first;
        const fallbacks = ['en-US', 'en-GB', 'en-IN'];
        bool found = false;
        for (final fallback in fallbacks) {
          if (fallback.startsWith(langPrefix) || langPrefix == 'en') {
            try {
              if (await _tts.isLanguageAvailable(fallback)) {
                localeToUse = fallback;
                found = true;
                break;
              }
            } catch (_) {}
          }
        }
        if (!found) {
          onComplete?.call();
          return false;
        }
      }

      try {
        await _tts.setLanguage(localeToUse);
        await _tts.setSpeechRate(0.45);
        await _tts.setPitch(1.0);
      } catch (_) {
        onComplete?.call();
        return false;
      }

      final result = await _tts.speak(text);
      if (result != 1) {
        onComplete?.call();
      }
      return result == 1;
    } catch (e) {
      debugPrint('speak() failed: $e');
      onComplete?.call();
      return false;
    }
  }

  /// Stop any ongoing TTS playback.
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {
      // ignore
    }
  }

  /// Release native resources (call on app shutdown if desired).
  Future<void> dispose() async {
    try {
      await _stt.stop();
      await _tts.stop();
    } catch (_) {
      // ignore
    }
  }
}
