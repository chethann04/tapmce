import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/student_attendance_provider.dart';

class ScanAttendanceScreen extends ConsumerStatefulWidget {
  const ScanAttendanceScreen({super.key});

  @override
  ConsumerState<ScanAttendanceScreen> createState() => _ScanAttendanceScreenState();
}

class _ScanAttendanceScreenState extends ConsumerState<ScanAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _cameraController;
  bool _isTorchOn = false;
  String? _cameraError;
  bool _cameraStopped = false;

  // Animation for success overlay
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
    _cameraController.addListener(_onCameraStateChange);
    _startCamera();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
  }

  Future<void> _startCamera() async {
    if (_cameraStopped) return;
    try {
      await _cameraController.start();
    } on MobileScannerException catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = e.errorDetails?.message ?? 'Camera permission denied or unavailable.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = 'Failed to start camera: $e';
        });
      }
    }
  }

  Future<void> _stopCamera() async {
    try {
      await _cameraController.stop();
    } catch (_) {}
    _cameraStopped = true;
  }

  void _onCameraStateChange() {
    final state = _cameraController.value;
    if (state.error != null && mounted) {
      final errorCode = state.error!.errorCode;
      if (errorCode == MobileScannerErrorCode.permissionDenied) {
        setState(() {
          _cameraError = 'Camera permission is required to scan QR codes. Please grant permission in Settings.';
        });
      } else if (state.error!.errorDetails?.message != null) {
        setState(() {
          _cameraError = state.error!.errorDetails!.message;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController.removeListener(_onCameraStateChange);
    _cameraController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final state = ref.read(scanAttendanceProvider);
    if (state.status == ScanAttendanceStatus.validating) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        HapticFeedback.mediumImpact();
        _stopCamera();
        ref.read(scanAttendanceProvider.notifier).processQrCode(raw);
        return;
      }
    }
  }

  void _showSuccessOverlay() {
    if (!_animController.isAnimating && _animController.value == 0) {
      _animController.forward();
    }
  }

  void _hideSuccessOverlay() {
    _animController.reverse();
  }

  Future<void> _toggleTorch() async {
    await _cameraController.toggleTorch();
    setState(() {
      _isTorchOn = _cameraController.value.torchState == TorchState.on;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final scanState = ref.watch(scanAttendanceProvider);

    // Trigger animation on success
    if (scanState.status == ScanAttendanceStatus.success) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSuccessOverlay());
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/student');
        }
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera view
          if (_cameraError != null)
            _buildCameraError(brandTheme)
          else
            Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: MobileScanner(
                    controller: _cameraController,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              error.errorDetails?.message ?? 'Camera error',
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _startCamera,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: brandTheme.brassPrimary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Retry', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          // Scan overlay
          _buildScanOverlay(brandTheme, scanState),

          // Top bar
          _buildTopBar(brandTheme, scanState),

          // Loading panel
          if (scanState.status == ScanAttendanceStatus.validating)
            _buildLoadingPanel(brandTheme),

          // Error panel
          if (scanState.status == ScanAttendanceStatus.error)
            _buildErrorPanel(brandTheme, scanState),

          // Success overlay — dimmed background + animated card
          if (scanState.status == ScanAttendanceStatus.success)
            _buildSuccessOverlay(brandTheme, scanState),
        ],
      ),
    ));
  }

  // ---------------------------------------------------------------------------
  // Camera Error
  // ---------------------------------------------------------------------------
  Widget _buildCameraError(AppBrandTheme brandTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 56),
            const SizedBox(height: 16),
            Text(
              _cameraError!,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                setState(() => _cameraError = null);
                _startCamera();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: brandTheme.brassPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Grant Permission & Retry',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Scan Overlay (frame + corners)
  // ---------------------------------------------------------------------------
  Widget _buildScanOverlay(AppBrandTheme brandTheme, ScanAttendanceState state) {
    final isProcessing = state.status == ScanAttendanceStatus.validating;
    return Center(
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isProcessing
                      ? brandTheme.brassSoft.withValues(alpha: 0.5)
                      : brandTheme.brassPrimary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            if (!isProcessing) ...[
              Positioned(top: -1, left: -1, child: _cornerAccent(brandTheme, topLeft: true)),
              Positioned(top: -1, right: -1, child: _cornerAccent(brandTheme, topRight: true)),
              Positioned(bottom: -1, left: -1, child: _cornerAccent(brandTheme, bottomLeft: true)),
              Positioned(bottom: -1, right: -1, child: _cornerAccent(brandTheme, bottomRight: true)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cornerAccent(
    AppBrandTheme brandTheme, {
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border(
          top: topLeft || topRight ? BorderSide(color: brandTheme.brassPrimary, width: 4) : BorderSide.none,
          bottom: bottomLeft || bottomRight ? BorderSide(color: brandTheme.brassPrimary, width: 4) : BorderSide.none,
          left: topLeft || bottomLeft ? BorderSide(color: brandTheme.brassPrimary, width: 4) : BorderSide.none,
          right: topRight || bottomRight ? BorderSide(color: brandTheme.brassPrimary, width: 4) : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: topLeft ? const Radius.circular(8) : Radius.zero,
          topRight: topRight ? const Radius.circular(8) : Radius.zero,
          bottomLeft: bottomLeft ? const Radius.circular(8) : Radius.zero,
          bottomRight: bottomRight ? const Radius.circular(8) : Radius.zero,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Bar
  // ---------------------------------------------------------------------------
  Widget _buildTopBar(AppBrandTheme brandTheme, ScanAttendanceState state) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sp4, vertical: AppSpacing.sp2),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Scan Attendance',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _toggleTorch,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isTorchOn
                        ? brandTheme.brassPrimary.withValues(alpha: 0.9)
                        : Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loading Panel
  // ---------------------------------------------------------------------------
  Widget _buildLoadingPanel(AppBrandTheme brandTheme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sp6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: brandTheme.brassPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sp4),
              Text(
                'Verifying attendance...',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sp2),
              Text(
                'Please wait while we record your attendance',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Success Overlay — dimmed background + animated card
  // ---------------------------------------------------------------------------
  Widget _buildSuccessOverlay(AppBrandTheme brandTheme, ScanAttendanceState state) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnim.value,
            child: Stack(
              children: [
                // Dimmed + blurred background
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(color: Colors.black.withValues(alpha: 0.6)),
                  ),
                ),
                // Centered card
                Center(
                  child: Transform.scale(
                    scale: _scaleAnim.value,
                    child: AttendanceSuccessCard(
                      brandTheme: brandTheme,
                      record: state.attendanceRecord,
                      onDone: () {
                        _hideSuccessOverlay();
                        ref.read(scanAttendanceProvider.notifier).reset();
                        Navigator.of(context).pop();
                      },
                      onScanAnother: () {
                        _hideSuccessOverlay();
                        ref.read(scanAttendanceProvider.notifier).reset();
                        setState(() => _cameraStopped = false);
                        _startCamera();
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error Panel
  // ---------------------------------------------------------------------------
  Widget _buildErrorPanel(AppBrandTheme brandTheme, ScanAttendanceState state) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sp6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.98),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: brandTheme.statusRejected.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline_rounded, size: 36, color: brandTheme.statusRejected),
              ),
              const SizedBox(height: AppSpacing.sp4),
              Text(
                state.errorTitle ?? 'Error',
                style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sp2),
              Text(
                state.errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: AppSpacing.sp5),
              GestureDetector(
                onTap: () {
                  ref.read(scanAttendanceProvider.notifier).resetToScanning();
                  setState(() => _cameraStopped = false);
                  _startCamera();
                },
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: brandTheme.brassGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text('Try Again',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: brandTheme.onBrass)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sp3),
              GestureDetector(
                onTap: () {
                  ref.read(scanAttendanceProvider.notifier).reset();
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Center(
                    child: Text('Go Back',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Extracted Widgets
// =============================================================================

/// Full success card shown as a centered modal after a successful scan.
class AttendanceSuccessCard extends StatelessWidget {
  final AppBrandTheme brandTheme;
  final Map<String, dynamic>? record;
  final VoidCallback onDone;
  final VoidCallback onScanAnother;

  const AttendanceSuccessCard({
    super.key,
    required this.brandTheme,
    required this.record,
    required this.onDone,
    required this.onScanAnother,
  });

  @override
  Widget build(BuildContext context) {
    final scannedAtRaw = record?['scanned_at'] as String?;
    final scanTime = scannedAtRaw != null ? (DateTime.tryParse(scannedAtRaw)?.toLocal() ?? DateTime.now()) : DateTime.now();

    final day = scanTime.day.toString().padLeft(2, '0');
    final month = scanTime.month.toString().padLeft(2, '0');
    final dateStr = '$day/$month/${scanTime.year}';

    final hour12 = scanTime.hour == 0 ? 12 : (scanTime.hour > 12 ? scanTime.hour - 12 : scanTime.hour);
    final minuteStr = scanTime.minute.toString().padLeft(2, '0');
    final amPm = scanTime.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '${hour12.toString().padLeft(2, '0')}:$minuteStr $amPm';

    final attendanceId = record?['id'] as String? ?? '';
    final shortId = attendanceId.length > 8 ? attendanceId.substring(0, 8) : attendanceId;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: brandTheme.brassPrimary.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: brandTheme.brassPrimary.withValues(alpha: 0.15),
                blurRadius: 40,
                spreadRadius: -4,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: brandTheme.statusShortlisted.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_rounded, size: 36, color: brandTheme.statusShortlisted),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Attendance Marked',
                  style: GoogleFonts.fraunces(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Your attendance has been recorded.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
                  textAlign: TextAlign.center,
                ),

                // Attendance ID badge
                if (attendanceId.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AttendanceStatusChip(
                    label: 'ATT-$shortId',
                    icon: Icons.tag_rounded,
                    color: brandTheme.brassPrimary,
                  ),
                ],

                // Sync status
                const SizedBox(height: 10),
                AttendanceStatusChip(
                  label: 'Synced with Server',
                  icon: Icons.cloud_done_rounded,
                  color: brandTheme.statusShortlisted,
                ),

                const SizedBox(height: 20),

                // Info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      // Student section
                      _sectionHeader('Student', brandTheme),
                      const SizedBox(height: 8),
                      AttendanceInfoTile(
                        label: 'Name',
                        value: (record?['student_name'] as String?)?.isNotEmpty == true
                            ? record!['student_name'] as String
                            : '—',
                      ),
                      const SizedBox(height: 8),
                      _twoColumnRow(
                        left: AttendanceInfoTile(
                          label: 'USN',
                          value: (record?['usn'] as String?)?.isNotEmpty == true
                              ? record!['usn'] as String
                              : '—',
                        ),
                        right: AttendanceInfoTile(
                          label: 'Department',
                          value: (record?['department'] as String?)?.isNotEmpty == true
                              ? record!['department'] as String
                              : '—',
                        ),
                      ),

                      const SizedBox(height: 16),
                      Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                      const SizedBox(height: 16),

                      // Drive section
                      _sectionHeader('Drive Details', brandTheme),
                      const SizedBox(height: 8),
                      _twoColumnRow(
                        left: AttendanceInfoTile(
                          label: 'Company',
                          value: record?['company_name'] ?? '—',
                        ),
                        right: AttendanceInfoTile(
                          label: 'Role',
                          value: record?['drive_role'] ?? '—',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _twoColumnRow(
                        left: AttendanceInfoTile(label: 'Date', value: dateStr),
                        right: AttendanceInfoTile(label: 'Time', value: timeStr),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Download Slip (PDF) button
                GestureDetector(
                  onTap: () async {
                    final pdf = pw.Document();
                    final studentName = record?['student_name'] as String? ?? 'Student';
                    final usn = record?['usn'] as String? ?? '—';
                    final dept = record?['department'] as String? ?? '—';
                    final company = record?['company_name'] as String? ?? 'Placement Drive';
                    final role = record?['drive_role'] as String? ?? '—';

                    pdf.addPage(
                      pw.Page(
                        pageFormat: PdfPageFormat.a4,
                        build: (pw.Context context) {
                          return pw.Center(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(24),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.black, width: 2),
                                borderRadius: pw.BorderRadius.circular(8),
                              ),
                              child: pw.Column(
                                mainAxisSize: pw.MainAxisSize.min,
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Center(
                                    child: pw.Text(
                                      'MALNAD COLLEGE OF ENGINEERING, HASSAN',
                                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                                    ),
                                  ),
                                  pw.SizedBox(height: 4),
                                  pw.Center(
                                    child: pw.Text(
                                      'Training & Placement Office - Attendance Check-In Slip',
                                      style: const pw.TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  pw.SizedBox(height: 16),
                                  pw.Divider(),
                                  pw.SizedBox(height: 12),
                                  pw.Text('STUDENT DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                                  pw.SizedBox(height: 6),
                                  pw.Text('Name: $studentName', style: const pw.TextStyle(fontSize: 10)),
                                  pw.Text('USN: $usn', style: const pw.TextStyle(fontSize: 10)),
                                  pw.Text('Department: $dept', style: const pw.TextStyle(fontSize: 10)),
                                  pw.SizedBox(height: 12),
                                  pw.Text('DRIVE CHECK-IN DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                                  pw.SizedBox(height: 6),
                                  pw.Text('Company: $company', style: const pw.TextStyle(fontSize: 10)),
                                  pw.Text('Role: $role', style: const pw.TextStyle(fontSize: 10)),
                                  pw.Text('Date & Time: $dateStr - $timeStr', style: const pw.TextStyle(fontSize: 10)),
                                  pw.Text('Verification Status: CONFIRMED (VERIFIED)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                  pw.SizedBox(height: 16),
                                  pw.Divider(),
                                  pw.SizedBox(height: 8),
                                  pw.Center(
                                    child: pw.Text(
                                      'This is an officially verified electronic attendance receipt generated by MCE Placement Connect.',
                                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );

                    await Printing.layoutPdf(
                      onLayout: (format) async => pdf.save(),
                      name: 'Attendance_Slip_${usn}_$company.pdf',
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: (brandTheme.brassPrimary).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: brandTheme.brassPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.picture_as_pdf_rounded, size: 20, color: brandTheme.brassPrimary),
                        const SizedBox(width: 8),
                        Text(
                          'Download Check-In Slip (PDF)',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: brandTheme.brassPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Done button
                GestureDetector(
                  onTap: onDone,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: brandTheme.brassGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        'Done',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: brandTheme.onBrass,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Scan Another QR button
                GestureDetector(
                  onTap: onScanAnother,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Center(
                      child: Text(
                        'Scan Another QR',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, AppBrandTheme brandTheme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: brandTheme.brassPrimary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _twoColumnRow({required Widget left, required Widget right}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

/// A single info tile with a grey label and bold white value.
/// Uses Flexible wrapping to handle any text length without overflow.
class AttendanceInfoTile extends StatelessWidget {
  final String label;
  final String value;

  const AttendanceInfoTile({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// A small status chip with an icon and label.
class AttendanceStatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const AttendanceStatusChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

