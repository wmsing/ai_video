import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class FfmpegEvent extends Equatable {
  const FfmpegEvent();
  @override
  List<Object?> get props => [];
}

class StartFfmpegDownload extends FfmpegEvent {
  final String url;
  final String savePath;
  final String fileName;
  const StartFfmpegDownload(this.url, this.savePath, this.fileName);
  @override
  List<Object?> get props => [url, savePath, fileName];
}

class CombineReactionVideo extends FfmpegEvent {
  final String videoAPath;
  final String webcamPath;
  final String outputPath;
  final bool useOverlay;
  const CombineReactionVideo(this.videoAPath, this.webcamPath, this.outputPath, {this.useOverlay = true});
  @override
  List<Object?> get props => [videoAPath, webcamPath, outputPath, useOverlay];
}

class CancelFfmpegDownload extends FfmpegEvent {}

// States
abstract class FfmpegState extends Equatable {
  const FfmpegState();
  @override
  List<Object?> get props => [];
}

class FfmpegInitial extends FfmpegState {}
class FfmpegLoading extends FfmpegState {
  final double progress;
  const FfmpegLoading(this.progress);
  @override
  List<Object?> get props => [progress];
}
class FfmpegSuccess extends FfmpegState {
  final String filePath;
  const FfmpegSuccess(this.filePath);
  @override
  List<Object?> get props => [filePath];
}
class FfmpegError extends FfmpegState {
  final String error;
  const FfmpegError(this.error);
  @override
  List<Object?> get props => [error];
}

class FfmpegBloc extends Bloc<FfmpegEvent, FfmpegState> {
  Process? _process;
  FfmpegBloc() : super(FfmpegInitial()) {
    on<StartFfmpegDownload>(_onStartDownload);
    on<CancelFfmpegDownload>(_onCancelDownload);
    on<CombineReactionVideo>(_onCombineReactionVideo);
  }

  Future<void> _onStartDownload(StartFfmpegDownload event, Emitter<FfmpegState> emit) async {
    print('[FfmpegBloc] Start download: url=${event.url}, savePath=${event.savePath}, fileName=${event.fileName}');
    emit(FfmpegLoading(0.01));
    final filePath = event.savePath + Platform.pathSeparator + event.fileName;
    final args = [
      '-y',
      '-i', event.url,
      '-c', 'copy',
      filePath,
    ];
    try {
      _process = await Process.start('ffmpeg', args);
      print('[FfmpegBloc] ffmpeg process started (pid: ${_process?.pid})');
    } catch (e) {
      print('[FfmpegBloc] ffmpeg failed to start: $e');
      emit(FfmpegError('ffmpeg not found or failed to start: $e'));
      return;
    }
    // Log ffmpeg output
    _process!.stdout.transform(SystemEncoding().decoder).listen((data) {
      print('[FfmpegBloc] ffmpeg stdout: $data');
    });
    _process!.stderr.transform(SystemEncoding().decoder).listen((data) {
      print('[FfmpegBloc] ffmpeg stderr: $data');
    });
    await _process!.exitCode;
    print('[FfmpegBloc] ffmpeg process finished');
    emit(FfmpegLoading(1.0));
    emit(FfmpegSuccess(filePath));
  }

  void _onCancelDownload(CancelFfmpegDownload event, Emitter<FfmpegState> emit) {
    print('[FfmpegBloc] Cancel download');
    _process?.kill();
    emit(FfmpegInitial());
  }

  Future<void> _onCombineReactionVideo(CombineReactionVideo event, Emitter<FfmpegState> emit) async {
    print('[FfmpegBloc] Combine reaction video: ${event.videoAPath}, ${event.webcamPath}, ${event.outputPath}');
    emit(FfmpegLoading(0.01));
    
    List<String> args;
    if (event.useOverlay) {
      args = [
        '-y',
        '-i', event.videoAPath,
        '-i', event.webcamPath,
        '-filter_complex', '[0:v][1:v]overlay=W-w-10:H-h-10[v];[0:a][1:a]amix=inputs=2[a]',
        '-map', '[v]',
        '-map', '[a]',
        '-c:v', 'libx264',
        '-preset', 'ultrafast',
        event.outputPath,
      ];
    } else {
      // Side by side (hstack) with equal height and mixed audio
      args = [
        '-y',
        '-i', event.videoAPath,
        '-i', event.webcamPath,
        '-filter_complex', '[0:v]scale=-1:720:force_original_aspect_ratio=increase,crop=720:720[v0];[1:v]scale=-1:720:force_original_aspect_ratio=increase,crop=720:720[v1];[v0][v1]hstack=inputs=2[v];[0:a][1:a]amix=inputs=2[a]',
        '-map', '[v]',
        '-map', '[a]',
        '-c:v', 'libx264',
        '-preset', 'ultrafast',
        event.outputPath,
      ];
    }
    
    try {
      _process = await Process.start('ffmpeg', args);
      print('[FfmpegBloc] ffmpeg process started for combine');
      _process!.stdout.transform(SystemEncoding().decoder).listen((data) {
        print('[FfmpegBloc] ffmpeg stdout: $data');
      });
      _process!.stderr.transform(SystemEncoding().decoder).listen((data) {
        print('[FfmpegBloc] ffmpeg stderr: $data');
      });
      await _process!.exitCode;
      print('[FfmpegBloc] ffmpeg combine finished');
      emit(FfmpegLoading(1.0));
      emit(FfmpegSuccess(event.outputPath));
    } catch (e) {
      print('[FfmpegBloc] ffmpeg combine failed: $e');
      emit(FfmpegError('ffmpeg failed: $e'));
    }
  }
}
