import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'blocs/download_bloc.dart';
import 'blocs/download_event.dart';
import 'blocs/download_state.dart';
import 'widgets/download_history_list.dart';
import '../../shared/widgets/main_folder_app_bar.dart';

class DownloadPage extends StatelessWidget {
  const DownloadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DownloadBloc(),
      child: const DownloadView(),
    );
  }
}

class DownloadView extends StatefulWidget {
  const DownloadView({super.key});

  @override
  State<DownloadView> createState() => _DownloadViewState();
}

class _DownloadViewState extends State<DownloadView> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  List<String> _downloadHistory = [];
  String? _mainFolderPath;

  @override
  void initState() {
    super.initState();
    _loadDownloadHistory();
    _loadMainFolderPath();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadDownloadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _downloadHistory = prefs.getStringList('download_history') ?? [];
    });
  }

  Future<void> _loadMainFolderPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mainFolderPath = prefs.getString('main_folder_path');
    });
  }

  Future<void> _openMainFolder() async {
    if (_mainFolderPath == null) return;
    
    final mainFolder = Directory(_mainFolderPath!);
    if (!await mainFolder.exists()) {
      await mainFolder.create(recursive: true);
    }
    
    if (Platform.isMacOS) {
      await Process.run('open', [_mainFolderPath!]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [_mainFolderPath!]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [_mainFolderPath!]);
    } else {
      // For web or others, try url_launcher
      await launchUrl(Uri.parse('file://${_mainFolderPath!}'));
    }
  }

  Future<void> _openFolder(String filePath) async {
    final folder = p.dirname(filePath);
    if (Platform.isMacOS) {
      await Process.run('open', [folder]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [folder]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [folder]);
    } else {
      // For web or others, try url_launcher
      await launchUrl(Uri.parse('file://$folder'));
    }
  }

  // Move download logic to BLoC
  void _startDownload() async {
    final url = _urlController.text.trim();
    final name = _nameController.text.trim();
    if (url.isEmpty || name.isEmpty) return;

    // Get save path - use main folder
    final savePath = _mainFolderPath ?? (await getDownloadsDirectory())?.path ?? '/tmp';
    context.read<DownloadBloc>().add(StartDownload(url, savePath, name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainFolderAppBar(
        title: 'Download',
        mainFolderPath: _mainFolderPath,
        onOpenMainFolder: _openMainFolder,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BlocBuilder<DownloadBloc, DownloadState>(
          builder: (context, state) {
            return Column(
              children: [
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(labelText: 'Youtube or M3U8 URL'),
                ),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '資料夾名稱'),
                ),
                ElevatedButton(
                  onPressed: state is DownloadLoading ? null : _startDownload,
                  child: const Text('下載'),
                ),
                if (state is DownloadLoading)
                  LinearProgressIndicator(value: state.progress),
                if (state is DownloadSuccess) ...[
                  Text('已下載: ${p.basename(state.filePath)}'),
                  ElevatedButton(
                    onPressed: () => _openFolder(state.filePath),
                    child: const Text('打開資料夾'),
                  ),
                ],
                if (state is DownloadError)
                  Text('Error: ${state.error}'),
                // History list
                  Expanded(
                    child: DownloadHistoryList(history: _downloadHistory),
                  ),

              ],
            );
          },
        ),
      ),
    );
  }
}
