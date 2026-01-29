import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'download_event.dart';
import 'download_state.dart';
import '../../../shared/blocs/ffmpeg_bloc.dart';

class DownloadBloc extends Bloc<DownloadEvent, DownloadState> {
  DownloadBloc() : super(DownloadInitial()) {
    on<StartDownload>(_onStartDownload);
    on<CancelDownload>(_onCancelDownload);
  }

  Future<void> _onStartDownload(StartDownload event, Emitter<DownloadState> emit) async {
    try {
      emit(DownloadLoading(0.0));
      final url = event.url;
      final savePath = event.savePath;
      final name = event.name;

      // Create subfolder
      final folderPath = p.join(savePath, name);
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      // Save to history
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('download_history') ?? [];
      history.add(url);
      await prefs.setStringList('download_history', history);

      String? filePath;
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        filePath = await _downloadYouTube(url, folderPath, emit);
      } else if (url.endsWith('.m3u8')) {
        filePath = await _downloadM3U8(url, folderPath, emit);
      } else {
        throw Exception('Unsupported URL type');
      }

      emit(DownloadSuccess(filePath));
    } catch (e) {
      emit(DownloadError(e.toString()));
    }
  }

  Future<String> _downloadYouTube(String url, String savePath, Emitter<DownloadState> emit) async {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(url);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final streamInfo = manifest.muxed.withHighestBitrate();
      final stream = yt.videos.streamsClient.get(streamInfo);

      final fileName = '${video.title}.mp4'.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final filePath = p.join(savePath, fileName);
      final file = File(filePath);
      final fileStream = file.openWrite();

      final totalBytes = streamInfo.size.totalBytes;
      var downloadedBytes = 0;

      await for (final data in stream) {
        fileStream.add(data);
        downloadedBytes += data.length;
        final progress = downloadedBytes / totalBytes;
        emit(DownloadLoading(progress));
      }

      await fileStream.close();
      return filePath;
    } finally {
      yt.close();
    }
  }

  Future<String> _downloadM3U8(String url, String savePath, Emitter<DownloadState> emit) async {
    // Use shared FfmpegBloc for m3u8 download
    final fileName = 'playlist_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final ffmpegBloc = FfmpegBloc();
    ffmpegBloc.add(StartFfmpegDownload(url, savePath, fileName));
    // Listen for completion
    final completer = Completer<String>();
    final subscription = ffmpegBloc.stream.listen((state) {
      if (state is FfmpegLoading) {
        emit(DownloadLoading(state.progress));
      } else if (state is FfmpegSuccess) {
        completer.complete(state.filePath);
      } else if (state is FfmpegError) {
        completer.completeError(state.error);
      }
    });
    final filePath = await completer.future;
    await subscription.cancel();
    return filePath;
  }

  // List<String> _parseM3U8(String content, String baseUrl) {
  //   final lines = LineSplitter.split(content).toList();
  //   final segments = <String>[];

  //   for (final line in lines) {
  //     if (line.startsWith('#')) continue;
  //     if (line.isNotEmpty) {
  //       final segmentUrl = line.startsWith('http') ? line : p.join(p.dirname(baseUrl), line);
  //       segments.add(segmentUrl);
  //     }
  //   }

  //   return segments;
  // }

  void _onCancelDownload(CancelDownload event, Emitter<DownloadState> emit) {
    // Cancel logic - for now, just reset
    emit(DownloadInitial());
  }
}