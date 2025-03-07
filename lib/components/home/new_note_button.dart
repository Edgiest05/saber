import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class NewNoteButton extends StatefulWidget {
  const NewNoteButton({
    super.key,
    required this.cupertino,
    this.path,
  });

  final bool cupertino;
  final String? path;

  @override
  State<NewNoteButton> createState() => _NewNoteButtonState();
}

class _NewNoteButtonState extends State<NewNoteButton> {
  final ValueNotifier<bool> isDialOpen = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      spacing: 3,
      mini: true,
      openCloseDial: isDialOpen,
      childPadding: const EdgeInsets.all(5),
      spaceBetweenChildren: 4,
      switchLabelPosition: Directionality.of(context) == TextDirection.rtl,
      dialRoot: (ctx, open, toggleChildren) {
        return FloatingActionButton(
            shape: widget.cupertino ? const CircleBorder() : null,
            onPressed: toggleChildren,
            tooltip: t.home.tooltips.newNote,
            child: const Icon(Icons.add));
      },
      children: [
        SpeedDialChild(
          child: const Icon(Icons.create),
          label: t.home.create.newNote,
          onTap: () async {
            if (widget.path == null) {
              context.push(RoutePaths.edit);
            } else {
              final newFilePath =
                  await FileManager.newFilePath('${widget.path}/');
              if (!context.mounted) return;
              context.push(RoutePaths.editFilePath(newFilePath));
            }
          },
        ),
        SpeedDialChild(
          child: const Icon(Icons.note_add),
          label: t.home.create.importNote,
          onTap: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.any,
              allowMultiple: true,
              withData: false,
            );
            if (result == null) return;

            if (result.files.length > 1) {
              bool foundPdf = false;
              WakelockPlus.enable();
              for (var elem in result.files) {
                final filePath = elem.path;
                if (filePath == null) continue;

                if (filePath.endsWith('.sbn') ||
                    filePath.endsWith('.sbn2') ||
                    filePath.endsWith('.sba')) {
                  final path = await FileManager.importFile(
                    filePath,
                    '${widget.path ?? ''}/',
                  );
                  if (path == null) continue;
                  if (!context.mounted) continue;
                } else if (filePath.endsWith('.pdf') && !foundPdf) {
                  foundPdf = true;
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('PDFs can only be imported singularly'),
                    ));
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(t.home.invalidFormat),
                    ));
                  }
                  WakelockPlus.disable();
                  throw 'Invalid file type';
                }
              }
              WakelockPlus.disable();
            } else {
              final filePath = result.files.single.path;
              final fileName = result.files.single.name;
              if (filePath == null) return;

              if (filePath.endsWith('.sbn') ||
                  filePath.endsWith('.sbn2') ||
                  filePath.endsWith('.sba')) {
                final path = await FileManager.importFile(
                  filePath,
                  '${widget.path ?? ''}/',
                );
                if (path == null) return;
                if (!context.mounted) return;

                context.push(RoutePaths.editFilePath(path));
              } else if (filePath.endsWith('.pdf')) {
                if (!Editor.canRasterPdf) return;
                if (!mounted) return;

                final fileNameWithoutExtension =
                    fileName.substring(0, fileName.length - '.pdf'.length);
                final sbnFilePath =
                    await FileManager.suffixFilePathToMakeItUnique(
                  '${widget.path ?? ''}/$fileNameWithoutExtension',
                );
                if (!context.mounted) return;

                context.push(RoutePaths.editImportPdf(sbnFilePath, filePath));
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(t.home.invalidFormat),
                  ));
                }
                throw 'Invalid file type';
              }
            }
          },
        ),
      ],
    );
  }
}
