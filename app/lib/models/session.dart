/// The authenticated user, mirroring the server's LoginResponse.
///
/// `role` drives which workspace the app builds. It is read from the server
/// response and never inferred client-side: the server is authoritative and
/// enforces the same boundary again on every request.
class Session {
  final String accessToken;
  final String role;
  final String doctorId;
  final String name;
  // Null for health_authority/admin accounts, which aren't tied to one
  // facility (health authority sees every facility; admin approves
  // accounts before any facility-scoped work exists for them).
  final String? facilityId;
  final bool mustChangePassword;

  const Session({
    required this.accessToken,
    required this.role,
    required this.doctorId,
    required this.name,
    required this.facilityId,
    this.mustChangePassword = false,
  });

  bool get isLab => role == 'lab';
  bool get isHealthAuthority => role == 'health_authority';
  bool get isAdmin => role == 'admin';

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        accessToken: json['access_token'] as String,
        role: json['role'] as String? ?? 'doctor',
        doctorId: json['doctor_id'] as String,
        name: json['name'] as String,
        facilityId: json['facility_id'] as String?,
        mustChangePassword: json['must_change_password'] as bool? ?? false,
      );
}
