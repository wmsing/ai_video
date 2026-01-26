import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String? _generatedSrtPath;
  String? _projectRoot;
  String? _mainFolderPath;

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
        _status = '已選擇視頻: ${p.basename(_selectedVideoPath!)}';
        _generatedSrtPath = null;
        _terminalOutput = '';
      });
    }
  }

  Future<void> _extractSubtitles() async {
    if (_selectedVideoPath == null || _projectRoot == null) return;

    setState(() {
      _isProcessing = true;
      _status = '正在提取字幕... 請稍候';
      _terminalOutput = '';
    });

    try {
      // Use the python interpreter from the virtual environment (.venv or venv)
      // This ensures openai-whisper and other dependencies are correctly found
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
      
      // Verification
      setState(() {
        _terminalOutput += "檢查路徑...\n";
        _terminalOutput += "工具目錄: $_projectRoot\n";
        _terminalOutput += "Python路徑: ${venvPython ?? "未找到"}\n";
      });

      if (!await Directory(_projectRoot!).exists()) {
        throw "工具目錄不存在：$_projectRoot";
      }
      if (venvPython == null) {
        throw "找不到 Python 環境 (.venv 或 venv)，請確保已在大模型工具目錄內執行安裝步驟。";
      }

      final command = '"$venvPython" tools/index3.py -v "$_selectedVideoPath" -l $_selectedLanguage --model $_selectedModel';
      
      final process = await Process.start(
        'zsh',
        [
          '-l',
          '-c',
          'cd "$_projectRoot" && $command'
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
        final videoDir = p.dirname(_selectedVideoPath!);
        final videoName = p.basenameWithoutExtension(_selectedVideoPath!);
        
        // 定義可能的 SRT 路徑模式
        List<String> possibleSrtPaths = [
          p.join(videoDir, 'srt', '${videoName}_final.srt'), // 使用者提到的模式
          p.join(videoDir, 'srt', '$videoName.srt'), // srt 子資料夾
          p.join(videoDir, '$videoName.srt'), // 同目錄
          p.join(videoDir, '${videoName}_final.srt'), // 同目錄帶 final
          p.join(videoDir, '$videoName.$_selectedLanguage.srt'), // 帶語言後綴
          p.join(_projectRoot!, '$videoName.srt'), // 工具根目錄
        ];

        String? foundPath;
        for (var path in possibleSrtPaths) {
          if (await File(path).exists()) {
            foundPath = path;
            break;
          }
        }

        // 如果還是找不到，嘗試在附近的目錄搜尋
        if (foundPath == null) {
          try {
            // 搜尋影片目錄及其 srt 子目錄
            final searchDirs = [Directory(videoDir), Directory(p.join(videoDir, 'srt'))];
            for (var dir in searchDirs) {
              if (await dir.exists()) {
                final files = await dir.list().toList();
                final srtFiles = files.whereType<File>().where((f) => 
                  p.extension(f.path).toLowerCase() == '.srt' && 
                  (p.basename(f.path).contains(videoName) || p.basename(f.path).contains('final'))
                ).toList();
                
                if (srtFiles.isNotEmpty) {
                  srtFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
                  foundPath = srtFiles.first.path;
                  break;
                }
              }
            }
          } catch (_) {}
        }

        setState(() {
          if (foundPath != null) {
            _status = '字幕提取成功！';
            _generatedSrtPath = foundPath;
            _terminalOutput += '\n[App] 找到字幕檔: $foundPath\n';
          } else {
            _status = '提取完成，但找不到 SRT 檔案。';
            _generatedSrtPath = null;
            _terminalOutput += '\n[App] 搜尋了以下路徑但未發現 SRT:\n${possibleSrtPaths.join('\n')}\n';
          }
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

  Future<void> _autoEmbedSubtitles() async {
    if (_selectedVideoPath == null || _generatedSrtPath == null || _projectRoot == null) return;

    setState(() {
      _isProcessing = true;
      _status = '正在將字幕壓制入影片... 請稍候';
      _terminalOutput = '\n--- 開始壓制字幕 ---\n';
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

      if (venvPython == null) throw "找不到 Python 環境";

      final String dirName = p.dirname(_selectedVideoPath!);
      final String baseName = p.basenameWithoutExtension(_selectedVideoPath!);
      final String outputPath = p.join(dirName, '${baseName}_final.mp4');

      final command = '"$venvPython" tools/index2.py -v "$_selectedVideoPath" -s "$_generatedSrtPath" -o "$outputPath"';
      
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
      setState(() {
        _isProcessing = false;
        if (exitCode == 0) {
          _status = '影片壓制成功！\n儲存於: ${p.basename(outputPath)}';
        } else {
          _status = '壓制失敗，退出代碼: $exitCode';
        }
      });
    } catch (e) {
      setState(() {
        _status = '壓制錯誤: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _openProjectFolder() async {
    if (_projectRoot == null) return;
    final url = Uri.file(_projectRoot!);
    if (Platform.isMacOS) {
      await Process.run('open', [_projectRoot!]);
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
                    Text(_projectRoot ?? '尚未設置', style: const TextStyle(color: Colors.grey)),
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
            if (_generatedSrtPath != null && !_isProcessing) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _autoEmbedSubtitles,
                icon: const Icon(Icons.movie_filter),
                label: const Text('一鍵壓制字幕到影片 (產生 _final.mp4)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
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
