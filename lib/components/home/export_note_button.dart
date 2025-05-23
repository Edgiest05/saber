import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:saber/components/nextcloud/spinning_loading_icon.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/editor_exporter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/i18n/strings.g.dart';

class ExportNoteButton extends StatefulWidget {
  const ExportNoteButton({
    super.key,
    required this.selectedFiles,
  });

  final List<String> selectedFiles;

  @override
  State<ExportNoteButton> createState() => _ExportNoteButtonState();
}

class _ExportNoteButtonState extends State<ExportNoteButton> {
  final ValueNotifier<bool> isDialOpen = ValueNotifier(false);
  bool _currentlyExporting = false;

  Future exportFile(List<String> selectedFiles, bool exportPdf) async {
    setState(() => _currentlyExporting = true);
    WakelockPlus.enable();

    final files = <ArchiveFile>[];
    for (String filePath in selectedFiles) {
      EditorCoreInfo coreInfo = await EditorCoreInfo.loadFromFilePath(filePath);
      if (!mounted) break;

      final fileNameWithoutExtension =
          coreInfo.filePath.substring(coreInfo.filePath.lastIndexOf('/') + 1);

      if (exportPdf) {
        final pdfDoc = await EditorExporter.generatePdf(coreInfo, context);
        final pdfBytes = await pdfDoc.save();
        files.add(ArchiveFile(
          '$fileNameWithoutExtension.pdf',
          pdfBytes.length,
          pdfBytes,
        ));
      } else {
        final sba = await coreInfo.saveToSba(currentPageIndex: null);
        files.add(ArchiveFile(
          '$fileNameWithoutExtension.sba',
          sba.length,
          sba,
        ));
      }
    }

    if (!mounted) return;
    if (selectedFiles.length == 1) {
      await FileManager.exportFile(
        files.single.name,
        files.single.content,
        context: context,
      );
    } else if (selectedFiles.length > 1) {
      final archive = Archive();
      for (final archiveFile in files) {
        archive.addFile(archiveFile);
      }
      await FileManager.exportFile(
        '${files.first.name}.zip',
        Uint8List.fromList(ZipEncoder().encode(archive)),
        context: context,
      );
    }

    WakelockPlus.disable();
    setState(() => _currentlyExporting = false);
  }

  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      spacing: 3,
      mini: true,
      openCloseDial: isDialOpen,
      childPadding: const EdgeInsets.all(5),
      spaceBetweenChildren: 4,
      switchLabelPosition: Directionality.of(context) == TextDirection.rtl,
      dialRoot: (context, open, toggleChildren) {
        return _currentlyExporting
            ? const SpinningLoadingIcon()
            : IconButton(
                padding: EdgeInsets.zero,
                tooltip: t.home.tooltips.exportNote,
                onPressed: toggleChildren,
                icon: const Icon(Icons.share),
              );
      },
      children: [
        SpeedDialChild(
          child: const Icon(CupertinoIcons.doc_text),
          label: 'PDF',
          onTap: () => exportFile(widget.selectedFiles, true),
        ),
        SpeedDialChild(
          child: const Icon(Icons.note),
          label: 'SBA',
          onTap: () => exportFile(widget.selectedFiles, false),
        ),
      ],
    );
  }
}
