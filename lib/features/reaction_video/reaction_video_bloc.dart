import 'package:equatable/equatable.dart';
import 'package:bloc/bloc.dart';
import 'package:file_picker/file_picker.dart';

// Events
abstract class ReactionVideoEvent extends Equatable {
  const ReactionVideoEvent();
  @override
  List<Object?> get props => [];
}

class PickVideoA extends ReactionVideoEvent {}
class StartWebcamRecording extends ReactionVideoEvent {}
class StopWebcamRecording extends ReactionVideoEvent {}
class CombineReactionVideo extends ReactionVideoEvent {
  final String videoAPath;
  final String webcamPath;
  final String outputPath;
  final bool useOverlay; // true: 畫中畫, false: 分屏
  const CombineReactionVideo(this.videoAPath, this.webcamPath, this.outputPath, {this.useOverlay = true});
  @override
  List<Object?> get props => [videoAPath, webcamPath, outputPath, useOverlay];
}

// States
abstract class ReactionVideoState extends Equatable {
  const ReactionVideoState();
  @override
  List<Object?> get props => [];
}

class ReactionVideoInitial extends ReactionVideoState {}
class ReactionVideoPicking extends ReactionVideoState {}
class ReactionVideoPicked extends ReactionVideoState {
  final String videoAPath;
  const ReactionVideoPicked(this.videoAPath);
  @override
  List<Object?> get props => [videoAPath];
}
class ReactionVideoRecording extends ReactionVideoState {}
class ReactionVideoRecorded extends ReactionVideoState {
  final String webcamPath;
  const ReactionVideoRecorded(this.webcamPath);
  @override
  List<Object?> get props => [webcamPath];
}
class ReactionVideoCombining extends ReactionVideoState {}
class ReactionVideoCombined extends ReactionVideoState {
  final String outputPath;
  const ReactionVideoCombined(this.outputPath);
  @override
  List<Object?> get props => [outputPath];
}
class ReactionVideoError extends ReactionVideoState {
  final String error;
  const ReactionVideoError(this.error);
  @override
  List<Object?> get props => [error];
}

class ReactionVideoBloc extends Bloc<ReactionVideoEvent, ReactionVideoState> {
  ReactionVideoBloc() : super(ReactionVideoInitial()) {
    on<PickVideoA>(_onPickVideoA);
    on<StartWebcamRecording>(_onStartWebcamRecording);
    on<StopWebcamRecording>(_onStopWebcamRecording);
    on<CombineReactionVideo>(_onCombineReactionVideo);
  }

  Future<void> _onPickVideoA(PickVideoA event, Emitter<ReactionVideoState> emit) async {
    emit(ReactionVideoPicking());
    // 使用 file_picker 選擇主視頻
    try {
      final result = await FilePicker.pickFiles(type: FileType.video);
      if (result != null && result.files.isNotEmpty) {
        final pickedPath = result.files.single.path;
        if (pickedPath != null) {
          emit(ReactionVideoPicked(pickedPath));
        } else {
          emit(ReactionVideoInitial());
        }
      } else {
        emit(ReactionVideoInitial());
      }
    } catch (e) {
      emit(ReactionVideoError('選擇視頻失敗: $e'));
    }
  }

  Future<void> _onStartWebcamRecording(StartWebcamRecording event, Emitter<ReactionVideoState> emit) async {
    emit(ReactionVideoRecording());
    // TODO: 實現攝像頭錄製（可用 camera 插件或命令行）
    // 假設錄製完成，emit ReactionVideoRecorded
    // emit(ReactionVideoRecorded(webcamPath));
  }

  Future<void> _onStopWebcamRecording(StopWebcamRecording event, Emitter<ReactionVideoState> emit) async {
    // TODO: 停止錄製
    // emit(ReactionVideoRecorded(webcamPath));
  }

  Future<void> _onCombineReactionVideo(CombineReactionVideo event, Emitter<ReactionVideoState> emit) async {
    emit(ReactionVideoCombining());
    // TODO: 調用FFmpeg合成 reaction video
    // emit(ReactionVideoCombined(event.outputPath));
  }
}
