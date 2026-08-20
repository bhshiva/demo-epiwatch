import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:epiwatch/models/patient_models.dart';
import 'package:epiwatch/services/api_client.dart';
import 'package:epiwatch/state/auth.dart';
import 'package:epiwatch/state/patient_records.dart';
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
  group('patient search', () {
    test('an empty query does not hit the API and clears results', () async {
      final container = _containerWith(_StubAdapter(body: []));
      final notifier = container.read(patientRecordsProvider.notifier);

      notifier.setQuery('   ');
      await notifier.search();

      final state = container.read(patientRecordsProvider);
      expect(state.results, isEmpty);
      expect(state.searchError, isNull);
    });

    test('no results shows an empty list without an error', () async {
      final container = _containerWith(_StubAdapter(body: []));
      final notifier = container.read(patientRecordsProvider.notifier);

      notifier.setQuery('nobody');
      await notifier.search();

      final state = container.read(patientRecordsProvider);
      expect(state.results, isEmpty);
      expect(state.hasSearched, isTrue);
      expect(state.searchError, isNull);
      expect(state.isSearching, isFalse);
    });

    test('results are parsed into PatientSearchResult rows', () async {
      final container = _containerWith(_StubAdapter(body: [
        {
          'patient_id': 'p1',
          'full_name': 'Asha Verma',
          'age_group': '25-44',
          'sex': 'Female',
          'district': 'Pune',
          'report_count': 2,
        },
      ]));
      final notifier = container.read(patientRecordsProvider.notifier);

      notifier.setQuery('Asha');
      await notifier.search();

      final state = container.read(patientRecordsProvider);
      expect(state.results, hasLength(1));
      expect(state.results.first.fullName, 'Asha Verma');
      expect(state.results.first.visitSummary, contains('2 reports'));
    });

    test('a server refusal sets searchError as a non-network failure', () async {
      final container =
          _containerWith(_StubAdapter(status: 500, body: {}));
      final notifier = container.read(patientRecordsProvider.notifier);

      notifier.setQuery('Asha');
      await notifier.search();

      final state = container.read(patientRecordsProvider);
      expect(state.searchError, isNotNull);
      expect(state.isSearchNetworkError, isFalse);
    });
  });

  group('history load', () {
    test('selecting a patient loads their history entries', () async {
      final container = _containerWith(_StubAdapter(body: [
        {
          'report_id': 'r1',
          'report_date': '2026-01-02',
          'diagnosis': 'Typhoid',
          'diagnosis_status': 'Confirmed',
          'pathogen': 'Salmonella Typhi',
        }
      ]));
      final notifier = container.read(patientRecordsProvider.notifier);

      await notifier.selectPatient(_patient);

      final state = container.read(patientRecordsProvider);
      expect(state.selectedPatient?.patientId, 'p1');
      expect(state.history, hasLength(1));
      expect(state.history.first.hasLabResult, isTrue);
      expect(state.historyError, isNull);
    });

    test('a history load failure is kept separate from the search error', () async {
      final container = _containerWith(_StubAdapter(status: 404, body: {}));
      final notifier = container.read(patientRecordsProvider.notifier);

      await notifier.selectPatient(_patient);

      final state = container.read(patientRecordsProvider);
      expect(state.historyError, isNotNull);
      expect(state.searchError, isNull);
    });
  });
}

const _patient = PatientSearchResult(
  patientId: 'p1',
  fullName: 'Asha Verma',
  ageGroup: '25-44',
  sex: 'Female',
  district: 'Pune',
  reportCount: 1,
);
