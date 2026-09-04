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
import 'dart:convert';

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

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        'fromCloud': fromCloud,
        'personalized': personalized,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        text: j['text'] as String,
        isUser: j['isUser'] as bool,
        timestamp: DateTime.parse(j['timestamp'] as String),
        fromCloud: j['fromCloud'] as bool? ?? false,
        personalized: j['personalized'] as bool? ?? false,
      );
}

class _ChatConversation {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;

  _ChatConversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory _ChatConversation.fromJson(Map<String, dynamic> j) =>
      _ChatConversation(
        id: j['id'] as String,
        title: j['title'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        messages: (j['messages'] as List)
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
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
  List<_ChatConversation> _conversations = [];
  String? _currentConversationId;

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

    // Load saved conversations.
    _conversations = _loadConversations(prefs);

    if (_conversations.isNotEmpty) {
      // Restore the most recent conversation.
      final conv = _conversations.first;
      _currentConversationId = conv.id;
      setState(() {
        _messages.addAll(conv.messages);
      });
    } else {
      // No saved conversations — start fresh with a greeting.
      _startFreshConversation();
      final profile = _profile;
      if (profile != null) {
        final greeting = AICoachEngine.instance.greeting(profile);
        setState(() {
          _messages.add(
            ChatMessage(
              text: greeting,
              isUser: false,
              timestamp: DateTime.now(),
              personalized: profile.isComplete,
            ),
          );
        });
      }
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
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
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
        _messages.add(
          ChatMessage(
            text: response.text,
            isUser: false,
            timestamp: DateTime.now(),
            fromCloud: response.fromCloud,
            personalized: response.personalized,
          ),
        );
        _isThinking = false;
      });
      _scrollToBottom();
      _saveCurrentConversation();

      // Auto-speak the response if TTS is enabled.
      if (_ttsEnabled && response.text.isNotEmpty) {
        _speakResponse(response.text);
      }
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Sorry, something went wrong. Please try again.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isThinking = false;
      });
      _saveCurrentConversation();
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

    final ok = await VoiceService.instance.initStt();
    if (!ok) {
      _showSnackBar(
        'Speech recognition could not be initialized. '
        'Please check your device settings and try again.',
      );
      return false;
    }
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
        if (state == VoiceState.idle ||
            state == VoiceState.error ||
            state == VoiceState.unsupported) {
          setState(() {
            _voiceState = VoiceState.idle;
            if (_partialText.isNotEmpty && state != VoiceState.unsupported) {
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
        'Microphone could not start. Make sure Google app is installed '
        'and speech recognition is enabled on your phone. '
        'You can type your message instead.',
      );
      return;
    }

    // Voice is listening — state already set above.
  }

  // -------------------------------------------------------------------
  // Voice output (TTS)
  // -------------------------------------------------------------------

  Future<void> _speakResponse(String text) async {
    if (!VoiceService.instance.currentLanguageSupportsTts) {
      _showSnackBar(
        'Text-to-speech is not available for ${L.language.name} on this device.',
      );
      return;
    }

    setState(() {
      _isSpeaking = true;
      _voiceState = VoiceState.speaking;
    });

    final started = await VoiceService.instance.speak(
      text,
      onComplete: () {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _voiceState = VoiceState.idle;
          });
        }
      },
    );

    if (!started && mounted) {
      setState(() {
        _isSpeaking = false;
        _voiceState = VoiceState.idle;
      });
      _showSnackBar(
        'Could not speak this response. Try a different language or check device TTS settings.',
      );
    }
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
      _showSnackBar(
        result.isEmpty
            ? 'Switched to on-device AI coach.'
            : 'Cloud AI enabled — responses will be richer.',
      );
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
  // Conversation persistence
  // -------------------------------------------------------------------

  static const _kConversationsKey = 'coach_conversations';

  List<_ChatConversation> _loadConversations(SharedPreferences prefs) {
    final raw = prefs.getString(_kConversationsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final convos = list
          .map((e) => _ChatConversation.fromJson(e as Map<String, dynamic>))
          .toList();
      convos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return convos;
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _conversations.map((c) => c.toJson()).toList(),
    );
    await prefs.setString(_kConversationsKey, encoded);
  }

  void _saveCurrentConversation() {
    if (_currentConversationId == null || _messages.isEmpty) return;
    final idx = _conversations.indexWhere((c) => c.id == _currentConversationId);
    final userMsgs = _messages.where((m) => m.isUser).toList();
    final title = userMsgs.isNotEmpty
        ? (userMsgs.first.text.length > 40
            ? '${userMsgs.first.text.substring(0, 40)}...'
            : userMsgs.first.text)
        : _conversations.isNotEmpty && idx >= 0
            ? _conversations[idx].title
            : 'New Chat';

    final updated = _ChatConversation(
      id: _currentConversationId!,
      title: title,
      messages: List.from(_messages),
      createdAt: idx >= 0 ? _conversations[idx].createdAt : DateTime.now(),
    );

    setState(() {
      if (idx >= 0) {
        _conversations[idx] = updated;
      } else {
        _conversations.insert(0, updated);
      }
    });
    _saveConversations();
  }

  void _startFreshConversation() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _currentConversationId = id;
    final conv = _ChatConversation(
      id: id,
      title: 'New Chat',
      messages: [],
      createdAt: DateTime.now(),
    );
    setState(() {
      _conversations.insert(0, conv);
    });
  }

  void _startNewChat() {
    // Save current conversation first if it has messages.
    if (_messages.isNotEmpty) {
      _saveCurrentConversation();
    }

    // Start a fresh conversation.
    _startFreshConversation();

    setState(() {
      _messages.clear();
    });

    // Add greeting.
    final profile = _profile;
    if (profile != null) {
      final greeting = AICoachEngine.instance.greeting(profile);
      setState(() {
        _messages.add(
          ChatMessage(
            text: greeting,
            isUser: false,
            timestamp: DateTime.now(),
            personalized: profile.isComplete,
          ),
        );
      });
    }
    _scrollToBottom();
  }

  void _loadConversation(_ChatConversation conv) {
    _saveCurrentConversation();
    _currentConversationId = conv.id;
    setState(() {
      _messages.clear();
      _messages.addAll(conv.messages);
    });
    _scrollToBottom();
    Navigator.pop(context);
  }

  Future<void> _deleteConversation(_ChatConversation conv) async {
    setState(() {
      _conversations.removeWhere((c) => c.id == conv.id);
    });
    await _saveConversations();

    // If we deleted the current conversation, start a new one.
    if (_currentConversationId == conv.id) {
      if (_conversations.isNotEmpty) {
        final next = _conversations.first;
        _currentConversationId = next.id;
        setState(() {
          _messages.clear();
          _messages.addAll(next.messages);
        });
      } else {
        _startFreshConversation();
        setState(() {
          _messages.clear();
        });
        final profile = _profile;
        if (profile != null) {
          final greeting = AICoachEngine.instance.greeting(profile);
          setState(() {
            _messages.add(
              ChatMessage(
                text: greeting,
                isUser: false,
                timestamp: DateTime.now(),
                personalized: profile.isComplete,
              ),
            );
          });
        }
      }
    }
    _scrollToBottom();
  }

  void _showChatHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx2, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        L.t('conversations'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_conversations.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _conversations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 40, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              Text(
                                L.t('noConversations'),
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _conversations.length,
                          itemBuilder: (ctx3, i) {
                            final conv = _conversations[i];
                            final isCurrent =
                                conv.id == _currentConversationId;
                            return Dismissible(
                              key: Key(conv.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              confirmDismiss: (_) async {
                                await _deleteConversation(conv);
                                if (ctx.mounted) Navigator.pop(ctx);
                                return false;
                              },
                              child: ListTile(
                                tileColor: isCurrent
                                    ? Colors.blue.withValues(alpha: 0.05)
                                    : null,
                                leading: Icon(
                                  Icons.chat_bubble,
                                  color: isCurrent
                                      ? Colors.blue.shade600
                                      : Colors.grey.shade400,
                                ),
                                title: Text(
                                  conv.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  '${_formatDate(conv.createdAt)} · ${conv.messages.length} messages',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      size: 20, color: Colors.red.shade300),
                                  onPressed: () async {
                                    await _deleteConversation(conv);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                                ),
                                onTap: () => _loadConversation(conv),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
            // New chat.
            IconButton(
              icon: const Icon(Icons.add_comment, size: 22),
              tooltip: L.t('newChat'),
              onPressed: _startNewChat,
            ),
            // Chat history.
            IconButton(
              icon: const Icon(Icons.history, size: 22),
              tooltip: L.t('chatHistory'),
              onPressed: _showChatHistory,
            ),
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
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
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
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Colors.grey.shade300,
            ),
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
                      Icon(
                        Icons.volume_up,
                        size: 12,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Listen',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
