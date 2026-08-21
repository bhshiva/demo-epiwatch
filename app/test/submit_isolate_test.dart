import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:epiwatch/models/lab_models.dart';
import 'package:epiwatch/services/api_client.dart';
import 'package:epiwatch/services/clinical_catalog.dart';
import 'package:epiwatch/state/auth.dart';
import 'package:epiwatch/state/submit_isolate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with a canned isolate and records the request it
/// was called with, so a test can assert POST vs. PATCH and the target path.
class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode({
        'isolate_id': 'i1',
        'status': 'final',
        'created_at': '2026-08-01T00:00:00Z',
        'pathogen': 'Escherichia coli',
        'ast_results': [],
        'resistant_count': 0,
        'tested_count': 0,
        'is_mdr': false,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

SubmitIsolateState _validState() => const SubmitIsolateState(
      accessionNo: 'ACC-1001',
      cultureResult: 'Growth - organism identified',
      pathogen: 'Escherichia coli',
      specimenType: 'Urine',
    );

void main() {
  group('clinical catalog integrity', () {
    // The WPF client's real bug: Cefepime was in the standard panel but
    // missing from the antibiotic-class map, so it silently submitted with
    // no class and was skipped when counting distinct resistant classes for
    // MDR. Every drug the standard panel can add must resolve a class.
    test('every drug in the standard Gram-negative panel resolves a class', () {
      for (final drug in ClinicalCatalog.gramNegativePanel) {
        final resolved = ClinicalCatalog.classFor(drug);
        expect(resolved, isNotNull, reason: '$drug has no class in antibioticToClass');
        expect(resolved, isNotEmpty, reason: '$drug has no class in antibioticToClass');
      }
    });

    test('classFor matches case-insensitively', () {
      expect(ClinicalCatalog.classFor('meropenem'), 'Carbapenems');
      expect(ClinicalCatalog.classFor('MEROPENEM'), 'Carbapenems');
    });

    test('classFor returns null for an unknown drug', () {
      expect(ClinicalCatalog.classFor('Not A Real Drug'), isNull);
    });
  });

  group('validation requirements', () {
    test('submit is blocked until the required fields are present', () {
      const empty = SubmitIsolateState();
      expect(empty.canSubmit, isFalse);

      final withAccessionAndCulture = empty.copyWith(
        accessionNo: 'ACC-1001',
        cultureResult: 'Growth - organism identified',
      );
      // Growth without an organism named is an incomplete result.
      expect(withAccessionAndCulture.canSubmit, isFalse);
      expect(withAccessionAndCulture.missingRequirements(), contains('Pathogen'));

      final complete = withAccessionAndCulture.copyWith(pathogen: 'Escherichia coli');
      expect(complete.canSubmit, isTrue);
    });

    test('a negative culture (no growth) does not require a pathogen', () {
      const vm = SubmitIsolateState(
        accessionNo: 'ACC-1002',
        cultureResult: 'No growth',
      );

      expect(vm.canSubmit, isTrue);
    });

    test('"Other" requires the detail field to be specified', () {
      final vm = _validState().copyWith(pathogen: 'Other');

      expect(vm.showPathogenOther, isTrue);
      expect(vm.canSubmit, isFalse);

      final withDetail = vm.copyWith(pathogenOther: 'Burkholderia pseudomallei');
      expect(withDetail.canSubmit, isTrue);
    });

    test('duplicate antibiotics (case-insensitive) block submission', () {
      final vm = _validState().copyWith(panel: const [
        AstRowDraft(antibiotic: 'Meropenem'),
        AstRowDraft(antibiotic: 'meropenem'),
      ]);

      expect(vm.canSubmit, isFalse);
      expect(vm.validationSummary.toLowerCase(), contains('duplicate'));
    });

    test('an incomplete row (no antibiotic named) does not count as a duplicate', () {
      final vm = _validState().copyWith(panel: const [
        AstRowDraft(antibiotic: 'Meropenem'),
        AstRowDraft(),
      ]);

      expect(vm.canSubmit, isTrue);
    });
  });

  group('AstRowDraft', () {
    test('selecting an antibiotic resolves its class', () {
      const row = AstRowDraft(antibiotic: 'Meropenem');
      expect(row.antibioticClass, 'Carbapenems');
    });
  });

  group('SubmitIsolateNotifier', () {
    late ProviderContainer container;
    late SubmitIsolateNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
      notifier = container.read(submitIsolateProvider.notifier);
    });

    test('loadStandardPanel populates the full Gram-negative panel with resolved classes', () {
      notifier.loadStandardPanel();

      final panel = container.read(submitIsolateProvider).panel;
      expect(panel, hasLength(ClinicalCatalog.gramNegativePanel.length));
      expect(panel.any((r) => r.antibiotic == 'Meropenem'), isTrue);
      for (final row in panel) {
        expect(row.antibioticClass, isNotNull, reason: '${row.antibiotic} has no class');
        expect(row.antibioticClass, isNotEmpty, reason: '${row.antibiotic} has no class');
      }
    });

    test('addDrug and removeDrugAt manage panel rows', () {
      notifier.addDrug();
      notifier.addDrug();
      expect(container.read(submitIsolateProvider).panel, hasLength(2));

      notifier.removeDrugAt(0);
      expect(container.read(submitIsolateProvider).panel, hasLength(1));
    });

    test('buildRequest carries the panel with parsed measurements and omits abandoned "Other" text', () {
      notifier.setAccessionNo('ACC-1001');
      notifier.setCultureResult('Growth - organism identified');
      notifier.setPathogen('Other');
      notifier.setPathogenOther('Something rare');
      notifier.setPathogen('Escherichia coli'); // abandoning "Other"
      notifier.addDrug();
      notifier.updateDrugAt(
        0,
        const AstRowDraft(
          antibiotic: 'Meropenem',
          astResult: 'Resistant',
          micValue: '16',
          micOperator: '>=',
          method: 'Broth microdilution',
        ),
      );

      final dto = notifier.buildRequest();

      expect(dto.pathogenOther, isNull);
      expect(dto.astResults, hasLength(1));
      expect(dto.astResults[0].antibiotic, 'Meropenem');
      expect(dto.astResults[0].antibioticClass, 'Carbapenems');
      expect(dto.astResults[0].micValue, 16);
      expect(dto.astResults[0].micOperator, '>=');
    });

    test('buildRequest skips rows with no antibiotic named', () {
      notifier.addDrug();
      notifier.addDrug();
      notifier.updateDrugAt(0, const AstRowDraft(antibiotic: 'Ciprofloxacin'));

      expect(notifier.buildRequest().astResults, hasLength(1));
    });

    test('submitAnother clears the panel and header fields for the next isolate', () {
      notifier.setAccessionNo('ACC-1001');
      notifier.setPathogen('Escherichia coli');
      notifier.loadStandardPanel();

      notifier.submitAnother();

      final state = container.read(submitIsolateProvider);
      expect(state.panel, isEmpty);
      expect(state.accessionNo, '');
      expect(state.pathogen, '');
      expect(state.isSubmitted, isFalse);
    });

    test('loadForEdit prefills the form and its AST panel from a worklist entry', () {
      notifier.loadForEdit(const Isolate(
        isolateId: 'i1',
        accessionNo: 'ACC-9',
        specimenType: 'Urine',
        cultureResult: 'Growth - organism identified',
        pathogen: 'Escherichia coli',
        status: 'preliminary',
        createdAt: '2026-08-01T00:00:00Z',
        astResults: [
          AstResult(antibiotic: 'Meropenem', astResult: 'Resistant', micValue: 16),
        ],
      ));

      final state = container.read(submitIsolateProvider);
      expect(state.isEditing, isTrue);
      expect(state.editingIsolateId, 'i1');
      expect(state.accessionNo, 'ACC-9');
      expect(state.panel, hasLength(1));
      expect(state.panel[0].antibiotic, 'Meropenem');
      expect(state.panel[0].micValue, '16.0');
    });

    test('submitAnother clears editingIsolateId, leaving a fresh form', () {
      notifier.loadForEdit(const Isolate(
        isolateId: 'i1',
        status: 'preliminary',
        createdAt: '2026-08-01T00:00:00Z',
      ));
      expect(container.read(submitIsolateProvider).isEditing, isTrue);

      notifier.submitAnother();

      expect(container.read(submitIsolateProvider).isEditing, isFalse);
    });

    test('submit() amends via PATCH when editing an existing isolate', () async {
      final adapter = _RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://test.local', validateStatus: (_) => true));
      dio.httpClientAdapter = adapter;
      final client = ApiClient(dio: dio);
      final editContainer = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(client),
      ]);
      addTearDown(editContainer.dispose);
      final editNotifier = editContainer.read(submitIsolateProvider.notifier);

      editNotifier.loadForEdit(const Isolate(
        isolateId: 'i1',
        accessionNo: 'ACC-9',
        cultureResult: 'Growth - organism identified',
        pathogen: 'Escherichia coli',
        status: 'preliminary',
        createdAt: '2026-08-01T00:00:00Z',
      ));

      await editNotifier.submit();

      expect(adapter.lastRequest?.method, 'PATCH');
      expect(adapter.lastRequest?.path, '/lab/isolates/i1');
      expect(editContainer.read(submitIsolateProvider).isSubmitted, isTrue);
    });

    test('submit() creates via POST when not editing', () async {
      final adapter = _RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://test.local', validateStatus: (_) => true));
      dio.httpClientAdapter = adapter;
      final client = ApiClient(dio: dio);
      final createContainer = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(client),
      ]);
      addTearDown(createContainer.dispose);
      final createNotifier = createContainer.read(submitIsolateProvider.notifier);

      createNotifier.setAccessionNo('ACC-1001');
      createNotifier.setCultureResult('Growth - organism identified');
      createNotifier.setPathogen('Escherichia coli');

      await createNotifier.submit();

      expect(adapter.lastRequest?.method, 'POST');
      expect(adapter.lastRequest?.path, '/lab/isolates');
    });
  });
}
