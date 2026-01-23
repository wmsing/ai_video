import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isDownloading = false;
  String _status = '';
  double _progress = 0;
  String? _lastDownloadPath;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _openFolder() async {
    if (_lastDownloadPath != null) {
      final folderPath = p.dirname(_lastDownloadPath!);
      final url = Uri.file(folderPath);
      if (Platform.isMacOS) {
        // More reliable for macOS sandboxed apps
        await Process.run('open', [folderPath]);
      } else if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }

  Future<void> _handleDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isDownloading = true;
      _status = 'Analyzing link...';
      _progress = 0;
      _lastDownloadPath = null;
    });

    try {
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        await _downloadYouTube(url);
      } else if (url.contains('.m3u8')) {
        await _downloadM3U8(url);
      } else {
        setState(() {
          _status = 'Unsupported link format.';
        });
      }
    } catch (e) {
      print('Download error: $e');
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _downloadYouTube(String url) async {
    final yt = YoutubeExplode();
    try {
      setState(() => _status = 'Fetching video info...');
      
      // Explicitly parse the video ID to handle complex URLs
      final videoId = VideoId.parseVideoId(url);
      if (videoId == null) {
        setState(() => _status = 'Invalid YouTube URL.');
        return;
      }

      final video = await yt.videos.get(videoId);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      
      if (manifest.muxed.isNotEmpty) {
        final streamInfo = manifest.muxed.withHighestBitrate();
        
        // Use Downloads directory on macOS
        Directory? dir;
        try {
          if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
            dir = await getDownloadsDirectory();
          }
        } catch (e) {
          debugPrint('Could not get downloads directory: $e');
        }
        dir ??= await getApplicationDocumentsDirectory();

        // Clean the title for filesystem safety
        final safeTitle = video.title.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
        final filePath = p.join(dir.path, '$safeTitle.mp4');

        // 1. Check if file already exists
        if (await File(filePath).exists()) {
          setState(() {
            _status = 'File already exists in Downloads:\n$filePath';
            _lastDownloadPath = filePath;
            _progress = 1.0;
          });
          // Automatically open folder since it exists
          await _openFolder();
          return;
        }
        
        setState(() => _status = 'Downloading: ${video.title}');
        
        final file = File(filePath);
        final stream = yt.videos.streamsClient.get(streamInfo);
        final fileStream = file.openWrite();

        final totalSize = streamInfo.size.totalBytes;
        int downloaded = 0;

        await for (final data in stream) {
          fileStream.add(data);
          downloaded += data.length;
          setState(() {
            _progress = downloaded / totalSize;
            _status = 'Downloading: ${(_progress * 100).toStringAsFixed(1)}%';
          });
        }

        await fileStream.flush();
        await fileStream.close();
        setState(() {
          _status = 'Successfully downloaded to:\n$filePath';
          _lastDownloadPath = filePath;
        });
      } else {
        setState(() => _status = 'No suitable stream found for this video.');
      }
    } finally {
      yt.close();
    }
  }

  Future<void> _downloadM3U8(String url) async {
    setState(() => _status = 'M3U8 download started (simplified)...');
    
    final dio = Dio();
    Directory? dir;
    try {
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        dir = await getDownloadsDirectory();
      }
    } catch (e) {
      debugPrint('Could not get downloads directory: $e');
    }
    dir ??= await getApplicationDocumentsDirectory();

    final filePath = p.join(dir.path, 'downloaded_video.m3u8');

    // Check if file already exists
    if (await File(filePath).exists()) {
      setState(() {
        _status = 'File already exists in Downloads:\n$filePath';
        _lastDownloadPath = filePath;
        _progress = 1.0;
      });
      await _openFolder();
      return;
    }

    // For simplicity, we just download the manifest file in this example.
    await dio.download(url, filePath, onReceiveProgress: (received, total) {
      if (total != -1) {
        setState(() {
          _progress = received / total;
          _status = 'Downloading manifest: ${(_progress * 100).toStringAsFixed(1)}%';
        });
      }
    });

    setState(() {
      _status = 'Manifest downloaded to:\n$filePath';
      _lastDownloadPath = filePath;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('下載')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: '輸入網址 (YouTube or M3U8)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isDownloading ? null : _handleDownload,
                  child: const Text('Submit'),
                ),
                if (_lastDownloadPath != null)
                  ElevatedButton.icon(
                    onPressed: _openFolder,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('打開資料夾'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isDownloading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
            ],
            SelectableText(
              _status,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
