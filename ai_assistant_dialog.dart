import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============= FIREBASE CONFIG - YOUR ORIGINAL =============
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

// ============= MODELS - SAFE PARSING =============
class FeatureModel {
  final String id;
  final String name;
  final String apiKey;
  final int used;
  final int quota;
  final double cost;
  final bool isOn;
  final String type;
  final String status;

  FeatureModel({
    required this.id,
    required this.name,
    required this.apiKey,
    required this.used,
    required this.quota,
    required this.cost,
    required this.isOn,
    required this.type,
    required this.status,
  });

  factory FeatureModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final rawStatus = (d['status'] ?? 'Active').toString();
    final safeStatus = const ['Active', 'Offline', 'Pending'].contains(rawStatus)
        ? rawStatus
        : 'Active';
    return FeatureModel(
      id: doc.id,
      name: (d['name'] ?? doc.id).toString(),
      apiKey: (d['apiKey'] ?? '').toString(),
      used: (d['used'] as num?)?.toInt() ?? 0,
      quota: (d['quota'] as num?)?.toInt() ?? 10000,
      cost: (d['cost'] as num?)?.toDouble() ?? 0.0,
      isOn: d['isOn'] == true,
      type: (d['type'] ?? 'user_app').toString(),
      status: safeStatus,
    );
  }
}

class TrainModel {
  final String id;
  final String name;
  final String country;
  final String routeMap;
  final String speed;
  final String capacity;
  final String nextStop;

  TrainModel({
    required this.id,
    required this.name,
    required this.country,
    required this.routeMap,
    required this.speed,
    required this.capacity,
    required this.nextStop,
  });

  factory TrainModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return TrainModel(
      id: doc.id,
      name: (d['name'] ?? '').toString(),
      country: (d['country'] ?? '').toString(),
      routeMap: (d['routeMap'] ?? '').toString(),
      speed: (d['speed'] ?? '80 km/h').toString(),
      capacity: (d['capacity'] ?? '75% Full').toString(),
      nextStop: (d['nextStop'] ?? 'Central Station').toString(),
    );
  }
}

class SupportChatModel {
  final String id;
  final String userId;
  final String message;
  final String lang;
  final bool aiMode;
  final Timestamp? lastAdminReplyAt;
  final Timestamp? updatedAt;

  SupportChatModel({
    required this.id,
    required this.userId,
    required this.message,
    required this.lang,
    required this.aiMode,
    this.lastAdminReplyAt,
    this.updatedAt,
  });

  factory SupportChatModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SupportChatModel(
      id: doc.id,
      userId: (d['userId'] ?? d['userName'] ?? doc.id).toString(),
      message: (d['lastMessage'] ?? '').toString(),
      lang: (d['lang'] ?? 'en').toString(),
      aiMode: d['aiMode'] == true,
      lastAdminReplyAt: d['lastAdminReplyAt'] is Timestamp
          ? d['lastAdminReplyAt'] as Timestamp
          : null,
      updatedAt: d['updatedAt'] is Timestamp ? d['updatedAt'] as Timestamp : null,
    );
  }
}

