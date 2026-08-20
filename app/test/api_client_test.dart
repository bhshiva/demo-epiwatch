import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:epiwatch/services/api_client.dart';
import 'package:epiwatch/services/api_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with a canned response, so the classification logic
/// can be exercised without a server.
class _StubAdapter implements HttpClientAdapter {
  final int status;
  final dynamic body;
  final DioException? throws;

  _StubAdapter({this.status = 200, this.body, this.throws});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    if (throws != null) throw throws!;
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

ApiClient _clientWith(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://test.local',
    validateStatus: (_) => true,
  ));
  dio.httpClientAdapter = adapter;
  return ApiClient(dio: dio);
}

void main() {
  group('login', () {
    test('parses the session including the role', () async {
      final client = _clientWith(_StubAdapter(body: {
        'access_token': 'tok',
        'role': 'lab',
        'doctor_id': 'd1',
        'name': 'Priya Nair',
        'facility_id': 'f1',
      }));

      final session = await client.login('lab@epiwatch.test', 'pw');

      expect(session.role, 'lab');
      expect(session.isLab, isTrue);
      expect(session.name, 'Priya Nair');
    });

    test('defaults to the doctor role when the server omits it', () async {
      final client = _clientWith(_StubAdapter(body: {
        'access_token': 'tok',
        'doctor_id': 'd1',
        'name': 'Dr. Asha Rao',
        'facility_id': 'f1',
      }));

      final session = await client.login('doctor@epiwatch.test', 'pw');

      expect(session.role, 'doctor');
      expect(session.isLab, isFalse);
    });
  });

  group('error classification', () {
    test('a 409 duplicate carries its candidates and is not a NetworkException',
        () async {
      final client = _clientWith(_StubAdapter(status: 409, body: {
        'detail': {
          'message': 'This patient may already exist.',
          'candidates': [
            {'patient_id': 'p1'}
          ],
        }
      }));

      // The WPF client turned this into a transport error and queued it for
      // infinite retry. It must surface as a refusal instead.
      await expectLater(
        client.post('/reports', {}),
        throwsA(isA<DuplicatePatientException>()
            .having((e) => e.candidates.length, 'candidates', 1)
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
      await expectLater(
        client.post('/reports', {}),
        throwsA(isNot(isA<NetworkException>())),
      );
    });

    test('a 403 is a refusal, not a retryable failure', () async {
      final client = _clientWith(
          _StubAdapter(status: 403, body: {'detail': 'Requires role: lab'}));

      await expectLater(
        client.get('/lab/summary'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.message, 'message', 'Requires role: lab')),
      );
    });

    test('a connection error is a NetworkException and so is retryable',
        () async {
      final client = _clientWith(_StubAdapter(
        throws: DioException(
          requestOptions: RequestOptions(path: '/reports'),
          type: DioExceptionType.connectionError,
        ),
      ));

      await expectLater(
        client.post('/reports', {}),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a 500 gets a generic message rather than leaking server detail',
        () async {
      final client = _clientWith(_StubAdapter(status: 500, body: {}));

      await expectLater(
        client.get('/dashboard/summary'),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', contains('server had a problem'))),
      );
    });
  });
}
