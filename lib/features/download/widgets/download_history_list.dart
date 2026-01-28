import 'package:flutter/material.dart';

class DownloadHistoryList extends StatelessWidget {
  final List<String> history;
  const DownloadHistoryList({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: history.length,
      itemBuilder: (context, index) => ListTile(
        title: SelectableText(history[index]),
      ),
    );
  }
}