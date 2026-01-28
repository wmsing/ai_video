import 'package:camera_macos/camera_macos_arguments.dart';
import 'package:camera_macos/camera_macos_controller.dart';
import 'package:camera_macos/camera_macos_file.dart';
import 'package:camera_macos/camera_macos_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_macos_permissions/flutter_macos_permissions.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/blocs/ffmpeg_bloc.dart';

class VideoPreviewPage extends StatefulWidget {
  final String videoPath;

  const VideoPreviewPage({super.key, required this.videoPath});

  @override
  State<VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<VideoPreviewPage> {
  VideoPlayerController? _controller;
  bool _isRecording = false;
  String? _recordedVideoPath;
  String? _mainFolderPath;
  CameraMacOSController? macOSController;

  @override
  void initState() {
    super.initState();
    _loadMainFolder();
    _initializeVideo();
    _initializeCamera();
  }

  Future<void> _loadMainFolder() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mainFolderPath = prefs.getString('main_folder_path');
    });
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {});
      });
  }

  Future<void> _initializeCamera() async {
    // Request camera and microphone permission
    final cameraGranted = await FlutterMacosPermissions.requestCamera();
    final microphoneGranted = await FlutterMacosPermissions.requestMicrophone();
    print("_initializeCamera cameraGranted: $cameraGranted, microphoneGranted: $microphoneGranted");
    if (!cameraGranted || !microphoneGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Camera or Microphone permission denied')));
    }
    // CameraMacOSView will initialize the camera
  }

  Future<void> _toggleReaction() async {
    print("_toggleReaction: _isRecording: $_isRecording");
    if (!_isRecording) {
      // Start reaction
      await _startReaction();
    } else {
      // End reaction
      await _endReaction();
    }
  }

  Future<void> _startReaction() async {
    if (_controller != null) {
      // Start playing video A
      // Ensure videos subdirectory exists in cache
      final cacheFolder = await _getCacheFolderPath();
      final videosDir = Directory(p.join(cacheFolder, 'videos'));
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }
      _recordedVideoPath = p.join(
        videosDir.path,
        'reaction_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      try {
        await macOSController?.recordVideo(url: _recordedVideoPath!);
        print("Recording started successfully");
        await _controller!.play();
        setState(() => _isRecording = true);
      } catch (e) {
        print("Error starting recording: $e");
      }
    }
  }

  Future<void> _endReaction() async {
    if (_controller != null &&
        macOSController != null &&
        _recordedVideoPath != null) {
      // Stop playing video A
      await _controller!.pause();
      _controller!.seekTo(Duration.zero);
      try {
        print("_recordedVideoPath: $_recordedVideoPath");
        final CameraMacOSFile? file = await macOSController?.stopRecording();
        print("CameraMacOSFile file: ${file.toString()}");
        print("CameraMacOSFile url: ${file?.url}");
        // File is already saved to _recordedVideoPath
        setState(() => _isRecording = false);
        // Merge videos using FFmpeg
        await _mergeVideos();
      } catch (e) {
        print("Error stopping recording: $e");
      }
    }
  }

  Future<void> _mergeVideos() async {
    if (_mainFolderPath != null && _recordedVideoPath != null) {
      final outputPath = p.join(
        _mainFolderPath!,
        'reaction_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      final ffmpegBloc = context.read<FfmpegBloc>();
      ffmpegBloc.add(
        CombineReactionVideo(
          _recordedVideoPath!, // Use reaction video as first input for side-by-side
          widget.videoPath,    // Original video as second input
          outputPath,
          useOverlay: false,
        ),
      ); // hstack

      // Listen for completion
      final subscription = ffmpegBloc.stream.listen((state) async {
        if (state is FfmpegSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Reaction video saved: ${p.basename(state.filePath)}',
              ),
              action: SnackBarAction(
                label: 'Open Folder',
                onPressed: () async {
                  final folder = Directory(p.dirname(state.filePath));
                  if (await folder.exists()) {
                    await launchUrl(Uri.directory(folder.path));
                  }
                },
              ),
            ),
          );
        } else if (state is FfmpegError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${state.error}')));
        }
      });

      // Cancel after some time or handle properly
      Future.delayed(const Duration(seconds: 30), () => subscription.cancel());
    }
  }

  Future<String> _getCacheFolderPath() async {
    final directory = await getTemporaryDirectory();
    return directory.path;
  }

  @override
  void dispose() {
    _controller?.dispose();
    macOSController?.destroy();
    super.dispose();
  }

  final GlobalKey cameraKey = GlobalKey(debugLabel: "cameraKey");

  Widget _body() {
    return Column(
      children: [
        Expanded(
          child: _controller != null && _controller!.value.isInitialized
              ? GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_controller!.value.isPlaying) {
                        _controller!.pause();
                      } else {
                        _controller!.play();
                      }
                    });
                  },
                  child: Stack(
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                      if (!_controller!.value.isPlaying && !_isRecording)
                        const Center(
                          child: Icon(
                            Icons.play_circle,
                            size: 64,
                            color: Colors.white70,
                          ),
                        ),

                        Positioned(
                          top: 10,
                          right: 10,
                          child: SizedBox(
                            width: 100,
                            height: 75,
                            child: CameraMacOSView(
                              key: cameraKey,
                              fit: BoxFit.fill,
                              cameraMode: CameraMacOSMode.video,
                              onCameraInizialized:
                                  (CameraMacOSController controller) {
                                    print("onCameraInizialized===");
                                    setState(() {
                                      macOSController = controller;
                                    });
                                  },
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
        ),
        if (macOSController == null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 12),
                Text('Initializing camera...'),
              ],
            ),
          ),
        if (macOSController != null && !_isRecording)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Camera ready. You can start recording.'),
          ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: (_controller != null) ? _toggleReaction : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRecording ? Colors.red : Colors.green,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(_isRecording ? 'End Reaction' : 'Start Reaction'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, _) async {
        if (_isRecording) {
          await _endReaction();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Video Preview: ${widget.videoPath.split('/').last}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _body(),
      ),
    );
  }
}
