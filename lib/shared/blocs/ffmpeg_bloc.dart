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
}
