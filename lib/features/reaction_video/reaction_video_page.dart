import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'reaction_video_bloc.dart';
import 'video_preview_page.dart';

class ReactionVideoPage extends StatelessWidget {
  const ReactionVideoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReactionVideoBloc(),
      child: const ReactionVideoView(),
    );
  }
}

class ReactionVideoView extends StatefulWidget {
  const ReactionVideoView({super.key});

  @override
  State<ReactionVideoView> createState() => _ReactionVideoViewState();
}

class _ReactionVideoViewState extends State<ReactionVideoView> {
  String? webcamPath;
  String? outputPath;
  bool isRecording = false;
  bool isProcessing = false;
  String log = '';

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reaction Video 製作')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BlocConsumer<ReactionVideoBloc, ReactionVideoState>(
          listener: (context, state) {
            if (state is ReactionVideoPicked) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VideoPreviewPage(videoPath: state.videoAPath),
                ),
              );
            }
          },
          builder: (context, state) {
            String? videoAPath;
            if (state is ReactionVideoPicked) {
              videoAPath = state.videoAPath;
            }
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('步驟：'),
                  const SizedBox(height: 8),
                  Text('1. 選擇主視頻A'),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ReactionVideoBloc>().add(PickVideoA());
                    },
                    child: Text(videoAPath == null ? '選擇視頻A (將在新頁面全螢幕預覽)' : '已選擇: ${videoAPath.split('/').last}'),
                ),
                const SizedBox(height: 16),
                Text('2. 開啟攝像頭錄製你的反應'),
                ElevatedButton(
                  onPressed: isRecording ? null : () {
                    context.read<ReactionVideoBloc>().add(StartWebcamRecording());
                  },
                  child: Text(isRecording ? '錄製中...' : (webcamPath == null ? '開始錄製' : '已錄製: $webcamPath')),
                ),
                const SizedBox(height: 16),
                Text('3. 合成 Reaction Video'),
                ElevatedButton(
                  onPressed: (videoAPath != null && webcamPath != null && !isProcessing)
                      ? () {
                          // TODO: 調用FFmpeg合成
                        }
                      : null,
                  child: Text(isProcessing ? '處理中...' : '合成 Reaction Video'),
                ),
                const SizedBox(height: 16),
                if (outputPath != null) Text('已生成: $outputPath'),
                const SizedBox(height: 16),
                Text('日誌：'),
                Container(
                  width: double.infinity,
                  height: 120,
                  color: Colors.grey.shade200,
                  child: SingleChildScrollView(child: Text(log)),
                ),
                const SizedBox(height: 16),
                Text('說明：'),
                const Text('此頁面可製作 reaction video：一邊播放主視頻A，一邊錄製你的反應，最後合成畫中畫或分屏效果。'),
                const SizedBox(height: 8),
                Text('FFmpeg命令範例：'),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText('ffmpeg -i videoA.mp4 -i webcam.mp4 -filter_complex "[0][1] overlay=W-w-10:H-h-10" reaction.mp4'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: 'ffmpeg -i videoA.mp4 -i webcam.mp4 -filter_complex "[0][1] overlay=W-w-10:H-h-10" reaction.mp4'));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製到剪貼簿')));
                      },
                      tooltip: '複製命令',
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText('ffmpeg -i videoA.mp4 -i webcam.mp4 -filter_complex hstack reaction.mp4'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: 'ffmpeg -i videoA.mp4 -i webcam.mp4 -filter_complex hstack reaction.mp4'));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製到剪貼簿')));
                      },
                      tooltip: '複製命令',
                    ),
                  ],
                ),
              ],  
              ),
            );
          },
        ),
      ),
    );
  }
}
