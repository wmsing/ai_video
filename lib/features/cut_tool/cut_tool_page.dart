import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class CutToolPage extends StatefulWidget {
  const CutToolPage({super.key});

  @override
  State<CutToolPage> createState() => _CutToolPageState();
}

class _CutToolPageState extends State<CutToolPage> {
  VideoPlayerController? _videoPlayerController;
  File? _selectedFile;
  final TextEditingController _startTimeController = TextEditingController(text: '00:00:00');
  final TextEditingController _endTimeController = TextEditingController(text: '00:00:10');
  final TextEditingController _fileNameController = TextEditingController(text: '_cut');
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _concatenateOutputController = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode = FocusNode();
  
  List<File> _concatenateFiles = [];
  bool _isProcessing = false;
  String _status = '';
  double _currentSpeed = 1.0;
  String? _mainFolderPath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _startFocusNode.addListener(() => _onFocusChange('start'));
    _endFocusNode.addListener(() => _onFocusChange('end'));
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mainFolderPath = prefs.getString('main_folder_path');
    });
  }

  Future<void> _openFolder() async {
    String? folderPath;
    if (_selectedFile != null) {
      folderPath = p.dirname(_selectedFile!.path);
    } else {
      folderPath = _mainFolderPath;
    }
    if (folderPath != null) {
      if (Platform.isMacOS) {
        await Process.run('open', [folderPath]);
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _fileNameController.dispose();
    _titleController.dispose();
    _concatenateOutputController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange(String type) {
    final focusNode = type == 'start' ? _startFocusNode : _endFocusNode;
    if (focusNode.hasFocus) {
      final controller = type == 'start' ? _startTimeController : _endTimeController;
      final text = controller.text.trim();
      if (text.isNotEmpty) {
        final duration = _parseDuration(text);
        if (duration != null && _videoPlayerController != null) {
          _videoPlayerController!.seekTo(duration);
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _setStartTime() {
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      final position = _videoPlayerController!.value.position;
      setState(() {
        _startTimeController.text = _formatDuration(position);
      });
    }
  }

  void _setEndTime() {
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      final position = _videoPlayerController!.value.position;
      setState(() {
        _endTimeController.text = _formatDuration(position);
      });
    }
  }

  void _setPlaybackSpeed(double speed) {
    if (_videoPlayerController != null) {
      _videoPlayerController!.setPlaybackSpeed(speed);
      setState(() {
        _currentSpeed = speed;
      });
    }
  }

  Future<void> _selectVideo() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      initialDirectory: _mainFolderPath
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _status = 'Selected: ${p.basename(_selectedFile!.path)}';
      });
      _initVideoPlayer(_selectedFile!);
    }
  }

  Future<void> _initVideoPlayer(File file) async {
    await _videoPlayerController?.dispose();
    _videoPlayerController = VideoPlayerController.file(file);
    await _videoPlayerController!.initialize();
    // Set default start to 00:00:00 and end to video duration
    _startTimeController.text = '00:00:00';
    _endTimeController.text = _formatDuration(_videoPlayerController!.value.duration);
    setState(() {});
  }

  Future<void> _cutVideo() async {
    if (_selectedFile == null) return;
    
    setState(() {
      _isProcessing = true;
      _status = 'Cutting video...';
    });

    try {
      final inputPath = _selectedFile!.path;
      final dir = p.dirname(inputPath);
      final ext = p.extension(inputPath);
      final name = p.basenameWithoutExtension(inputPath);
      final customSuffix = _fileNameController.text.trim();
      final outputPath = p.join(dir, '$name$customSuffix$ext');

      final start = _startTimeController.text.trim();
      final end = _endTimeController.text.trim();
      final title = _titleController.text.trim();

      String ffmpegCmd;
      if (title.isEmpty) {
        // Lossless cut if no text burns in
        ffmpegCmd = 'ffmpeg -i "$inputPath" -ss "$start" -to "$end" -c copy -y "$outputPath"';
      } else {
        // Burn text requires re-encoding
        // Escaping single quotes for ffmpeg drawtext
        final escapedTitle = title.replaceAll("'", "'\\\\''");
        // Using STHeiti Medium for robust Chinese support on macOS
        // We use single quotes inside the filter to handle the space in the font path
        const fontPath = '/System/Library/Fonts/STHeiti Medium.ttc';
        ffmpegCmd = 'ffmpeg -i "$inputPath" -ss "$start" -to "$end" '
            '-vf "drawtext=fontfile=\'$fontPath\':text=\'$escapedTitle\':x=(w-text_w)/2:y=10:fontsize=24:fontcolor=yellow:shadowcolor=black@0.5:shadowx=2:shadowy=2" '
            '-c:v libx264 -preset fast -crf 23 -c:a copy -y "$outputPath"';
      }

      final result = await Process.run('zsh', [
        '-l',
        '-c',
        ffmpegCmd
      ]);

      if (result.exitCode == 0) {
        setState(() => _status = 'Cut finished: $outputPath');
        _showOpenFolderButton(outputPath);
      } else {
        setState(() => _status = 'Error: ${result.stderr}');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showOpenFolderButton(String filePath) {
    // This could be a snackbar or just a status update
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('完成！已儲存至 $filePath'),
        action: SnackBarAction(
          label: '打開資料夾',
          onPressed: () async {
            final dir = p.dirname(filePath);
            if (Platform.isMacOS) {
              await Process.run('open', [dir]);
            }
          },
        ),
      ),
    );
  }

  Future<void> _selectConcatenateVideos() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.video,
      allowMultiple: true,
      initialDirectory: _mainFolderPath
    );

    if (result != null) {
      setState(() {
        _concatenateFiles = result.paths.map((path) => File(path!)).toList();
        _status = 'Selected ${_concatenateFiles.length} videos to concatenate';
      });
    }
  }

  Future<void> _concatenateVideos() async {
    if (_concatenateFiles.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _status = 'Concatenating videos...';
    });

    try {
      final dir = p.dirname(_concatenateFiles.first.path);
      final ext = p.extension(_concatenateFiles.first.path);
      final baseName = _concatenateOutputController.text.trim();
      final isDefault = baseName.isEmpty || baseName == 'concatenated';
      final fileName = isDefault ? '${baseName.isEmpty ? 'concatenated' : baseName}_${DateTime.now().millisecondsSinceEpoch}$ext' : '$baseName$ext';
      final outputPath = p.join(dir, fileName);

      // Create temporary file list for ffmpeg
      final listFile = File(p.join(dir, 'ffmpeg_list.txt'));
      final content = _concatenateFiles.map((f) => "file '${f.path}'").join('\n');
      await listFile.writeAsString(content);

      // ffmpeg -f concat -safe 0 -i ffmpeg_list.txt -c copy output.mp4
      final result = await Process.run('zsh', [
        '-l',
        '-c',
        'ffmpeg -f concat -safe 0 -i "${listFile.path}" -c copy -y "$outputPath"'
      ]);

      await listFile.delete();

      if (result.exitCode == 0) {
        setState(() => _status = 'Concatenation finished: $outputPath');
        _showOpenFolderButton(outputPath);
      } else {
        setState(() => _status = 'Error: ${result.stderr}');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CUT工具'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _openFolder,
            tooltip: '打開資料夾',
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Side: Functions
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('功能 1: 裁剪 (Cut)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _selectVideo,
                      icon: const Icon(Icons.file_open),
                      label: const Text('選擇影片'),
                    ),
                    if (_selectedFile != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText('已選: ${p.basename(_selectedFile!.path)}'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              // Copy the full path to clipboard
                              Clipboard.setData(ClipboardData(text: _selectedFile!.path));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('檔案路徑已複製到剪貼簿')),
                              );
                            },
                            tooltip: '複製檔案路徑',
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _startTimeController,
                              focusNode: _startFocusNode,
                              onSubmitted: (val) => _onFocusChange('start'),
                              decoration: const InputDecoration(labelText: '開始時間 (HH:MM:SS)'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _setStartTime,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent.shade100,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('套用時間', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _endTimeController,
                              focusNode: _endFocusNode,
                              onSubmitted: (val) => _onFocusChange('end'),
                              decoration: const InputDecoration(labelText: '結束時間 (HH:MM:SS)'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _setEndTime,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.shade100,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('套用時間', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: '影片標題 (顯示在頂部中間)',
                          hintText: '輸入文字，將以黃色顯示',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _fileNameController,
                        decoration: const InputDecoration(
                          labelText: '檔案名稱後綴 (例如: _cut)',
                          hintText: '_cut',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _cutVideo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade100,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('執行裁切'),
                        ),
                      ),
                    ],
                    const Divider(height: 32),
                    const Text('功能 2: 合併 (Concatenate)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _selectConcatenateVideos,
                      icon: const Icon(Icons.library_add),
                      label: const Text('選擇多個影片'),
                    ),
                    if (_concatenateFiles.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('已選 ${_concatenateFiles.length} 個影片:'),
                      ..._concatenateFiles.map((f) => SelectableText('- ${p.basename(f.path)}')),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _concatenateOutputController,
                        decoration: const InputDecoration(
                          labelText: '輸出檔案名稱 (可選)',
                          hintText: 'concatenated',
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _isProcessing ? null : _concatenateVideos,
                        child: const Text('執行合併'),
                      ),
                    ],
                    const Divider(height: 32),
                    if (_isProcessing) const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    SelectableText(_status, style: const TextStyle(color: Colors.blue)),
                  ],
                ),
              ),
            ),
          ),
          
          // Right Side: Video Player
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black12,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized)
                    AspectRatio(
                      aspectRatio: _videoPlayerController!.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          VideoPlayer(_videoPlayerController!),
                          _VideoControls(
                            controller: _videoPlayerController!,
                            currentSpeed: _currentSpeed,
                            onSpeedChanged: _setPlaybackSpeed,
                          ),
                        ],
                      ),
                    )
                  else
                    const Center(child: Text('未播放影片', style: TextStyle(color: Colors.grey))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;
  final double currentSpeed;
  final Function(double) onSpeedChanged;

  const _VideoControls({
    required this.controller,
    required this.currentSpeed,
    required this.onSpeedChanged,
  });

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  @override
  void didUpdateWidget(_VideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_update);
      widget.controller.addListener(_update);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black45,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  widget.controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  widget.controller.value.isPlaying
                      ? widget.controller.pause()
                      : widget.controller.play();
                },
              ),
              Expanded(
                child: VideoProgressIndicator(
                  widget.controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(playedColor: Colors.red),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '${_formatDuration(widget.controller.value.position)} / ${_formatDuration(widget.controller.value.duration)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _speedButton(1.0),
              _speedButton(2.0),
              _speedButton(5.0),
              _speedButton(10.0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _speedButton(double speed) {
    final isSelected = widget.currentSpeed == speed;
    return TextButton(
      onPressed: () => widget.onSpeedChanged(speed),
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        backgroundColor: isSelected ? Colors.blue.withValues(alpha: 0.3) : null,
      ),
      child: Text(
        '${speed.toInt()}x',
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }
}
