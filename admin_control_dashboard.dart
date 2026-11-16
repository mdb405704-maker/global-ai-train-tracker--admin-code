import 'dart:async';
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

class AdminControlService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<DocumentSnapshot> adConfigStream() =>
      _db.collection('config').doc('ads').snapshots();

  Stream<DocumentSnapshot> featureConfigStream() =>
      _db.collection('config').doc('features').snapshots();

  Stream<QuerySnapshot> usersStatsStream() =>
      _db.collection('users').snapshots();

  Stream<QuerySnapshot> searchStream(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      return _db
          .collection('security_logs')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots();
    }
    return _db
        .collection('security_logs')
        .where('keyword', arrayContains: clean)
        .limit(20)
        .snapshots();
  }

  Future<void> toggleAd(String adType, bool val) async {
    await _db.collection('config').doc('ads').set({
      adType: val,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.email ?? 'admin',
    }, SetOptions(merge: true));
  }

  Future<void> toggleFeature(String featureKey, bool val) async {
    await _db.collection('config').doc('features').set({
      featureKey: val,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.email ?? 'admin',
    }, SetOptions(merge: true));
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AdminControlAuthGate(),
    ),
  );
}

class AdminControlAuthGate extends StatelessWidget {
  const AdminControlAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF000B1E),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const AdminControlDashboard();
        }
        return const _AdminControlLoginScreen();
      },
    );
  }
}

class _AdminControlLoginScreen extends StatefulWidget {
  const _AdminControlLoginScreen();

  @override
  State<_AdminControlLoginScreen> createState() =>
      _AdminControlLoginScreenState();
}

