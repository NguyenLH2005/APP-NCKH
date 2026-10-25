import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class FullScreenImage extends StatelessWidget {
  final File? imageFile;
  final Uint8List? imageBytes;
  final String? heroTag;

  const FullScreenImage({
    super.key,
    this.imageFile,
    this.imageBytes,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (imageFile != null && imageFile!.existsSync()) {
      imageWidget = Image.file(
        imageFile!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (imageBytes != null && imageBytes!.isNotEmpty) {
      imageWidget = Image.memory(
        imageBytes!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      imageWidget = const Center(
        child: Text(
          'Không thể tải ảnh',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final tag = heroTag ?? imageFile?.path;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 1.0,
          maxScale: 5.0,
          child: tag != null && tag.isNotEmpty
              ? Hero(tag: tag, child: imageWidget)
              : imageWidget,
        ),
      ),
    );
  }
}
