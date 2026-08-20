import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:epiwatch/models/patient_models.dart';
import 'package:epiwatch/services/api_client.dart';
import 'package:epiwatch/state/auth.dart';
import 'package:epiwatch/state/submit_report.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with a canned response, mirroring the stub in
/// test/api_client_test.dart so the Notifier can be exercised without a
/// server.
class _StubAdapter implements HttpClientAdapter {
  final int status;
  final dynamic body;

  _StubAdapter({this.status = 200, this.body});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _containerWith(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local', validateStatus: (_) => true));
  dio.httpClientAdapter = adapter;
  final client = ApiClient(dio: dio);
  final container = ProviderContainer(overrides: [
    apiClientProvider.overrideWithValue(client),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('validation', () {
    test('a fresh form cannot be submitted and lists what is missing', () {
      final container = _containerWith(_StubAdapter());
      final state = container.read(submitReportProvider);

      expect(state.canSubmit, isFalse);
      expect(state.missingRequirements, contains('Patient'));
      expect(state.missingRequirements, contains('Age'));
      expect(state.missingRequirements, contains('Sex'));
      expect(state.missingRequirements, contains('District'));
      expect(state.missingRequirements, contains('Chief Complaint'));
    });

    test('filling every required field with an existing patient makes it submittable',
        () async {
      final container = _containerWith(_StubAdapter(body: []));
      final notifier = container.read(submitReportProvider.notifier);

      await notifier.selectPatient(_samplePatient);
      notifier.setPatientAge('30');
      notifier.setPatientSex('Female');
      notifier.setPatientDistrict('Pune');
      notifier.setComplaints('Fever for 3 days');

      final state = container.read(submitReportProvider);
      expect(state.missingRequirements, isEmpty);
      expect(state.canSubmit, isTrue);
    });

    test('selecting "Other" for a coded field requires the free-text detail', () {
      final container = _containerWith(_StubAdapter());
      final notifier = container.read(submitReportProvider.notifier);

      notifier.setLabPerformed(true);
      notifier.setPathogen('Other');

      final state = container.read(submitReportProvider);
      expect(state.missingRequirements, contains('Pathogen detail'));

      notifier.setPathogenOther('Novel organism');
      final updated = container.read(submitReportProvider);
      expect(updated.missingRequirements, isNot(contains('Pathogen detail')));
    });

    test('age derives the correct GLASS band', () {
      final container = _containerWith(_StubAdapter());
      final notifier = container.read(submitReportProvider.notifier);

      notifier.setPatientAge('7');
      expect(container.read(submitReportProvider).derivedAgeGroup, '5-14');

      notifier.setPatientAge('70');
      expect(container.read(submitReportProvider).derivedAgeGroup, '65+');
    });
  });

  group('duplicate-patient flow', () {
    test('a 409 with candidates surfaces them without throwing or crashing',
        () async {
      final container = _containerWith(_StubAdapter(status: 409, body: {
        'detail': {
          'message': 'This patient may already exist.',
          'candidates': [
            {
              'patient_id': 'p2',
              'full_name': 'Ravi Kumar',
              'age_group': '25-44',
              'sex': 'Male',
              'district': 'Mumbai',
              'report_count': 1,
              'score': 0.91,
              'confidence': 'review',
              'match_type': 'probabilistic',
              'matched_on': ['name', 'district'],
            },
          ],
        },
      }));
      final notifier = container.read(submitReportProvider.notifier);

      notifier.startNewPatient();
      notifier.setNewPatientName('Ravi Kumar');
      notifier.setPatientAge('30');
      notifier.setPatientSex('Male');
      notifier.setPatientDistrict('Mumbai');
      notifier.setComplaints('Cough');

      // Must not throw: the notifier catches DuplicatePatientException.
      await notifier.submit();

      final state = container.read(submitReportProvider);
      expect(state.isSubmitted, isFalse);
      expect(state.nearMatches, hasLength(1));
      expect(state.nearMatches.first.fullName, 'Ravi Kumar');
      expect(state.errorMessage, 'This patient may already exist.');
      // Not treated as a network failure — form data survives.
      expect(state.newPatientName, 'Ravi Kumar');
    });

    test('picking a candidate attaches the report to that patient', () async {
      final container = _containerWith(_StubAdapter(body: [
        {
          'report_id': 'r1',
          'report_date': '2026-01-01',
        }
      ]));
      final notifier = container.read(submitReportProvider.notifier);

      const candidate = _sampleCandidate;
      await notifier.useExistingPatient(candidate);

      final state = container.read(submitReportProvider);
      expect(state.selectedPatient?.patientId, 'p2');
      expect(state.hasNearMatches, isFalse);
      expect(state.isNewPatient, isFalse);
    });
  });

  group('confirmedNew flow', () {
    test('createAnyway sets confirmedNew:true on the built request', () {
      final container = _containerWith(_StubAdapter());
      final notifier = container.read(submitReportProvider.notifier);

      notifier.startNewPatient();
      notifier.setNewPatientName('New Person');
      notifier.setPatientAge('40');
      notifier.setPatientSex('Male');
      notifier.setPatientDistrict('Delhi');
      notifier.setComplaints('Sore throat');
      notifier.createAnyway();

      final state = container.read(submitReportProvider);
      final request = state.buildRequest();

      expect(request.confirmedNew, isTrue);
      expect(request.patientIdentity?.fullName, 'New Person');
      expect(state.hasNearMatches, isFalse);
    });

    test('without confirmation confirmedNew defaults to false', () {
      final container = _containerWith(_StubAdapter());
      final notifier = container.read(submitReportProvider.notifier);

      notifier.startNewPatient();
      notifier.setNewPatientName('Someone');

      final request = container.read(submitReportProvider).buildRequest();
      expect(request.confirmedNew, isFalse);
    });
  });

  group('submit success', () {
    test('a successful create marks the form submitted', () async {
      final container = _containerWith(_StubAdapter(body: {'report_id': 'r1'}));
      final notifier = container.read(submitReportProvider.notifier);

      // Avoids selectPatient(), which also calls the patient-history
      // endpoint (a list response) — this stub answers every request
      // identically with a Map body, so the new-patient path is used
      // instead to keep the create-report call the only request made.
      notifier.startNewPatient();
      notifier.setNewPatientName('Asha Verma');
      notifier.setPatientAge('30');
      notifier.setPatientSex('Female');
      notifier.setPatientDistrict('Pune');
      notifier.setComplaints('Fever');

      await notifier.submit();

      final state = container.read(submitReportProvider);
      expect(state.isSubmitted, isTrue);
      expect(state.errorMessage, isNull);
    });
  });
}

const _samplePatient = PatientSearchResult(
  patientId: 'p1',
  fullName: 'Asha Verma',
  ageGroup: '25-44',
  sex: 'Female',
  district: 'Pune',
  reportCount: 1,
);

const _sampleCandidate = PatientMatchCandidate(
  patientId: 'p2',
  fullName: 'Ravi Kumar',
  ageGroup: '25-44',
  sex: 'Male',
  district: 'Mumbai',
  reportCount: 1,
  score: 0.91,
  confidence: 'review',
  matchType: 'probabilistic',
  matchedOn: ['name', 'district'],
);