class _AdminControlLoginScreenState extends State<_AdminControlLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final email = _emailCtrl.text.trim().toLowerCase();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter Admin Email and Password"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? "Login failed"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF000B1E), Color(0xFF0A192F)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withOpacity(0.4),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.admin_panel_settings,
                          color: Color(0xFFFFD700),
                          size: 56,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "ADMIN CONTROL LOGIN",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Global AI Train Tracker",
                          style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Admin Email",
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(Icons.email, color: Color(0xFF00E5FF)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Password",
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(Icons.lock, color: Color(0xFF00E5FF)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white54,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E5FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "LOGIN",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminControlDashboard extends StatefulWidget {
  const AdminControlDashboard({super.key});
  @override
  State<AdminControlDashboard> createState() => _AdminControlDashboardState();
}

class _AdminControlDashboardState extends State<AdminControlDashboard> {
  final _service = AdminControlService();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openPage(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _statCard(String label, int count, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "$count",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _adToggle(String title, String keyName, bool value) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value ? "ON" : "OFF",
              style: TextStyle(
                color: value ? Colors.greenAccent : Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: (v) async {
                try {
                  await _service.toggleAd(keyName, v);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Failed to update $title: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              activeColor: Colors.greenAccent,
              inactiveThumbColor: Colors.redAccent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      );

  Widget _primaryButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
            ],
          ),
        ),
      );

  Widget _featureCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    final query = _searchCtrl.text.trim();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF000B1E), Color(0xFF0A192F)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. TOP HEADER & NAVIGATION
                      Row(
                        children: [
                          if (Navigator.canPop(context))
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () {
                                  if (Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                            ),
                          const Expanded(
                            child: Text(
                              "Admin Control",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "Owner: MD BELAL HOSSEN",
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: "Sign Out",
                            icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      // 2. REAL-TIME USER STATISTICS COUNTER
                      StreamBuilder<QuerySnapshot>(
                        stream: _service.usersStatsStream(),
                        builder: (context, snap) {
                          int total = 0;
                          int active = 0;
                          int inactive = 0;
                          if (snap.hasData) {
                            final docs = snap.data!.docs;
                            total = docs.length;
                            active = docs.where((d) {
                              final data = d.data() as Map<String, dynamic>? ?? {};
                              return (data['isActive'] ?? true) == true &&
                                  (data['isBlocked'] ?? false) == false;
                            }).length;
                            inactive = total - active;
                          }
                          return Row(
                            children: [
                              _statCard("TOTAL", total, const Color(0xFF00E5FF)),
                              const SizedBox(width: 8),
                              _statCard("ACTIVE", active, Colors.greenAccent),
                              const SizedBox(width: 8),
                              _statCard("INACTIVE", inactive, Colors.orangeAccent),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 14),
                      // 3. GLOBAL REAL-TIME SEARCH BAR
                      TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: "Search hackers, devices, IP, logs...",
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white38,
                            size: 20,
                          ),
                          suffixIcon: query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.white54,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.07),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),

                      if (query.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.35),
                            ),
                          ),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _service.searchStream(query),
                            builder: (context, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF00E5FF),
                                    ),
                                  ),
                                );
                              }
                              final docs = snap.data?.docs ?? [];
                              if (docs.isEmpty) {
                                return const Text(
                                  "No matching security logs found",
                                  style: TextStyle(color: Colors.white54, fontSize: 12),
                                );
                              }
                              return Column(
                                children: docs.map((d) {
                                  final data = d.data() as Map<String, dynamic>? ?? {};
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.warning_amber,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    title: Text(
                                      (data['reason'] ?? data['event'] ?? 'Security Event')
                                          .toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "IP: ${data['ip'] ?? 'Unknown'} | UID: ${data['uid'] ?? 'N/A'}",
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),
                      // 4. AD MANAGEMENT CONTROLS (REAL-TIME STREAM TOGGLES)
                      const Text(
                        "AD MANAGEMENT CONTROLS",
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      StreamBuilder<DocumentSnapshot>(
                        stream: _service.adConfigStream(),
                        builder: (context, snap) {
                          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                          final appOpen = data['appOpen'] ?? true;
                          final interstitial = data['interstitial'] ?? true;
                          final rewarded = data['rewarded'] ?? true;

                          return Column(
                            children: [
                              _adToggle("App Open Ad", 'appOpen', appOpen),
                              _adToggle("Interstitial Ad", 'interstitial', interstitial),
                              _adToggle("Rewarded/Timer Ad", 'rewarded', rewarded),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 14),
                      // 5. PRIMARY SECURITY & ADMIN MANAGEMENT BUTTONS
                      _primaryButton(
                        "View All Hackers List >",
                        Icons.security,
                        Colors.redAccent,
                        () => _openPage(const _HackersListScreen()),
                      ),
                      const SizedBox(height: 8),
                      _primaryButton(
                        "View Admin List >",
                        Icons.admin_panel_settings,
                        const Color(0xFF00E5FF),
                        () => _openPage(const _QuickAdminsScreen()),
                      ),

                      const SizedBox(height: 16),
                      // 6. MAIN FEATURE MODULES (2x2 GRID)
                      const Text(
                        "MAIN FEATURE MODULES",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: isWeb ? 4 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: isWeb ? 1.35 : 1.15,
                        children: [
                          _featureCard(
                            "Feature Control",
                            "Manage app features ON/OFF",
                            Icons.tune,
                            const Color(0xFFFFA500),
                            () => _openPage(_FeatureControlScreen(service: _service)),
                          ),
                          _featureCard(
                            "Notifications",
                            "Send notices, alerts & broadcasts",
                            Icons.notifications_active,
                            const Color(0xFF00E5FF),
                            () => _openPage(const _AdminNotificationsScreen()),
                          ),
                          _featureCard(
                            "User Activities",
                            "Monitor user actions & logs",
                            Icons.history,
                            Colors.greenAccent,
                            () => _openPage(const _UserActivitiesScreen()),
                          ),
                          _featureCard(
                            "Supporting System",
                            "Customer support & live chat",
                            Icons.headset_mic,
                            Colors.purpleAccent,
                            () => _openPage(const _AdminSupportInboxScreen()),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      // 7. AI ASSISTANT BANNER BUTTON
                      InkWell(
                        onTap: () => _openPage(const _AdminAiAssistantScreen()),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A00FF), Color(0xFF00E5FF)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6A00FF).withOpacity(0.3),
                                blurRadius: 15,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.psychology,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  "AI Assistant - Ask anything about the platform",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Project: global-ai-train-tracker 793207191715 | com.belal.traintracker | AdMob: ca-app-pub-7456993737714049 | 100% Ad-Free Admin",
                        style: TextStyle(color: Colors.white24, fontSize: 7.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SUB-PAGE 1: HACKERS & SECURITY LOGS LIST (REAL-TIME BLOCK / UNBLOCK)
// =============================================================================
class _HackersListScreen extends StatelessWidget {
  const _HackersListScreen();

  Future<void> _toggleUserBlock(
    BuildContext context,
    String uid,
    bool currentlyBlocked,
  ) async {
    if (uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'isBlocked': !currentlyBlocked,
        'isActive': currentlyBlocked,
        'blockedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyBlocked ? "User Unblocked" : "User Blocked for Security",
            ),
            backgroundColor: currentlyBlocked ? Colors.green : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A192F),
        iconTheme: const IconThemeData(color: Colors.redAccent),
        title: const Text(
          "Security & Hackers List",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('security_logs')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            );
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No suspicious activity or hacker attempts logged",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data() as Map<String, dynamic>? ?? {};
              final uid = (data['uid'] ?? '').toString();
              final reason = (data['reason'] ?? data['event'] ?? 'Suspicious Attempt').toString();
              final ip = (data['ip'] ?? 'Unknown IP').toString();
              final device = (data['device'] ?? 'Unknown Device').toString();
              final isBlocked = data['isBlocked'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reason,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "UID: ${uid.isEmpty ? 'Anonymous' : uid}\nIP: $ip | Device: $device",
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    if (uid.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isBlocked ? Colors.green : Colors.redAccent,
                          ),
                          onPressed: () =>
                              _toggleUserBlock(context, uid, isBlocked),
                          child: Text(
                            isBlocked ? "UNBLOCK USER" : "BLOCK USER",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =============================================================================
// SUB-PAGE 2: QUICK ADMIN LIST VIEW
// =============================================================================
class _QuickAdminsScreen extends StatelessWidget {
  const _QuickAdminsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A192F),
        iconTheme: const IconThemeData(color: Color(0xFF00E5FF)),
        title: const Text(
          "Admins Overview",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('admins').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            );
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "Only Owner (MD BELAL HOSSEN) active. No sub-admins added.",
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final d = docs[i];
              final m = d.data() as Map<String, dynamic>? ?? {};
              final approved = m['isApproved'] == true;
              final online = m['isOnline'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: approved
                        ? Colors.greenAccent.withOpacity(0.4)
                        : Colors.white12,
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.admin_panel_settings,
                    color: approved ? Colors.greenAccent : Colors.grey,
                  ),
                  title: Text(
                    (m['name'] ?? 'Admin').toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    "${m['email'] ?? ''} | ${online ? 'ONLINE' : 'OFFLINE'}",
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  trailing: Switch(
                    value: approved,
                    activeColor: const Color(0xFF00E5FF),
                    onChanged: (v) async {
                      await FirebaseFirestore.instance
                          .collection('admins')
                          .doc(d.id)
                          .set({'isApproved': v}, SetOptions(merge: true));
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =============================================================================
// SUB-PAGE 3: FEATURE CONTROL (REAL-TIME APP FEATURE TOGGLES)
// =============================================================================
class _FeatureControlScreen extends StatelessWidget {
  final AdminControlService service;
  const _FeatureControlScreen({required this.service});

  static const List<Map<String, String>> _features = [
    {'key': 'train_search', 'title': 'Live Train Search'},
    {'key': 'ai_assistant', 'title': 'AI Assistant'},
    {'key': 'pnr_check', 'title': 'PNR Status Check'},
    {'key': 'prayer_qibla', 'title': 'Prayer Times & Qibla'},
    {'key': 'official_notice', 'title': 'Official Notices'},
    {'key': 'live_support', 'title': 'Customer Support Chat'},
    {'key': 'maintenance_mode', 'title': 'Maintenance Mode (App Lock)'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A192F),
        iconTheme: const IconThemeData(color: Color(0xFFFFA500)),
        title: const Text(
          "Feature Control",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: service.featureConfigStream(),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: _features.length,
            itemBuilder: (ctx, i) {
              final f = _features[i];
              final key = f['key']!;
              final defaultVal = key != 'maintenance_mode';
              final enabled = data[key] ?? defaultVal;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFFA500).withOpacity(0.3),
                  ),
                ),
                child: SwitchListTile(
                  title: Text(
                    f['title']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    enabled ? "Status: ON" : "Status: OFF",
                    style: TextStyle(
                      color: enabled ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 11,
                    ),
                  ),
                  value: enabled,
                  activeColor: const Color(0xFFFFA500),
                  onChanged: (v) => service.toggleFeature(key, v),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =============================================================================
// SUB-PAGE 4: ADMIN NOTIFICATIONS & BROADCAST COMPOSER
// =============================================================================
class _AdminNotificationsScreen extends StatefulWidget {
  const _AdminNotificationsScreen();

  @override
  State<_AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<_AdminNotificationsScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  String _type = 'text';
  String _countryFilter = 'ALL';
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendNotice() async {
    if (_sending) return;
    final title = _titleCtrl.text.trim();
    final content = _bodyCtrl.text.trim();
    final url = _urlCtrl.text.trim();

    if (title.isEmpty || (_type == 'text' && content.isEmpty) || (_type == 'link' && url.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter required title and content/link"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('official_notices').add({
        'title': title,
        'content': content,
        'url': url,
        'type': _type,
        'country_filter': _countryFilter,
        'is_active': true,
        'view_count': 0,
        'copy_count': 0,
        'created_at': FieldValue.serverTimestamp(),
      });
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _urlCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Notice published to all users in real time"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A192F),
        iconTheme: const IconThemeData(color: Color(0xFF00E5FF)),
        title: const Text(
          "Send Notice / Broadcast",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              dropdownColor: const Color(0xFF0A192F),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Notice Type",
                labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.07),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'text', child: Text("Text Notice")),
                DropdownMenuItem(value: 'link', child: Text("Official Link")),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _countryFilter,
              dropdownColor: const Color(0xFF0A192F),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Target Region",
                labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.07),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text("ALL Countries (Global)")),
                DropdownMenuItem(value: 'BD', child: Text("BD - Bangladesh")),
                DropdownMenuItem(value: 'IN', child: Text("IN - India")),
                DropdownMenuItem(value: 'PK', child: Text("PK - Pakistan")),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _countryFilter = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Notice Title",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.07),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            if (_type == 'link')
              TextField(
                controller: _urlCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Official Website URL (https://...)",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            else
              TextField(
                controller: _bodyCtrl,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Write official notice message...",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: _sending ? null : _sendNotice,
                icon: const Icon(Icons.send, color: Colors.black),
                label: Text(
                  _sending ? "PUBLISHING..." : "PUBLISH NOTICE",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SUB-PAGE 5: USER ACTIVITIES LOGS
// =============================================================================
class _UserActivitiesScreen extends StatelessWidget {
  const _UserActivitiesScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A192F),
        iconTheme: const IconThemeData(color: Colors.greenAccent),
        title: const Text(
          "User Activities",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bar_logs')
            .orderBy('timestamp', descending: true)
            .limit(40)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            );
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No recent user activities recorded yet",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final d = docs[i].data() as Map<String, dynamic>? ?? {};
              final bar = d['bar'] ?? '-';
              final api = (d['api'] ?? 'Action').toString();
              String time = '';
              if (d['timestamp'] is Timestamp) {
                time = (d['timestamp'] as Timestamp)
                    .toDate()
                    .toString()
                    .split('.')
                    .first;
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.greenAccent.withOpacity(0.2),
                    child: Text(
                      "$bar",
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    api,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: Text(
                    time,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =============================================================================
// SUB-PAGE 6: ADMIN SUPPORT CHAT INBOX (REPLY TO USERS LIVE)
// =============================================================================
class _AdminSupportInboxScreen extends StatelessWidget {
  const _AdminSupportInboxScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A192F),
        iconTheme: const IconThemeData(color: Colors.purpleAccent),
        title: const Text(
          "Support Inbox (Live Chat)",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('support_chats')
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent),
            );
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No user support chats yet",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>? ?? {};
              final name = (data['userName'] ?? 'User').toString();
              final email = (data['userEmail'] ?? d.id).toString();
              final lastMsg = (data['lastMessage'] ?? 'Tap to reply').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.35)),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.purpleAccent,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    "$name ($email)",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    lastMsg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.chat,
                    color: Color(0xFFFFD700),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _AdminChatReplyScreen(
                          chatId: d.id,
                          userName: name,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminChatReplyScreen extends StatefulWidget {
  final String chatId;
  final String userName;

  const _AdminChatReplyScreen({required this.chatId, required this.userName});

  @override
  State<_AdminChatReplyScreen> createState() => _AdminChatReplyScreenState();
}

class _AdminChatReplyScreenState extends State<_AdminChatReplyScreen> {
  final _replyCtrl = TextEditingController();

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final int h24 = dt.hour;
    final int h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
    final String m = dt.minute.toString().padLeft(2, '0');
    final String p = h24 >= 12 ? 'PM' : 'AM';
    return '$h12:$m $p';
  }

  Future<void> _sendAdminReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    _replyCtrl.clear();

    final nowTime = _formatTime(DateTime.now());
    final chatRef =
        FirebaseFirestore.instance.collection('support_chats').doc(widget.chatId);

    await chatRef.set({
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await chatRef.collection('messages').add({
      'sender': 'admin',
      'text': text,
      'imageUrl': '',
      'localTime': nowTime,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A192F),
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        title: Text(
          "Chat: ${widget.userName}",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('support_chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final d = docs[i].data() as Map<String, dynamic>? ?? {};
                    final isAdmin = d['sender'] == 'admin';
                    final text = (d['text'] ?? '').toString();
                    final imageUrl = (d['imageUrl'] ?? '').toString();
                    String time = (d['localTime'] ?? '').toString();
                    if (d['timestamp'] is Timestamp) {
                      time = _formatTime((d['timestamp'] as Timestamp).toDate());
                    }

                    return Align(
                      alignment:
                          isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? const Color(0xFF00E5FF)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: isAdmin
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(imageUrl, width: 180),
                              ),
                            if (text.isNotEmpty)
                              Text(
                                text,
                                style: TextStyle(
                                  color: isAdmin ? Colors.black : Colors.white,
                                ),
                              ),
                            const SizedBox(height: 3),
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 10,
                                color: isAdmin ? Colors.black54 : Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyCtrl,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _sendAdminReply(),
                    decoration: InputDecoration(
                      hintText: "Reply as Admin...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF00E5FF),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black),
                    onPressed: _sendAdminReply,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SUB-PAGE 7: ADMIN PLATFORM AI ASSISTANT & DIAGNOSTICS
// =============================================================================
class _AdminAiAssistantScreen extends StatefulWidget {
  const _AdminAiAssistantScreen();

  @override
  State<_AdminAiAssistantScreen> createState() =>
      _AdminAiAssistantScreenState();
}

class _AdminAiAssistantScreenState extends State<_AdminAiAssistantScreen> {
  final _qCtrl = TextEditingController();
  final List<Map<String, String>> _history = [
    {
      'role': 'ai',
      'text':
          'Hello Admin! Ask me about platform status, users, ads, security logs, or support tickets.',
    },
  ];
  bool _loading = false;

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final q = _qCtrl.text.trim();
    if (q.isEmpty || _loading) return;
    _qCtrl.clear();

    setState(() {
      _loading = true;
      _history.add({'role': 'user', 'text': q});
    });

    try {
      final db = FirebaseFirestore.instance;
      final usersSnap = await db.collection('users').count().get();
      final chatsSnap = await db.collection('support_chats').count().get();
      final secSnap = await db.collection('security_logs').count().get();
      final adsDoc = await db.collection('config').doc('ads').get();
      final ads = adsDoc.data() ?? {};

      final reply =
          'Live Platform Summary:\n'
          '- Total Registered Users: ${usersSnap.count ?? 0}\n'
          '- Support Conversations: ${chatsSnap.count ?? 0}\n'
          '- Security Alerts Logged: ${secSnap.count ?? 0}\n'
          '- Ads Status: AppOpen=${ads['appOpen'] ?? true}, Interstitial=${ads['interstitial'] ?? true}, Rewarded=${ads['rewarded'] ?? true}';

      if (mounted) {
        setState(() => _history.add({'role': 'ai', 'text': reply}));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _history.add({'role': 'ai', 'text': 'Error: $e'}));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A192F),
        iconTheme: const IconThemeData(color: Color(0xFF00E5FF)),
        title: const Text(
          "Platform AI Assistant",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _history.length,
              itemBuilder: (ctx, i) {
                final m = _history[i];
                final isUser = m['role'] == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF6A00FF)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      m['text'] ?? '',
                      style: const TextStyle(color: Colors.white, height: 1.4),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qCtrl,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _ask(),
                    decoration: InputDecoration(
                      hintText: "Ask about users, ads, security...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF00E5FF),
                  child: IconButton(
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.black),
                    onPressed: _loading ? null : _ask,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}