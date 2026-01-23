import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

class SubtitlePage extends StatefulWidget {
  const SubtitlePage({super.key});

  @override
  State<SubtitlePage> createState() => _SubtitlePageState();
}

class _SubtitlePageState extends State<SubtitlePage> {
  String? _selectedVideoPath;
  bool _isProcessing = false;
  String _status = '';
  String _terminalOutput = '';
  String? _outputSrtPath;

  // New state for model and language selection
  String _selectedModel = 'turbo';
  String _selectedLanguage = 'zh-HK';

  final List<String> _models = ['turbo', 'large-v3'];
  final Map<String, String> _languages = {
    'zh-HK': '繁體中文 (香港)',
    'en-US': 'English',
    'zh_CN': '简体中文',
    'ja_JP': '日本語',
  };

  // Hardcoded project path as specified by the user
  final String _projectRoot = '/Users/wmsing/Documents/tony/github/text_to_video/tt_video';

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedVideoPath = result.files.single.path;
        _status = '已選擇視頻: ${p.basename(_selectedVideoPath!)}';
        _outputSrtPath = null;
        _terminalOutput = '';
      });
    }
  }

  Future<void> _extractSubtitles() async {
    if (_selectedVideoPath == null) return;

    setState(() {
      _isProcessing = true;
      _status = '正在提取字幕... 請稍候';
      _terminalOutput = '';
    });

    try {
      // Use the python interpreter from the virtual environment (.venv)
      // This ensures openai-whisper and other dependencies are correctly found
      final venvPython = '$_projectRoot/.venv/bin/python';
      final command = '$venvPython tools/index3.py -v "$_selectedVideoPath" -l $_selectedLanguage --model $_selectedModel';
      
      final process = await Process.start(
        'zsh',
        [
          '-l',
          '-c',
          'cd $_projectRoot && $command'
        ],
      );

      // Listen to stdout and stderr
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
        // Assume SRT is generated in the same folder as the video or project output
        // Based on the user's command, let's look for the .srt file
        final videoName = p.basenameWithoutExtension(_selectedVideoPath!);
        // Usually these tools generate output in a specific folder or same as input.
        // I'll show the terminal output so the user knows where it went.
        setState(() {
          _status = '字幕提取完成！';
          _isProcessing = false;
        });
      } else {
        setState(() {
          _status = '提取失敗，退出代碼: $exitCode';
          _isProcessing = false;
        });
      }
    } catch (e) {
      print("Subtitle extraction error: $e");
      setState(() {
        _status = '錯誤: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _openProjectFolder() async {
    final url = Uri.file(_projectRoot);
    if (Platform.isMacOS) {
      await Process.run('open', [_projectRoot]);
    } else if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('提取字幕 (Video to SRT)')),
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
                    const Text('工具路徑:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_projectRoot, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _pickVideo,
                      icon: const Icon(Icons.video_file),
                      label: const Text('選擇視頻文件'),
                    ),
                    if (_selectedVideoPath != null) ...[
                      const SizedBox(height: 8),
                      Text('已選: ${p.basename(_selectedVideoPath!)}', 
                           style: const TextStyle(color: Colors.blue)),
                    ],
                    const Divider(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('語言 Language:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              DropdownButton<String>(
                                value: _selectedLanguage,
                                isExpanded: true,
                                items: _languages.entries.map((e) {
                                  return DropdownMenuItem(value: e.key, child: Text(e.value));
                                }).toList(),
                                onChanged: _isProcessing ? null : (val) {
                                  if (val != null) setState(() => _selectedLanguage = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('模型 Model:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              DropdownButton<String>(
                                value: _selectedModel,
                                isExpanded: true,
                                items: _models.map((m) {
                                  return DropdownMenuItem(value: m, child: Text(m));
                                }).toList(),
                                onChanged: _isProcessing ? null : (val) {
                                  if (val != null) setState(() => _selectedModel = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (_selectedVideoPath == null || _isProcessing) ? null : _extractSubtitles,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isProcessing 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('開始提取 ($_selectedLanguage ${_selectedModel.toUpperCase()})'),
            ),
            const SizedBox(height: 20),
            Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_terminalOutput.isNotEmpty) ...[
              const Text('終端輸出:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Container(
                height: 200,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _terminalOutput,
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
            OutlinedButton.icon(
              onPressed: _openProjectFolder,
              label: const Text('打開工具所在文件夾', style: TextStyle(color: Colors.grey),),
            ),
          ],
        ),
      ),
    );
  }
}
