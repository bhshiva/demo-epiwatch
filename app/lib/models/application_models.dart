/// Facility onboarding: a hospital/clinic applies for access, admin reviews.
///
/// Mirrors `FacilityApplicationCreate`/`FacilityApplicationOut`/
/// `ApplicationApproveResponse` from the backend contract.
class FacilityApplicationRequest {
  final String facilityName;
  final String facilityType;
  final String district;
  final String state;
  final String contactName;
  final String contactEmail;
  final String? contactPhone;
  final String? licenseNo;
  final String requestedRole;

  const FacilityApplicationRequest({
    required this.facilityName,
    required this.facilityType,
    required this.district,
    required this.state,
    required this.contactName,
    required this.contactEmail,
    this.contactPhone,
    this.licenseNo,
    required this.requestedRole,
  });

  Map<String, dynamic> toJson() => {
        'facility_name': facilityName,
        'facility_type': facilityType,
        'district': district,
        'state': state,
        'contact_name': contactName,
        'contact_email': contactEmail,
        'contact_phone': contactPhone,
        'license_no': licenseNo,
        'requested_role': requestedRole,
      };
}

class FacilityApplication {
  final String applicationId;
  final String facilityName;
  final String facilityType;
  final String district;
  final String state;
  final String contactName;
  final String contactEmail;
  final String? contactPhone;
  final String? licenseNo;
  final String requestedRole;
  final String status;
  final String? reviewedAt;
  final String? rejectionReason;
  final String submittedAt;

  const FacilityApplication({
    required this.applicationId,
    required this.facilityName,
    required this.facilityType,
    required this.district,
    required this.state,
    required this.contactName,
    required this.contactEmail,
    this.contactPhone,
    this.licenseNo,
    required this.requestedRole,
    required this.status,
    this.reviewedAt,
    this.rejectionReason,
    required this.submittedAt,
  });

  factory FacilityApplication.fromJson(Map<String, dynamic> json) => FacilityApplication(
        applicationId: json['application_id'] as String,
        facilityName: json['facility_name'] as String,
        facilityType: json['facility_type'] as String,
        district: json['district'] as String,
        state: json['state'] as String,
        contactName: json['contact_name'] as String,
        contactEmail: json['contact_email'] as String,
        contactPhone: json['contact_phone'] as String?,
        licenseNo: json['license_no'] as String?,
        requestedRole: json['requested_role'] as String,
        status: json['status'] as String,
        reviewedAt: json['reviewed_at'] as String?,
        rejectionReason: json['rejection_reason'] as String?,
        submittedAt: json['submitted_at'] as String,
      );
}

/// The one-time credential shown after approval -- admin relays this to the
/// applicant out-of-band; there's no email/notification path yet.
class ApplicationApproveResult {
  final FacilityApplication application;
  final String facilityId;
  final String doctorId;
  final String email;
  final String temporaryPassword;

  const ApplicationApproveResult({
    required this.application,
    required this.facilityId,
    required this.doctorId,
    required this.email,
    required this.temporaryPassword,
  });

  factory ApplicationApproveResult.fromJson(Map<String, dynamic> json) => ApplicationApproveResult(
        application: FacilityApplication.fromJson(json['application'] as Map<String, dynamic>),
        facilityId: json['facility_id'] as String,
        doctorId: json['doctor_id'] as String,
        email: json['email'] as String,
        temporaryPassword: json['temporary_password'] as String,
      );
}
