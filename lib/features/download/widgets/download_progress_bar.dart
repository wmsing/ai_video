import 'package:flutter/material.dart';

class DownloadProgressBar extends StatelessWidget {
  final double progress;
  const DownloadProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(value: progress);
  }
}
