import 'package:flutter/material.dart';

class MainFolderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? mainFolderPath;
  final VoidCallback? onOpenMainFolder;
  final String title;

  const MainFolderAppBar({
    super.key,
    required this.title,
    required this.mainFolderPath,
    required this.onOpenMainFolder,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        if (mainFolderPath != null)
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: onOpenMainFolder,
            tooltip: '打開主資料夾',
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
