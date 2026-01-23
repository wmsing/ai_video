import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'download_page.dart';
import 'subtitle_page.dart';
import 'embed_subtitle_page.dart';

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

  @override
  void initState() {
    super.initState();
    _loadMainFolder();
  }

  Future<void> _loadMainFolder() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mainFolderPath = prefs.getString('main_folder_path');
    });
  }

  Future<void> _selectMainFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('main_folder_path', selectedDirectory);
      setState(() {
        _mainFolderPath = selectedDirectory;
      });
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
            // Top Location Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: isFolderSet ? Colors.green.shade50 : Colors.red.shade50,
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isFolderSet ? Icons.check_circle : Icons.warning,
                        color: isFolderSet ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isFolderSet 
                            ? '主資料夾已設置：\n$_mainFolderPath' 
                            : '尚未設置主資料夾，請先選擇存放位置',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isFolderSet ? Colors.green.shade900 : Colors.red.shade900,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _selectMainFolder,
                        child: Text(isFolderSet ? '更改' : '設置'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (isFolderSet) ...[
                    ElevatedButton.icon(
                      onPressed: _openMainFolder,
                      icon: const Icon(Icons.folder_special),
                      label: const Text('打開主資料夾'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade100,
                        minimumSize: const Size(250, 50),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  
                  // Action Buttons
                  Opacity(
                    opacity: isFolderSet ? 1.0 : 0.5,
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: isFolderSet ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const DownloadPage()),
                            );
                          } : null,
                          style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                          child: const Text('下載影片'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: isFolderSet ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const SubtitlePage()),
                            );
                          } : null,
                          style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                          child: const Text('提取字幕 (SRT)'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: isFolderSet ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const EmbedSubtitlePage()),
                            );
                          } : null,
                          style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                          child: const Text('加字幕入影片'),
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
