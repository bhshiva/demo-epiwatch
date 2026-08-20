/// A request that reached the server and was refused on its merits.
///
/// Distinct from a transport failure: these must never be queued for retry,
/// because retrying an identical payload produces an identical refusal.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// The server matched this submission to an existing patient.
///
/// Carries the candidates so the UI can ask the clinician to confirm rather
/// than silently creating a duplicate record.
class DuplicatePatientException extends ApiException {
  final List<dynamic> candidates;

  const DuplicatePatientException(String message, this.candidates)
      : super(409, message);
}

/// The request never got an answer: offline, DNS failure, timeout.
///
/// Only this class is safe to queue in the outbox.
class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);

  @override
  String toString() => message;
}
