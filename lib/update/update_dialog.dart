import 'package:flutter/material.dart';

import 'update_service.dart';

Future<void> showUpdateDialog({
  required BuildContext context,
  required UpdateService service,
  required UpdateInfo update,
}) async {
  var downloading = false;
  var progress = 0.0;
  String? error;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return PopScope(
            canPop: !downloading,
            child: AlertDialog(
              title: const Text('发现新版本'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('当前版本 ${update.currentVersion}'),
                      const SizedBox(height: 4),
                      Text(
                        '最新版本 ${update.latestVersion}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '更新说明',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      SelectableText(update.releaseNotes),
                      if (downloading) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(value: progress),
                        const SizedBox(height: 6),
                        Text('${(progress * 100).round()}%'),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: downloading
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('稍后'),
                ),
                FilledButton(
                  onPressed: downloading
                      ? null
                      : () async {
                          setDialogState(() {
                            downloading = true;
                            progress = 0;
                            error = null;
                          });
                          try {
                            await service.downloadAndInstall(
                              update,
                              onProgress: (value) {
                                if (!dialogContext.mounted) return;
                                setDialogState(() => progress = value);
                              },
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (exception) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              downloading = false;
                              error = _friendlyError(exception);
                            });
                          }
                        },
                  child: Text(downloading ? '下载中…' : '下载并安装'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

String _friendlyError(Object error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}
