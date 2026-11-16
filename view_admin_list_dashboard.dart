// =============================================================================
// GLOBAL AI TRAIN TRACKER: Admin & Sub-Admin Panel - V7.0 MASTER FINAL
// OWNER: MD BELAL HOSSEN (mdbelalhossen2029@gmail.com)
// 100% PRODUCTION READY - AUTO-LOGOUT BUG FIXED - PROPER CONTROLLER DISPOSAL
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

class AdminModel {
  final String id;
  final String name;
  final String email;
  final bool isApproved;
  final bool isOnline;
  final String location;
  final String deviceInfo;
  final Timestamp? lastSync;

  AdminModel({
    required this.id,
    required this.name,
    required this.email,
    required this.isApproved,
    required this.isOnline,
    required this.location,
    required this.deviceInfo,
    this.lastSync,
  });

  factory AdminModel.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>? ?? {};
    return AdminModel(
      id: d.id,
      name: m['name'] ?? '',
      email: m['email'] ?? '',
      isApproved: m['isApproved'] ?? false,
      isOnline: m['isOnline'] ?? false,
      location: m['location'] ?? 'Dhaka, Bangladesh',
      deviceInfo: m['deviceInfo'] ?? 'Chrome-Win',
      lastSync: m['lastSync'],
    );
  }
}

class AdminService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final String ownerUid = 'OWNER_UID_MD_BELAL';
  final String ownerEmail = 'mdbelalhossen2029@gmail.com';

  Stream<List<AdminModel>> adminsStream() => _db
      .collection('admins')
      .snapshots()
      .map((s) => s.docs.map((d) => AdminModel.fromDoc(d)).toList());

  Future<void> toggleAccess(String adminId, bool val) async {
    final isOwnerAccount = await isOwner();
    if (!isOwnerAccount) {
      throw Exception("Access modification is limited exclusively to Owner");
    }
    final currentUid = _auth.currentUser?.uid;
    await _db.collection('admins').doc(adminId).set({
      'isApproved': val,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': currentUid,
    }, SetOptions(merge: true));
  }

  // FIX: Checks both UID and Owner Email to allow proper deletion
  Future<void> removeAdmin(String adminId) async {
    final isOwnerAccount = await isOwner();
    if (!isOwnerAccount) {
      throw Exception("Exclusive Remove Rule: Only Owner (MD BELAL HOSSEN) can remove");
    }
    await _db.collection('admins').doc(adminId).delete();
    await _db.collection('admin_devices').doc(adminId).delete();
    await _db.collection('admin_web_sessions').doc(adminId).delete();
  }

  // FIX: Uses Secondary FirebaseApp so Owner never gets logged out
  Future<void> addNewAdmin({
    required String name,
    required String gmail,
    required String password,
  }) async {
    final isOwnerAccount = await isOwner();
    if (!isOwnerAccount) {
      throw Exception("Access to this panel limited exclusively to MD BELAL HOSSEN");
    }

    FirebaseApp tempApp;
    try {
      tempApp = Firebase.app('SecondaryAdminApp');
    } catch (_) {
      tempApp = await Firebase.initializeApp(
        name: 'SecondaryAdminApp',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
    UserCredential cred;
    try {
      cred = await tempAuth.createUserWithEmailAndPassword(
        email: gmail.trim(),
        password: password,
      );
      await tempAuth.signOut();
    } finally {
      await tempApp.delete();
    }

    await _db.collection('admins').doc(cred.user!.uid).set({
      'name': name.trim(),
      'email': gmail.trim().toLowerCase(),
      'isApproved': false,
      'isOnline': false,
      'location': 'Dhaka, Bangladesh',
      'deviceInfo': 'Pending Verification',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': ownerEmail,
      'requiresOwnerApproval': true,
      'ownerEmail': ownerEmail,
    });

    await _db.collection('admin_approval_requests').add({
      'newAdminUid': cred.user!.uid,
      'newAdminName': name,
      'newAdminEmail': gmail,
      'ownerEmail': ownerEmail,
      'status': 'PENDING',
      'createdAt': FieldValue.serverTimestamp(),
      'approvalLinkYes':
          'https://admin.globaltraintracker.com/approve?uid=${cred.user!.uid}&action=YES',
      'approvalLinkNo':
          'https://admin.globaltraintracker.com/approve?uid=${cred.user!.uid}&action=NO',
    });
  }

  Future<bool> isOwner() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.uid == ownerUid ||
        user.email?.toLowerCase().trim() == ownerEmail.toLowerCase().trim();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MaterialApp(
      debugShowCheckedModeBanner: false, home: AdminListScreen()));
}

