import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

class EmbedSubtitlePage extends StatefulWidget {
  const EmbedSubtitlePage({super.key});

  @override
  State<EmbedSubtitlePage> createState() => _EmbedSubtitlePageState();
}

class _EmbedSubtitlePageState extends State<EmbedSubtitlePage> {
  String? _selectedVideoPath;
  String? _selectedSrtPath;
  bool _isProcessing = false;
  String _status = '';
  String _terminalOutput = '';

  final String _projectRoot = '/Users/wmsing/Documents/tony/github/text_to_video/tt_video';

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedVideoPath = result.files.single.path;
        _status = '已選擇視頻: ${p.basename(_selectedVideoPath!)}';
      });
    }
  }

  Future<void> _pickSrt() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedSrtPath = result.files.single.path;
        _status = '已選擇字幕: ${p.basename(_selectedSrtPath!)}';
      });
    }
  }

  Future<void> _embedSubtitles() async {
    if (_selectedVideoPath == null || _selectedSrtPath == null) {
      setState(() => _status = '請選擇影片與字幕檔案');
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = '正在合成影片字幕... 請稍候';
      _terminalOutput = '';
    });

    try {
      final venvPython = '$_projectRoot/.venv/bin/python';
      
      // Construct output path: same folder as video, with _final suffix
      final String dirName = p.dirname(_selectedVideoPath!);
      final String baseName = p.basenameWithoutExtension(_selectedVideoPath!);
      final String outputPath = p.join(dirName, '${baseName}_final.mp4');

      final command = '$venvPython tools/index2.py -v "$_selectedVideoPath" -s "$_selectedSrtPath" -o "$outputPath"';
      
      final process = await Process.start(
        'zsh',
        [
          '-l',
          '-c',
          'cd $_projectRoot && $command'
        ],
      );

      process.stdout.transform(SystemEncoding().decoder).listen((data) {
        if (!mounted) return;
        setState(() => _terminalOutput += data);
      });
      process.stderr.transform(SystemEncoding().decoder).listen((data) {
        if (!mounted) return;
        setState(() => _terminalOutput += data);
      });

      final exitCode = await process.exitCode;

      if (!mounted) return;
      if (exitCode == 0) {
        setState(() {
          _status = '影片合成成功！\n儲存於: $outputPath';
          _isProcessing = false;
        });
      } else {
        setState(() {
          _status = '合成失敗，退出代碼: $exitCode';
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = '錯誤: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _openOutputFolder() async {
    if (_selectedVideoPath != null) {
      final folderPath = p.dirname(_selectedVideoPath!);
      if (Platform.isMacOS) {
        await Process.run('open', [folderPath]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('加字幕入影片')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('選擇素材:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.video_file, color: Colors.blue),
                      title: Text(_selectedVideoPath == null ? '尚未選擇影片' : p.basename(_selectedVideoPath!)),
                      subtitle: const Text('原始影片 (.mov/.mp4)'),
                      trailing: ElevatedButton(onPressed: _pickVideo, child: const Text('選擇')),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.subtitles, color: Colors.green),
                      title: Text(_selectedSrtPath == null ? '尚未選擇字幕' : p.basename(_selectedSrtPath!)),
                      subtitle: const Text('字幕檔案 (.srt)'),
                      trailing: ElevatedButton(onPressed: _pickSrt, child: const Text('選擇')),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_selectedVideoPath == null || _selectedSrtPath == null || _isProcessing) ? null : _embedSubtitles,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isProcessing 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('開始壓制字幕 (產生 _final.mp4)'),
            ),
            const SizedBox(height: 20),
            Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (_terminalOutput.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                height: 150,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                child: SingleChildScrollView(
                  child: Text(_terminalOutput, style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace')),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_selectedVideoPath != null)
              OutlinedButton.icon(
                onPressed: _openOutputFolder,
                icon: const Icon(Icons.folder),
                label: const Text('打開檔案所在資料夾'),
              ),
          ],
        ),
      ),
    );
  }
}
