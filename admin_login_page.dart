// GLOBAL AI TRAIN TRACKER / BD-IN SMART APP: Owner Exclusive Admin Login
// MASTER FINAL V1.0 - 100% EXCLUSIVE OWNER ACCESS, PLAY STORE SAFE & PRODUCTION READY
// Owner: MD BELAL HOSSEN - mdbelalhossen2029@gmail.com
// Firebase: global-ai-train-tracker - 793207191715
// Package: com.belal.traintracker

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC8PteupdXqGNNfPYkEYVGB5WwiueRMDOg',
    appId: '1:793207191715:android:a7f7e788220ebb3c26a716',
    messagingSenderId: '793207191715',
    projectId: 'global-ai-train-tracker',
    databaseURL: 'https://global-ai-train-tracker-default-rtdb.firebaseio.com',
    storageBucket: 'global-ai-train-tracker.firebasestorage.app',
  );
  static FirebaseOptions get currentPlatform => android;
}

enum AdminLoginStatus { success, pendingApproval, blocked, reApprovalRequired }

class AdminLoginResult {
  final AdminLoginStatus status;
  final String message;
  AdminLoginResult(this.status, this.message);
}

class AdminAuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  static const String ownerGmail = 'mdbelalhossen2029@gmail.com';

  Future<String> _getDeviceId() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        final web = await plugin.webBrowserInfo;
        return 'web_${web.browserName.name}_${web.platform ?? 'unknown'}_${web.hardwareConcurrency ?? 0}';
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await plugin.androidInfo;
        return 'android_${info.manufacturer}_${info.brand}_${info.model}_${info.device}_${info.hardware}';
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await plugin.iosInfo;
        return 'ios_${ios.identifierForVendor ?? ios.utsname.machine}';
      }
      return 'other_device';
    } catch (_) {
      return 'unknown_device';
    }
  }

  Future<AdminLoginResult> ownerExclusiveLogin({
    required String fullName,
    required String gmail,
    required String password,
  }) async {
    final cleanEmail = gmail.trim().toLowerCase();
    final cred = await _auth.signInWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = cred.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-null',
        message: 'Authentication failed.',
      );
    }

    final uid = user.uid;
    final deviceId = await _getDeviceId();
    final bool isOwnerAccount = cleanEmail == ownerGmail.toLowerCase();

    final docRef = _db.collection('admins').doc(uid);
    final snap = await docRef.get();

    // Auto-bootstrap Owner document if first-time login; reject all unknown non-admin users
    if (!snap.exists) {
      if (isOwnerAccount) {
        await docRef.set({
          'name': fullName,
          'fullName': fullName,
          'email': cleanEmail,
          'gmail': cleanEmail,
          'isOwner': true,
          'isApproved': true,
          'isBlocked': false,
          'isOnline': true,
          'allowedDeviceId': deviceId,
          'deviceInfo': deviceId,
          'lastLogin': FieldValue.serverTimestamp(),
          'lastSync': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return AdminLoginResult(
          AdminLoginStatus.success,
          'Owner Login Success - Device Locked',
        );
      }

      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'not-admin',
        message: 'Access denied: Not an admin account.',
      );
    }

    final data = snap.data() ?? {};

    // Owner always retains access and updates device lock smoothly
    if (isOwnerAccount) {
      await docRef.set({
        'name': fullName,
        'fullName': fullName,
        'email': cleanEmail,
        'gmail': cleanEmail,
        'isOwner': true,
        'isApproved': true,
        'isBlocked': false,
        'isOnline': true,
        'allowedDeviceId': deviceId,
        'deviceInfo': deviceId,
        'lastLogin': FieldValue.serverTimestamp(),
        'lastSync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return AdminLoginResult(AdminLoginStatus.success, 'Owner Login Success');
    }

    if (data['isBlocked'] == true) {
      await _auth.signOut();
      return AdminLoginResult(
        AdminLoginStatus.blocked,
        'Your account is blocked. Contact owner.',
      );
    }

    if (data['isApproved'] == false) {
      await _auth.signOut();
      return AdminLoginResult(
        AdminLoginStatus.pendingApproval,
        'Your request is pending for owner approval.',
      );
    }

    final allowed = data['allowedDeviceId'] as String?;
    if (allowed == null || allowed.isEmpty) {
      await docRef.set({
        'allowedDeviceId': deviceId,
        'deviceInfo': deviceId,
        'fullName': fullName,
        'name': fullName,
        'gmail': cleanEmail,
        'email': cleanEmail,
        'isOnline': true,
        'lastLogin': FieldValue.serverTimestamp(),
        'lastSync': FieldValue.serverTimestamp(),
        'isApproved': true,
        'isBlocked': false,
      }, SetOptions(merge: true));
      return AdminLoginResult(
        AdminLoginStatus.success,
        'Login Success - Device Locked',
      );
    }

    if (allowed != deviceId) {
      await docRef.set({
        'isApproved': false,
        'isBlocked': true,
        'isOnline': false,
        'pendingDeviceId': deviceId,
        'requiresOwnerReApproval': true,
        'blockReason': 'New device: $deviceId',
      }, SetOptions(merge: true));

      await _db.collection('admin_approval_requests').add({
        'uid': uid,
        'fullName': fullName,
        'gmail': cleanEmail,
        'oldDeviceId': allowed,
        'newDeviceId': deviceId,
        'ownerGmail': ownerGmail,
        'type': 'DEVICE_CHANGE_BLOCKED',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'PENDING_OWNER_CLICK',
      });

      await _auth.signOut();
      return AdminLoginResult(
        AdminLoginStatus.reApprovalRequired,
        'New device detected. Blocked. Owner notified.',
      );
    }

    await docRef.set({
      'isOnline': true,
      'lastLogin': FieldValue.serverTimestamp(),
      'lastSync': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return AdminLoginResult(AdminLoginStatus.success, 'Login Success');
  }

  Future<void> requestOwnerResetCode(String requesterGmail) async {
    final cleanEmail = requesterGmail.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      throw Exception('Please enter your Gmail address first.');
    }
    await _db.collection('password_reset_requests').add({
      'requesterGmail': cleanEmail,
      'ownerGmail': ownerGmail,
      'type': 'OWNER_ONLY_RESET',
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'PENDING_OWNER_CODE',
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AdminLoginScreen(),
    );
  }
}

class AdminLoginScreen extends StatefulWidget {
  final WidgetBuilder? dashboardBuilder;
  const AdminLoginScreen({super.key, this.dashboardBuilder});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _gmail = TextEditingController();
  final _password = TextEditingController();
  final _service = AdminAuthService();

  bool _obscure = true;
  bool _loading = false;
  bool _sendingReset = false;

  final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  @override
  void dispose() {
    _name.dispose();
    _gmail.dispose();
    _password.dispose();
    super.dispose();
  }

  void _navigateToDashboard() {
    if (!mounted) return;
    if (widget.dashboardBuilder != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: widget.dashboardBuilder!),
      );
      return;
    }
    try {
      Navigator.pushReplacementNamed(context, '/admin_dashboard');
    } catch (_) {
      try {
        Navigator.pushReplacementNamed(context, '/dashboard');
      } catch (_) {}
    }
  }

  Future<void> _login() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final res = await _service.ownerExclusiveLogin(
        fullName: _name.text.trim(),
        gmail: _gmail.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: res.status == AdminLoginStatus.success
                ? Colors.green
                : Colors.orange,
          ),
        );

      if (res.status == AdminLoginStatus.success) {
        _navigateToDashboard();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(e.message ?? 'Login Failed'),
              backgroundColor: Colors.redAccent,
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.redAccent,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_sendingReset) return;
    FocusScope.of(context).unfocus();

    final email = _gmail.text.trim().toLowerCase();
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please enter your valid Gmail address first'),
            backgroundColor: Colors.redAccent,
          ),
        );
      return;
    }

    setState(() => _sendingReset = true);
    try {
      await _service.requestOwnerResetCode(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Reset code request sent to owner mdbelalhossen2029@gmail.com',
            ),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Failed: ${e.toString().replaceAll('Exception: ', '')}',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF0A4DA1)),
      suffixIcon: suffix,
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.cyan.withValues(alpha: 0.45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.cyan, width: 1.5),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF001A33), Color(0xFF0B2545)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -40,
                left: -30,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const Text(
                              'RAILWAY ADMIN LOGIN',
                              style: TextStyle(
                                color: Color(0xFF0A4DA1),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(color: Colors.black12, blurRadius: 6),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'GLOBAL AI TRAIN TRACKER',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _name,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: Colors.black87),
                              decoration: _fieldDecoration(
                                label: 'Name',
                                hint: 'Enter your full name',
                                icon: Icons.person,
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _gmail,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: Colors.black87),
                              decoration: _fieldDecoration(
                                label: 'Gmail',
                                hint: 'Enter your Gmail address',
                                icon: Icons.email,
                              ),
                              validator: (v) {
                                final email = (v ?? '').trim();
                                if (email.isEmpty) return 'Required';
                                if (!_emailRegex.hasMatch(email)) {
                                  return 'Enter valid Gmail';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _login(),
                              style: const TextStyle(color: Colors.black87),
                              decoration: _fieldDecoration(
                                label: 'Password',
                                hint: 'Enter your password',
                                icon: Icons.lock,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.black54,
                                  ),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _sendingReset ? null : _handleForgotPassword,
                                child: Text(
                                  _sendingReset ? 'SENDING...' : 'FORGOT PASSWORD?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0A4DA1),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                icon: _loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.settings,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                label: Text(
                                  _loading ? 'VERIFYING...' : 'LOGIN',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A4DA1),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  shadowColor: Colors.blueAccent,
                                  elevation: 12,
                                ),
                                onPressed: _loading ? null : _login,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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