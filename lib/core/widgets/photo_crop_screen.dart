import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/colors.dart';
import '../utils/image_optimizer.dart';

enum CropShape { circle, rectangle }

class PhotoCropScreen extends StatefulWidget {
  final File imageFile;
  final CropShape cropShape;
  final String title;

  const PhotoCropScreen({
    Key? key,
    required this.imageFile,
    this.cropShape = CropShape.rectangle,
    this.title = 'Adjust & Crop Photo',
  }) : super(key: key);

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _transformController = TransformationController();
  int _rotationQuarterTurns = 0;
  bool _isProcessing = false;

  void _rotateClockwise() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
    setState(() {
      _rotationQuarterTurns = 0;
    });
  }

  Future<void> _captureCroppedImage() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not locate render boundary');
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode image data');
      }

      final rawBytes = byteData.buffer.asUint8List();
      final targetDimension = widget.cropShape == CropShape.circle ? 512 : 1280;
      final compressedBytes = await AppImageOptimizer.optimizeBytes(
        rawBytes,
        maxDimension: targetDimension,
        quality: 82,
      );

      final tempDir = await getTemporaryDirectory();
      final fileName = 'cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final croppedFile = File('${tempDir.path}/$fileName');
      await croppedFile.writeAsBytes(compressedBytes);

      if (mounted) {
        Navigator.pop(context, croppedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to crop photo: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isCircle = widget.cropShape == CropShape.circle;
    final cropBoxWidth = screenSize.width * 0.85;
    final cropBoxHeight = isCircle ? cropBoxWidth : (cropBoxWidth * 0.65);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Rotate 90°',
            icon: const Icon(Icons.rotate_90_degrees_cw_rounded, color: Colors.white),
            onPressed: _rotateClockwise,
          ),
          IconButton(
            tooltip: 'Reset',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _resetZoom,
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Background instructions
          Positioned(
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pinch_rounded, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Pinch to zoom • Drag to adjust position',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          // Crop Viewport Frame
          Center(
            child: Container(
              width: cropBoxWidth,
              height: cropBoxHeight,
              decoration: BoxDecoration(
                shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isCircle ? null : BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryPill, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 0,
                    spreadRadius: 2000,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: isCircle ? BorderRadius.circular(cropBoxWidth / 2) : BorderRadius.circular(14),
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: Container(
                    color: Colors.black,
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.5,
                      maxScale: 4.5,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: _rotationQuarterTurns,
                          child: Image.file(
                            widget.imageFile,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPill,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isProcessing ? null : _captureCroppedImage,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.crop_rounded, size: 20),
                    label: Text(
                      _isProcessing ? 'CROPPING...' : 'DONE & USE PHOTO',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to pick an image from camera or gallery and open the PhotoCropScreen.
Future<File?> pickAndCropImage(
  BuildContext context, {
  required ImageSource source,
  CropShape cropShape = CropShape.rectangle,
  String title = 'Adjust & Crop Photo',
}) async {
  final picker = ImagePicker();
  final maxDim = cropShape == CropShape.circle ? 1024.0 : 1600.0;
  final picked = await picker.pickImage(
    source: source,
    maxWidth: maxDim,
    maxHeight: maxDim,
    imageQuality: 85,
  );
  if (picked == null) return null;
  if (!context.mounted) return null;

  return Navigator.push<File?>(
    context,
    MaterialPageRoute(
      builder: (context) => PhotoCropScreen(
        imageFile: File(picked.path),
        cropShape: cropShape,
        title: title,
      ),
    ),
  );
}
