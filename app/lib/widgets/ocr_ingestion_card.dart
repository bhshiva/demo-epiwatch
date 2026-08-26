import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:convert';
import '../models/ingestion_models.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../services/app_strings.dart';
import '../state/locale.dart';

class OcrIngestionCard extends ConsumerStatefulWidget {
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
  ConsumerState<OcrIngestionCard> createState() => _OcrIngestionCardState();
}

class _OcrIngestionCardState extends ConsumerState<OcrIngestionCard> with SingleTickerProviderStateMixin {
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
    final lang = ref.watch(localeProvider);
    final isDoctor = widget.documentType == 'clinical_report';
    final cardTitle = isDoctor
        ? AppStrings.get('ocr_title_doctor', lang)
        : AppStrings.get('ocr_title_lab', lang);
    final cardSubtitle = isDoctor
        ? AppStrings.get('ocr_subtitle_doctor', lang)
        : AppStrings.get('ocr_subtitle_lab', lang);

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
          // Header Bar
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome, size: 12, color: AppColors.accentTeal),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppStrings.get('ocr_ai_audit', lang),
                                    style: const TextStyle(
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
                          cardSubtitle,
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

            // Tab Mode Switcher
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _buildTabButton(0, AppStrings.get('quick_templates', lang), Icons.collections_bookmark_outlined),
                  const SizedBox(width: 8),
                  _buildTabButton(1, AppStrings.get('google_lens', lang), Icons.camera_alt_outlined),
                  const SizedBox(width: 8),
                  _buildTabButton(2, AppStrings.get('paste_notes', lang), Icons.edit_note_outlined),
                ],
              ),
            ),

            // Tab Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedTab == 0) _buildTemplatesTab(isDoctor),
                  if (_selectedTab == 1) _buildGoogleLensScanTab(isDoctor),
                  if (_selectedTab == 2) _buildManualTextTab(isDoctor),

                  // Structured Extraction Preview (Decramped Cards)
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
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentTeal : AppColors.bgTertiary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.accentTeal : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplatesTab(bool isDoctor) {
    final lang = ref.watch(localeProvider);
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
        Text(
          AppStrings.get('select_scenario', lang).toUpperCase(),
          style: const TextStyle(
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
    final lang = ref.watch(localeProvider);
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
                        child: Text(
                          AppStrings.get('ocr_contains_anomaly', lang),
                          style: const TextStyle(
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
            label: Text(AppStrings.get('extract_fill', lang), style: const TextStyle(fontSize: 11.5)),
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
    final lang = ref.watch(localeProvider);
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
          Text(
            AppStrings.get('ocr_cloud_vision', lang),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.get('ocr_cloud_vision_sub', lang),
            textAlign: Alignment.center == Alignment.center ? TextAlign.center : TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                label: Text(AppStrings.get('ocr_select_file', lang)),
                onPressed: _isProcessing ? null : _pickAndProcessImage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualTextTab(bool isDoctor) {
    final lang = ref.watch(localeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.get('ocr_paste_title', lang),
          style: const TextStyle(
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
            label: Text(AppStrings.get('ocr_run_normalization', lang)),
            onPressed: _isProcessing ? null : () => _processOcr(),
          ),
        ),
      ],
    );
  }

  Widget _buildStructuredExtractionCards(OcrParseResult result, bool isDoctor) {
    final lang = ref.watch(localeProvider);
    final ext = result.extracted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.accentTeal, size: 18),
            const SizedBox(width: 6),
            Text(
              AppStrings.get('ocr_structured_entities', lang),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${AppStrings.get("ocr_score", lang)}: ${result.intelligenceAudit.plausibilityScore}%',
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
          // Doctor Demographics Card
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
                    _buildPill(AppStrings.get('ocr_patient', lang), ext['full_name']?.toString() ?? '—', Icons.person_outline),
                    _buildPill(AppStrings.get('ocr_age', lang), '${ext['exact_age'] ?? '—'} yrs (${ext['age_group'] ?? '—'})', Icons.cake_outlined),
                    _buildPill(AppStrings.get('ocr_sex', lang), ext['sex']?.toString() ?? '—', Icons.wc_outlined),
                    _buildPill(AppStrings.get('ocr_district', lang), ext['district']?.toString() ?? '—', Icons.location_on_outlined),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _buildPill(AppStrings.get('ocr_diagnosis', lang), ext['diagnosis']?.toString() ?? '—', Icons.medical_services_outlined),
                    _buildPill(AppStrings.get('ocr_syndrome', lang), ext['infection_syndrome']?.toString() ?? '—', Icons.health_and_safety_outlined),
                    _buildPill(AppStrings.get('ocr_origin', lang), ext['infection_origin']?.toString() ?? '—', Icons.apartment_outlined),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          // Lab Isolate & AST Matrix Card
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
                    _buildPill(AppStrings.get('ocr_sample_id', lang), ext['accession_no']?.toString() ?? '—', Icons.qr_code),
                    _buildPill(AppStrings.get('ocr_specimen', lang), ext['specimen_type']?.toString() ?? '—', Icons.science_outlined),
                    _buildPill(AppStrings.get('ocr_organism', lang), ext['pathogen']?.toString() ?? '—', Icons.bug_report_outlined),
                    _buildPill(AppStrings.get('ocr_culture', lang), ext['culture_result']?.toString() ?? '—', Icons.biotech_outlined),
                  ],
                ),
                if ((ext['ast_panel'] as List<dynamic>?)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 10),
                  Text(
                    AppStrings.get('ocr_ast_results_title', lang),
                    style: const TextStyle(
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
    final lang = ref.watch(localeProvider);
    Color badgeColor = AppColors.statusNotTested;
    String localizedResult = AppStrings.get('ast_not_tested', lang);
    if (result == 'Resistant') {
      badgeColor = AppColors.statusCritical;
      localizedResult = AppStrings.get('ast_resistant', lang);
    } else if (result == 'Susceptible') {
      badgeColor = AppColors.statusNormal;
      localizedResult = AppStrings.get('ast_susceptible', lang);
    } else if (result == 'Intermediate') {
      badgeColor = AppColors.statusMonitoring;
      localizedResult = AppStrings.get('ast_intermediate', lang);
    }

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
          Text('($localizedResult)', style: TextStyle(fontSize: 11, color: badgeColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
