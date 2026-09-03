import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for global access to EmailNotificationService
final emailNotificationServiceProvider = Provider<EmailNotificationService>((ref) {
  return EmailNotificationService(Supabase.instance.client);
});

/// Production-Ready Email Notification System Service
/// Directly handles non-blocking dispatches via Gmail SMTP with auto-retry, logging, and HTML templates.
class EmailNotificationService {
  final SupabaseClient _supabase;

  // Environment / Configuration getters
  String get _smtpHost => const String.fromEnvironment('SMTP_HOST', defaultValue: 'smtp.gmail.com');
  int get _smtpPort => int.parse(const String.fromEnvironment('SMTP_PORT', defaultValue: '465'));
  String get _smtpEmail => const String.fromEnvironment('SMTP_EMAIL', defaultValue: '');
  String get _smtpPassword => const String.fromEnvironment('SMTP_PASSWORD', defaultValue: '');

  static const String _collegeName = "MCE Placement Connect";
  static const String _brandGold = "#D4AF37";

  EmailNotificationService(this._supabase);

  /// Standardized dispatch method with non-blocking async execution, retry mechanism, and logging.
  Future<void> sendEmail({
    required String recipientEmail,
    required String subject,
    required String emailType,
    required String htmlBody,
    Map<String, dynamic>? metadata,
    int maxRetries = 3,
  }) async {
    if (recipientEmail.isEmpty || !recipientEmail.contains('@')) return;

    final currentUserId = _supabase.auth.currentUser?.id;

    // Fire-and-forget non-blocking execution
    unawaited(Future.microtask(() async {
      int attempt = 0;
      bool sent = false;
      String? lastError;
      String? lastSmtpResponse;
      bool usedEdgeFunction = false;
      final stopwatch = Stopwatch()..start();

      while (attempt < maxRetries && !sent) {
        attempt++;
        try {
          if (_smtpEmail.isNotEmpty && _smtpPassword.isNotEmpty) {
            // Send using direct Gmail SMTP (sender = SMTP_EMAIL dart-define).
            // In production this path is disabled — email is sent server-side
            // by the send-email Edge Function using Supabase Secrets.
            final smtpServer = _smtpPort == 465
                ? gmail(_smtpEmail, _smtpPassword)
                : SmtpServer(
                    _smtpHost,
                    port: _smtpPort,
                    ssl: _smtpPort == 465,
                    username: _smtpEmail,
                    password: _smtpPassword,
                  );

            final message = Message()
              ..from = Address(_smtpEmail, _collegeName)
              ..recipients.add(recipientEmail)
              ..subject = subject
              ..text = _htmlToText(htmlBody)
              ..html = htmlBody;

            final report = await send(message, smtpServer);
            lastSmtpResponse = 'SMTP $_smtpHost:$_smtpPort ok — ${report.toString().trim()}';
            sent = true;
          } else {
            // Fallback: Invoke the deployed send-email Edge Function using Supabase Secrets
            usedEdgeFunction = true;
            dev.log(
              '[EmailNotificationService] Client SMTP variables empty. Invoking Edge Function fallback...',
              name: 'EmailNotificationService',
            );
            final res = await _supabase.functions.invoke(
              'send-email',
              body: {
                'emailType': emailType,
                'recipient': recipientEmail,
                'subject': subject,
                'data': metadata ?? {},
                'createdBy': currentUserId,
              },
            );

            if (res.status >= 400) {
              throw Exception('Edge function send-email returned error status ${res.status}: ${res.data}');
            }

            final resData = res.data is Map ? res.data as Map : {};
            if (resData['success'] != true) {
              throw Exception('Edge function send-email failed: ${resData['error']}');
            }
            lastSmtpResponse = '${resData['smtpResponse'] ?? ''}'.trim();
            sent = true;
          }
        } catch (e) {
          lastError = e.toString();
          dev.log(
            '[EmailNotificationService] Attempt $attempt/$maxRetries failed for $recipientEmail: $e',
            name: 'EmailNotificationService',
          );
          if (attempt < maxRetries) {
            // Backoff retry schedule: 1s, 5s, 15s
            final backoffMs = attempt == 1 ? 1000 : (attempt == 2 ? 5000 : 15000);
            await Future.delayed(Duration(milliseconds: backoffMs));
          }
        }
      }

      stopwatch.stop();

      // Audit Logging into email_logs table. When the Edge Function path was
      // used the server already wrote the enriched log (sender, smtp_response,
      // message_id), so skip the duplicate client-side insert.
      if (!usedEdgeFunction) {
        try {
          await _supabase.from('email_logs').insert({
            'sender': _smtpEmail.isNotEmpty ? _smtpEmail : 'students.tap@mcehassan.ac.in',
            'recipient': recipientEmail,
            'subject': subject,
            'email_type': emailType,
            'status': sent ? 'sent' : 'failed',
            'error_message': sent ? null : lastError,
            'smtp_response': sent ? lastSmtpResponse : null,
            'sent_at': sent ? DateTime.now().toIso8601String() : null,
            'created_by': currentUserId,
          });
        } catch (logErr) {
          dev.log('[EmailNotificationService] Error writing to email_logs: $logErr', name: 'EmailNotificationService');
        }
      }
    }));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HTML Template Wrapper
  // ───────────────────────────────────────────────────────────────────────────
  String _htmlToText(String html) {
    return html
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|h1|h2|h3|h4|li|tr)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</td>', caseSensitive: false), '\t')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&copy;', '©')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _wrapTemplate(String title, String bodyContent) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>
  <style>
    body { margin: 0; padding: 0; background-color: #0F0F0F; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; color: #E0E0E0; }
    .container { max-width: 600px; margin: 20px auto; background: #1A1A1A; border: 1px solid #333333; border-radius: 12px; overflow: hidden; box-shadow: 0 8px 24px rgba(0,0,0,0.5); }
    .header { background: linear-gradient(135deg, #1A1A1A 0%, #2A2A2A 100%); padding: 30px 20px; text-align: center; border-bottom: 2px solid $_brandGold; }
    .header h1 { margin: 0; color: $_brandGold; font-size: 24px; font-weight: 700; letter-spacing: 1px; }
    .header p { margin: 5px 0 0 0; color: #A0A0A0; font-size: 13px; text-transform: uppercase; letter-spacing: 1.5px; }
    .content { padding: 30px 25px; line-height: 1.6; font-size: 15px; }
    .content h2 { color: #FFFFFF; font-size: 18px; margin-top: 0; margin-bottom: 15px; border-bottom: 1px solid #333; padding-bottom: 8px; }
    .info-table { width: 100%; border-collapse: collapse; margin: 20px 0; background: #222222; border-radius: 8px; overflow: hidden; }
    .info-table td { padding: 12px 16px; border-bottom: 1px solid #2C2C2C; font-size: 14px; }
    .info-table td.label { color: $_brandGold; font-weight: 600; width: 40%; }
    .info-table td.value { color: #FFFFFF; }
    .highlight-box { background: rgba(212, 175, 55, 0.1); border-left: 4px solid $_brandGold; padding: 15px; border-radius: 4px; margin: 20px 0; color: #F0F0F0; }
    .badge { display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: bold; text-transform: uppercase; }
    .badge-success { background: #1B4D3E; color: #4EAE87; }
    .badge-danger { background: #4D1B1B; color: #E57373; }
    .footer { background: #121212; padding: 20px; text-align: center; font-size: 12px; color: #777777; border-top: 1px solid #262626; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>PLACEMENT CONNECT</h1>
      <p>$_collegeName</p>
    </div>
    <div class="content">
      $bodyContent
    </div>
    <div class="footer">
      <p>This is an automated placement notification. Please do not reply directly to this email.</p>
      <p>&copy; ${DateTime.now().year} $_collegeName. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
''';
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Authentication & Security Emails
  // ───────────────────────────────────────────────────────────────────────────
  void sendLoginAlertEmail({required String recipientEmail, required String userName}) {
    sendEmail(
      recipientEmail: recipientEmail,
      subject: 'New Login Security Notice',
      emailType: 'login_alert',
      metadata: {
        'userName': userName,
        'email': recipientEmail,
        'time': DateTime.now().toIso8601String(),
      },
      htmlBody: _wrapTemplate(
        'Login Security Alert',
        '''
        <h2>New Login Detected</h2>
        <p>Hello <strong>$userName</strong>,</p>
        <p>A new login to your Placement Connect account was registered.</p>
        <table class="info-table">
          <tr><td class="label">Account Email</td><td class="value">$recipientEmail</td></tr>
          <tr><td class="label">Login Time</td><td class="value">${DateTime.now().toString().split('.')[0]}</td></tr>
          <tr><td class="label">Status</td><td class="value"><span class="badge badge-success">Successful Login</span></td></tr>
        </table>
        <p>If this was you, no further action is required.</p>
        ''',
      ),
    );
  }

  void sendOtpEmail({required String recipientEmail, required String otp}) {
    sendEmail(
      recipientEmail: recipientEmail,
      subject: 'Your Placement Connect Verification Code: $otp',
      emailType: 'otp',
      metadata: {'otp': otp},
      htmlBody: _wrapTemplate(
        'Verification Code',
        '''
        <h2>Account Verification Code</h2>
        <p>Use the 6-digit verification code below to confirm your account on <strong>Placement Connect</strong>.</p>
        <div class="highlight-box" style="text-align: center; font-size: 28px; font-weight: bold; letter-spacing: 6px; color: $_brandGold; margin: 30px 0;">
          $otp
        </div>
        <p>This code will expire shortly. If you did not request this registration, please ignore this email.</p>
        ''',
      ),
    );
  }

  void sendProfileApprovedEmail({
    required String recipientEmail,
    required String studentName,
    required String usn,
    required String verifiedCourse,
  }) {
    sendEmail(
      recipientEmail: recipientEmail,
      subject: 'Placement Connect — Student Profile Approved',
      emailType: 'profile_approved',
      metadata: {
        'studentName': studentName,
        'usn': usn,
        'verifiedCourse': verifiedCourse,
      },
      htmlBody: _wrapTemplate(
        'Profile Verification Approved',
        '''
        <h2>Student Profile Approved</h2>
        <p>Dear <strong>$studentName</strong>,</p>
        <p>Your student profile has been successfully verified and approved by the Placement Cell/Faculty Coordinator.</p>
        <p>Your Placement Connect profile is now verified and you can access placement opportunities according to your eligibility.</p>
        <table class="info-table">
          <tr><td class="label">USN</td><td class="value">$usn</td></tr>
          <tr><td class="label">Course</td><td class="value">$verifiedCourse</td></tr>
          <tr><td class="label">Status</td><td class="value"><span class="badge badge-success">APPROVED</span></td></tr>
        </table>
        <p>You can now log in to Placement Connect.</p>
        <p>Regards,<br><strong>Training & Placement Cell</strong><br>Malnad College of Engineering</p>
        ''',
      ),
    );
  }

  void sendProfileRejectedEmail({
    required String recipientEmail,
    required String studentName,
    required String reason,
  }) {
    sendEmail(
      recipientEmail: recipientEmail,
      subject: 'Placement Connect — Profile Verification Required',
      emailType: 'profile_rejected',
      metadata: {
        'studentName': studentName,
        'reason': reason,
      },
      htmlBody: _wrapTemplate(
        'Profile Verification Required',
        '''
        <h2>Profile Verification Action Required</h2>
        <p>Dear <strong>$studentName</strong>,</p>
        <p>Your Placement Connect student profile could not be approved at this stage.</p>
        <table class="info-table">
          <tr><td class="label">Reason</td><td class="value"><strong style="color:#E57373;">$reason</strong></td></tr>
          <tr><td class="label">Status</td><td class="value"><span class="badge badge-danger">REJECTED / ACTION REQUIRED</span></td></tr>
        </table>
        <p><strong>You are required to meet your Faculty Coordinator for verification and correction of your student details.</strong></p>
        <p>Please contact/meet your Faculty Coordinator and get the required details corrected.</p>
        <p>After the necessary corrections are completed, your profile will be reviewed again for approval.</p>
        <p>Regards,<br><strong>Training & Placement Cell</strong><br>Malnad College of Engineering</p>
        ''',
      ),
    );
  }

  void sendWelcomeEmail({required String recipientEmail, required String studentName, required String role, required String department}) {
    sendEmail(
      recipientEmail: recipientEmail,
      subject: 'Welcome to Placement Connect — $studentName',
      emailType: 'welcome',
      metadata: {
        'studentName': studentName,
        'role': role,
        'department': department,
      },
      htmlBody: _wrapTemplate(
        'Welcome to Placement Connect',
        '''
        <h2>Welcome aboard, $studentName!</h2>
        <p>Your registration and profile verification for <strong>Placement Connect</strong> at <strong>$_collegeName</strong> has been completed successfully.</p>
        <table class="info-table">
          <tr><td class="label">Student Name</td><td class="value">$studentName</td></tr>
          <tr><td class="label">Role</td><td class="value">$role</td></tr>
          <tr><td class="label">Department</td><td class="value">$department</td></tr>
          <tr><td class="label">Institution</td><td class="value">$_collegeName</td></tr>
        </table>
        <p>You can now log in to access active placement drives, monitor your application status, and track drive attendance seamlessly.</p>
        ''',
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Student Event Notifications
  // ───────────────────────────────────────────────────────────────────────────
  void sendApplicationSubmittedEmail({required String recipientEmail, required String studentName, required String companyName, required String roleTitle}) {
    sendEmail(
      recipientEmail: recipientEmail,
      subject: 'Application Confirmed: $companyName',
      emailType: 'application_submitted',
      metadata: {
        'studentName': studentName,
        'companyName': companyName,
        'roleTitle': roleTitle,
      },
      htmlBody: _wrapTemplate(
        'Application Confirmation',
        '''
        <h2>Application Submitted Successfully</h2>
        <p>Dear <strong>$studentName</strong>,</p>
        <p>Your application for the following campus recruitment drive has been successfully registered.</p>
        <table class="info-table">
          <tr><td class="label">Company</td><td class="value"><strong>$companyName</strong></td></tr>
          <tr><td class="label">Role</td><td class="value">$roleTitle</td></tr>
          <tr><td class="label">Application Date</td><td class="value">${DateTime.now().toString().split(' ')[0]}</td></tr>
          <tr><td class="label">Status</td><td class="value"><span class="badge badge-success">Applied</span></td></tr>
        </table>
        ''',
      ),
    );
  }

  void sendAttendanceConfirmationEmail({required String recipientEmail, required String companyName, required String date, required String time}) {
    sendEmail(
      recipientEmail: recipientEmail,
      subject: 'Attendance Confirmed: $companyName Drive',
      emailType: 'attendance_marked',
      metadata: {
        'companyName': companyName,
        'date': date,
        'time': time,
      },
      htmlBody: _wrapTemplate(
        'Attendance Confirmation',
        '''
        <h2>QR Attendance Recorded</h2>
        <p>Your attendance for the recruitment drive has been verified via QR scan.</p>
        <table class="info-table">
          <tr><td class="label">Company</td><td class="value"><strong>$companyName</strong></td></tr>
          <tr><td class="label">Date</td><td class="value">$date</td></tr>
          <tr><td class="label">Time</td><td class="value">$time</td></tr>
          <tr><td class="label">Status</td><td class="value"><span class="badge badge-success">Present</span></td></tr>
        </table>
        ''',
      ),
    );
  }

  void sendRoundQualifiedEmail({required String recipientEmail, required String studentName, required String companyName, required String qualifiedRound, required String nextRoundName}) {
    sendEmail(
      recipientEmail: recipientEmail,
      subject: 'Congratulations! Qualified for $nextRoundName — $companyName',
      emailType: 'round_qualified',
      metadata: {
        'studentName': studentName,
        'companyName': companyName,
        'qualifiedRound': qualifiedRound,
        'nextRoundName': nextRoundName,
      },
      htmlBody: _wrapTemplate(
        'Round Advancement Notice',
        '''
        <h2>Congratulations! You Have Shortlisted</h2>
        <p>Dear <strong>$studentName</strong>,</p>
        <p>We are pleased to inform you that you have cleared the selection criteria for <strong>$companyName</strong>.</p>
        <table class="info-table">
          <tr><td class="label">Company</td><td class="value"><strong>$companyName</strong></td></tr>
          <tr><td class="label">Cleared Round</td><td class="value">$qualifiedRound</td></tr>
          <tr><td class="label">Upcoming Round</td><td class="value"><strong>$nextRoundName</strong></td></tr>
        </table>
        ''',
      ),
    );
  }

  void sendRoundRejectedEmail({required String recipientEmail, required String studentName, required String companyName, required String rejectedRound, String? remarks}) {
    sendEmail(
      recipientEmail: recipientEmail,
      subject: 'Drive Status Update: $companyName',
      emailType: 'round_rejected',
      metadata: {
        'studentName': studentName,
        'companyName': companyName,
        'rejectedRound': rejectedRound,
        if (remarks != null) 'remarks': remarks,
      },
      htmlBody: _wrapTemplate(
        'Drive Update',
        '''
        <h2>Selection Process Update</h2>
        <p>Dear <strong>$studentName</strong>,</p>
        <p>Thank you for participating in the campus recruitment drive for <strong>$companyName</strong>.</p>
        <table class="info-table">
          <tr><td class="label">Company</td><td class="value">$companyName</td></tr>
          <tr><td class="label">Round Evaluated</td><td class="value">$rejectedRound</td></tr>
          <tr><td class="label">Status</td><td class="value"><span class="badge badge-danger">Not Shortlisted</span></td></tr>
        </table>
        ${remarks != null ? '<p><strong>Feedback/Remarks:</strong> $remarks</p>' : ''}
        ''',
      ),
    );
  }

  void sendOfferReleasedEmail({required String recipientEmail, required String studentName, required String companyName, required String roleTitle, required String package}) {
    sendEmail(
      recipientEmail: recipientEmail,
      subject: 'JOB OFFER: Selection Confirmed at $companyName!',
      emailType: 'offer_released',
      metadata: {
        'studentName': studentName,
        'companyName': companyName,
        'roleTitle': roleTitle,
        'package': package,
      },
      htmlBody: _wrapTemplate(
        'Job Offer Released',
        '''
        <h2>Congratulations on Your Job Offer! 🎉</h2>
        <p>Dear <strong>$studentName</strong>,</p>
        <p>The Training & Placement Office is proud to announce that you have been selected for a job offer with <strong>$companyName</strong>!</p>
        <table class="info-table">
          <tr><td class="label">Company</td><td class="value"><strong>$companyName</strong></td></tr>
          <tr><td class="label">Role Title</td><td class="value">$roleTitle</td></tr>
          <tr><td class="label">Offered Package</td><td class="value"><strong>$package</strong></td></tr>
        </table>
        ''',
      ),
    );
  }

  void sendFacultyAppointmentEmail({required String recipientEmail, required String facultyName, required String department, String? appointmentDate}) {
    sendEmail(
      recipientEmail: recipientEmail,
      subject: 'Appointment as Faculty Coordinator — $department',
      emailType: 'faculty_appointment',
      metadata: {
        'facultyName': facultyName,
        'department': department,
        if (appointmentDate != null) 'appointmentDate': appointmentDate,
      },
      htmlBody: _wrapTemplate(
        'Faculty Coordinator Appointment',
        '''
        <h2>Faculty Coordinator Appointment Notice</h2>
        <p>Dear <strong>$facultyName</strong>,</p>
        <p>You have been officially appointed as the <strong>Faculty Coordinator</strong> for the Department of <strong>$department</strong>.</p>
        <table class="info-table">
          <tr><td class="label">Faculty Name</td><td class="value">$facultyName</td></tr>
          <tr><td class="label">Department</td><td class="value">$department</td></tr>
          <tr><td class="label">Appointment Date</td><td class="value">${appointmentDate ?? DateTime.now().toString().split(' ')[0]}</td></tr>
        </table>
        ''',
      ),
    );
  }

  void sendDrivePublishedEmail({
    required String recipientEmail,
    required String studentName,
    required String companyName,
    required String roleTitle,
    required String package,
    required String registrationDeadline,
    String? driveDate,
  }) {
    sendEmail(
      recipientEmail: recipientEmail,
      subject: 'New Placement Drive Announced: $companyName ($roleTitle)',
      emailType: 'drive_published',
      metadata: {
        'studentName': studentName,
        'companyName': companyName,
        'roleTitle': roleTitle,
        'package': package,
        'registrationDeadline': registrationDeadline,
        if (driveDate != null) 'driveDate': driveDate,
      },
      htmlBody: _wrapTemplate(
        'New Placement Drive',
        '''
        <h2>New Placement Drive Announced</h2>
        <p>Dear <strong>$studentName</strong>,</p>
        <p>A new placement recruitment drive matching your department/branch eligibility has been published.</p>
        <table class="info-table">
          <tr><td class="label">Company Name</td><td class="value"><strong>$companyName</strong></td></tr>
          <tr><td class="label">Role Title</td><td class="value">$roleTitle</td></tr>
          <tr><td class="label">Package (CTC)</td><td class="value">$package</td></tr>
          <tr><td class="label">Registration Deadline</td><td class="value">$registrationDeadline</td></tr>
        </table>
        <div class="highlight-box">
          Please log into MCE Placement Connect before the registration deadline to review full job requirements and submit your application.
        </div>
        ''',
      ),
    );
  }

  void sendDriveCancelledEmail({required String recipientEmail, required String companyName, required String reason}) {
    sendEmail(
      recipientEmail: recipientEmail,
      subject: 'URGENT: Placement Drive Update — $companyName',
      emailType: 'drive_cancelled',
      metadata: {
        'companyName': companyName,
        'reason': reason,
      },
      htmlBody: _wrapTemplate(
        'Placement Drive Update',
        '''
        <h2>Placement Drive Cancelled/Rescheduled</h2>
        <p>Please note an important update regarding the recruitment drive for <strong>$companyName</strong>.</p>
        <p><strong>Reason:</strong> $reason</p>
        ''',
      ),
    );
  }

  void sendReminderEmail({required String recipientEmail, required String studentName, required String reminderTitle, required String message, String? deadline}) {
    sendEmail(
      recipientEmail: recipientEmail,
      subject: 'Placement Action Required: $reminderTitle',
      emailType: 'reminder',
      metadata: {
        'studentName': studentName,
        'reminderTitle': reminderTitle,
        'message': message,
        if (deadline != null) 'deadline': deadline,
      },
      htmlBody: _wrapTemplate(
        'Action Required',
        '''
        <h2>$reminderTitle</h2>
        <p>Dear <strong>$studentName</strong>,</p>
        <p>$message</p>
        ${deadline != null ? '<p><strong>Deadline:</strong> $deadline</p>' : ''}
        ''',
      ),
    );
  }

  void sendGeneralNotification({required String recipientEmail, required String subject, required String message}) {
    sendEmail(
      recipientEmail: recipientEmail,
      subject: subject,
      emailType: 'general',
      metadata: {
        'message': message,
      },
      htmlBody: _wrapTemplate('Notice', '<p>$message</p>'),
    );
  }
}
