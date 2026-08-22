import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/patient_models.dart';

abstract final class PdfExportService {
  static Future<void> exportReportPdf({
    required PatientSearchResult patient,
    required PatientHistoryEntry entry,
    String? doctorName,
    String? facilityName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'EpiWatch Surveillance Network',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        facilityName ?? 'Sunrise Multispeciality Clinic',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'CLINICAL VISIT REPORT',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Date: ${entry.reportDate}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey400, thickness: 1),
              pw.SizedBox(height: 12),

              // Patient Info Card
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PATIENT INFORMATION',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Full Name: ${patient.fullName}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.Text('Age / Sex: ${patient.summary}',
                            style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('District: ${patient.district}',
                            style: const pw.TextStyle(fontSize: 11)),
                        if (patient.facilityMrn != null && patient.facilityMrn!.isNotEmpty)
                          pw.Text('MRN: ${patient.facilityMrn}',
                              style: const pw.TextStyle(fontSize: 11)),
                        if (patient.abhaId != null && patient.abhaId!.isNotEmpty)
                          pw.Text('ABHA ID: ${patient.abhaId}',
                              style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Clinical Findings & Diagnosis
              pw.Text(
                'CLINICAL FINDINGS & DIAGNOSIS',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal900,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headers: ['FIELD', 'DETAILS'],
                data: [
                  ['Diagnosis', entry.diagnosis ?? '—'],
                  ['Diagnosis Status', entry.diagnosisStatus ?? 'Suspected'],
                  ['Chief Complaints', entry.complaints ?? '—'],
                  ['Attending Doctor', doctorName ?? 'Dr. Asha Rao'],
                ],
              ),
              pw.SizedBox(height: 16),

              // Laboratory Results & AMR
              if (entry.hasLabResult) ...[
                pw.Text(
                  'LABORATORY RESULTS & AMR',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal900,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  headers: ['TEST', 'RESULT'],
                  data: [
                    if (entry.pathogen != null && entry.pathogen!.isNotEmpty)
                      ['Identified Pathogen', entry.pathogen!],
                    if (entry.cultureResult != null && entry.cultureResult!.isNotEmpty)
                      ['Culture Result', entry.cultureResult!],
                    if (entry.astResult != null && entry.astResult!.isNotEmpty)
                      ['AST Susceptibility', entry.astResult!],
                  ],
                ),
                pw.SizedBox(height: 16),
              ],

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Report ID: ${entry.reportId}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Text('Generated by EpiWatch Surveillance System',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    final cleanName = patient.fullName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Clinical_Report_${cleanName}_${entry.reportDate}.pdf',
    );
  }
}
