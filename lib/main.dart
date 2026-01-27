import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'download_page.dart';
import 'subtitle_page.dart';
import 'embed_subtitle_page.dart';
import 'story_video_page.dart';
import 'golden_quotes_cut_page.dart';
import 'cut_tool_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Video',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _mainFolderPath;
  String? _aiToolsPath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mainFolderPath = prefs.getString('main_folder_path');
      _aiToolsPath = prefs.getString('ai_tools_path');
    });
  }

  Future<void> _selectMainFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('main_folder_path', selectedDirectory);
      setState(() => _mainFolderPath = selectedDirectory);
    }
  }

  Future<void> _selectAiToolsFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_tools_path', selectedDirectory);
      setState(() => _aiToolsPath = selectedDirectory);
    }
  }

  Future<void> _openMainFolder() async {
    if (_mainFolderPath == null) return;
    
    final mainFolder = Directory(_mainFolderPath!);
    if (!await mainFolder.exists()) {
      await mainFolder.create(recursive: true);
    }
    
    if (Platform.isMacOS) {
      await Process.run('open', [_mainFolderPath!]);
    } else {
      final url = Uri.file(_mainFolderPath!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFolderSet = _mainFolderPath != null;
    final isToolsSet = _aiToolsPath != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Video App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (isFolderSet)
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: _openMainFolder,
              tooltip: '打開主資料夾',
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Download Location display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: isFolderSet ? Colors.green.shade50 : Colors.red.shade50,
              child: Row(
                children: [
                  Icon(isFolderSet ? Icons.check_circle : Icons.warning, color: isFolderSet ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(isFolderSet ? '下載路徑：$_mainFolderPath' : '請設置下載資料夾')),
                  TextButton(onPressed: _selectMainFolder, child: Text(isFolderSet ? '更改' : '設置')),
                ],
              ),
            ),
            // 2. AI Tools Path display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: isToolsSet ? Colors.blue.shade50 : Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(isToolsSet ? Icons.settings_suggest : Icons.error_outline, color: isToolsSet ? Colors.blue : Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(isToolsSet ? 'AI工具路徑 (tt_video)：$_aiToolsPath' : '請設置 tt_video 工具夾路徑')),
                  TextButton(onPressed: _selectAiToolsFolder, child: Text(isToolsSet ? '更改' : '設置')),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Action Buttons
                  Opacity(
                    opacity: (isFolderSet && isToolsSet) ? 1.0 : 0.5,
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: isFolderSet ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const DownloadPage()),
                            );
                          } : null,
                          style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                          child: const Text('下載影片 (YouTube/M3U8)'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: (isFolderSet && isToolsSet) ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const SubtitlePage()),
                            );
                          } : null,
                          style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                          child: const Text('提取字幕 (Whisper AI)'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: (isFolderSet && isToolsSet) ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const EmbedSubtitlePage()),
                            );
                          } : null,
                          style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                          child: const Text('加字幕入影片'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: (isFolderSet && isToolsSet) ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const StoryVideoPage()),
                            );
                          } : null,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(200, 45),
                            backgroundColor: Colors.orange.shade100,
                          ),
                          child: const Text('劇情影片 (Summary)'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: (isFolderSet && isToolsSet) ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const CutToolPage()),
                            );
                          } : null,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(200, 45),
                            backgroundColor: Colors.blue.shade100,
                          ),
                          child: const Text('CUT工具'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: (isFolderSet && isToolsSet) ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const GoldenQuotesCutPage()),
                            );
                          } : null,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(200, 45),
                            backgroundColor: Colors.amber.shade100,
                          ),
                          child: const Text('金句CUT'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
