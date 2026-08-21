import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/dashboard_models.dart';
import '../models/lab_models.dart';
import '../models/patient_models.dart';
import '../models/report_models.dart';
import '../models/session.dart';
import 'api_exceptions.dart';

class ApiClient {
  final Dio _dio;
  String? _token;

  ApiClient({String? baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? defaultBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              // Let non-2xx through so the interceptor can classify it,
              // rather than Dio throwing a generic DioException first.
              validateStatus: (_) => true,
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
    ));
  }

  /// The Android emulator reaches the host machine on 10.0.2.2, not localhost.
  static String get defaultBaseUrl {
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  void setToken(String? token) => _token = token;

  Future<Session> login(String email, String password) async {
    final res = await _send(() => _dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: {'email': email, 'password': password},
        ));
    return Session.fromJson(res);
  }

  Future<DashboardSummary> getDashboardSummary() async {
    final res = await get('/dashboard/summary');
    return DashboardSummary.fromJson(res);
  }

  Future<List<ReportSummary>> getReports() async {
    final res = await getList('/reports');
    return res.map((e) => ReportSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> createReport(ReportCreateRequest request) =>
      post('/reports', request.toJson());

  Future<List<PatientSearchResult>> searchPatients(String query) async {
    if (query.trim().isEmpty) return [];
    final res = await getList('/patients/search', query: {'q': query.trim()});
    return res.map((e) => PatientSearchResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<PatientMatchCandidate>> matchPatients(Map<String, dynamic> body) async {
    final res = await _sendRaw(() => _dio.post<dynamic>('/patients/match', data: body));
    return (res as List<dynamic>)
        .map((e) => PatientMatchCandidate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AbhaVerifyResult> verifyAbha(String abhaNumber) async {
    final res = await post('/patients/verify-abha', {'abha_number': abhaNumber});
    return AbhaVerifyResult.fromJson(res);
  }

  Future<List<PatientHistoryEntry>> patientHistory(String patientId) async {
    final res = await getList('/patients/$patientId/history');
    return res.map((e) => PatientHistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<Map<String, dynamic>>(path, queryParameters: query));

  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? query}) async {
    final res = await _sendRaw(() => _dio.get<dynamic>(path, queryParameters: query));
    return res as List<dynamic>;
  }

  Future<Map<String, dynamic>> post(String path, Object? body) =>
      _send(() => _dio.post<Map<String, dynamic>>(path, data: body));

  Future<Map<String, dynamic>> patch(String path, Object? body) =>
      _send(() => _dio.patch<Map<String, dynamic>>(path, data: body));

  Future<Map<String, dynamic>> _send(
          Future<Response<Map<String, dynamic>>> Function() call) async =>
      (await _sendRaw(call)) as Map<String, dynamic>;

  /// Single place where transport failure and server refusal are told apart.
  Future<dynamic> _sendRaw(Future<Response<dynamic>> Function() call) async {
    late final Response<dynamic> res;
    try {
      res = await call();
    } on DioException catch (e) {
      // No HTTP response at all: offline, timeout, DNS. Safe to retry later.
      throw NetworkException(_describeTransport(e));
    }

    final status = res.statusCode ?? 0;
    if (status >= 200 && status < 300) return res.data;

    final body = res.data;
    final detail = body is Map<String, dynamic> ? body['detail'] : null;

    if (status == 409 && detail is Map<String, dynamic>) {
      throw DuplicatePatientException(
        detail['message'] as String? ?? 'This patient may already exist.',
        detail['candidates'] as List<dynamic>? ?? const [],
      );
    }

    throw ApiException(status, _describeRefusal(status, detail));
  }

  String _describeRefusal(int status, Object? detail) {
    if (detail is String && detail.isNotEmpty) return detail;
    if (status >= 500) return 'The server had a problem. Please try again.';
    return switch (status) {
      401 => 'Your session has expired. Please sign in again.',
      403 => 'Your role does not have access to this.',
      404 => 'Not found.',
      _ => 'Request failed ($status).',
    };
  }

  String _describeTransport(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'The server took too long to respond.',
        DioExceptionType.connectionError =>
          'Cannot reach the server. Check that the backend is running.',
        _ => 'Network error: ${e.message ?? 'unknown'}',
      };

  Future<LabSummary> getLabSummary() async {
    final res = await get('/lab/summary');
    return LabSummary.fromJson(res);
  }

  Future<List<Isolate>> getWorklist() async {
    final res = await getList('/lab/worklist');
    return res.map((e) => Isolate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Isolate>> getIsolates() async {
    final res = await getList('/lab/isolates');
    return res.map((e) => Isolate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Isolate> createIsolate(IsolateCreateRequest request) async {
    final res = await post('/lab/isolates', request.toJson());
    return Isolate.fromJson(res);
  }

  /// Supersedes [isolateId] with a corrected result (`PATCH /lab/isolates/{id}`),
  /// e.g. finalizing a worklist entry that was left pending/preliminary.
  Future<Isolate> amendIsolate(String isolateId, IsolateCreateRequest request) async {
    final res = await patch('/lab/isolates/$isolateId', request.toJson());
    return Isolate.fromJson(res);
  }
}
