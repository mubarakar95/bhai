import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart' show DateTimeRange, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class PdfService {
  static final PdfService instance = PdfService._internal();
  PdfService._internal();

  Future<Uint8List> generatePoliceReport({
    required String propertyName,
    required String propertyAddress,
    String? businessName,
    String? businessAddress,
    required List<Stay> stays,
    DateTimeRange? dateRange,
    bool isFreeTier = false,
    Uint8List? logoImageBytes,
  }) async {
    final pdf = pw.Document();

    final fontTitle = pw.Font.helveticaBold();
    final fontBody = pw.Font.helvetica();
    final fontBodyBold = pw.Font.helveticaBold();

    // Load Bhai App logo from asset or parameter
    Uint8List? loadedLogoBytes = logoImageBytes;
    if (loadedLogoBytes == null) {
      try {
        final byteData = await rootBundle.load('assets/logo.png');
        loadedLogoBytes = byteData.buffer.asUint8List();
      } catch (e) {
        // Fallback to direct file read if running in tests or if bundle lookup fails
        try {
          final logoFile = File('assets/logo.png');
          if (await logoFile.exists()) {
            loadedLogoBytes = await logoFile.readAsBytes();
          }
        } catch (_) {}
      }
    }
    final pw.MemoryImage? logoImage =
        loadedLogoBytes != null ? pw.MemoryImage(loadedLogoBytes) : null;

    // Fetch images in parallel before rendering the PDF pages to avoid blocking.
    final Map<String, Uint8List> guestPhotos = {};
    await Future.wait(
      stays.map((stay) async {
        final guest = stay.person;
        if (guest != null && guest.personPhoto.isNotEmpty) {
          try {
            if (guest.personPhoto.startsWith('http://') ||
                guest.personPhoto.startsWith('https://')) {
              final response = await http
                  .get(Uri.parse(guest.personPhoto))
                  .timeout(const Duration(seconds: 4));
              if (response.statusCode == 200) {
                guestPhotos[guest.id] = response.bodyBytes;
              }
            } else {
              final file = File(guest.personPhoto);
              if (await file.exists()) {
                guestPhotos[guest.id] = await file.readAsBytes();
              }
            }
          } catch (e) {
            debugPrint('Failed to load photo for ${guest.name}: $e');
          }
        }
      }),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          buildBackground: (pw.Context context) {
            if (!isFreeTier) return pw.SizedBox();
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Transform.rotate(
                  angle: -math.pi / 4,
                  child: pw.Text(
                    'Bhai App',
                    style: pw.TextStyle(
                      font: fontTitle,
                      fontSize: 88,
                      color: PdfColor.fromHex('#E2E8F0'),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        header: (pw.Context context) {
          // On pages after page 1, show a compact running header (height ~20pt)
          if (context.pageNumber > 1) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 5),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: PdfColor.fromHex('#D8D5CE'),
                    width: 0.8,
                  ),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null) ...[
                        pw.Image(logoImage, width: 14, height: 14),
                        pw.SizedBox(width: 5),
                      ],
                      pw.Text(
                        'BHAI APP - OFFICIAL GUEST REGISTRATION RECORD',
                        style: pw.TextStyle(
                          font: fontBodyBold,
                          fontSize: 7.5,
                          color: PdfColor.fromHex('#1F2A44'),
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    propertyName,
                    style: pw.TextStyle(
                      font: fontBody,
                      fontSize: 7.5,
                      color: PdfColor.fromHex('#64748B'),
                    ),
                  ),
                ],
              ),
            );
          }
          return pw.SizedBox();
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.only(top: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(
                  color: PdfColor.fromHex('#D8D5CE'),
                  width: 1,
                ),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated securely via Bhai App | Confidential Official Record',
                  style: pw.TextStyle(
                    font: fontBody,
                    fontSize: 8,
                    color: PdfColor.fromHex('#64748B'),
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(
                    font: fontBody,
                    fontSize: 8,
                    color: PdfColor.fromHex('#64748B'),
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Top Bhai App Branding Bar with Logo (No "Available on Play Store" heading)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null) ...[
                      pw.Container(
                        width: 26,
                        height: 26,
                        decoration: const pw.BoxDecoration(
                          borderRadius:
                              pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 6,
                          verticalRadius: 6,
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                    ],
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#1F2A44'),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'BHAI APP',
                        style: pw.TextStyle(
                          font: fontTitle,
                          fontSize: 11,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'Document ID: BA-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
                  style: pw.TextStyle(
                    font: fontBody,
                    fontSize: 8,
                    color: PdfColor.fromHex('#64748B'),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // Header: Title and Property Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'OFFICIAL GUEST REGISTRATION RECORD',
                        style: pw.TextStyle(
                          font: fontTitle,
                          fontSize: 16,
                          color: PdfColor.fromHex('#1F2A44'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Verified Resident & Tenant Registration Ledger',
                        style: pw.TextStyle(
                          font: fontBody,
                          fontSize: 9.5,
                          color: PdfColor.fromHex('#64748B'),
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      if (businessName != null && businessName.isNotEmpty) ...[
                        pw.Text(
                          businessName,
                          style: pw.TextStyle(
                            font: fontBodyBold,
                            fontSize: 12,
                            color: PdfColor.fromHex('#1F2A44'),
                          ),
                        ),
                        if (businessAddress != null && businessAddress.isNotEmpty)
                          pw.Text(
                            businessAddress,
                            style: pw.TextStyle(
                              font: fontBody,
                              fontSize: 8.5,
                              color: PdfColor.fromHex('#64748B'),
                            ),
                          ),
                        pw.SizedBox(height: 4),
                      ],
                      pw.Text(
                        propertyName,
                        style: pw.TextStyle(
                          font: fontBodyBold,
                          fontSize: 12,
                          color: PdfColor.fromHex('#2B2B2E'),
                        ),
                      ),
                      pw.Text(
                        propertyAddress,
                        style: pw.TextStyle(
                          font: fontBody,
                          fontSize: 8.5,
                          color: PdfColor.fromHex('#2B2B2E'),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Date: ${DateFormat('dd-MMM-yyyy').format(DateTime.now())}',
                      style: pw.TextStyle(font: fontBody, fontSize: 9.5),
                    ),
                    if (dateRange != null)
                      pw.Text(
                        'Period: ${DateFormat('dd/MM/yy').format(dateRange.start)} - ${DateFormat('dd/MM/yy').format(dateRange.end)}',
                        style: pw.TextStyle(font: fontBody, fontSize: 9),
                      ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#1F2A44')),
            pw.SizedBox(height: 8),

            // Statistics Summary
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#D8D5CE')),
                color: PdfColor.fromHex('#F3F5F4'),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Total Guests', stays.length.toString(),
                      fontBodyBold, fontBody),
                  _buildStatItem(
                    'Active Checked-in',
                    stays.where((s) => s.status == 'active').length.toString(),
                    fontBodyBold,
                    fontBody,
                  ),
                  _buildStatItem(
                    'Blacklisted Flagged',
                    stays
                        .where((s) => s.person?.isBlacklisted == true)
                        .length
                        .toString(),
                    fontBodyBold,
                    fontBody,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Guest Ledger Title
            pw.Text(
              'GUEST VERIFICATION RECORDS',
              style: pw.TextStyle(
                font: fontBodyBold,
                fontSize: 11,
                color: PdfColor.fromHex('#1F2A44'),
              ),
            ),
            pw.SizedBox(height: 8),

            // Stays List
            ...stays.map((stay) {
              final guest = stay.person;
              if (guest == null) return pw.SizedBox();

              final photoBytes = guestPhotos[guest.id];
              final image =
                  photoBytes != null ? pw.MemoryImage(photoBytes) : null;

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 9),
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                      color: PdfColor.fromHex('#D8D5CE'), width: 0.8),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Photo Column
                    pw.Container(
                      width: 66,
                      height: 75,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                            color: PdfColor.fromHex('#D8D5CE'), width: 0.8),
                        color: PdfColor.fromHex('#F3F5F4'),
                      ),
                      child: image != null
                          ? pw.Image(image, fit: pw.BoxFit.cover)
                          : pw.Center(
                              child: pw.Text(
                                'NO PHOTO',
                                style:
                                    pw.TextStyle(font: fontBody, fontSize: 7.5),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                    ),
                    pw.SizedBox(width: 9),

                    // Primary Guest Info Column
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            guest.name.toUpperCase(),
                            style: pw.TextStyle(
                              font: fontBodyBold,
                              fontSize: 10.5,
                              color: PdfColor.fromHex('#1F2A44'),
                            ),
                          ),
                          pw.SizedBox(height: 1.5),
                          pw.Text('Father: ${guest.fatherName}',
                              style: pw.TextStyle(
                                  font: fontBody, fontSize: 8.5)),
                          pw.Text(
                              'DOB: ${DateFormat('dd-MMM-yyyy').format(guest.dob)}',
                              style: pw.TextStyle(
                                  font: fontBody, fontSize: 8.5)),
                          pw.Text('Mobile: ${guest.mobileNo}',
                              style: pw.TextStyle(
                                  font: fontBody, fontSize: 8.5)),
                          pw.Text(
                            'Aadhaar: ${guest.aadhaarNo.replaceAllMapped(RegExp(r'.{4}'), (match) => '${match.group(0)} ')}',
                            style: pw.TextStyle(
                                font: fontBodyBold, fontSize: 8.5),
                          ),
                        ],
                      ),
                    ),

                    // Stay & Police Details Column
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Room No: ${stay.room?.roomNumber ?? 'N/A'}',
                              style: pw.TextStyle(
                                  font: fontBodyBold, fontSize: 9.5)),
                          pw.SizedBox(height: 1.5),
                          pw.Text(
                            'Check-in: ${DateFormat('dd-MMM-yyyy hh:mm a').format(stay.checkInDate)}',
                            style: pw.TextStyle(
                                font: fontBody, fontSize: 8.5),
                          ),
                          pw.Text(
                            stay.checkOutDate != null
                                ? 'Check-out: ${DateFormat('dd-MMM-yyyy hh:mm a').format(stay.checkOutDate!)}'
                                : 'Check-out: Active Guest',
                            style: pw.TextStyle(
                                font: fontBody, fontSize: 8.5),
                          ),
                          pw.Text(
                              'Police Circle: ${guest.policeStationCircle}',
                              style: pw.TextStyle(
                                  font: fontBody, fontSize: 8.5)),
                          pw.Text(
                            'Address: ${guest.address}, ${guest.city}, ${guest.state} - ${guest.pincode}',
                            style: pw.TextStyle(font: fontBody, fontSize: 8),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),

                    // Status Flag Column
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: stay.status == 'active'
                                ? PdfColor.fromHex('#2F6F5E')
                                : PdfColor.fromHex('#2B2B2E'),
                            borderRadius:
                                const pw.BorderRadius.all(pw.Radius.circular(2)),
                          ),
                          child: pw.Text(
                            stay.status == 'active'
                                ? 'CHECKED-IN'
                                : 'CHECKED-OUT',
                            style: pw.TextStyle(
                                font: fontBodyBold,
                                fontSize: 7.5,
                                color: PdfColors.white),
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        if (guest.isBlacklisted)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#8C2F2F'),
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(2)),
                            ),
                            child: pw.Text(
                              'BLACKLISTED',
                              style: pw.TextStyle(
                                  font: fontBodyBold,
                                  fontSize: 7.5,
                                  color: PdfColors.white),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildStatItem(
      String label, String value, pw.Font fontValue, pw.Font fontLabel) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
              font: fontValue, fontSize: 13, color: PdfColor.fromHex('#1F2A44')),
        ),
        pw.Text(
          label,
          style: pw.TextStyle(
              font: fontLabel, fontSize: 8, color: PdfColor.fromHex('#2B2B2E')),
        ),
      ],
    );
  }
}

