/// FitAI Gym Music Screen
///
/// Manages user's workout music library. Allows adding YouTube links
/// and phone audio files, playing music, and removing items.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_localizations.dart' show L;
import '../core/music_service.dart';

class GymMusicScreen extends StatefulWidget {
  const GymMusicScreen({super.key});

  @override
  State<GymMusicScreen> createState() => _GymMusicScreenState();
}

class _GymMusicScreenState extends State<GymMusicScreen> {
  final MusicService _musicService = MusicService.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<MusicItem> _library = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    setState(() => _isLoading = true);
    _library = await _musicService.loadLibrary();
    setState(() => _isLoading = false);
  }

  void _addYouTubeItem() {
    showDialog(
      context: context,
      builder: (context) => _AddYouTubeDialog(
        onAdd: (title, url) async {
          await _musicService.addYouTubeItem(title, url);
          await _loadLibrary();
        },
      ),
    );
  }

  Future<void> _addPhoneAudio() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.audio);

      if (result.isEmpty) {
        return;
      }

      final file = result.first;
      final fileName = file.name;
      final filePath = file.path;

      if (filePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(L.t('fileSelectionFailed'))));
        }
        return;
      }

      // Extract title from filename (remove extension)
      final title = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;

      await _musicService.addPhoneAudioItem(title, filePath);
      await _loadLibrary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L.t('audioAdded')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${L.t("error")}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _playItem(MusicItem item) async {
    if (item.sourceType == MusicSourceType.youtube) {
      final uri = Uri.parse(item.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(L.t('couldNotOpenLink'))));
        }
      }
    } else if (item.sourceType == MusicSourceType.phoneAudio) {
      try {
        // Stop any currently playing audio
        await _audioPlayer.stop();

        // Play the local audio file
        await _audioPlayer.play(DeviceFileSource(item.url));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${L.t("playing")}: ${item.title}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${L.t("playbackError")}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeItem(MusicItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L.t('removeItem')),
        content: Text(L.t('removeItemConfirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              L.t('remove'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _musicService.removeItem(item.id);
      await _loadLibrary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('gymMusic')),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            onSelected: (value) {
              if (value == 'youtube') {
                _addYouTubeItem();
              } else if (value == 'phone') {
                _addPhoneAudio();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'youtube',
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_fill, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(L.t('addYouTube')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'phone',
                child: Row(
                  children: [
                    const Icon(Icons.audio_file),
                    const SizedBox(width: 8),
                    Text(L.t('addFromPhone')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_library.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              L.t('noMusicYet'),
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              L.t('addMusicToLibrary'),
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _library.length,
      itemBuilder: (context, index) {
        final item = _library[index];
        return _buildMusicCard(item);
      },
    );
  }

  Widget _buildMusicCard(MusicItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.sourceType == MusicSourceType.youtube
              ? Colors.red
              : Colors.deepPurple,
          child: Icon(
            item.sourceType == MusicSourceType.youtube
                ? Icons.play_circle_fill
                : Icons.audio_file,
            color: Colors.white,
          ),
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          item.sourceType == MusicSourceType.youtube
              ? L.t('youtube')
              : L.t('phoneAudio'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => _playItem(item),
              tooltip: L.t('play'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _removeItem(item),
              tooltip: L.t('remove'),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// ADD YOUTUBE DIALOG
// -------------------------------------------------------------------

class _AddYouTubeDialog extends StatefulWidget {
  final Future<void> Function(String title, String url) onAdd;

  const _AddYouTubeDialog({required this.onAdd});

  @override
  State<_AddYouTubeDialog> createState() => _AddYouTubeDialogState();
}

class _AddYouTubeDialogState extends State<_AddYouTubeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final title = _titleController.text.trim();
    final url = _urlController.text.trim();

    await widget.onAdd(title, url);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L.t('addYouTube')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: L.t('title'),
                hintText: L.t('musicTitleHint'),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return L.t('titleRequired');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: L.t('youtubeUrl'),
                hintText: 'https://youtube.com/watch?v=...',
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return L.t('urlRequired');
                }
                if (!MusicService.instance.isValidYouTubeUrl(value.trim())) {
                  return L.t('invalidYouTubeUrl');
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(L.t('cancel')),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(L.t('add')),
        ),
      ],
    );
  }
}
