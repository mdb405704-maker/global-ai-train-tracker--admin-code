import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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

class HackerModel {
  final String id;
  final String deviceModel;
  final String ip;
  final String location;
  final String attackType;
  final String time;
  final bool isBlocked;
  final int sortMillis;

  HackerModel({
    required this.id,
    required this.deviceModel,
    required this.ip,
    required this.location,
    required this.attackType,
    required this.time,
    required this.isBlocked,
    this.sortMillis = 0,
  });

  factory HackerModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final ts = data['timestamp'] is Timestamp ? data['timestamp'] as Timestamp : null;
    String formattedTime = (data['time'] ?? '').toString().trim();
    if (formattedTime.isEmpty && ts != null) {
      final dt = ts.toDate();
      final min = dt.minute.toString().padLeft(2, '0');
      final hr24 = dt.hour;
      final hr12 = hr24 == 0 ? 12 : (hr24 > 12 ? hr24 - 12 : hr24);
      final ampm = hr24 >= 12 ? 'PM' : 'AM';
      formattedTime = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hr12:$min $ampm';
    }
    return HackerModel(
      id: doc.id,
      deviceModel: (data['deviceModel'] ?? 'Unknown Device').toString(),
      ip: (data['ip'] ?? 'Unknown IP').toString(),
      location: (data['location'] ?? 'Unknown Location').toString(),
      attackType: (data['attackType'] ?? 'Suspicious Activity').toString(),
      time: formattedTime.isNotEmpty ? formattedTime : 'N/A',
      isBlocked: data['isBlocked'] == true,
      sortMillis: ts?.millisecondsSinceEpoch ?? 0,
    );
  }
}

class HackerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<HackerModel>> get hackersStream =>
      _db.collection('hackers_list').snapshots().map((snap) {
        final list = snap.docs.map((d) => HackerModel.fromDoc(d)).toList();
        list.sort((a, b) => b.sortMillis.compareTo(a.sortMillis));
        return list;
      });

  Future<void> toggleBlock(String docId, bool isBlocked) async {
    await _db.collection('hackers_list').doc(docId).set({
      'isBlocked': isBlocked,
      'status': isBlocked ? 'Blocked' : 'Monitoring',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('admin_logs').add({
      'action': isBlocked ? 'BLOCK' : 'MONITOR',
      'hackerId': docId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  List<HackerModel> filterSearch(List<HackerModel> list, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where(
          (h) =>
              h.ip.toLowerCase().contains(q) ||
              h.deviceModel.toLowerCase().contains(q) ||
              h.location.toLowerCase().contains(q) ||
              h.time.toLowerCase().contains(q) ||
              h.attackType.toLowerCase().contains(q),
        )
        .toList();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const HackerApp());
}

class HackerApp extends StatelessWidget {
  const HackerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AllHackersListDashboard(),
    );
  }
}

class AllHackersListDashboard extends StatefulWidget {
  const AllHackersListDashboard({super.key});
  @override
  State<AllHackersListDashboard> createState() =>
      _AllHackersListDashboardState();
}

class _AllHackersListDashboardState extends State<AllHackersListDashboard> {
  final HackerService _service = HackerService();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() => _searchQuery = _searchCtrl.text);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleToggleBlock(HackerModel hacker, bool newVal) async {
    try {
      await _service.toggleBlock(hacker.id, newVal);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              newVal
                  ? '${hacker.ip} is now Blocked'
                  : '${hacker.ip} moved to Monitoring',
            ),
            backgroundColor: newVal ? Colors.red.shade700 : Colors.orange.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F8FF),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF0E2A5A),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (Navigator.canPop(context))
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Icon(Icons.shield, color: Color(0xFF4DA3FF), size: 42),
                    const SizedBox(height: 6),
                    const Text(
                      "Security Center",
                      style: TextStyle(color: Color(0xFF8BB8FF), fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "All Hackers List",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9EDF5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.black87, fontSize: 13.5),
                      decoration: InputDecoration(
                        icon: const Icon(Icons.search, color: Colors.black54),
                        hintText: "Search by IP, Device, Location or Date",
                        hintStyle: const TextStyle(color: Colors.black54, fontSize: 13),
                        border: InputBorder.none,
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.black54),
                                onPressed: () => _searchCtrl.clear(),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: StreamBuilder<List<HackerModel>>(
                    stream: _service.hackersStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFF0E2A5A)),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              "Error loading security logs: ${snapshot.error}",
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final list = snapshot.data ?? [];
                      final filtered = _service.filterSearch(list, _searchQuery);

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 56,
                                color: Colors.blueGrey.withValues(alpha: 0.45),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _searchQuery.isEmpty
                                    ? "No security threats or hacker attempts detected"
                                    : "No matching threats found for '$_searchQuery'",
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final hacker = filtered[index];
                          final bool isBlocked = hacker.isBlocked;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isBlocked
                                  ? Colors.white
                                  : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isBlocked
                                    ? const Color(0xFFE0E0E0)
                                    : const Color(0xFFFFB74D).withValues(alpha: 0.5),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isBlocked
                                        ? const Color(0xFFFFEBEE)
                                        : const Color(0xFFFFE0B2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isBlocked
                                        ? Icons.warning_amber_rounded
                                        : Icons.wifi_tethering,
                                    color: isBlocked ? Colors.red : Colors.orange,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Device Model: ${hacker.deviceModel}",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        "IP Address: ${hacker.ip}",
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        "Location: ${hacker.location}",
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        "Attack Type: ${hacker.attackType}",
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        "Time: ${hacker.time}",
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  children: [
                                    Switch(
                                      value: isBlocked,
                                      activeColor: Colors.white,
                                      activeTrackColor: const Color(0xFFD32F2F),
                                      inactiveThumbColor: Colors.white,
                                      inactiveTrackColor: Colors.grey.shade400,
                                      onChanged: (v) =>
                                          _handleToggleBlock(hacker, v),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isBlocked ? "Blocked" : "Monitoring",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isBlocked ? Colors.red : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
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