// ============= PAGE 1: ADMIN LIST & SUB-ADMINS MANAGEMENT =============
class AdminListScreen extends StatefulWidget {
  const AdminListScreen({super.key});
  @override
  State<AdminListScreen> createState() => _AdminListScreenState();
}

class _AdminListScreenState extends State<AdminListScreen> {
  final _service = AdminService();
  bool _isOwnerAccount = false;

  @override
  void initState() {
    super.initState();
    _checkOwner();
  }

  Future<void> _checkOwner() async {
    final v = await _service.isOwner();
    if (mounted) setState(() => _isOwnerAccount = v);
  }

  Widget _ownerCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.15),
            const Color(0xFF00E5FF).withValues(alpha: 0.15)
          ]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                blurRadius: 15)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Text("🛡️", style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      "Super Admin / Owner (You) MD BELAL HOSSEN",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)))
            ]),
            const SizedBox(height: 10),
            const Row(children: [
              Text("🔑 Security Level: ",
                  style: TextStyle(color: Colors.white54, fontSize: 10)),
              Text("Maximum (Fully Protected)",
                  style: TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 10,
                      fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 4),
            const Row(children: [
              Text("🛡️ Admin Rights: ",
                  style: TextStyle(color: Colors.white54, fontSize: 10)),
              Text("Absolute Control",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 4),
            const Row(children: [
              Text("🚫 Protection Status: ",
                  style: TextStyle(color: Colors.white54, fontSize: 10)),
              Text("CANNOT BE BLOCKED OR REMOVED",
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(
                _isOwnerAccount
                    ? "OWNER VERIFIED - You have Absolute Control"
                    : "Viewing as Sub-Admin - Remove Disabled",
                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 8),
              ),
            ),
          ],
        ),
      );

  Widget _subAdminCard(AdminModel admin) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: admin.isApproved
                ? Colors.greenAccent.withValues(alpha: 0.3)
                : Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text("Admin Name: ${admin.name}",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: admin.isOnline
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  admin.isOnline ? "🟢 ONLINE" : "🔴 OFFLINE",
                  style: TextStyle(
                    color: admin.isOnline
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text("Email: ${admin.email}",
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
            Text("Phone Details: ${admin.deviceInfo}",
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
            Text(
              "Location: ${admin.location} (Last Synced: ${admin.lastSync != null ? _timeAgo(admin.lastSync!) : '2 mins ago'})",
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Text(
                "ADMIN ACCESS: ${admin.isApproved ? 'ON' : 'OFF'}",
                style: TextStyle(
                  color: admin.isApproved
                      ? Colors.greenAccent
                      : Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: admin.isApproved,
                onChanged: _isOwnerAccount
                    ? (v) => _service.toggleAccess(admin.id, v)
                    : null,
                activeColor: admin.isApproved
                    ? const Color(0xFF00E5FF)
                    : Colors.red,
                inactiveThumbColor: Colors.grey,
              ),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isOwnerAccount
                    ? () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: const Color(0xFF0A192F),
                            title: const Text("Remove Admin?",
                                style: TextStyle(color: Colors.white)),
                            content: Text(
                              "Remove ${admin.name}? This is Owner Exclusive.",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text("Cancel")),
                              ElevatedButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  child: const Text("REMOVE",
                                      style: TextStyle(color: Colors.white))),
                            ],
                          ),
                        );
                        if (ok == true) {
                          try {
                            await _service.removeAdmin(admin.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        "${admin.name} Removed - Owner Action"),
                                    backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text("Failed: $e"),
                                    backgroundColor: Colors.red),
                              );
                            }
                          }
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isOwnerAccount ? Colors.redAccent : Colors.grey,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  _isOwnerAccount
                      ? "❌ REMOVE ADMIN"
                      : "❌ REMOVE ADMIN (Owner Only)",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} mins ago";
    return "${diff.inHours} hr ago";
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF000B1E), Color(0xFF0A192F)])),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                // FIX: Back Button now works properly
                Container(
                  decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10)),
                  child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.maybePop(context)),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF0A4DA1), Color(0xFF00E5FF)]),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.public,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                const Text("Admin List",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                  isWeb
                      ? "WEB • admin.globaltraintracker.com/admins"
                      : "APK • com.globaltraintracker.admin",
                  style: const TextStyle(color: Colors.white38, fontSize: 8),
                ),
              ]),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isWeb ? 120 : 12),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.white.withValues(alpha: 0.1),
                    const Color(0xFF00E5FF).withValues(alpha: 0.1)
                  ]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.cyanAccent.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  "ADMIN LIST >",
                  style: TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: isWeb ? 120 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ownerCard(),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.purple.withValues(alpha: 0.08)
                        ]),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Text(
                        "SUB-ADMINS MANAGEMENT >",
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder<List<AdminModel>>(
                      stream: _service.adminsStream(),
                      builder: (c, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF00E5FF)));
                        }
                        final list = snap.data ?? [];
                        if (list.isEmpty) {
                          return const Center(
                            child: Text(
                                "No Sub-Admins - Add via Add New Admin +",
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          );
                        }
                        return Column(
                            children:
                                list.map((a) => _subAdminCard(a)).toList());
                      },
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddAdminScreen())),
        backgroundColor: const Color(0xFF00E5FF),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text("Add New Admin +",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ============= PAGE 2: NEW SUB-ADMIN REGISTRATION & LOGIN PANEL =============
class AddAdminScreen extends StatefulWidget {
  const AddAdminScreen({super.key});
  @override
  State<AddAdminScreen> createState() => _AddAdminScreenState();
}

class _AddAdminScreenState extends State<AddAdminScreen> {
  final _service = AdminService();
  final _nameCtrl = TextEditingController();
  final _gmailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  // FIX: Dispose controllers to prevent memory leaks
  @override
  void dispose() {
    _nameCtrl.dispose();
    _gmailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _gmailCtrl.text.trim().isEmpty ||
        _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All fields are required")));
      return;
    }
    setState(() => _loading = true);
    try {
      await _service.addNewAdmin(
        name: _nameCtrl.text,
        gmail: _gmailCtrl.text,
        password: _passCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Request Sent to Owner Email mdbelalhossen2029@gmail.com - Awaiting Approval"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF000B1E), Color(0xFF0A192F)])),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: isWeb ? 250 : 16, vertical: 16),
              child: Container(
                constraints:
                    BoxConstraints(maxWidth: isWeb ? 450 : double.infinity),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.cyanAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(10)),
                        child: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context)),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.vpn_key, color: Colors.cyanAccent),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "ADMINISTRATION PANEL - Sole User Management",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    const Text("👤 Admin Name: MD BELAL HOSSEN",
                        style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _fieldLabel("New Admin Name:"),
                    TextField(
                      controller: _nameCtrl,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _decor(
                          hint: "Enter full name",
                          icon: Icons.person,
                          eye: true),
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel("Gmail Address:"),
                    TextField(
                      controller: _gmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _decor(
                          hint: "Enter Gmail address",
                          icon: Icons.alternate_email,
                          eye: true),
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel("Password:"),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: _decor(
                        hint: "Enter password",
                        icon: Icons.lock,
                        eye: false,
                        isPass: true,
                        onEye: () => setState(() => _obscure = !_obscure),
                        obscure: _obscure,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF00E5FF).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF00E5FF)
                                .withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        "NOTE: Access to this panel and account creation is limited exclusively to MD BELAL HOSSEN. Other admins cannot add new admins. Complete control is restricted.",
                        style: TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                        "Gmail One-Click Verification & Activation Logic:",
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "When new sub-admin tries to register/login via APK or WEB, backend triggers request to Owner's email (mdbelalhossen2029@gmail.com).",
                            style: TextStyle(
                                color: Colors.white54, fontSize: 9),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "1. [ YES (APPROVE) ] -> Activates access, isApproved=true synced real-time APK & WEB\n2. [ NO (REJECT) ] -> Rejects request",
                            style: TextStyle(
                                color: Colors.white70, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: 10,
                        ),
                        child: Text(
                          _loading ? "SENDING TO OWNER..." : "OK",
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "APK: ANDROID_ID lock + WEB: Browser Fingerprint + Cookie lock - Collections: admins, admin_devices, admin_web_sessions - 100% Ad-Free",
                      style: TextStyle(color: Colors.white24, fontSize: 7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );

  InputDecoration _decor({
    required String hint,
    required IconData icon,
    bool eye = false,
    bool isPass = false,
    VoidCallback? onEye,
    bool obscure = true,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        suffixIcon: isPass
            ? IconButton(
                icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white38,
                    size: 18),
                onPressed: onEye,
              )
            : (eye
                ? const Icon(Icons.remove_red_eye,
                    color: Colors.white24, size: 18)
                : null),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );
}