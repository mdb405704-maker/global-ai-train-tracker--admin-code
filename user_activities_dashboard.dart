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

class UserModel {
  final String id;
  final String name;
  final String userId;
  final String country;
  final String location;
  final String liveLoc;
  final String flag;
  final bool isActive;
  final bool isSpecialist;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.userId,
    required this.country,
    required this.location,
    required this.liveLoc,
    required this.flag,
    required this.isActive,
    required this.isSpecialist,
    this.createdAt,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final ts = d['createdAt'] ?? d['created_at'];
    final DateTime? created = ts is Timestamp ? ts.toDate() : null;

    final resolvedName =
        (d['name'] ?? d['fullName'] ?? d['displayName'] ?? 'User').toString();
    final resolvedUserId =
        (d['userId'] ?? d['uid'] ?? doc.id).toString();
    final resolvedCountry =
        (d['country'] ?? d['country_lock'] ?? 'Global').toString();
    final resolvedFlag =
        (d['flag'] ?? (resolvedCountry.length == 2 ? resolvedCountry : 'GL'))
            .toString();

    return UserModel(
      id: doc.id,
      name: resolvedName,
      userId: resolvedUserId,
      country: resolvedCountry,
      location: (d['location'] ?? resolvedCountry).toString(),
      liveLoc: (d['liveLoc'] ?? 'Active Session').toString(),
      flag: resolvedFlag,
      isActive: d['isActive'] ?? true,
      isSpecialist: d['isSpecialist'] == true,
      createdAt: created,
    );
  }
}

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<UserModel>> usersStream() =>
      _db.collection('users').snapshots().map((s) {
        final list = s.docs.map((d) => UserModel.fromDoc(d)).toList();
        list.sort((a, b) {
          final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });
        return list;
      });

  Future<void> toggleActive(String uid, bool val) async {
    await _db.collection('users').doc(uid).set({
      'isActive': val,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> toggleSpecialist(String uid, bool val) async {
    await _db.collection('users').doc(uid).set({
      'isSpecialist': val,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> createUser({
    required String emailOrPhone,
    required String customUserId,
    required String password,
  }) async {
    final cleanInput = emailOrPhone.trim();
    final cleanCustomId = customUserId.trim();
    final String authEmail;

    if (cleanInput.contains('@')) {
      authEmail = cleanInput.toLowerCase();
    } else {
      final digits = cleanInput.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 6) {
        throw Exception("Enter a valid Email or Phone Number");
      }
      authEmail = 'phone_$digits@phone.user';
    }

    FirebaseApp? secondaryApp;
    try {
      try {
        secondaryApp = Firebase.app('SecondaryUserCreator');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryUserCreator',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      final uid = cred.user!.uid;
      try {
        await cred.user!.updateDisplayName(cleanCustomId);
      } catch (_) {}
      await secondaryAuth.signOut();

      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': cleanInput.contains('@') ? authEmail : null,
        'phone_optional': cleanInput.contains('@') ? null : cleanInput,
        'userId': cleanCustomId,
        'isActive': true,
        'isSpecialist': false,
        'name': cleanCustomId,
        'fullName': cleanCustomId,
        'displayName': cleanCustomId,
        'createdBy': _auth.currentUser?.uid,
        'createdFrom': 'ADMIN_PANEL',
        'createdAt': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
        'country': 'BD',
        'country_lock': 'BD',
        'location': 'Dhaka',
        'liveLoc': 'Dhaka Central',
        'flag': 'BD',
      });
    } finally {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }
    }
  }

  Map<String, int> computeStats(List<UserModel> list) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));
    final startOfWeek = now.subtract(const Duration(days: 7));
    final startOfMonth = DateTime(now.year, now.month, 1);

    int yesterday = 0;
    int week = 0;
    int month = 0;

    for (final u in list) {
      final dt = u.createdAt;
      if (dt == null) continue;
      if (!dt.isBefore(startOfYesterday) && dt.isBefore(startOfToday)) {
        yesterday++;
      }
      if (!dt.isBefore(startOfWeek)) {
        week++;
      }
      if (!dt.isBefore(startOfMonth)) {
        month++;
      }
    }

    return {
      'total': list.length,
      'yesterday': yesterday,
      'week': week,
      'month': month,
    };
  }

  List<UserModel> filter(List<UserModel> list, String q, String tab) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(const Duration(days: 7));

    var filtered = list;

    if (tab == 'Today') {
      filtered = filtered
          .where((u) => u.createdAt != null && !u.createdAt!.isBefore(startOfToday))
          .toList();
    } else if (tab == 'This Week') {
      filtered = filtered
          .where((u) => u.createdAt != null && !u.createdAt!.isBefore(startOfWeek))
          .toList();
    }

    if (q.trim().isNotEmpty) {
      final query = q.trim().toLowerCase();
      filtered = filtered
          .where(
            (u) =>
                u.name.toLowerCase().contains(query) ||
                u.userId.toLowerCase().contains(query) ||
                u.country.toLowerCase().contains(query) ||
                u.location.toLowerCase().contains(query),
          )
          .toList();
    }
    return filtered;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const UsersApp());
}

