import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/colors.dart';

class PdfReportViewerScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;
  final String fileName;

  const PdfReportViewerScreen({
    Key? key,
    required this.pdfBytes,
    this.title = 'Guest Registration Report',
    this.fileName = 'official_guest_registration_report.pdf',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textMain,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: PdfPreview(
          build: (format) => pdfBytes,
          useActions: true,
          allowPrinting: true,
          allowSharing: true,
          canChangePageFormat: false,
          canChangeOrientation: false,
          pdfFileName: fileName,
          previewPageMargin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          loadingWidget: const Center(
            child: CircularProgressIndicator(color: AppColors.primaryPill),
          ),
        ),
      ),
    );
  }
}
