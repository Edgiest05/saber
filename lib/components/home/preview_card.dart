import 'dart:async';
import 'dart:io';

import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/components/canvas/canvas_preview.dart';
import 'package:saber/components/canvas/invert_widget.dart';
import 'package:saber/components/home/sync_indicator.dart';
import 'package:saber/components/navbar/responsive_navbar.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/pages/editor/editor.dart';

class PreviewCard extends StatefulWidget {
  PreviewCard({
    required this.filePath,
    required this.toggleSelection,
    required this.selected,
    required this.isAnythingSelected,
  }) : super(key: ValueKey('PreviewCard$filePath'));

  final String filePath;
  final bool selected;
  final bool isAnythingSelected;
  final void Function(String, bool) toggleSelection;

  @override
  State<PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends State<PreviewCard> {
  final expanded = ValueNotifier(false);
  final thumbnail = _ThumbnailState();

  @override
  void initState() {
    fileWriteSubscription =
        FileManager.fileWriteStream.stream.listen(fileWriteListener);

    expanded.value = widget.selected;
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final imageFile =
        FileManager.getFile('${widget.filePath}${Editor.extension}.p');
    if (kDebugMode && Platform.environment.containsKey('FLUTTER_TEST')) {
      // Avoid FileImages in tests
      thumbnail.image = MemoryImage(imageFile.readAsBytesSync());
    } else {
      thumbnail.image = FileImage(imageFile);
    }
  }

  StreamSubscription? fileWriteSubscription;
  void fileWriteListener(FileOperation event) {
    if (event.filePath != widget.filePath) return;
    if (event.type == FileOperationType.delete) {
      thumbnail.image = null;
    } else if (event.type == FileOperationType.write) {
      thumbnail.image?.evict();
      thumbnail.markAsChanged();
    } else {
      throw Exception('Unknown file operation type: ${event.type}');
    }
  }

  void _toggleCardSelection() {
    expanded.value = !expanded.value;
    widget.toggleSelection(widget.filePath, expanded.value);
  }

  @override
  Widget build(BuildContext context) {
    expanded.value = widget.selected;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final transitionDuration =
        Duration(milliseconds: disableAnimations ? 0 : 300);
    final invert =
        theme.brightness == Brightness.dark && Prefs.editorAutoInvert.value;

    Widget card = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isAnythingSelected ? _toggleCardSelection : null,
        onSecondaryTap: _toggleCardSelection,
        onLongPress: _toggleCardSelection,
        child: ColoredBox(
          color: colorScheme.primary.withValues(alpha: 0.05),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      AnimatedBuilder(
                        animation: thumbnail,
                        builder: (context, _) => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: thumbnail.doesImageExist
                              ? InvertWidget(
                                  invert: invert,
                                  child: Image(
                                    key: ValueKey(thumbnail.updateCount),
                                    image: thumbnail.image!,
                                  ),
                                )
                              : FittedBox(
                                  alignment: Alignment.topCenter,
                                  child: ClipRect(
                                    child: CanvasPreview.fromFile(
                                      key: ValueKey(
                                          'CanvasPreview${thumbnail.updateCount}'),
                                      filePath: widget.filePath,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Positioned.fill(
                        left: -1,
                        top: -1,
                        right: -1,
                        bottom: -1,
                        child: ValueListenableBuilder(
                          valueListenable: expanded,
                          builder: (context, expanded, child) =>
                              AnimatedOpacity(
                            opacity: expanded ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: IgnorePointer(
                              ignoring: !expanded,
                              child: child!,
                            ),
                          ),
                          child: GestureDetector(
                            onTap: _toggleCardSelection,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    colorScheme.surface.withValues(alpha: 0.2),
                                    colorScheme.surface.withValues(alpha: 0.8),
                                    colorScheme.surface.withValues(alpha: 1),
                                  ],
                                ),
                              ),
                              child: ColoredBox(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(widget.filePath
                          .substring(widget.filePath.lastIndexOf('/') + 1)),
                    ),
                  ),
                ],
              ),
              SyncIndicator(
                filePath: widget.filePath,
              ),
            ],
          ),
        ),
      ),
    );

    return ValueListenableBuilder(
      valueListenable: expanded,
      builder: (context, expanded, _) {
        return OpenContainer(
          closedColor: colorScheme.surface,
          closedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          closedElevation: expanded ? 4 : 1,
          closedBuilder: (context, action) => card,
          openColor: colorScheme.surface,
          openBuilder: (context, action) => Editor(path: widget.filePath),
          transitionDuration: transitionDuration,
          routeSettings: RouteSettings(
            name: RoutePaths.editFilePath(widget.filePath),
          ),
          onClosed: (_) async {
            thumbnail.image?.evict();
            thumbnail.markAsChanged();

            await Future.delayed(transitionDuration);
            if (!context.mounted) return;
            if (!GoRouterState.of(context)
                .uri
                .toString()
                .startsWith(RoutePaths.prefixOfHome)) return;
            ResponsiveNavbar.setAndroidNavBarColor(theme);
          },
        );
      },
    );
  }

  @override
  void dispose() {
    fileWriteSubscription?.cancel();
    super.dispose();
  }
}

class _ThumbnailState extends ChangeNotifier {
  int updateCount = 0;
  ImageProvider? _image;

  void markAsChanged() {
    ++updateCount;
    notifyListeners();
  }

  ImageProvider? get image => _image;
  set image(ImageProvider? image) {
    _image = image;
    markAsChanged();
  }

  bool get doesImageExist => switch (image) {
        (FileImage fileImage) => fileImage.file.existsSync(),
        null => false,
        _ => true,
      };
}
