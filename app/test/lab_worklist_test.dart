import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:epiwatch/screens/lab_worklist_screen.dart';
import 'package:epiwatch/screens/shell_screen.dart';
import 'package:epiwatch/services/api_client.dart';
import 'package:epiwatch/state/auth.dart';
import 'package:epiwatch/state/submit_isolate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with a canned response, mirroring the stub-Dio
/// pattern used in test/api_client_test.dart.
class _StubAdapter implements HttpClientAdapter {
  final dynamic body;

  _StubAdapter({this.body});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _clientWith(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local', validateStatus: (_) => true));
  dio.httpClientAdapter = adapter;
  return ApiClient(dio: dio);
}

void main() {
  testWidgets('shows an empty state rather than a blank screen when nothing is pending',
      (tester) async {
    final client = _clientWith(_StubAdapter(body: []));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: const MaterialApp(home: Scaffold(body: LabWorklistScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No isolates awaiting results.'), findsOneWidget);
  });

  testWidgets('renders a row for each isolate awaiting a final result', (tester) async {
    final client = _clientWith(_StubAdapter(body: [
      {
        'isolate_id': 'i1',
        'accession_no': 'ACC-1',
        'collection_date': '2026-08-01',
        'specimen_type': 'Urine',
        'culture_result': 'Growth - organism identified',
        'pathogen': 'Escherichia coli',
        'status': 'preliminary',
        'created_at': '2026-08-01T00:00:00Z',
        'ast_results': [],
        'resistant_count': 0,
        'tested_count': 0,
        'is_mdr': false,
      }
    ]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: const MaterialApp(home: Scaffold(body: LabWorklistScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ACC-1'), findsOneWidget);
    expect(find.text('Escherichia coli'), findsOneWidget);
    expect(find.text('1 awaiting a final result'), findsOneWidget);
  });

  testWidgets('tapping a row loads it into the isolate form for editing', (tester) async {
    final client = _clientWith(_StubAdapter(body: [
      {
        'isolate_id': 'i1',
        'accession_no': 'ACC-1',
        'collection_date': '2026-08-01',
        'specimen_type': 'Urine',
        'culture_result': 'Growth - organism identified',
        'pathogen': 'Escherichia coli',
        'status': 'preliminary',
        'created_at': '2026-08-01T00:00:00Z',
        'ast_results': [],
        'resistant_count': 0,
        'tested_count': 0,
        'is_mdr': false,
      }
    ]));

    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ShellNav(
              navigateTo: (_) {},
              child: const LabWorklistScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    final formState = container.read(submitIsolateProvider);
    expect(formState.isEditing, isTrue);
    expect(formState.accessionNo, 'ACC-1');
    expect(formState.pathogen, 'Escherichia coli');
  });
}
