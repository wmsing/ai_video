import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class GoldenQuotesCutPage extends StatefulWidget {
  const GoldenQuotesCutPage({super.key});

  @override
  State<GoldenQuotesCutPage> createState() => _GoldenQuotesCutPageState();
}

class _GoldenQuotesCutPageState extends State<GoldenQuotesCutPage> {
  String? _selectedVideoPath;
  String? _selectedJsonPath;
  String? _projectRoot;
  String? _mainFolderPath;
  bool _isProcessing = false;
  String _status = '';
  String _terminalOutput = '';
  final TextEditingController _jsonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
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
      final path = result.files.single.path!;
      final content = await File(path).readAsString();
      setState(() {
        _selectedJsonPath = path;
        _jsonController.text = content;
        _status = '已選擇 JSON: ${p.basename(path)}';
      });
    }
  }

  void _showJsonEditorDialog() async {
    dynamic decoded;
    try {
      decoded = jsonDecode(_jsonController.text);
      if (decoded is! List) {
        throw Exception('JSON 必須是物件列表');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON 格式錯誤，無法以結構化方式編輯: $e')),
      );
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return _StructuredJsonDialog(
          initialData: decoded as List<dynamic>,
          defaultVideoPath: _selectedVideoPath,
          mainFolderPath: _mainFolderPath,
        );
      },
    );

    if (result != null) {
      _jsonController.text = result;
      await _saveJson();
    }
  }

  Future<void> _createNewJson() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return _StructuredJsonDialog(
          initialData: const [],
          defaultVideoPath: _selectedVideoPath,
          mainFolderPath: _mainFolderPath,
        );
      },
    );

    if (result != null) {
      String? fileName = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          if (_selectedVideoPath != null) {
            controller.text = p.basenameWithoutExtension(_selectedVideoPath!) + '_quotes.json';
          } else {
            controller.text = 'quotes.json';
          }
          return AlertDialog(
            title: const Text('輸入新的設定檔名稱'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'filename.json'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('創建'),
              ),
            ],
          );
        },
      );

      if (fileName != null && fileName.isNotEmpty) {
        if (!fileName.endsWith('.json')) fileName += '.json';
        
        String baseDir = _mainFolderPath ?? '';
        if (_selectedVideoPath != null) {
          baseDir = p.dirname(_selectedVideoPath!);
        }

        final newPath = p.join(baseDir, fileName);
        try {
          await File(newPath).writeAsString(result);
          setState(() {
            _selectedJsonPath = newPath;
            _jsonController.text = result;
            _status = '新設定檔已創建: ${p.basename(newPath)}';
          });
        } catch (e) {
          setState(() => _status = '創建失敗: $e');
        }
      }
    }
  }

  Future<void> _saveJson() async {
    if (_selectedJsonPath == null) return;
    try {
      await File(_selectedJsonPath!).writeAsString(_jsonController.text);
      setState(() {
        _status = 'JSON 已儲存';
      });
    } catch (e) {
      setState(() {
        _status = '儲存失敗: $e';
      });
    }
  }

  Future<void> _runGoldenQuotesCut() async {
    if (_selectedVideoPath == null || _selectedJsonPath == null || _projectRoot == null) {
      setState(() => _status = '請選擇影片、JSON 並設置工具路徑');
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = '正在生成金句影片... 請稍候';
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

      if (venvPython == null) {
        throw Exception('找不到虛擬環境中的 Python 執行檔');
      }

      final scriptPath = p.join(_projectRoot!, 'tools', 'create_quotes_video.py');
      
      final result = await Process.run(venvPython, [
        scriptPath,
        '-i', _selectedVideoPath!,
        '-c', _selectedJsonPath!,
      ]);

      setState(() {
        _status = result.exitCode == 0 ? '金句影片生成完成！' : '生成出錯';
        _terminalOutput = result.stdout + '\n' + result.stderr;
      });
    } catch (e) {
      setState(() {
        _status = '錯誤: $e';
        _terminalOutput = e.toString();
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('金句CUT'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_library),
              label: const Text('選擇影片 (MP4/MOV)'),
            ),
            if (_selectedVideoPath != null) ...[
              const SizedBox(height: 8),
              Text('影片：${p.basename(_selectedVideoPath!)}', style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickJson,
                    icon: const Icon(Icons.description),
                    label: const Text('選擇設定檔'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text("OR"),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedVideoPath != null ? _createNewJson : null,
                    icon: const Icon(Icons.add_box),
                    label: const Text('創建新設定檔'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedJsonPath != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('已載入設定檔：', style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
                          Text(p.basename(_selectedJsonPath!), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showJsonEditorDialog,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('編輯'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_isProcessing || _selectedVideoPath == null || _selectedJsonPath == null) ? null : _runGoldenQuotesCut,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade200,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isProcessing 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('生成金句影片 (Submit)'),
            ),
            const SizedBox(height: 16),
            Text('狀態: $_status', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('終端輸出:'),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _terminalOutput,
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StructuredJsonDialog extends StatefulWidget {
  final List<dynamic> initialData;
  final String? defaultVideoPath;
  final String? mainFolderPath;

  const _StructuredJsonDialog({
    required this.initialData,
    this.defaultVideoPath,
    this.mainFolderPath,
  });

  @override
  State<_StructuredJsonDialog> createState() => _StructuredJsonDialogState();
}

class _StructuredJsonDialogState extends State<_StructuredJsonDialog> {
  late List<Map<String, dynamic>> items;
  late List<Map<String, TextEditingController>> controllers;
  late List<Key> keys;
  late List<FocusNode> startFocusNodes;
  late List<FocusNode> endFocusNodes;
  VideoPlayerController? _videoController;
  bool _showVideoPlayer = true;
  double _currentSpeed = 1.0;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    items = List<Map<String, dynamic>>.from(
        widget.initialData.map((e) => Map<String, dynamic>.from(e)));
    controllers = items.map((item) {
      return {
        'title': TextEditingController(text: item['title']?.toString() ?? ''),
        'video_path': TextEditingController(text: item['video_path']?.toString() ?? ''),
        'start': TextEditingController(text: item['start']?.toString() ?? ''),
        'end': TextEditingController(text: item['end']?.toString() ?? ''),
        'font_size': TextEditingController(text: item['font_size']?.toString() ?? ''),
      };
    }).toList();
    keys = List.generate(items.length, (index) => UniqueKey());
    startFocusNodes = List.generate(items.length, (index) => FocusNode());
    endFocusNodes = List.generate(items.length, (index) => FocusNode());

    for (int i = 0; i < items.length; i++) {
      startFocusNodes[i].addListener(() => _onFocusChange(i, 'start'));
      endFocusNodes[i].addListener(() => _onFocusChange(i, 'end'));
    }

    _initVideo();
  }

  void _initVideo() {
    if (widget.defaultVideoPath != null) {
      String videoPath = widget.defaultVideoPath!;
      File file = File(videoPath);

      print('DEBUG: Initial videoPath: $videoPath');

      // Robust path resolution for relative paths
      if (!file.existsSync() && !p.isAbsolute(videoPath)) {
        print('DEBUG: File not found at relative path, trying resolution...');
        if (widget.mainFolderPath != null) {
          String altPath = p.join(widget.mainFolderPath!, videoPath);
          print('DEBUG: Trying mainFolderPath resolution: $altPath');
          if (File(altPath).existsSync()) {
            videoPath = altPath;
            file = File(videoPath);
          }
        }
        if (!file.existsSync()) {
          videoPath = p.join(Directory.current.path, videoPath);
          print('DEBUG: Trying Directory.current resolution: $videoPath');
          file = File(videoPath);
        }
      }

      print('DEBUG: Final video file path: ${file.absolute.path}');
      if (!file.existsSync()) {
        print('DEBUG: Final file DOES NOT EXIST');
        setState(() {
          _videoError = '找不到影片檔案: $videoPath\n(已嘗試從主資料夾與目前目錄解析)';
        });
        return;
      }

      // Check for reading permissions
      try {
        file.readAsBytesSync();
        print('DEBUG: File readability check PASSED');
      } catch (e) {
        print('DEBUG: File readability check FAILED: $e');
        setState(() {
          _videoError = '無法讀取影片檔案 (權限問題?): $e';
        });
        return;
      }

      _videoController = VideoPlayerController.file(file);
      
      // Add a listener to catch initialization state changes earlier
      _videoController!.addListener(() {
        if (_videoController!.value.hasError) {
          print('DEBUG: Video Error from listener: ${_videoController!.value.errorDescription}');
          if (mounted && _videoError == null) {
            setState(() {
              _videoError = '影片載入錯誤: ${_videoController!.value.errorDescription}';
            });
          }
        }
        if (_videoController!.value.isInitialized && _videoError != null) {
          setState(() {
            _videoError = null;
          });
        }
      });

      _videoController!.initialize().then((_) {
        print('DEBUG: Video initialized successfully. Duration: ${_videoController!.value.duration}');
        if (mounted) {
          setState(() {
            _videoError = null;
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _videoError = '影片載入失敗 (Codec/Format?): $error';
          });
        }
        print('DEBUG: Video initialization error: $error');
      });

      // Increase timeout to 60 seconds for very long videos (like 2-hour movies)
      Future.delayed(const Duration(seconds: 60), () {
        if (mounted && _videoController != null && !_videoController!.value.isInitialized && _videoError == null) {
          print('DEBUG: Video initialization TIMED OUT after 60s');
          setState(() {
            _videoError = '影片載入超時 (這段影片長達 2 小時，可能是系統正在解析中，或者受限於 macOS App Sandbox)。\n若一直無法載入，建議將影片移至專案目錄內再試。';
          });
        }
      });
    }
  }

  @override
  void dispose() {
    for (var charControllers in controllers) {
      for (var controller in charControllers.values) {
        controller.dispose();
      }
    }
    for (var node in startFocusNodes) {
      node.dispose();
    }
    for (var node in endFocusNodes) {
      node.dispose();
    }
    _videoController?.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      items.add({
        'title': '',
        'start': '00:00:00',
        'end': '00:00:05',
      });
      controllers.add({
        'title': TextEditingController(text: ''),
        'video_path': TextEditingController(text: ''),
        'start': TextEditingController(text: '00:00:00'),
        'end': TextEditingController(text: '00:00:05'),
        'font_size': TextEditingController(text: ''),
      });
      keys.add(UniqueKey());
      startFocusNodes.add(FocusNode());
      endFocusNodes.add(FocusNode());
      startFocusNodes.last.addListener(() => _onFocusChange(items.length - 1, 'start'));
      endFocusNodes.last.addListener(() => _onFocusChange(items.length - 1, 'end'));
    });
  }

  void _removeItem(int index) {
    setState(() {
      final removed = controllers.removeAt(index);
      for (var controller in removed.values) {
        controller.dispose();
      }
      items.removeAt(index);
      keys.removeAt(index);
      startFocusNodes[index].dispose();
      endFocusNodes[index].dispose();
      startFocusNodes.removeAt(index);
      endFocusNodes.removeAt(index);
    });
  }

  void _setStartTime(int index) {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final position = _videoController!.value.position;
      final formatted = _formatDuration(position);
      controllers[index]['start']!.text = formatted;
    }
  }

  void _setEndTime(int index) {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final position = _videoController!.value.position;
      final formatted = _formatDuration(position);
      controllers[index]['end']!.text = formatted;
    }
  }

  void _setPlaybackSpeed(double speed) {
    if (_videoController != null) {
      _videoController!.setPlaybackSpeed(speed);
      setState(() {
        _currentSpeed = speed;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _onFocusChange(int index, String type) {
    final focusNode = type == 'start' ? startFocusNodes[index] : endFocusNodes[index];
    if (focusNode.hasFocus) {
      final text = controllers[index][type]!.text;
      if (text.isNotEmpty) {
        final duration = _parseDuration(text);
        if (duration != null && _videoController != null) {
          _videoController!.seekTo(duration);
        }
      }
    }
  }

  Duration? _parseDuration(String timeString) {
    final parts = timeString.split(':');
    if (parts.length == 3) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      final seconds = int.tryParse(parts[2]) ?? 0;
      return Duration(hours: hours, minutes: minutes, seconds: seconds);
    }
    return null;
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
      
      final controller = controllers.removeAt(oldIndex);
      controllers.insert(newIndex, controller);
      
      final key = keys.removeAt(oldIndex);
      keys.insert(newIndex, key);

      final startNode = startFocusNodes.removeAt(oldIndex);
      startFocusNodes.insert(newIndex, startNode);

      final endNode = endFocusNodes.removeAt(oldIndex);
      endFocusNodes.insert(newIndex, endNode);
    });
  }

  void _save() {
    final List<Map<String, dynamic>> result = [];
    for (int i = 0; i < items.length; i++) {
      final Map<String, dynamic> item = {};
      final itemControllers = controllers[i];
      
      item['title'] = itemControllers['title']!.text;
      if (itemControllers['video_path']!.text.isNotEmpty) {
        item['video_path'] = itemControllers['video_path']!.text;
      }
      item['start'] = itemControllers['start']!.text;
      item['end'] = itemControllers['end']!.text;
      
      if (itemControllers['font_size']!.text.isNotEmpty) {
        item['font_size'] = int.tryParse(itemControllers['font_size']!.text) ?? itemControllers['font_size']!.text;
      }
      
      result.add(item);
    }
    Navigator.pop(context, const JsonEncoder.withIndent('  ').convert(result));
  }

  Future<void> _pickItemVideo(int index) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      initialDirectory: widget.mainFolderPath,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        controllers[index]['video_path']!.text = result.files.single.path!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.all(10),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('結構化編輯 JSON'),
              Row(
                children: [
                  if (_videoController != null) ...[
                    IconButton(
                      onPressed: () => setState(() => _showVideoPlayer = !_showVideoPlayer),
                      icon: Icon(_showVideoPlayer ? Icons.videocam_off : Icons.videocam),
                      tooltip: _showVideoPlayer ? '隱藏影片播放器' : '顯示影片播放器',
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('新增金句'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (widget.defaultVideoPath != null) ...[
            const SizedBox(height: 8),
            Text(
              '預設影片：${p.basename(widget.defaultVideoPath!)}',
              style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.normal),
            ),
          ],
          const Text(
            '預設字體大小：90',
            style: TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.normal),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 800,
        child: KeyboardListener(
          focusNode: FocusNode(),
          autofocus: true,
          onKeyEvent: (KeyEvent event) {
            // if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
            //   if (_videoController != null) {
            //     setState(() {
            //       _videoController!.value.isPlaying
            //           ? _videoController!.pause()
            //           : _videoController!.play();
            //     });
            //   }
            // }
          },
          child: Row(
          children: [
            Expanded(
              flex: 1,
              child: ReorderableListView(
                onReorder: _onReorder,
                children: List.generate(items.length, (index) {
                  final itemControllers = controllers[index];
                  return Card(
                    key: keys[index],
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.drag_handle, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text('金句 #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeItem(index),
                                tooltip: '刪除此項',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: itemControllers['title'],
                            maxLines: 2,
                            decoration: const InputDecoration(labelText: '標題 (Title)', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: itemControllers['start'],
                                  focusNode: startFocusNodes[index],
                                  decoration: const InputDecoration(labelText: '開始時間 (Start)', hintText: '00:00:00'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _setStartTime(index),
                                child: const Text('Set Start'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: itemControllers['end'],
                                  focusNode: endFocusNodes[index],
                                  decoration: const InputDecoration(labelText: '結束時間 (End)', hintText: '00:00:00'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _setEndTime(index),
                                child: const Text('Set End'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: itemControllers['video_path'],
                                  decoration: const InputDecoration(
                                    labelText: '影片路徑 (選填)',
                                    hintText: 'input/...',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _pickItemVideo(index),
                                icon: const Icon(Icons.file_open),
                                tooltip: '選擇影片檔',
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: itemControllers['font_size'],
                                  decoration: const InputDecoration(
                                    labelText: '字體',
                                    hintText: '70',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (_showVideoPlayer && _videoController != null) ...[
              const VerticalDivider(width: 20),
              Expanded(
                flex: 1,
                child: _videoError != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                _videoError!,
                                style: const TextStyle(color: Colors.red, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                FilePickerResult? result = await FilePicker.platform.pickFiles(
                                  type: FileType.video,
                                  initialDirectory: widget.mainFolderPath,
                                );
                                if (result != null && result.files.single.path != null) {
                                  final newPath = result.files.single.path!;
                                  _videoController?.dispose();
                                  _videoController = VideoPlayerController.file(File(newPath))
                                    ..initialize().then((_) {
                                      setState(() {
                                        _videoError = null;
                                      });
                                    }).catchError((e) {
                                      setState(() {
                                        _videoError = '重新載入失敗: $e';
                                      });
                                    });
                                }
                              },
                              icon: const Icon(Icons.file_open),
                              label: const Text('手動重新選擇影片'),
                            ),
                          ],
                        ),
                      )
                    : !_videoController!.value.isInitialized
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _videoController!.value.isPlaying
                                        ? _videoController!.pause()
                                        : _videoController!.play();
                                  });
                                },
                                child: AspectRatio(
                                  aspectRatio: _videoController!.value.aspectRatio,
                                  child: VideoPlayer(_videoController!),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _videoController!.value.isPlaying
                                            ? _videoController!.pause()
                                            : _videoController!.play();
                                      });
                                    },
                                    icon: Icon(
                                      _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                    ),
                                  ),
                                  Expanded(
                                    child: VideoProgressIndicator(
                                      _videoController!,
                                      allowScrubbing: true,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _setPlaybackSpeed(1.0),
                                    style: _currentSpeed == 1.0 ? TextButton.styleFrom(backgroundColor: Colors.blue.shade100) : null,
                                    child: const Text('1x'),
                                  ),
                                  TextButton(
                                    onPressed: () => _setPlaybackSpeed(2.0),
                                    style: _currentSpeed == 2.0 ? TextButton.styleFrom(backgroundColor: Colors.blue.shade100) : null,
                                    child: const Text('2x'),
                                  ),
                                  TextButton(
                                    onPressed: () => _setPlaybackSpeed(5.0),
                                    style: _currentSpeed == 5.0 ? TextButton.styleFrom(backgroundColor: Colors.blue.shade100) : null,
                                    child: const Text('5x'),
                                  ),
                                  TextButton(
                                    onPressed: () => _setPlaybackSpeed(10.0),
                                    style: _currentSpeed == 10.0 ? TextButton.styleFrom(backgroundColor: Colors.blue.shade100) : null,
                                    child: const Text('10x'),
                                  ),
                                ],
                              ),
                            ],
                          ),
              ),
            ],
          ],
        ),
      ),),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(onPressed: _save, child: const Text('儲存修改')),
      ],
    );
  }
}