// ============= ADMIN SERVICE - V24.1 GLOBAL FIXED =============
class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<FeatureModel>> featuresStream() => _db
      .collection('feature_flags')
      .snapshots()
      .map((s) => s.docs.map((d) => FeatureModel.fromDoc(d)).toList());

  Stream<List<TrainModel>> trainsStream() => _db
      .collection('trains')
      .snapshots()
      .map((s) => s.docs.map((d) => TrainModel.fromDoc(d)).toList());

  Stream<List<SupportChatModel>> supportChatsStream() => _db
      .collection('support_chats')
      .snapshots()
      .map((s) {
        final list = s.docs.map((d) => SupportChatModel.fromDoc(d)).toList();
        list.sort((a, b) {
          final ta = (a.updatedAt ?? a.lastAdminReplyAt)?.millisecondsSinceEpoch ?? 0;
          final tb = (b.updatedAt ?? b.lastAdminReplyAt)?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });
        return list;
      });

  Future<Map<String, dynamic>> aiQueryResolver({required String query}) async {
    final bool isBn = RegExp(r'[\u0980-\u09FF]').hasMatch(query);
    final String lang = isBn ? 'bn' : 'en';

    try {
      await _db.collection('admin_query_logs').add({
        'adminId': _auth.currentUser?.email ?? 'admin',
        'query': query,
        'lang': lang,
        'platform': 'ADMIN_APP',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    final snap = await _db.collection('trains').limit(50).get();
    final qLower = query.toLowerCase();
    TrainModel? matched;

    for (final doc in snap.docs) {
      final t = TrainModel.fromDoc(doc);
      if (t.name.toLowerCase().contains(qLower) ||
          t.routeMap.toLowerCase().contains(qLower) ||
          t.country.toLowerCase().contains(qLower) ||
          t.nextStop.toLowerCase().contains(qLower)) {
        matched = t;
        break;
      }
    }

    matched ??= snap.docs.isNotEmpty ? TrainModel.fromDoc(snap.docs.first) : null;

    final String responseText = matched != null
        ? 'Response: ${matched.name} (${matched.country}) is moving at ${matched.speed}. Next Stop: ${matched.nextStop}. Capacity: ${matched.capacity}.'
        : 'No matching train found in Firestore "trains" collection for "$query". Total trains in DB: ${snap.docs.length}.';

    return {
      'response': responseText,
      'train': matched,
      'model': 'Gemini Pro (Model 1 of 5)',
      'lang': lang,
    };
  }

  Future<void> toggleFeature(String id, bool val, String status) async {
    await _db.collection('feature_flags').doc(id).set({
      'isOn': val,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.email ?? 'admin',
    }, SetOptions(merge: true));
  }

  Future<void> applyChanges() async {
    final email = _auth.currentUser?.email ?? 'admin';
    await _db.collection('remote_config_logs').add({
      'action': 'APPLY_FEATURE_CHANGES',
      'performedBy': email,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await _db.collection('admin_logs').add({
      'action': 'APPLY_FEATURE_CHANGES',
      'performedBy': email,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addTrain({
    required String country,
    required String routeMap,
    required String speed,
    required String capacity,
    required String nextStop,
  }) async {
    final firstLine = routeMap.split('\n').first.trim();
    await _db.collection('trains').add({
      'name': firstLine.isNotEmpty ? firstLine : 'Express Train',
      'country': country,
      'routeMap': routeMap,
      'speed': speed,
      'capacity': capacity,
      'nextStop': nextStop,
      'createdAt': FieldValue.serverTimestamp(),
      'addedBy': _auth.currentUser?.email ?? 'admin',
    });
  }

  Future<void> deleteTrain(String trainId) async =>
      await _db.collection('trains').doc(trainId).delete();

  Future<void> saveVideo({
    required String videoUrl,
    required String targetPage,
    required String type,
  }) async =>
      await _db.collection('app_videos').add({
        'videoUrl': videoUrl,
        'targetPage': targetPage,
        'type': type,
        'platform': 'APK/WEB',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.email ?? 'admin',
      });

  Future<void> checkAndTriggerAIMode(String chatId) async {
    final doc = await _db.collection('support_chats').doc(chatId).get();
    if (!doc.exists) return;
    final data = doc.data() ?? {};
    final lastReply = data['lastAdminReplyAt'] as Timestamp?;
    final created = data['updatedAt'] as Timestamp?;
    final refTime = lastReply ?? created;
    if (refTime == null) return;

    final diff = DateTime.now().difference(refTime.toDate()).inMinutes;
    if (diff >= 2 && !(data['aiMode'] == true)) {
      await _db.collection('support_chats').doc(chatId).set({
        'aiMode': true,
        'aiTriggeredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _db.collection('support_chats').doc(chatId).collection('messages').add({
        'sender': 'AI_SUPPORT',
        'text':
            'I am AI Support. For your issue:\n- Check ticket\n- View live location\n- Call helpline',
        'timestamp': FieldValue.serverTimestamp(),
        'lang': data['lang'] ?? 'en',
      });
    }
  }

  Future<void> adminReply(String chatId, String text) async {
    await _db.collection('support_chats').doc(chatId).set({
      'aiMode': false,
      'lastMessage': text,
      'lastAdminReplyAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _db.collection('support_chats').doc(chatId).collection('messages').add({
      'sender': 'admin',
      'text': text,
      'imageUrl': '',
      'timestamp': FieldValue.serverTimestamp(),
      'adminId': _auth.currentUser?.email ?? 'admin',
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Screen0AdminLaunchpad(),
    ),
  );
}

// ============= PART 3: ADMIN LAUNCHPAD - SCREEN 0 =============
class Screen0AdminLaunchpad extends StatelessWidget {
  const Screen0AdminLaunchpad({super.key});

  Widget _card(
    BuildContext context,
    String title,
    String sub,
    IconData icon,
    VoidCallback onTap,
  ) =>
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(18),
          leading: Icon(icon, color: Colors.cyanAccent, size: 32),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            sub,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            color: Colors.white38,
            size: 16,
          ),
          onTap: onTap,
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF000B1E),
                Color(0xFF0A192F),
                Color(0xFF001A33),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.train, color: Colors.cyanAccent),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "GLOBAL AI TRAIN TRACKER - ADMIN LAUNCHPAD V24.1",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _card(
                    context,
                    "INTELLIGENT QUERY RESOLVER",
                    "AI ASSISTANT & LIVE SUPPORT - PART 1 & 2",
                    Icons.smart_toy,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IntelligentQueryResolverScreen(),
                      ),
                    ),
                  ),
                  _card(
                    context,
                    "FEATURE CONTROL",
                    "API GATEWAY + ADMIN AI LIMIT",
                    Icons.settings,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Page1FeatureControl(),
                      ),
                    ),
                  ),
                  _card(
                    context,
                    "ADD NEW TRAIN",
                    "GLOBAL 200+ COUNTRIES ROUTE MANAGEMENT",
                    Icons.add_road,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Page2AddNewTrain(),
                      ),
                    ),
                  ),
                  _card(
                    context,
                    "USER LOGIN & REGISTRATION VIDEO",
                    "SEND VIDEO TO USERS APK/WEB",
                    Icons.video_library,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Page3VideoGateway(),
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

// ============= PART 1: ADMIN CONTROL - INTELLIGENT QUERY RESOLVER =============
class IntelligentQueryResolverScreen extends StatefulWidget {
  const IntelligentQueryResolverScreen({super.key});
  @override
  State<IntelligentQueryResolverScreen> createState() =>
      _IntelligentQueryResolverScreenState();
}

class _IntelligentQueryResolverScreenState
    extends State<IntelligentQueryResolverScreen> {
  final AdminService _service = AdminService();
  final TextEditingController _aiCtrl = TextEditingController();
  Map<String, dynamic>? _aiResult;
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _aiCtrl.dispose();
    super.dispose();
  }

  void _onAIChanged(String v) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final q = v.trim();
      if (q.isEmpty || !mounted) return;
      setState(() => _isSearching = true);
      try {
        final res = await _service.aiQueryResolver(query: q);
        if (mounted) {
          setState(() => _aiResult = res);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Query error: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _showMoreTrainData() {
    final TrainModel? train = _aiResult?['train'] as TrainModel?;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A192F),
        title: Text(
          train?.name ?? 'Train Route Details',
          style: const TextStyle(color: Colors.cyanAccent, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Text(
            train != null
                ? 'Country: ${train.country}\nSpeed: ${train.speed}\nCapacity: ${train.capacity}\nNext Stop: ${train.nextStop}\n\nFull Route Map:\n${train.routeMap}'
                : 'No additional train route data available.',
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(SupportChatModel chat) {
    final replyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A192F),
        title: Text(
          "Reply to ${chat.userId}",
          style: const TextStyle(color: Colors.cyanAccent, fontSize: 15),
        ),
        content: TextField(
          controller: replyCtrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Write admin reply...",
            hintStyle: TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.black26,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF)),
            onPressed: () async {
              final text = replyCtrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              await _service.adminReply(chat.id, text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Admin reply sent"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text("Send", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    ).then((_) => replyCtrl.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF000B1E), Color(0xFF0A192F)],
            ),
          ),
          child: SafeArea(
            child: isWeb
                ? Row(
                    children: [
                      Expanded(
                        flex: 7,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(14),
                          child: _buildMain(context),
                        ),
                      ),
                      Container(width: 1, color: Colors.white10),
                      Expanded(flex: 3, child: _buildSidePanel()),
                    ],
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: _buildMain(context),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMain(BuildContext context) {
    final TrainModel? train = _aiResult?['train'] as TrainModel?;

    return Column(
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
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Admin Control",
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    "Intelligent Query Resolver",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.smart_toy, color: Colors.cyanAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _aiCtrl,
                  onChanged: _onAIChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText:
                        "Ask AI Assistant (e.g., \"Find Dhaka-to-Chittagong train\")...",
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_isSearching)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.cyanAccent,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_aiResult != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.greenAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.train, color: Colors.greenAccent, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Train Info (${train?.name ?? 'No Train Matched'})",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _infoChip("Speed", train?.speed ?? "N/A"),
                    const SizedBox(width: 8),
                    _infoChip("Capacity", train?.capacity ?? "N/A"),
                    const SizedBox(width: 8),
                    _infoChip("Next", train?.nextStop ?? "N/A"),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFF0A2A4A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.orangeAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_pin, color: Colors.redAccent, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      train != null
                          ? "Route: ${train.country} - Next: ${train.nextStop}"
                          : "OpenStreetMap Route Preview",
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      height: 3,
                      width: 180,
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _aiResult!['response'] ?? "",
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  "Response powered by: ${_aiResult!['model']} (Admin Note: Model 1 to 5 available in Firebase)",
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _showMoreTrainData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A4DA1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    "SEARCH MORE DATA",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    "Close",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 40),
          const Center(
            child: Column(
              children: [
                Icon(Icons.search, color: Colors.white24, size: 48),
                SizedBox(height: 12),
                Text(
                  "Type in AI Assistant box to search Firebase instantly",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          "Live Support Chats - 2 Min Auto AI Mode",
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<SupportChatModel>>(
          stream: _service.supportChatsStream(),
          builder: (c, snap) {
            if (snap.hasError) {
              return Text(
                "Chat load error: ${snap.error}",
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              );
            }
            if (!snap.hasData) return const SizedBox();
            final list = snap.data!;
            if (list.isEmpty) {
              return const Text(
                "No live chats",
                style: TextStyle(color: Colors.white38, fontSize: 11),
              );
            }
            return Column(
              children: list.take(5).map((chat) {
                return InkWell(
                  onTap: () => _showReplyDialog(chat),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: chat.aiMode
                            ? Colors.orangeAccent.withValues(alpha: 0.4)
                            : Colors.white10,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${chat.userId}: ${chat.message}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: chat.aiMode
                                ? Colors.orangeAccent.withValues(alpha: 0.2)
                                : Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            chat.aiMode ? "AI MODE - 2min" : "ADMIN",
                            style: TextStyle(
                              color: chat.aiMode
                                  ? Colors.orangeAccent
                                  : Colors.greenAccent,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: "Reply",
                          icon: const Icon(
                            Icons.reply,
                            color: Colors.cyanAccent,
                            size: 16,
                          ),
                          onPressed: () => _showReplyDialog(chat),
                        ),
                        IconButton(
                          tooltip: "Check 2-min AI Trigger",
                          icon: const Icon(
                            Icons.timer,
                            color: Colors.white38,
                            size: 16,
                          ),
                          onPressed: () =>
                              _service.checkAndTriggerAIMode(chat.id),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSidePanel() => Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text(
              "AI Command Palette (Cmd+K) - WEB",
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "admin.globaltraintracker.com/query-resolver - 2-pane 70/30",
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ],
        ),
      );

  Widget _infoChip(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 8),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
}

// ============= PAGE 1: FEATURE CONTROL =============
class Page1FeatureControl extends StatefulWidget {
  const Page1FeatureControl({super.key});
  @override
  State<Page1FeatureControl> createState() => _Page1FeatureControlState();
}

class _Page1FeatureControlState extends State<Page1FeatureControl> {
  final AdminService _service = AdminService();
  final _searchCtrl = TextEditingController();
  String _q = "";

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() => _q = _searchCtrl.text.trim().toLowerCase());
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF000B1E), Color(0xFF0A192F)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            "Feature Control & API Gateway",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Search features...",
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<List<FeatureModel>>(
                      stream: _service.featuresStream(),
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
                              "Error: ${snap.error}",
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          );
                        }
                        if (!snap.hasData || snap.data!.isEmpty) {
                          return const Center(
                            child: Text(
                              "No features - Add in Firestore: feature_flags",
                              style: TextStyle(color: Colors.white54),
                            ),
                          );
                        }
                        var list = snap.data!;
                        if (_q.isNotEmpty) {
                          list = list
                              .where((f) => f.name.toLowerCase().contains(_q))
                              .toList();
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: list.length,
                          itemBuilder: (ctx, i) {
                            final f = list[i];
                            final bool isAdmin = f.type == 'admin_app';
                            final progress = f.quota > 0
                                ? (f.used / f.quota).clamp(0.0, 1.0)
                                : 0.0;
                            final maskedKey = f.apiKey.length > 4
                                ? f.apiKey.substring(f.apiKey.length - 4)
                                : '****';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isAdmin
                                    ? const Color(0xFF1A0A2E).withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isAdmin
                                      ? Colors.purpleAccent.withValues(alpha: 0.4)
                                      : Colors.cyanAccent.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isAdmin
                                            ? Icons.admin_panel_settings
                                            : Icons.settings,
                                        color: isAdmin
                                            ? Colors.purpleAccent
                                            : Colors.cyanAccent,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          f.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      DropdownButton<String>(
                                        value: f.status,
                                        dropdownColor: const Color(0xFF0A192F),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: "Active",
                                            child: Text("Active"),
                                          ),
                                          DropdownMenuItem(
                                            value: "Offline",
                                            child: Text("Offline"),
                                          ),
                                          DropdownMenuItem(
                                            value: "Pending",
                                            child: Text("Pending"),
                                          ),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) {
                                            _service.toggleFeature(f.id, f.isOn, v);
                                          }
                                        },
                                        underline: const SizedBox(),
                                      ),
                                      Switch(
                                        value: f.isOn,
                                        onChanged: (v) => _service.toggleFeature(
                                          f.id,
                                          v,
                                          f.status,
                                        ),
                                        activeColor: isAdmin
                                            ? Colors.purpleAccent
                                            : const Color(0xFF00E5FF),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "API: ********$maskedKey   Cost: \$${f.cost.toStringAsFixed(2)} | ${f.used}/${f.quota}",
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white10,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isAdmin
                                          ? Colors.purpleAccent
                                          : const Color(0xFF00E5FF),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await _service.applyChanges();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "APPLIED - Remote Config & Firestore Updated - Instant APK/WEB",
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Apply failed: $e"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A4DA1),
                        ),
                        child: const Text(
                          "APPLY CHANGES",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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

// ============= PAGE 2: ADD NEW TRAIN (GLOBAL 205 COUNTRIES) =============
class Page2AddNewTrain extends StatefulWidget {
  const Page2AddNewTrain({super.key});
  @override
  State<Page2AddNewTrain> createState() => _Page2AddNewTrainState();
}

class _Page2AddNewTrainState extends State<Page2AddNewTrain> {
  final AdminService _service = AdminService();
  final _searchCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  String _selectedCountry = "Bangladesh";
  String _searchQ = "";
  bool _adding = false;

  static const List<String> _countries = [
    "Global (All Countries)",
    "Afghanistan",
    "Albania",
    "Algeria",
    "Andorra",
    "Angola",
    "Antigua and Barbuda",
    "Argentina",
    "Armenia",
    "Australia",
    "Austria",
    "Azerbaijan",
    "Bahamas",
    "Bahrain",
    "Bangladesh",
    "Barbados",
    "Belarus",
    "Belgium",
    "Belize",
    "Benin",
    "Bhutan",
    "Bolivia",
    "Bosnia and Herzegovina",
    "Botswana",
    "Brazil",
    "Brunei",
    "Bulgaria",
    "Burkina Faso",
    "Burundi",
    "Cabo Verde",
    "Cambodia",
    "Cameroon",
    "Canada",
    "Central African Republic",
    "Chad",
    "Chile",
    "China",
    "Colombia",
    "Comoros",
    "Congo",
    "Congo (DRC)",
    "Costa Rica",
    "Cote d'Ivoire",
    "Croatia",
    "Cuba",
    "Cyprus",
    "Czech Republic",
    "Denmark",
    "Djibouti",
    "Dominica",
    "Dominican Republic",
    "Ecuador",
    "Egypt",
    "El Salvador",
    "Equatorial Guinea",
    "Eritrea",
    "Estonia",
    "Eswatini",
    "Ethiopia",
    "Fiji",
    "Finland",
    "France",
    "French Guiana",
    "Gabon",
    "Gambia",
    "Georgia",
    "Germany",
    "Ghana",
    "Greece",
    "Greenland",
    "Grenada",
    "Guatemala",
    "Guinea",
    "Guinea-Bissau",
    "Guyana",
    "Haiti",
    "Honduras",
    "Hong Kong",
    "Hungary",
    "Iceland",
    "India",
    "Indonesia",
    "Iran",
    "Iraq",
    "Ireland",
    "Israel",
    "Italy",
    "Jamaica",
    "Japan",
    "Jordan",
    "Kazakhstan",
    "Kenya",
    "Kiribati",
    "Korea (North)",
    "Korea (South)",
    "Kosovo",
    "Kuwait",
    "Kyrgyzstan",
    "Laos",
    "Latvia",
    "Lebanon",
    "Lesotho",
    "Liberia",
    "Libya",
    "Liechtenstein",
    "Lithuania",
    "Luxembourg",
    "Macau",
    "Madagascar",
    "Malawi",
    "Malaysia",
    "Maldives",
    "Mali",
    "Malta",
    "Marshall Islands",
    "Mauritania",
    "Mauritius",
    "Mexico",
    "Micronesia",
    "Moldova",
    "Monaco",
    "Mongolia",
    "Montenegro",
    "Morocco",
    "Mozambique",
    "Myanmar",
    "Namibia",
    "Nauru",
    "Nepal",
    "Netherlands",
    "New Zealand",
    "Nicaragua",
    "Niger",
    "Nigeria",
    "North Macedonia",
    "Norway",
    "Oman",
    "Pakistan",
    "Palau",
    "Palestine",
    "Panama",
    "Papua New Guinea",
    "Paraguay",
    "Peru",
    "Philippines",
    "Poland",
    "Portugal",
    "Puerto Rico",
    "Qatar",
    "Reunion",
    "Romania",
    "Russia",
    "Rwanda",
    "Saint Kitts and Nevis",
    "Saint Lucia",
    "Saint Vincent and the Grenadines",
    "Samoa",
    "San Marino",
    "Sao Tome and Principe",
    "Saudi Arabia",
    "Senegal",
    "Serbia",
    "Seychelles",
    "Sierra Leone",
    "Singapore",
    "Slovakia",
    "Slovenia",
    "Solomon Islands",
    "Somalia",
    "South Africa",
    "South Sudan",
    "Spain",
    "Sri Lanka",
    "Sudan",
    "Suriname",
    "Sweden",
    "Switzerland",
    "Syria",
    "Taiwan",
    "Tajikistan",
    "Tanzania",
    "Thailand",
    "Timor-Leste",
    "Togo",
    "Tonga",
    "Trinidad and Tobago",
    "Tunisia",
    "Turkey",
    "Turkmenistan",
    "Tuvalu",
    "Uganda",
    "Ukraine",
    "United Arab Emirates",
    "United Kingdom",
    "United States",
    "Uruguay",
    "Uzbekistan",
    "Vanuatu",
    "Vatican City",
    "Venezuela",
    "Vietnam",
    "Yemen",
    "Zambia",
    "Zimbabwe",
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _searchQ = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _routeCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmAndDeleteTrain(TrainModel t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A192F),
        title: const Text(
          "Delete Train?",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "Delete ${t.name} (${t.country})?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _service.deleteTrain(t.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Train deleted"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Delete failed: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF000B1E), Color(0xFF0A192F)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            "New Train Management & Global Route Search",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Search train or country...",
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedCountry,
                          isExpanded: true,
                          menuMaxHeight: 350,
                          dropdownColor: const Color(0xFF0A192F),
                          style: const TextStyle(color: Colors.white),
                          items: _countries
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.public,
                                        color: Colors.cyanAccent,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          c,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedCountry = v);
                          },
                          decoration: InputDecoration(
                            labelText: "Select Country (Global 200+)",
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _routeCtrl,
                          maxLines: 4,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: "Add Full Route Map & Schedule...",
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _adding
                                ? null
                                : () async {
                                    final routeText = _routeCtrl.text.trim();
                                    if (routeText.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Please enter train route map"),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    FocusScope.of(context).unfocus();
                                    setState(() => _adding = true);
                                    try {
                                      await _service.addTrain(
                                        country: _selectedCountry,
                                        routeMap: routeText,
                                        speed: "80 km/h",
                                        capacity: "75% Full",
                                        nextStop: "Central Station",
                                      );
                                      _routeCtrl.clear();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Train Added Instantly - APK/WEB Updated",
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("Failed: $e"),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (mounted) setState(() => _adding = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E5FF),
                            ),
                            child: Text(
                              _adding ? "ADDING..." : "CONFIRM",
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
                  Expanded(
                    child: StreamBuilder<List<TrainModel>>(
                      stream: _service.trainsStream(),
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
                              "Error: ${snap.error}",
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          );
                        }
                        var list = snap.data ?? [];
                        if (_searchQ.isNotEmpty) {
                          list = list
                              .where(
                                (t) =>
                                    t.name
                                        .toLowerCase()
                                        .contains(_searchQ.toLowerCase()) ||
                                    t.country
                                        .toLowerCase()
                                        .contains(_searchQ.toLowerCase()),
                              )
                              .toList();
                        }
                        if (list.isEmpty) {
                          return const Center(
                            child: Text(
                              "No trains found",
                              style: TextStyle(color: Colors.white54),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: list.length,
                          itemBuilder: (ctx, i) {
                            final t = list[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.cyanAccent.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.train, color: Colors.cyanAccent),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Train: ${t.name} | ${t.country} | ${t.speed}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _confirmAndDeleteTrain(t),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.delete_forever, size: 14),
                                    label: const Text(
                                      "DELETE",
                                      style: TextStyle(fontSize: 9.5),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ============= PAGE 3: VIDEO GATEWAY =============
class Page3VideoGateway extends StatefulWidget {
  const Page3VideoGateway({super.key});
  @override
  State<Page3VideoGateway> createState() => _Page3VideoGatewayState();
}

class _Page3VideoGatewayState extends State<Page3VideoGateway> {
  final AdminService _service = AdminService();
  final _urlCtrl = TextEditingController();
  String _targetPage = "Login Page Video";
  String _type = "youtube";
  bool _loading = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    final url = _urlCtrl.text.trim();
    if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid video URL starting with http:// or https://"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _service.saveVideo(
        videoUrl: url,
        targetPage: _targetPage,
        type: _type,
      );
      _urlCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Video Saved - Live Update APK/WEB without Play Store update",
            ),
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF000B1E), Color(0xFF0A192F)],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            "Login & Registration Video Gateway",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _urlCtrl,
                      keyboardType: TextInputType.url,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: "YouTube / Cloud Video URL (https://...)",
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _targetPage,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF0A192F),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(
                          value: "Login Page Video",
                          child: Text("Login Page Video"),
                        ),
                        DropdownMenuItem(
                          value: "Registration Page Video",
                          child: Text("Registration Page Video"),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _targetPage = v);
                      },
                      decoration: InputDecoration(
                        labelText: "Target Screen",
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _type,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF0A192F),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: "youtube", child: Text("YouTube")),
                        DropdownMenuItem(value: "mp4", child: Text("Direct MP4 / Cloud")),
                        DropdownMenuItem(value: "vimeo", child: Text("Vimeo")),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _type = v);
                      },
                      decoration: InputDecoration(
                        labelText: "Video Source Type",
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                        ),
                        child: Text(
                          _loading ? "SAVING..." : "OK - SAVE VIDEO",
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
            ),
          ),
        ),
      );
}