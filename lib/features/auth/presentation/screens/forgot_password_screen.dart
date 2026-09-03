import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../../../../shared/presentation/widgets/app_logo.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/theme/theme_extensions.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

enum _ResetStep { email, otp, password }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  _ResetStep _step = _ResetStep.email;
  String? _email;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _showError(String raw) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_friendlyError(raw)),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _friendlyError(String raw) {
    final msg = raw.replaceFirst('Exception: ', '').trim();
    final lower = msg.toLowerCase();
    if (lower.contains('please wait')) return msg;
    if (lower.contains('expired')) return 'Code expired. Please request a new one.';
    if (lower.contains('too many incorrect')) return 'Too many incorrect attempts. Please request a new code.';
    if (lower.contains('already been used')) return 'This code has already been used. Please request a new one.';
    if (lower.contains('incorrect code')) {
      final m = RegExp(r'(\d+)\s+attempt').firstMatch(msg);
      if (m != null) return 'Incorrect code. ${m.group(1)} attempt(s) left.';
      return 'Incorrect code. Please check and try again.';
    }
    if (lower.contains('no active code')) return 'No active code found. Please request a new one.';
    if (lower.contains('invalid code')) return 'Invalid code. Please enter the 6-digit code.';
    if (lower.contains('no account found')) return 'No account found for this email.';
    return 'Something went wrong. Please try again.';
  }

  Future<void> _sendCode() async {
    if (_isLoading || _isResending) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final email = _emailCtrl.text.trim().toLowerCase();
      await ref.read(authNotifierProvider.notifier).requestPasswordResetOtp(email);
      setState(() {
        _email = email;
        _step = _ResetStep.otp;
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueWithCode() async {
    if (_isLoading || _isResending) return;
    final code = _otpCtrl.text.trim();
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      _showError('Please enter the 6-digit code from your email.');
      return;
    }
    setState(() => _step = _ResetStep.password);
  }

  Future<void> _resendCode() async {
    if (_isLoading || _isResending) return;
    setState(() => _isResending = true);
    final email = _email ?? _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() {
        _isResending = false;
        _step = _ResetStep.email;
      });
      return;
    }
    try {
      await ref.read(authNotifierProvider.notifier).requestPasswordResetOtp(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new 6-digit code has been sent to your email.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_isLoading || _isResending) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).resetPasswordWithOtp(
        email: _email!,
        code: _otpCtrl.text.trim(),
        newPassword: _passwordCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully. Please sign in.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _passwordCtrl.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>();
    final brass = brandTheme?.brassPrimary ?? theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const AppLogo(size: 72, showGlow: true),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: brass),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Reset Password',
                      style: GoogleFonts.fraunces(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _step == _ResetStep.email
                      ? 'Enter your college email to receive a reset code'
                      : _step == _ResetStep.otp
                          ? 'We sent a 6-digit code to\n$_email'
                          : 'Choose a new password for $_email',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: brandTheme?.textMuted ?? theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: brandTheme?.cardBorder ?? theme.colorScheme.outline,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.4 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_step == _ResetStep.email) ...[
                          _label('COLLEGE EMAIL', brandTheme, theme),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _sendCode(),
                            style: GoogleFonts.inter(color: theme.colorScheme.onSurface, fontSize: 14),
                            validator: AppValidators.email,
                            decoration: const InputDecoration(hintText: 'you@mcehassan.ac.in'),
                          ),
                          const SizedBox(height: 22),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _sendCode,
                            style: _buttonStyle(brass, theme),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text('Send Code', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ],

                        if (_step == _ResetStep.otp) ...[
                          _label('VERIFICATION CODE', brandTheme, theme),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _otpCtrl,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _continueWithCode(),
                            maxLength: 6,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 6,
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: const InputDecoration(counterText: '', hintText: '000000'),
                          ),
                          const SizedBox(height: 22),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _continueWithCode,
                            style: _buttonStyle(brass, theme),
                            child: Text('Continue', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _resendCode,
                            child: Text(
                              "Didn't receive the code? Resend",
                              style: GoogleFonts.inter(fontSize: 13, color: brass, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],

                        if (_step == _ResetStep.password) ...[
                          _label('NEW PASSWORD', brandTheme, theme),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePass,
                            textInputAction: TextInputAction.next,
                            style: GoogleFonts.inter(color: theme.colorScheme.onSurface, fontSize: 14),
                            validator: AppValidators.password,
                            decoration: InputDecoration(
                              hintText: 'Min 8 chars, upper, number, symbol',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: brandTheme?.textMuted ?? Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePass = !_obscurePass),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _label('CONFIRM NEW PASSWORD', brandTheme, theme),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _resetPassword(),
                            style: GoogleFonts.inter(color: theme.colorScheme.onSurface, fontSize: 14),
                            validator: _validateConfirm,
                            decoration: InputDecoration(
                              hintText: 'Re-enter your password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: brandTheme?.textMuted ?? Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            style: _buttonStyle(brass, theme),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text('Reset Password', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => setState(() => _step = _ResetStep.otp),
                            child: Text(
                              '← Back to code entry',
                              style: GoogleFonts.inter(fontSize: 13, color: brass, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Text(
                    '← Back to sign in',
                    style: GoogleFonts.inter(
                      color: brandTheme?.textMuted ?? theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle(Color brass, ThemeData theme) => ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: brass,
        foregroundColor: theme.brightness == Brightness.dark ? const Color(0xFF0A0A0B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      );

  Widget _label(String t, AppBrandTheme? brandTheme, ThemeData theme) => Text(
        t,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: brandTheme?.textMuted ?? theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
}
