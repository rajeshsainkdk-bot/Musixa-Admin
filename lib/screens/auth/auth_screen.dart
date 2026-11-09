import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/cloud_backend_service.dart';
import '../../services/language_service.dart';
import '../../providers/player_provider.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({Key? key, required this.onAuthenticated}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _backend = CloudBackendService();
  final _lang = LanguageService();

  // Mode: true for Login, false for Register
  bool _isLoginMode = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  // Controllers for Login
  final _loginPhoneCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();

  // Controllers for Register
  final _regNameCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _lang.addListener(_onLangUpdate);
  }

  void _onLangUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _lang.removeListener(_onLangUpdate);
    _loginPhoneCtrl.dispose();
    _loginPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    super.dispose();
  }

  // ----------------------------------------------------
  // LOGIN FLOW (User ID = Phone Number + Password)
  // ----------------------------------------------------
  Future<void> _handleLogin() async {
    final phone = _loginPhoneCtrl.text.trim();
    final pass = _loginPassCtrl.text.trim();

    // 1. Phone validation
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = digitsOnly.length >= 10 ? digitsOnly.substring(digitsOnly.length - 10) : digitsOnly;
    if (last10.length != 10) {
      setState(() {
        _errorMessage = _lang.t('err_phone_required');
        _infoMessage = null;
      });
      return;
    }

    // 2. Password validation
    if (pass.isEmpty) {
      setState(() {
        _errorMessage = _lang.t('err_password_required');
        _infoMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final user = await _backend.loginUser(phoneNumber: last10, password: pass);

      if (mounted) {
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
        await playerProvider.reloadUserData(user.phoneNumber);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _lang.t('welcome_back'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        widget.onAuthenticated();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (e.toString().contains('NOT_REGISTERED')) {
          _errorMessage = _lang.t('err_not_registered');
          _regPhoneCtrl.text = last10; // Pre-fill registration tab with this phone
        } else if (e.toString().contains('WRONG_PASSWORD')) {
          _errorMessage = _lang.t('err_wrong_password');
        } else {
          _errorMessage = 'Error: $e';
        }
      });
    }
  }

  // ----------------------------------------------------
  // REGISTER FLOW (Name + 10-digit Phone + Email + Password)
  // ----------------------------------------------------
  Future<void> _handleRegister() async {
    final name = _regNameCtrl.text.trim();
    final phone = _regPhoneCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final pass = _regPassCtrl.text.trim();

    // 1. Mandatory Name
    if (name.isEmpty || name.length < 2) {
      setState(() {
        _errorMessage = _lang.t('err_name_required');
        _infoMessage = null;
      });
      return;
    }

    // 2. Mandatory 10-Digit Mobile
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = digitsOnly.length >= 10 ? digitsOnly.substring(digitsOnly.length - 10) : digitsOnly;
    if (last10.length != 10) {
      setState(() {
        _errorMessage = _lang.t('err_phone_required');
        _infoMessage = null;
      });
      return;
    }

    // 3. Mandatory Email ID (regex format)
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      setState(() {
        _errorMessage = _lang.t('err_email_required');
        _infoMessage = null;
      });
      return;
    }

    // 4. Mandatory Password (min 4 characters)
    if (pass.length < 4) {
      setState(() {
        _errorMessage = _lang.t('err_password_short');
        _infoMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final user = await _backend.registerUser(
        fullName: name,
        phoneNumber: last10,
        email: email,
        password: pass,
      );

      if (mounted) {
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
        await playerProvider.reloadUserData(user.phoneNumber);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _lang.t('welcome_new'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF00E5FF),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        widget.onAuthenticated();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (e.toString().contains('ALREADY_REGISTERED')) {
          _infoMessage = _lang.t('err_already_registered');
          _errorMessage = null;
          _loginPhoneCtrl.text = last10; // Pre-fill login tab with this phone
          _isLoginMode = true; // Automatically switch to Login mode
        } else {
          _errorMessage = 'Error: $e';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Stack(
          children: [
            // Top Right: Language Switcher Button
            Positioned(
              top: 14,
              right: 18,
              child: InkWell(
                onTap: () => _lang.toggleLanguage(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A2A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language_rounded, size: 15, color: Color(0xFF00E5FF)),
                      const SizedBox(width: 6),
                      Text(
                        _lang.displayLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // App Title
                    Text(
                      _lang.t('auth_title'),
                      style: GoogleFonts.syne(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lang.t('auth_subtitle'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.cyanAccent.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Login vs Register Pill Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131A2A),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _isLoginMode = true;
                                  _errorMessage = null;
                                  _infoMessage = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(26),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isLoginMode ? const Color(0xFF00E5FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: Center(
                                  child: Text(
                                    _lang.t('tab_login'),
                                    style: TextStyle(
                                      color: _isLoginMode ? Colors.black : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _isLoginMode = false;
                                  _errorMessage = null;
                                  _infoMessage = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(26),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isLoginMode ? const Color(0xFF00E5FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: Center(
                                  child: Text(
                                    _lang.t('tab_register'),
                                    style: TextStyle(
                                      color: !_isLoginMode ? Colors.black : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Info / Notification Card (e.g. Already Registered)
                    if (_infoMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFF00E5FF), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _infoMessage!,
                                style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Error Message Card
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            // Quick Switch Button if user tried to login without registering
                            if (_errorMessage == _lang.t('err_not_registered')) ...[
                              const SizedBox(height: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00E5FF),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isLoginMode = false;
                                    _errorMessage = null;
                                  });
                                },
                                child: Text(
                                  _lang.isHindi ? '👉 अभी नया खाता बनाएं (Register)' : '👉 Register New Account Now',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Form Container
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131A2A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ==========================================
                          // LOGIN FORM FIELDS
                          // ==========================================
                          if (_isLoginMode) ...[
                            _buildInputField(
                              controller: _loginPhoneCtrl,
                              label: _lang.t('user_id_label'),
                              hint: _lang.t('user_id_hint'),
                              icon: Icons.phone_android_rounded,
                              keyboardType: TextInputType.phone,
                              prefixText: '+91 ',
                            ),
                            const SizedBox(height: 14),
                            _buildPasswordField(
                              controller: _loginPassCtrl,
                              label: _lang.t('password_label'),
                              hint: _lang.t('password_hint'),
                            ),
                            const SizedBox(height: 22),
                            _buildSubmitButton(
                              title: _lang.t('btn_login'),
                              icon: Icons.login_rounded,
                              onPressed: _isLoading ? null : _handleLogin,
                            ),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLoginMode = false;
                                  _errorMessage = null;
                                  _infoMessage = null;
                                });
                              },
                              child: Text(
                                _lang.t('switch_to_register_prompt'),
                                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],

                          // ==========================================
                          // REGISTER FORM FIELDS
                          // ==========================================
                          if (!_isLoginMode) ...[
                            _buildInputField(
                              controller: _regNameCtrl,
                              label: _lang.t('full_name'),
                              hint: _lang.t('full_name_hint'),
                              icon: Icons.person_rounded,
                            ),
                            const SizedBox(height: 12),
                            _buildInputField(
                              controller: _regPhoneCtrl,
                              label: _lang.t('phone_number'),
                              hint: _lang.t('phone_number_hint'),
                              icon: Icons.phone_android_rounded,
                              keyboardType: TextInputType.phone,
                              prefixText: '+91 ',
                            ),
                            const SizedBox(height: 12),
                            _buildInputField(
                              controller: _regEmailCtrl,
                              label: _lang.t('email_mandatory'),
                              hint: _lang.t('email_hint'),
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            _buildPasswordField(
                              controller: _regPassCtrl,
                              label: _lang.t('create_password_label'),
                              hint: _lang.t('create_password_hint'),
                            ),
                            const SizedBox(height: 22),
                            _buildSubmitButton(
                              title: _lang.t('btn_register'),
                              icon: Icons.person_add_alt_1_rounded,
                              onPressed: _isLoading ? null : _handleRegister,
                            ),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLoginMode = true;
                                  _errorMessage = null;
                                  _infoMessage = null;
                                });
                              },
                              child: Text(
                                _lang.t('switch_to_login_prompt'),
                                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    Text(
                      _lang.t('auth_tagline'),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade300,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B101D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              prefixIcon: Icon(icon, color: const Color(0xFF00E5FF), size: 20),
              prefixText: prefixText,
              prefixStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade300,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B101D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            controller: controller,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF00E5FF), size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton({
    required String title,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00E5FF),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 18),
              ],
            ),
    );
  }
}
