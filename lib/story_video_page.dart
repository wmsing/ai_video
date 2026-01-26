import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class StoryVideoPage extends StatefulWidget {
  const StoryVideoPage({super.key});

  @override
  State<StoryVideoPage> createState() => _StoryVideoPageState();
}

class _StoryVideoPageState extends State<StoryVideoPage> {
  String? _selectedVideoPath;
  String? _selectedJsonPath;
  String? _projectRoot;
  String? _mainFolderPath;
  bool _isProcessing = false;
  String _status = '';
  String _terminalOutput = '';

  // Options
  String _selectedLanguage = 'en';
  double _clipDuration = 12.0;

  final Map<String, String> _languages = {
    'en': 'English',
    'cn': '简体中文',
    'hk': '繁體中文 (香港)',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _projectRoot = prefs.getString('ai_tools_path');
      _mainFolderPath = prefs.getString('main_folder_path');
    });
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      initialDirectory: _mainFolderPath,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedVideoPath = result.files.single.path;
        _status = '已選擇影片: ${p.basename(_selectedVideoPath!)}';
      });
    }
  }

  Future<void> _pickJson() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      initialDirectory: _mainFolderPath,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedJsonPath = result.files.single.path;
        _status = '已選擇時間線 JSON: ${p.basename(_selectedJsonPath!)}';
      });
    }
  }

  Future<void> _createSummary() async {
    if (_selectedVideoPath == null || _selectedJsonPath == null || _projectRoot == null) {
      setState(() => _status = '請選擇影片、JSON 檔案並設置工具路徑');
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = '正在生成劇情短片... 請稍候';
      _terminalOutput = '';
    });

    try {
      String? venvPython;
      final possibleVenvPaths = [
        p.join(_projectRoot!, '.venv', 'bin', 'python'),
        p.join(_projectRoot!, 'venv', 'bin', 'python'),
      ];

      for (var path in possibleVenvPaths) {
        if (await File(path).exists()) {
          venvPython = path;
          break;
        }
      }

      if (venvPython == null) throw "找不到 Python 環境 (.venv 或 venv)";

      // Output path in the same folder as video with _summary suffix
      final String dirName = p.dirname(_selectedVideoPath!);
      final String baseName = p.basenameWithoutExtension(_selectedVideoPath!);
      final String outputPath = p.join(dirName, '${baseName}_summary.mp4');

      final command = '"$venvPython" tools/create_video_summary.py '
          '-v "$_selectedVideoPath" '
          '-j "$_selectedJsonPath" '
          '-o "$outputPath" '
          '--mode video '
          '--lang $_selectedLanguage '
          '--aspect 9:16 '
          '--clip_duration ${_clipDuration.toInt()}';

      setState(() {
        _terminalOutput += "執行指令:\n$command\n\n";
      });

      final process = await Process.start(
        'zsh',
        ['-l', '-c', 'cd "$_projectRoot" && $command'],
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
          _status = '劇情短片生成成功！\n儲存於: ${p.basename(outputPath)}';
          _isProcessing = false;
        });
      } else {
        setState(() {
          _status = '生成失敗，退出代碼: $exitCode';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('劇情影片生成 (Video Summary)')),
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
                    const Text('設定素材:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.video_file),
                      title: Text(_selectedVideoPath == null ? '選擇原片' : p.basename(_selectedVideoPath!)),
                      subtitle: const Text('必選'),
                      onTap: _isProcessing ? null : _pickVideo,
                      trailing: const Icon(Icons.chevron_right),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.description),
                      title: Text(_selectedJsonPath == null ? '選擇時間線 JSON' : p.basename(_selectedJsonPath!)),
                      subtitle: const Text('必選'),
                      onTap: _isProcessing ? null : _pickJson,
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('參數設定:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('影片語言:'),
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
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('片段時長 (clip_duration): ${_clipDuration.toInt()}s'),
                        const Text('(默認 12)'),
                      ],
                    ),
                    Slider(
                      value: _clipDuration,
                      min: 3,
                      max: 30,
                      divisions: 27,
                      label: '${_clipDuration.toInt()}s',
                      onChanged: _isProcessing ? null : (val) {
                        setState(() => _clipDuration = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_selectedVideoPath == null || _selectedJsonPath == null || _isProcessing) ? null : _createSummary,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isProcessing 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('開始生成劇情影片'),
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
          ],
        ),
      ),
    );
  }
}