class UsersApp extends StatelessWidget {
  const UsersApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AllUsersDashboard(),
    );
  }
}

// ================= PAGE 1: ALL USERS =================
class AllUsersDashboard extends StatefulWidget {
  const AllUsersDashboard({super.key});
  @override
  State<AllUsersDashboard> createState() => _AllUsersDashboardState();
}

class _AllUsersDashboardState extends State<AllUsersDashboard> {
  final UserService _service = UserService();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQ = "";
  String _tab = "All";

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _searchQ = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
              colors: [Color(0xFF000B1E), Color(0xFF0A192F)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          if (Navigator.canPop(context))
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFD4AF37)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  if (Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                            )
                          else
                            const SizedBox(width: 38),
                          const Spacer(),
                          const Text(
                            "All Users",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.cyan, blurRadius: 10),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.cyan.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.cyanAccent),
                            ),
                            child: const Icon(
                              Icons.public,
                              color: Colors.cyanAccent,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: ["All", "Today", "This Week"]
                            .map(
                              (t) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    t,
                                    style: TextStyle(
                                      color: _tab == t
                                          ? Colors.black
                                          : Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  selected: _tab == t,
                                  selectedColor: const Color(0xFF00E5FF),
                                  backgroundColor: Colors.white10,
                                  onSelected: (_) => setState(() => _tab = t),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            icon: const Icon(
                              Icons.search,
                              color: Color(0xFF00E5FF),
                            ),
                            hintText:
                                "Search by User ID, Name, Phone or Country...",
                            hintStyle: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            border: InputBorder.none,
                            suffixIcon: _searchQ.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.white54,
                                    ),
                                    onPressed: () => _searchCtrl.clear(),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<List<UserModel>>(
                        stream: _service.usersStream(),
                        builder: (c, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF00E5FF),
                              ),
                            );
                          }
                          if (snap.hasError) {
                            return Center(
                              child: Text(
                                "Error loading users: ${snap.error}",
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            );
                          }

                          final list = snap.data ?? [];
                          final stats = _service.computeStats(list);
                          final filtered = _service.filter(list, _searchQ, _tab);

                          return Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _chip(
                                      "${stats['total']} Total Users",
                                      Icons.person,
                                      const Color(0xFF00FF88),
                                    ),
                                    _chip(
                                      "${stats['yesterday']} Yesterday",
                                      Icons.access_time,
                                      const Color(0xFF00E5FF),
                                    ),
                                    _chip(
                                      "${stats['week']} This Week",
                                      Icons.calendar_today,
                                      const Color(0xFF00FF88),
                                    ),
                                    _chip(
                                      "${stats['month']} This Month",
                                      Icons.show_chart,
                                      const Color(0xFF00E5FF),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: filtered.isEmpty
                                    ? const Center(
                                        child: Text(
                                          "No Users Found in Firestore",
                                          style: TextStyle(color: Colors.white54),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        itemCount: filtered.length,
                                        itemBuilder: (ctx, i) {
                                          final u = filtered[i];
                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.06,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.cyanAccent
                                                    .withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      backgroundColor: Colors.cyan
                                                          .withValues(alpha: 0.2),
                                                      child: Text(
                                                        u.name.isNotEmpty
                                                            ? u.name[0]
                                                                .toUpperCase()
                                                            : 'U',
                                                        style: const TextStyle(
                                                          color:
                                                              Colors.cyanAccent,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            u.name,
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                          Text(
                                                            u.userId,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              color: Colors
                                                                  .white54,
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white10,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Text(
                                                        u.flag,
                                                        style: const TextStyle(
                                                          color:
                                                              Colors.cyanAccent,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  "${u.location}, ${u.country}",
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on,
                                                      color: Color(0xFF00FF88),
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        "Live Loc. - ${u.liveLoc}",
                                                        style: const TextStyle(
                                                          color:
                                                              Color(0xFF00FF88),
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 6,
                                                  children: [
                                                    _toggleChip(
                                                      "Active",
                                                      u.isActive,
                                                      (v) async {
                                                        try {
                                                          await _service
                                                              .toggleActive(
                                                            u.id,
                                                            v,
                                                          );
                                                        } catch (e) {
                                                          if (mounted) {
                                                            ScaffoldMessenger
                                                                .of(context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  "Failed: $e",
                                                                ),
                                                                backgroundColor:
                                                                    Colors.red,
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      },
                                                    ),
                                                    _toggleChip(
                                                      "Specialist",
                                                      u.isSpecialist,
                                                      (v) async {
                                                        try {
                                                          await _service
                                                              .toggleSpecialist(
                                                            u.id,
                                                            v,
                                                          );
                                                        } catch (e) {
                                                          if (mounted) {
                                                            ScaffoldMessenger
                                                                .of(context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  "Failed: $e",
                                                                ),
                                                                backgroundColor:
                                                                    Colors.red,
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateNewUserPanel()),
          ),
          backgroundColor: const Color(0xFF00E5FF),
          icon: const Icon(Icons.add, color: Colors.black),
          label: const Text(
            "Add New User",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _chip(String t, IconData icon, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 4),
            Text(
              t,
              style: TextStyle(
                color: c,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  Widget _toggleChip(String label, bool val, Function(bool) on) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: val
              ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
              : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: val ? const Color(0xFF00E5FF) : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "$label: ${val ? 'ON' : 'OFF'}",
              style: TextStyle(
                color: val ? const Color(0xFF00E5FF) : Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Switch(
              value: val,
              onChanged: on,
              activeColor: const Color(0xFF00E5FF),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              activeTrackColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
            ),
          ],
        ),
      );
}

// ================= PAGE 2: 3D NEW USER REGISTRATION PANEL =================
class CreateNewUserPanel extends StatefulWidget {
  const CreateNewUserPanel({super.key});
  @override
  State<CreateNewUserPanel> createState() => _CreateNewUserPanelState();
}

class _CreateNewUserPanelState extends State<CreateNewUserPanel> {
  final UserService _service = UserService();
  final _emailCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _userIdCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    final emailOrPhone = _emailCtrl.text.trim();
    final customUserId = _userIdCtrl.text.trim();
    final pass = _passCtrl.text;

    if (emailOrPhone.isEmpty || customUserId.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All fields required"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 6 characters"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _service.createUser(
        emailOrPhone: emailOrPhone,
        customUserId: customUserId,
        password: pass,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User Created & Activated"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? "Failed"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString().replaceAll('Exception: ', '')}"),
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
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A192F), Color(0xFF001A33), Color(0xFF0B2545)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.cyanAccent.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withValues(alpha: 0.2),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.person_add,
                              color: Colors.cyanAccent,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "CREATE NEW USER ACCOUNT (3D PANEL)",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Authorized Access: Super Admin & Sub-Admin Panel",
                          style: TextStyle(
                            color: Color(0xFF00FF88),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _fieldLabel("Gmail Address or Phone Number:"),
                        _build3DField(
                          controller: _emailCtrl,
                          icon: Icons.email,
                          hint: "Enter user Gmail address or Phone Number...",
                        ),
                        const SizedBox(height: 14),
                        _fieldLabel("User ID (System Generated or Custom):"),
                        _build3DField(
                          controller: _userIdCtrl,
                          icon: Icons.badge,
                          hint: "e.g. #U-1004",
                        ),
                        const SizedBox(height: 14),
                        _fieldLabel("Access Password:"),
                        _build3DField(
                          controller: _passCtrl,
                          icon: Icons.lock,
                          hint: "Enter initial account password (min 6 chars)...",
                          isObscure: _obscurePass,
                          isPassword: true,
                          onEye: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                        const SizedBox(height: 24),
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
                                : const Icon(Icons.bolt, color: Colors.white),
                            label: Text(
                              _loading
                                  ? "CREATING..."
                                  : "CREATE & ACTIVATE USER",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A4DA1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 10,
                            ),
                            onPressed: _loading ? null : _create,
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

  Widget _fieldLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          t,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _build3DField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isObscure = false,
    VoidCallback? onEye,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? isObscure : false,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF00E5FF)),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isObscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white54,
                  ),
                  onPressed: onEye,
                )
              : null,
        ),
      ),
    );
  }
}