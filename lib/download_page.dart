import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';

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

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isDownloading = true;
      _status = 'Analyzing link...';
      _progress = 0;
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
      final video = await yt.videos.get(url);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      
      if (manifest.muxed.isNotEmpty) {
        final streamInfo = manifest.muxed.withHighestBitrate();
        final dir = await getApplicationDocumentsDirectory();
        final filePath = p.join(dir.path, '${video.title.replaceAll(RegExp(r'[^\w\s]+'), '')}.mp4');
        
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
        setState(() => _status = 'Downloaded to $filePath');
      } else {
        setState(() => _status = 'No suitable stream found.');
      }
    } finally {
      yt.close();
    }
  }

  Future<void> _downloadM3U8(String url) async {
    setState(() => _status = 'M3U8 download started (simplified)...');
    
    final dio = Dio();
    final dir = await getApplicationDocumentsDirectory();
    final filePath = p.join(dir.path, 'downloaded_video.m3u8');

    // For simplicity, we just download the manifest file in this example.
    // Full m3u8 download requires parsing segments and downloading each.
    await dio.download(url, filePath, onReceiveProgress: (received, total) {
      if (total != -1) {
        setState(() {
          _progress = received / total;
          _status = 'Downloading manifest: ${(_progress * 100).toStringAsFixed(1)}%';
        });
      }
    });

    setState(() => _status = 'Manifest downloaded. Full segment download not implemented in this demo.');
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
                labelText: 'Enter Link (YouTube or M3U8)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isDownloading ? null : _handleDownload,
              child: const Text('Submit'),
            ),
            const SizedBox(height: 24),
            if (_isDownloading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
            ],
            Text(_status),
          ],
        ),
      ),
    );
  }
}
