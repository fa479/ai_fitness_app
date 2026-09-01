/// FitAI AI Coach Chat Screen — Multilingual Voice + Text Chat
///
/// Replaces the fake AICoachScreen from main.dart with a real chat
/// interface that supports both text and voice input in the user's
/// selected language. Uses:
///   - AICoachEngine for multilingual, personalized responses
///   - VoiceService for speech-to-text (STT) and text-to-speech (TTS)
///   - UserProfileService for personalization context
///
/// The user can type a message or tap the microphone to speak. The AI
/// responds in the same language. TTS lets the user listen to responses.
/// States for listening, thinking, and speaking are clearly shown.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_localizations.dart' show L;
import '../core/ai_coach_engine.dart';
import '../core/food_data.dart';
import '../core/user_profile_service.dart';
import '../core/voice_service.dart';

/// A single chat message.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool fromCloud;
  final bool personalized;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.fromCloud = false,
    this.personalized = false,
  });
}

class AICoachChatScreen extends StatefulWidget {
  const AICoachChatScreen({super.key});

  @override
  State<AICoachChatScreen> createState() => _AICoachChatScreenState();
}

class _AICoachChatScreenState extends State<AICoachChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  UserProfile? _profile;
  VoiceState _voiceState = VoiceState.idle;
  String _partialText = '';
  bool _isThinking = false;
  bool _isSpeaking = false;
  bool _ttsEnabled = true;
  bool _sttInitialized = false;

  /// Gemini API key for optional cloud AI.
  static const _kApiKeyPref = 'gemini_api_key';

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    // Load user profile.
    _profile = await UserProfileService.instance.load();

    // Initialize TTS only — STT is lazy-initialized when the user taps
    // the mic button, so microphone permission is not requested eagerly.
    await VoiceService.instance.initTts();

    // Load the API key if previously saved.
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_kApiKeyPref);
    if (key != null && key.isNotEmpty) {
      AICoachEngine.instance.setApiKey(key);
      NutritionService.instance.setApiKey(key);
    }

    // Show a greeting from the coach.
    final profile = _profile;
    if (profile != null) {
      final greeting = AICoachEngine.instance.greeting(profile);
      setState(() {
        _messages.add(ChatMessage(
          text: greeting,
          isUser: false,
          timestamp: DateTime.now(),
          personalized: profile.isComplete,
        ));
      });
    }
  }

  @override
  void dispose() {
    VoiceService.instance.stopListening();
    VoiceService.instance.stopSpeaking();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // -------------------------------------------------------------------
  // Send a message (text or voice-transcribed)
  // -------------------------------------------------------------------

  Future<void> _sendMessage(String text) async {
    text = text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isThinking = true;
      _partialText = '';
      _textController.clear();
    });
    _scrollToBottom();

    final profile = _profile;
    if (profile == null) return;
    try {
      final response = await AICoachEngine.instance.respond(text, profile);
      setState(() {
        _messages.add(ChatMessage(
          text: response.text,
          isUser: false,
          timestamp: DateTime.now(),
          fromCloud: response.fromCloud,
          personalized: response.personalized,
        ));
        _isThinking = false;
      });
      _scrollToBottom();

      // Auto-speak the response if TTS is enabled.
      if (_ttsEnabled && response.text.isNotEmpty) {
        _speakResponse(response.text);
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Sorry, something went wrong. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isThinking = false;
      });
    }
  }

  // -------------------------------------------------------------------
  // Voice input (STT)
  // -------------------------------------------------------------------

  Future<bool> _ensureSttInitialized() async {
    if (_sttInitialized) return true;

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _showSnackBar(
        'Microphone permission is required for voice input. '
        'Please enable it in Settings.',
      );
      return false;
    }

    await VoiceService.instance.initStt();
    _sttInitialized = true;
    return true;
  }

  Future<void> _toggleVoiceInput() async {
    if (_voiceState == VoiceState.listening) {
      await VoiceService.instance.stopListening();
      setState(() => _voiceState = VoiceState.idle);
      // Send whatever partial text we have.
      if (_partialText.isNotEmpty) {
        _sendMessage(_partialText);
      }
      return;
    }

    if (_voiceState == VoiceState.speaking) {
      await VoiceService.instance.stopSpeaking();
      setState(() {
        _isSpeaking = false;
        _voiceState = VoiceState.idle;
      });
      return;
    }

    // Start listening — lazy-init STT and request mic permission first.
    final sttReady = await _ensureSttInitialized();
    if (!sttReady) return;

    if (!VoiceService.instance.isSttAvailable ||
        !VoiceService.instance.currentLanguageSupportsStt) {
      _showSnackBar(
        'Voice input is not available for ${L.language.name} '
        'on this device. Please type your message instead.',
      );
      return;
    }

    setState(() => _voiceState = VoiceState.listening);

    final started = await VoiceService.instance.startListening(
      onResult: (text, isFinal) {
        setState(() => _partialText = text);
        if (isFinal && text.isNotEmpty) {
          _sendMessage(text);
          setState(() => _voiceState = VoiceState.idle);
        }
      },
      onStatus: (state) {
        if (state == VoiceState.idle || state == VoiceState.error) {
          setState(() {
            _voiceState = VoiceState.idle;
            if (_partialText.isNotEmpty) {
              _sendMessage(_partialText);
            }
          });
        }
      },
    );

    if (!started) {
      setState(() {
        _voiceState = VoiceState.idle;
      });
      _showSnackBar(
        'Could not start voice recognition. '
        'Please check microphone permissions.',
      );
    }
  }

  // -------------------------------------------------------------------
  // Voice output (TTS)
  // -------------------------------------------------------------------

  Future<void> _speakResponse(String text) async {
    if (!VoiceService.instance.currentLanguageSupportsTts) return;

    setState(() {
      _isSpeaking = true;
      _voiceState = VoiceState.speaking;
    });

    await VoiceService.instance.speak(text, onComplete: () {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _voiceState = VoiceState.idle;
        });
      }
    });
  }

  Future<void> _stopSpeaking() async {
    await VoiceService.instance.stopSpeaking();
    setState(() {
      _isSpeaking = false;
      _voiceState = VoiceState.idle;
    });
  }

  // -------------------------------------------------------------------
  // API key dialog (optional cloud AI)
  // -------------------------------------------------------------------

  Future<void> _showApiKeyDialog() async {
    final controller = TextEditingController(
      text: AICoachEngine.instance.apiKey ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Cloud Settings (Optional)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a Gemini API key for richer cloud-based AI responses. '
              'Leave empty to use the on-device coach.\n\n'
              'Get a free key at: aistudio.google.com',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                border: OutlineInputBorder(),
                hintText: 'AIza...',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      AICoachEngine.instance.setApiKey(result);
      NutritionService.instance.setApiKey(result);
      final prefs = await SharedPreferences.getInstance();
      if (result.isEmpty) {
        await prefs.remove(_kApiKeyPref);
      } else {
        await prefs.setString(_kApiKeyPref, result);
      }
      _showSnackBar(result.isEmpty
          ? 'Switched to on-device AI coach.'
          : 'Cloud AI enabled — responses will be richer.');
    }
    controller.dispose();
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
    );
  }

  // -------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isRtl = L.isRtl;
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.smart_toy, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FitAI Coach',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${L.language.name} ${L.language.sttLocale != null ? "🎤" : ""}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // TTS toggle.
            IconButton(
              icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off),
              tooltip: 'Text-to-speech',
              onPressed: () {
                setState(() => _ttsEnabled = !_ttsEnabled);
                if (!_ttsEnabled) _stopSpeaking();
              },
            ),
            // Cloud AI settings.
            IconButton(
              icon: Icon(
                AICoachEngine.instance.hasCloud
                    ? Icons.cloud_done
                    : Icons.cloud_outlined,
              ),
              tooltip: 'AI Settings',
              onPressed: _showApiKeyDialog,
            ),
          ],
        ),
        body: Column(
          children: [
            // Voice status bar.
            if (_voiceState != VoiceState.idle || _isThinking)
              _buildStatusBar(),
            // Chat messages.
            Expanded(child: _buildMessageList()),
            // Input bar.
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    String text;
    Color color;
    if (_voiceState == VoiceState.listening) {
      text = '${L.t('listening')}... $_partialText';
      color = Colors.red;
    } else if (_isThinking) {
      text = '${L.t('thinking')}...';
      color = Colors.blue;
    } else if (_voiceState == VoiceState.speaking) {
      text = 'Speaking...';
      color = Colors.green;
    } else {
      text = '';
      color = Colors.grey;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          if (_isThinking || _voiceState == VoiceState.speaking)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              ),
            ),
          if (_voiceState == VoiceState.listening)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.mic, color: color, size: 16),
            ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_voiceState == VoiceState.speaking)
            TextButton.icon(
              onPressed: _stopSpeaking,
              icon: const Icon(Icons.stop, size: 16),
              label: const Text('Stop', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Ask me anything about fitness!',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i]),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.blue.shade600
              : (msg.fromCloud ? Colors.green.shade50 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isUser && msg.fromCloud)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud, size: 10, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Cloud AI',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            if (!isUser && !msg.fromCloud && msg.personalized)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, size: 10, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'On-device • Personalized',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              msg.text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (!isUser && _ttsEnabled && !_isSpeaking)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: GestureDetector(
                  onTap: () => _speakResponse(msg.text),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up, size: 12, color: Colors.blue.shade400),
                      const SizedBox(width: 2),
                      Text(
                        'Listen',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, -1),
              blurRadius: 4,
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ],
        ),
        child: Row(
          children: [
            // Microphone button.
            GestureDetector(
              onTap: _toggleVoiceInput,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _voiceState == VoiceState.listening
                      ? Colors.red
                      : Colors.blue.shade600,
                ),
                child: Icon(
                  _voiceState == VoiceState.listening
                      ? Icons.mic
                      : Icons.mic_none,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Text input.
            Expanded(
              child: TextField(
                controller: _textController,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                textAlign: L.isRtl ? TextAlign.right : TextAlign.left,
                decoration: InputDecoration(
                  hintText: _partialText.isNotEmpty
                      ? _partialText
                      : L.t('askCoach'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (text) => _sendMessage(text),
              ),
            ),
            const SizedBox(width: 8),
            // Send button.
            IconButton.filled(
              onPressed: _textController.text.trim().isNotEmpty
                  ? () => _sendMessage(_textController.text)
                  : null,
              icon: const Icon(Icons.send, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


