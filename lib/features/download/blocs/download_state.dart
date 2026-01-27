import 'package:equatable/equatable.dart';

abstract class DownloadState extends Equatable {
  const DownloadState();

  @override
  List<Object> get props => [];
}

class DownloadInitial extends DownloadState {}

class DownloadLoading extends DownloadState {
  final double progress;

  const DownloadLoading(this.progress);

  @override
  List<Object> get props => [progress];
}

class DownloadSuccess extends DownloadState {
  final String filePath;

  const DownloadSuccess(this.filePath);

  @override
  List<Object> get props => [filePath];
}

class DownloadError extends DownloadState {
  final String error;

  const DownloadError(this.error);

  @override
  List<Object> get props => [error];
}