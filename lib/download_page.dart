import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isDownloading = false;
  String _status = '';
  double _progress = 0;
  String? _lastDownloadPath;
  List<String> _downloadHistory = [];

  @override
  void initState() {
    super.initState();
    _loadDownloadHistory();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadDownloadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _downloadHistory = prefs.getStringList('download_history') ?? [];
    });
  }

  Future<void> _addToDownloadHistory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    _downloadHistory.add(path);
    await prefs.setStringList('download_history', _downloadHistory);
  }

  Future<Directory> _getAppDownloadDirectory(String subFolderName) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('main_folder_path');
    
    Directory baseDir;
    if (savedPath != null) {
      baseDir = Directory(savedPath);
    } else {
      // Fallback if not set
      Directory? downloadsDir = await getDownloadsDirectory();
      baseDir = Directory(p.join(downloadsDir?.path ?? '', 'AI_Video'));
    }

    final targetDir = Directory(p.join(baseDir.path, subFolderName));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
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
        if (!mounted) return;
        setState(() {
          _status = 'Unsupported link format.';
        });
      }
    } catch (e) {
      print('Download error: $e');
      if (!mounted) return;
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _downloadYouTube(String url) async {
    final yt = YoutubeExplode();
    try {
      if (mounted) setState(() => _status = 'Fetching video info...');
      
      // Explicitly parse the video ID to handle complex URLs
      final videoId = VideoId.parseVideoId(url);
      if (videoId == null) {
        if (mounted) setState(() => _status = 'Invalid YouTube URL.');
        return;
      }

      final video = await yt.videos.get(videoId);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      
      // Use user-defined name or default to video title
      final customName = _nameController.text.trim();
      final folderName = customName.isNotEmpty 
          ? customName 
          : video.title.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
          
      Directory dir = await _getAppDownloadDirectory(folderName);
      final filePath = p.join(dir.path, '$folderName.mp4');

      // 1. Check if file already exists
      if (await File(filePath).exists()) {
        if (mounted) {
          setState(() {
            _status = '檔案已存在於 AI_Video 資料夾：\n$filePath';
            _lastDownloadPath = filePath;
            _progress = 1.0;
          });
        }
        await _openFolder();
        return;
      }

      // 2. Determine which streams to download
      VideoStreamInfo? videoStream;
      AudioStreamInfo? audioStream;
      MuxedStreamInfo? muxedStream;

      // Try adaptive streams for 1080p or 720p first (YouTube usually separates them)
      videoStream = manifest.videoOnly.where((s) => s.videoResolution.height == 1080).firstOrNull;
      if (videoStream == null) {
        videoStream = manifest.videoOnly.where((s) => s.videoResolution.height == 720).firstOrNull;
      }

      if (videoStream != null) {
        audioStream = manifest.audioOnly.withHighestBitrate();
        if (mounted) setState(() => _status = 'Found adaptive ${videoStream!.videoResolution.height}p. Downloading video & audio...');
      } else {
        // Fallback to muxed streams
        muxedStream = manifest.muxed.where((s) => s.videoResolution.height == 1080).firstOrNull;
        if (muxedStream == null) {
          muxedStream = manifest.muxed.where((s) => s.videoResolution.height == 720).firstOrNull;
        }
        if (muxedStream == null) {
          muxedStream = manifest.muxed.withHighestBitrate();
        }
        if (mounted) setState(() => _status = 'Downloading muxed stream: ${video.title}');
      }

      if (videoStream != null && audioStream != null) {
        // Download adaptive streams
        final videoTempPath = p.join(dir.path, 'temp_video.mp4');
        final audioTempPath = p.join(dir.path, 'temp_audio.m4a');
        
        // Download Video
        await _downloadStream(yt, videoStream, videoTempPath, 'Video');
        // Download Audio
        await _downloadStream(yt, audioStream, audioTempPath, 'Audio');
        
        // Merge with FFmpeg
        if (mounted) setState(() => _status = 'Merging video and audio...');
        final result = await Process.run('zsh', [
          '-l',
          '-c',
          'ffmpeg -i "$videoTempPath" -i "$audioTempPath" -c copy -y "$filePath"'
        ]);

        if (await File(videoTempPath).exists()) await File(videoTempPath).delete();
        if (await File(audioTempPath).exists()) await File(audioTempPath).delete();

        if (result.exitCode != 0) {
          throw 'FFmpeg merge failed: ${result.stderr}';
        }
      } else if (muxedStream != null) {
        // Download single muxed stream
        await _downloadStream(yt, muxedStream, filePath, 'Video');
      } else {
        if (mounted) setState(() => _status = 'No suitable stream found for this video.');
        return;
      }

      await _addToDownloadHistory(filePath);
      if (mounted) {
        setState(() {
          _status = 'Successfully downloaded to:\n$filePath';
          _lastDownloadPath = filePath;
          _progress = 1.0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'YouTube 下載錯誤: $e');
      rethrow;
    } finally {
      yt.close();
    }
  }

  Future<void> _downloadStream(YoutubeExplode yt, StreamInfo streamInfo, String savePath, String label) async {
    final stream = yt.videos.streamsClient.get(streamInfo);
    final file = File(savePath);
    final fileStream = file.openWrite();

    final totalSize = streamInfo.size.totalBytes;
    int downloaded = 0;

    await for (final data in stream) {
      fileStream.add(data);
      downloaded += data.length;
      if (mounted) {
        setState(() {
          _progress = downloaded / totalSize;
          _status = 'Downloading $label: ${(_progress * 100).toStringAsFixed(1)}%';
        });
      }
    }

    await fileStream.flush();
    await fileStream.close();
  }

  Future<void> _downloadM3U8(String url) async {
    if (mounted) {
      setState(() {
        _isDownloading = true;
        _status = '正在解析 M3U8...';
        _progress = 0;
      });
    }

    final dio = Dio();
    try {
      // 1. 獲取索引內容
      var response = await dio.get(url);
      var content = response.data.toString();
      var baseUrl = url.substring(0, url.lastIndexOf('/') + 1);

      // 2. 如果是 Master Playlist (包含不同解析度)，選擇最後一個 (通常是最高畫質)
      if (content.contains('#EXT-X-STREAM-INF')) {
        var lines = content.split('\n');
        String? nextUrl;
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('#EXT-X-STREAM-INF')) {
            nextUrl = lines[i + 1].trim();
          }
        }
        if (nextUrl != null) {
          if (!nextUrl.startsWith('http')) nextUrl = baseUrl + nextUrl;
          return _downloadM3U8(nextUrl); // 遞歸下載真實的媒體列表
        }
      }

      // 3. 提取所有片段 (TS 檔案)
      var lines = content.split('\n');
      var tsUrls = <String>[];
      for (var line in lines) {
        line = line.trim();
        if (line.isNotEmpty && !line.startsWith('#')) {
          if (line.startsWith('http')) {
            tsUrls.add(line);
          } else {
            tsUrls.add(baseUrl + line);
          }
        }
      }

      if (tsUrls.isEmpty) {
        throw '未找到視頻片段';
      }

      // 4. 準備下載目錄
      final customName = _nameController.text.trim();
      final urlHash = md5.convert(utf8.encode(url)).toString().substring(0, 8);
      final folderName = customName.isNotEmpty ? customName : 'video_$urlHash';
      
      Directory dir = await _getAppDownloadDirectory(folderName);
      
      final tsFilePath = p.join(dir.path, '$folderName.ts');
      final mp4FilePath = p.join(dir.path, '$folderName.mp4');
      
      // A. 檢查 MP4 是否已存在
      if (await File(mp4FilePath).exists()) {
        if (mounted) {
          setState(() {
            _status = 'MP4 已存在：\n$mp4FilePath';
            _lastDownloadPath = mp4FilePath;
            _progress = 1.0;
          });
        }
        await _openFolder();
        return;
      }

      // B. 檢查 TS 是否已存在 (若存在則直接進行轉碼，不重新下載)
      if (await File(tsFilePath).exists()) {
        if (mounted) setState(() => _status = '找到現有的 TS 檔案，正在直接轉換為 MP4...');
        await _convertToMp4(tsFilePath, mp4FilePath);
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempDir = await Directory(p.join(dir.path, 'temp_$timestamp')).create();
      if (mounted) setState(() => _status = '準備下載 ${tsUrls.length} 個片段...');

      // 5. 併發下載所有片段
      int completed = 0;
      for (var i = 0; i < tsUrls.length; i++) {
        final segmentPath = p.join(tempDir.path, 'seg_$i.ts');
        await dio.download(tsUrls[i], segmentPath);
        completed++;
        if (mounted) {
          setState(() {
            _progress = completed / tsUrls.length;
            _status = '正在下載片段: $completed / ${tsUrls.length}';
          });
        }
      }

      // 6. 合併檔案為臨時 TS
      if (mounted) setState(() => _status = '正在合併片段...');
      final tsFile = File(tsFilePath);
      final sink = tsFile.openWrite(mode: FileMode.append);
      
      for (var i = 0; i < tsUrls.length; i++) {
        final segmentFile = File(p.join(tempDir.path, 'seg_$i.ts'));
        final bytes = await segmentFile.readAsBytes();
        sink.add(bytes);
        await segmentFile.delete();
      }
      await sink.flush();
      await sink.close();
      await tempDir.delete();

      // 7. 使用 FFmpeg 轉換為 MP4
      await _convertToMp4(tsFilePath, mp4FilePath);
      
      await _openFolder();

    } catch (e) {
      if (mounted) setState(() => _status = 'M3U8 下載失敗: $e');
      rethrow;
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _convertToMp4(String tsFilePath, String mp4FilePath) async {
    if (mounted) setState(() => _status = '正在轉碼為 MP4 (FFmpeg)...');
    try {
      final result = await Process.run('zsh', [
        '-l',
        '-c',
        'ffmpeg -i "$tsFilePath" -c copy -y "$mp4FilePath"'
      ]);

      if (result.exitCode == 0) {
        if (await File(tsFilePath).exists()) {
          await File(tsFilePath).delete(); 
        }
        await _addToDownloadHistory(mp4FilePath);
        if (mounted) {
          setState(() {
            _status = '轉碼完成：\n$mp4FilePath';
            _lastDownloadPath = mp4FilePath;
            _progress = 1.0;
          });
        }
      } else {
        if (mounted) {
          setState(() => _status = '轉碼失敗，保留原始 TS：\n$tsFilePath\n${result.stderr}');
          _lastDownloadPath = tsFilePath;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = '找不到 FFmpeg，保留原始 TS：\n$tsFilePath');
        _lastDownloadPath = tsFilePath;
      }
    }
  }

  void _showDownloadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final mainFolderPath = prefs.getString('main_folder_path');
    
    if (mainFolderPath == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('下載列表'),
          content: const Text('尚未設置主資料夾'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('關閉'),
            ),
          ],
        ),
      );
      return;
    }

    final mainDir = Directory(mainFolderPath);
    List<Directory> subFolders = [];
    
    if (await mainDir.exists()) {
      final entities = await mainDir.list().toList();
      subFolders = entities.whereType<Directory>().toList();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('下載列表'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: subFolders.isEmpty
              ? const Center(child: Text('主資料夾內沒有子資料夾'))
              : ListView.builder(
                  itemCount: subFolders.length,
                  itemBuilder: (context, index) {
                    final folder = subFolders[index];
                    final folderName = p.basename(folder.path);
                    return ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(folderName),
                      subtitle: Text(folder.path),
                      onTap: () async {
                        if (Platform.isMacOS) {
                          await Process.run('open', [folder.path]);
                        }
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('下載'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _showDownloadHistory,
            tooltip: '下載列表',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: '輸入網址 (YouTube or M3U8)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '輸入檔案名稱 (選填，將以此名稱創建資料夾)',
                  hintText: '例如：我的影片_01',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.drive_file_rename_outline),
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
              const Divider(height: 48),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '如何找到 M3U8 網址(例如從愛壹凡/粵漫之家下載)？',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. 在瀏覽器打開視頻播放頁面\n'
                      '2. 右鍵點擊網頁選擇「檢查 (Inspect)」或按 F12\n'
                      '3. 在工具欄切換到「網路 (Network)」標籤\n'
                      '4. 在過濾搜索框中輸入「m3u8」\n'
                      '5. 刷新頁面，找到類型為「fetch」或「xhr」的 .m3u8 連結\n'
                      '6. 右鍵點擊該連結並選擇「複製連結網址」',
                      style: TextStyle(color: Colors.grey, height: 1.5),
                    ),
                    const Divider(height: 32),
                    const Text(
                      '可下載的網址列表：',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => launchUrl(Uri.parse('https://www.ymvid.com/hk')),
                      child: const Text('1. 粵漫之家: https://www.ymvid.com/hk', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => launchUrl(Uri.parse('https://www.yfsp.tv/list')),
                      child: const Text('2. 愛壹凡: https://www.yfsp.tv/list', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
