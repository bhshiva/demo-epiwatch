import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:epiwatch/services/api_client.dart';
import 'package:epiwatch/state/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with a canned response, mirroring the stub-Dio
/// pattern used elsewhere in this test suite.
class _StubAdapter implements HttpClientAdapter {
  final dynamic body;
  RequestOptions? lastRequest;

  _StubAdapter({this.body});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    lastRequest = options;
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
  test('login carries must_change_password through to the session', () async {
    final client = _clientWith(_StubAdapter(body: {
      'access_token': 'tok',
      'role': 'admin',
      'doctor_id': 'd1',
      'name': 'Ravi Kulkarni',
      'facility_id': null,
      'must_change_password': true,
    }));
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
    ]);
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).signIn('admin@epiwatch.test', 'temp-pass');

    final session = container.read(authProvider).session;
    expect(session, isNotNull);
    expect(session!.mustChangePassword, isTrue);
    expect(session.facilityId, isNull);
    expect(session.isAdmin, isTrue);
  });

  test('changePassword clears mustChangePassword on success', () async {
    final adapter = _StubAdapter(body: {
      'access_token': 'tok',
      'role': 'admin',
      'doctor_id': 'd1',
      'name': 'Ravi Kulkarni',
      'facility_id': null,
      'must_change_password': true,
    });
    final client = _clientWith(adapter);
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(client),
    ]);
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).signIn('admin@epiwatch.test', 'temp-pass');
    expect(container.read(authProvider).session!.mustChangePassword, isTrue);

    await container.read(authProvider.notifier).changePassword('temp-pass', 'NewPass123!');

    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.path, '/auth/change-password');
    expect(container.read(authProvider).session!.mustChangePassword, isFalse);
  });
}
