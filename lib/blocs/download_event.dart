import 'package:equatable/equatable.dart';

abstract class DownloadEvent extends Equatable {
  const DownloadEvent();

  @override
  List<Object> get props => [];
}

class StartDownload extends DownloadEvent {
  final String url;
  final String savePath;
  final String name;

  const StartDownload(this.url, this.savePath, this.name);

  @override
  List<Object> get props => [url, savePath, name];
}

class CancelDownload extends DownloadEvent {}