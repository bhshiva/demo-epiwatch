import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:convert';
import '../models/ingestion_models.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';

class OcrIngestionCard extends StatefulWidget {
  final String documentType; // 'clinical_report' or 'lab_isolate'
  final ApiClient apiClient;
  final Function(OcrParseResult result) onParsed;

  const OcrIngestionCard({
    super.key,
    required this.documentType,
    required this.apiClient,
    required this.onParsed,
  });

  @override
  State<OcrIngestionCard> createState() => _OcrIngestionCardState();
}

class _OcrIngestionCardState extends State<OcrIngestionCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  bool _isProcessing = false;
  int _selectedTab = 0; // 0 = Samples, 1 = Google Lens / Vision Scan, 2 = Manual Transcription
  final TextEditingController _textController = TextEditingController();

  static const Map<String, dynamic> _fallbackSamples = {
    'doctor_pneumonia_prescription': {
      'title': 'Outpatient Rx: Community-Acquired Pneumonia',
      'document_type': 'clinical_report',
      'text': 'Patient: Rajesh Kumar, Age: 42, Sex: Male, District: Pune\nComplaints: High fever, productive cough with yellow sputum for 4 days\nDiagnosis: Community-Acquired Pneumonia\nPrescriptions: Amoxicillin-Clavulanate 625mg TID x 5 days, Paracetamol 650mg SOS',
    },
    'doctor_symptom_anomaly': {
      'title': 'Clinical Anomaly: Meningitis with only Gastro symptoms',
      'document_type': 'clinical_report',
      'text': 'Patient: Anita Sharma, Age: 31, Sex: Female, District: Pune\nComplaints: Diarrhea and abdominal pain\nDiagnosis: Bacterial Meningitis\nSyndrome: Central Nervous System infection',
    },
  };

  Map<String, dynamic> _sampleDocs = _fallbackSamples;
  OcrParseResult? _lastParsedResult;

  @override
  void initState() {
    super.initState();
    _loadSampleDocuments();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadSampleDocuments() async {
    try {
      final samples = await widget.apiClient.getSampleDocuments();
      if (mounted) {
        setState(() {
          _sampleDocs = samples;
        });
      }
    } catch (_) {
      // Retain fallback samples
    }
  }

  Future<void> _processOcr([String? customText, String? imageBase64]) async {
    final textToProcess = customText ?? _textController.text;
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await widget.apiClient.parseOcrDocument(
        widget.documentType,
        rawText: textToProcess,
        imageBase64: imageBase64,
      );

      if (mounted) {
        setState(() {
          _lastParsedResult = result;
        });
        widget.onParsed(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Google OCR & Intelligence Audit: Extracted successfully (Plausibility: ${result.intelligenceAudit.plausibilityScore}%)',
            ),
            backgroundColor: result.intelligenceAudit.isValid
                ? AppColors.accentTeal
                : AppColors.statusElevated,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR extraction error: $e'),
            backgroundColor: AppColors.statusCritical,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _pickAndProcessImage() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'Medical Documents & Scans',
        extensions: <String>['jpg', 'jpeg', 'png', 'pdf'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

      if (file == null) return;

      setState(() {
        _isProcessing = true;
      });

      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      await _processOcr(null, base64String);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read file: $e'),
            backgroundColor: AppColors.statusCritical,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = widget.documentType == 'clinical_report';
    final cardTitle = isDoctor
        ? 'Seamless Clinical Ingestion & Google OCR'
        : 'Microbiology Laboratory AST Ingestion & Google OCR';

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentTeal.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      color: AppColors.accentTeal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              cardTitle,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accentTeal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.accentTeal.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, size: 12, color: AppColors.accentTeal),
                                  SizedBox(width: 4),
                                  Text(
                                    'Google OCR & AI Audit',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentTeal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isDoctor
                              ? 'Scan prescriptions, notes, or patient slips with automatic entity normalization and false-data detection.'
                              : 'Scan microbiology culture sheets and AST disk diffusion / MIC tables with intrinsic resistance validation.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(height: 1, color: AppColors.border),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabButton(0, 'Quick Templates', Icons.collections_bookmark_outlined),
                    const SizedBox(width: 8),
                    _buildTabButton(1, 'Google Lens / Scan', Icons.camera_alt_outlined),
                    const SizedBox(width: 8),
                    _buildTabButton(2, 'Paste / Type Notes', Icons.edit_note_outlined),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedTab == 0) _buildTemplatesTab(isDoctor),
                  if (_selectedTab == 1) _buildGoogleLensScanTab(isDoctor),
                  if (_selectedTab == 2) _buildManualTextTab(isDoctor),

                  if (_lastParsedResult != null) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 14),
                    _buildStructuredExtractionCards(_lastParsedResult!, isDoctor),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentTeal : AppColors.bgTertiary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accentTeal : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesTab(bool isDoctor) {
    if (_sampleDocs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final filteredSamples = _sampleDocs.entries
        .where((e) => (e.value as Map<String, dynamic>)['document_type'] == widget.documentType)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECT A CLINICAL SCENARIO TO TEST GOOGLE OCR & INTELLIGENCE AUDIT:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        for (final entry in filteredSamples) ...[
          _buildSampleDocumentCard(entry.key, entry.value as Map<String, dynamic>),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildSampleDocumentCard(String key, Map<String, dynamic> doc) {
    final title = doc['title'] as String? ?? key;
    final text = doc['text'] as String? ?? '';
    final isAnomaly = title.contains('Anomaly') || title.contains('Violation') || title.contains('MDR');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAnomaly ? AppColors.statusMonitoring.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isAnomaly ? Icons.warning_amber_rounded : Icons.description_outlined,
            color: isAnomaly ? AppColors.statusMonitoring : AppColors.accentTeal,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isAnomaly)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.statusMonitoring.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Contains Test Anomaly',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.statusMonitoring,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  text.split('\n').take(2).join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.bolt, size: 14),
            label: const Text('Extract & Fill', style: TextStyle(fontSize: 11.5)),
            onPressed: _isProcessing
                ? null
                : () {
                    _textController.text = text;
                    _processOcr(text);
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleLensScanTab(bool isDoctor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.camera_enhance_rounded,
            size: 40,
            color: AppColors.accentTeal,
          ),
          const SizedBox(height: 10),
          const Text(
            'Google Cloud Vision & Multimodal OCR',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Upload a prescription photo or scanned laboratory slip. Google OCR performs layout analysis, optical character recognition, and entity mapping.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Select Medical Image / PDF'),
                onPressed: _isProcessing ? null : _pickAndProcessImage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualTextTab(bool isDoctor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PASTE OR TYPE CLINICAL DICTATION / REPORT TRANSCRIPTION:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _textController,
          maxLines: 4,
          style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: isDoctor
                ? 'Patient Name: Priya Sen, Age: 28, Sex: Female, District: Pune\nComplaints: Burning urination with fever\nDiagnosis: Urinary tract infection'
                : 'Sample ID: ACC-2026-901, Specimen: Urine\nPathogen: Klebsiella pneumoniae\nAST:\n- Ampicillin : Susceptible\n- Ceftriaxone : Resistant',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.bolt, size: 16),
            label: const Text('Run Normalization & Ingest'),
            onPressed: _isProcessing ? null : () => _processOcr(),
          ),
        ),
      ],
    );
  }

  Widget _buildStructuredExtractionCards(OcrParseResult result, bool isDoctor) {
    final ext = result.extracted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.accentTeal, size: 18),
            const SizedBox(width: 6),
            const Text(
              'STRUCTURED CLINICAL ENTITIES (EXTRACTED & NORMALIZED)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              'Score: ${result.intelligenceAudit.plausibilityScore}%',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: result.intelligenceAudit.isValid ? AppColors.accentTeal : AppColors.statusElevated,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (isDoctor) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgTertiary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _buildPill('Patient', ext['full_name']?.toString() ?? '—', Icons.person_outline),
                    _buildPill('Age', '${ext['exact_age'] ?? '—'} yrs (${ext['age_group'] ?? '—'})', Icons.cake_outlined),
                    _buildPill('Sex', ext['sex']?.toString() ?? '—', Icons.wc_outlined),
                    _buildPill('District', ext['district']?.toString() ?? '—', Icons.location_on_outlined),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _buildPill('Diagnosis', ext['diagnosis']?.toString() ?? '—', Icons.medical_services_outlined),
                    _buildPill('Syndrome', ext['infection_syndrome']?.toString() ?? '—', Icons.health_and_safety_outlined),
                    _buildPill('Origin', ext['infection_origin']?.toString() ?? '—', Icons.apartment_outlined),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgTertiary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _buildPill('Sample ID', ext['accession_no']?.toString() ?? '—', Icons.qr_code),
                    _buildPill('Specimen', ext['specimen_type']?.toString() ?? '—', Icons.science_outlined),
                    _buildPill('Organism', ext['pathogen']?.toString() ?? '—', Icons.bug_report_outlined),
                    _buildPill('Culture', ext['culture_result']?.toString() ?? '—', Icons.biotech_outlined),
                  ],
                ),
                if ((ext['ast_panel'] as List<dynamic>?)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'AST PANEL RESULTS (STANDARDIZED):',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ((ext['ast_panel'] as List<dynamic>?) ?? []).map((item) {
                      final m = item as Map<String, dynamic>;
                      final drug = m['antibiotic'] as String? ?? '';
                      final sir = m['ast_result'] as String? ?? 'Not tested';
                      return _buildAstChip(drug, sir);
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPill(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text('$label: ', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildAstChip(String antibiotic, String result) {
    Color badgeColor = AppColors.statusNotTested;
    if (result == 'Resistant') badgeColor = AppColors.statusCritical;
    if (result == 'Susceptible') badgeColor = AppColors.statusNormal;
    if (result == 'Intermediate') badgeColor = AppColors.statusMonitoring;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(antibiotic, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text('($result)', style: TextStyle(fontSize: 11, color: badgeColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
