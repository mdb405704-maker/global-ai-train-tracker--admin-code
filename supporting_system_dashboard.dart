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

const String ownerEmail = "mdbelalhossen2029@gmail.com";

class ProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool get isOwner =>
      (_auth.currentUser?.email ?? '').trim().toLowerCase() ==
      ownerEmail.toLowerCase();

  String? get currentUserEmail => _auth.currentUser?.email;

  Stream<DocumentSnapshot> adminProfileStream() =>
      _db.collection('admin_profile').doc('main').snapshots();

  Stream<QuerySnapshot> chatMessagesStream(String chatId) => _db
      .collection('support_chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp')
      .snapshots();

  Future<void> updateAdminProfile(Map<String, dynamic> data) async {
    await _db.collection('admin_profile').doc('main').set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.email ?? 'admin',
    }, SetOptions(merge: true));
  }

  Future<void> sendMessage(String chatId, Map<String, dynamic> msg) async {
    final chatRef = _db.collection('support_chats').doc(chatId);
    await chatRef.set({
      'lastMessage': msg['text'] ?? '',
      'lastAdminReplyAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await chatRef.collection('messages').add({
      ...msg,
      'sender': _auth.currentUser?.email ?? 'admin',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> isolatedUserUpdate(
    String userIdOrEmail,
    Map<String, dynamic> patch,
  ) async {
    final target = userIdOrEmail.trim();
    if (patch.containsKey('sendResetEmail') && target.contains('@')) {
      await _auth.sendPasswordResetEmail(email: target);
      return;
    }
    await _db.collection('users').doc(target).set({
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.email ?? 'admin',
    }, SetOptions(merge: true));
  }

  Future<void> requestAdminPasswordReset(String newPass) async {
    if (!isOwner) {
      await _db.collection('security_alerts').add({
        'type': 'ADMIN_PASS_TRY',
        'requester': _auth.currentUser?.email ?? 'unknown',
        'time': FieldValue.serverTimestamp(),
        'status': 'BLOCKED',
      });
      throw Exception("ENTRY RESTRICTED TO ONLY MD BELAL HOSSEN");
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("Owner must be logged in to change password");
    }

    await user.updatePassword(newPass);

    await _db.collection('admin_profile').doc('main').set({
      'passwordUpdatedAt': FieldValue.serverTimestamp(),
      'updatedBy': ownerEmail,
    }, SetOptions(merge: true));
  }

  Future<void> triggerSecurityAlert(String requester) async {
    await _db.collection('security_alerts').add({
      'requester': requester,
      'ownerEmail': ownerEmail,
      'type': 'BYPASS_ATTEMPT',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProfileSupportApp());
}

class ProfileSupportApp extends StatelessWidget {
  const ProfileSupportApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Page1ProfileSupportSystem(),
    );
  }
}

// ================= PAGE 1: PROFILE & SUPPORT SYSTEM =================
class Page1ProfileSupportSystem extends StatelessWidget {
  const Page1ProfileSupportSystem({super.key});

  Widget _module(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.25)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.cyanAccent),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        trailing: trailing ??
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF000B1E), Color(0xFF0A192F)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (Navigator.canPop(context))
                          Container(
                            margin: const EdgeInsets.only(right: 12),
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
                            "Profile & Support System",
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.cyan, blurRadius: 10)],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _module(
                      context,
                      "Live Chat",
                      "Instant Support Access",
                      Icons.chat_bubble,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const Page2LiveChat()),
                      ),
                    ),
                    _module(
                      context,
                      "User Password Reset",
                      "Standard Password Recovery & Limit Control",
                      Icons.lock_reset,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const Page3UserSecurity(),
                        ),
                      ),
                    ),
                    _module(
                      context,
                      "Admin Password Reset",
                      "Secure Recovery Process - Owner Exclusive",
                      Icons.admin_panel_settings,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const Page4AdminExclusive(),
                        ),
                      ),
                      trailing: const Icon(
                        Icons.lock,
                        color: Colors.amber,
                        size: 18,
                      ),
                    ),
                    _module(
                      context,
                      "Mobile Number",
                      "Edit Action - Instant Backend Sync",
                      Icons.phone,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const Page5LiveEdit()),
                      ),
                    ),
                    _module(
                      context,
                      "Gmail Address",
                      "Edit Action - Instant Backend Sync",
                      Icons.email,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const Page5LiveEdit(isGmail: true),
                        ),
                      ),
                    ),
                    _module(
                      context,
                      "Global App Language (Admin App Only)",
                      "200+ Countries & Languages - Admin interface only",
                      Icons.language,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const Page6LanguageEngine(),
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
    );
  }
}

// ================= PAGE 2: REALTIME LIVE CHAT =================
class Page2LiveChat extends StatefulWidget {
  final String chatId;
  final String userTitle;

  const Page2LiveChat({
    super.key,
    this.chatId = "chat_US-89234",
    this.userTitle = "John Doe / #US-89234",
  });

  @override
  State<Page2LiveChat> createState() => _Page2LiveChatState();
}

class _Page2LiveChatState extends State<Page2LiveChat> {
  final ProfileService _service = ProfileService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _msgCtrl.clear();
    setState(() => _sending = true);
    try {
      await _service.sendMessage(widget.chatId, {'text': text, 'type': 'text'});
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Send failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A192F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0E2A5A),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Admin Live Support: [${widget.userTitle}]",
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
              const Row(
                children: [
                  Icon(Icons.public, color: Color(0xFF00FF88), size: 12),
                  SizedBox(width: 4),
                  Text(
                    "GLOBAL LIVE SUPPORT (ACTIVE)",
                    style: TextStyle(fontSize: 10, color: Color(0xFF00FF88)),
                  ),
                ],
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: isWeb
            ? Row(
                children: [
                  Expanded(flex: 70, child: _chatBody()),
                  Container(
                    width: 300,
                    color: Colors.white.withValues(alpha: 0.05),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          "User Info Sidebar\n${widget.userTitle}\nChat ID: ${widget.chatId}",
                          style: const TextStyle(color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : _chatBody(),
      ),
    );
  }

  Widget _chatBody() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _service.chatMessagesStream(widget.chatId),
            builder: (c, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    "Error loading chat: ${snap.error}",
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }
              final msgs = snap.data?.docs ?? [];
              if (msgs.isEmpty) {
                return const Center(
                  child: Text(
                    "No messages in this chat yet",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: msgs.length,
                itemBuilder: (ctx, i) {
                  final m = msgs[i].data() as Map<String, dynamic>? ?? {};
                  final sender = (m['sender'] ?? '').toString();
                  final isMe = sender == _service.currentUserEmail ||
                      sender == 'admin' ||
                      sender == 'ADMIN';
                  final text = (m['text'] ?? '').toString();

                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.22)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        text,
                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
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
                  controller: _msgCtrl,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: "Type message...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white10,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              CircleAvatar(
                backgroundColor: const Color(0xFF00E5FF),
                child: IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.black, size: 18),
                  onPressed: _sending ? null : _send,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================= PAGE 3: USER SECURITY & ISOLATED GATEWAY =================
class Page3UserSecurity extends StatefulWidget {
  const Page3UserSecurity({super.key});
  @override
  State<Page3UserSecurity> createState() => _Page3UserSecurityState();
}

class _Page3UserSecurityState extends State<Page3UserSecurity> {
  final ProfileService _service = ProfileService();
  final _userIdCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  String _selectedFeature = "Railway Smart System";
  bool _saving = false;

  final List<String> _features = const [
    "Railway Smart System",
    "E-Ticket",
    "AI Assistant",
    "Live Tracking",
    "History",
    "Premium",
  ];

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _isolatedUpdate(String field) async {
    if (_saving) return;
    FocusScope.of(context).unfocus();

    final userTarget = _userIdCtrl.text.trim();
    if (userTarget.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter User System ID or Email first"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Map<String, dynamic> patch = {};
    if (field == 'password') {
      if (userTarget.contains('@')) {
        patch = {'sendResetEmail': true};
      } else {
        if (_newPassCtrl.text.length < 6) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Password must be at least 6 characters"),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        if (_newPassCtrl.text != _confirmPassCtrl.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Passwords do not match"),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        patch = {
          'forcePasswordReset': true,
          'passwordResetRequestedAt': FieldValue.serverTimestamp(),
        };
      }
    } else if (field == 'limit') {
      final limitVal = _limitCtrl.text.trim();
      if (limitVal.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Enter limit amount"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      patch = {
        'limits': {_selectedFeature: limitVal},
      };
    } else if (field == 'userId') {
      patch = {'userId': userTarget};
    }

    setState(() => _saving = true);
    try {
      await _service.isolatedUserUpdate(userTarget, patch);
      if (!mounted) return;
      final successMsg = (field == 'password' && userTarget.contains('@'))
          ? "Password reset email sent to $userTarget"
          : "Isolated Update Success: $field";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMsg), backgroundColor: Colors.green),
      );
      if (field == 'password') {
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      } else if (field == 'limit') {
        _limitCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          "User Security & Isolated Feature Limit Gateway",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Isolate Logic - Only changed field updates",
                    style: TextStyle(color: Color(0xFF00FF88), fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  _field(
                    "Option 1: User System ID or Email",
                    _userIdCtrl,
                    "Identify User UID or Gmail",
                    Icons.badge,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : () => _isolatedUpdate('userId'),
                    child: const Text("Update ID Only"),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    "Option 2: New Password",
                    _newPassCtrl,
                    "New Password (min 6 chars)",
                    Icons.lock,
                    isPass: true,
                  ),
                  const SizedBox(height: 8),
                  _field(
                    "Option 3: Confirm Password",
                    _confirmPassCtrl,
                    "Confirm Password",
                    Icons.lock_outline,
                    isPass: true,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : () => _isolatedUpdate('password'),
                    child: const Text("Update / Send Reset - Isolated"),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Option 4: Target Feature/Bar Selection",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _selectedFeature,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0A192F),
                    style: const TextStyle(color: Colors.white),
                    items: _features
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedFeature = v);
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _field(
                    "Option 5: Limit Amount Input",
                    _limitCtrl,
                    "e.g. 50, 100, Unlimited",
                    Icons.numbers,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : () => _isolatedUpdate('limit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                      ),
                      child: const Text(
                        "Update Limit Only - Isolated",
                        style: TextStyle(
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

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isPass = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          obscureText: isPass,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF00E5FF)),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

// ================= PAGE 4: ADMIN EXCLUSIVE =================
class Page4AdminExclusive extends StatefulWidget {
  const Page4AdminExclusive({super.key});
  @override
  State<Page4AdminExclusive> createState() => _Page4AdminExclusiveState();
}

class _Page4AdminExclusiveState extends State<Page4AdminExclusive> {
  final ProfileService _service = ProfileService();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    if (_newPassCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 6 characters"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords mismatch"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _service.requestAdminPasswordReset(_newPassCtrl.text);
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Admin Password Updated"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
      if (!_service.isOwner) {
        await _service.triggerSecurityAlert(
          _service.currentUserEmail ?? 'unknown',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOwner = _service.isOwner;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A0000), Color(0xFF0A192F)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          "ADMIN EXCLUSIVE PASSWORD CONTROL",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: const Text(
                      "ENTRY RESTRICTED TO ONLY MD BELAL HOSSEN",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _newPassCtrl,
                    enabled: isOwner,
                    obscureText: _obscure1,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "New Password",
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.lock, color: Colors.cyanAccent),
                      suffixIcon: isOwner
                          ? IconButton(
                              icon: Icon(
                                _obscure1 ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white54,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure1 = !_obscure1),
                            )
                          : const Icon(Icons.block, color: Colors.redAccent),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPassCtrl,
                    enabled: isOwner,
                    obscureText: _obscure2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Confirm Password",
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.cyanAccent,
                      ),
                      suffixIcon: isOwner
                          ? IconButton(
                              icon: Icon(
                                _obscure2 ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white54,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure2 = !_obscure2),
                            )
                          : const Icon(Icons.block, color: Colors.redAccent),
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
                    child: ElevatedButton.icon(
                      onPressed: isOwner && !_loading ? _apply : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isOwner ? const Color(0xFF00E5FF) : Colors.grey,
                      ),
                      icon: Icon(
                        isOwner ? Icons.check_circle : Icons.lock,
                        color: isOwner ? Colors.black : Colors.white,
                      ),
                      label: Text(
                        isOwner
                            ? (_loading ? "APPLYING..." : "APPLY")
                            : "APPLY LOCKED (OWNER ONLY)",
                        style: TextStyle(
                          color: isOwner ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (!isOwner)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        "Sub-Admin Block: This page is disabled. Security alert will go to mdbelalhossen2029@gmail.com with YES/NO buttons.",
                        style: TextStyle(color: Colors.white54, fontSize: 11),
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
}

// ================= PAGE 5: LIVE MOBILE & GMAIL EDIT =================
class Page5LiveEdit extends StatefulWidget {
  final bool isGmail;
  const Page5LiveEdit({super.key, this.isGmail = false});
  @override
  State<Page5LiveEdit> createState() => _Page5LiveEditState();
}

class _Page5LiveEditState extends State<Page5LiveEdit> {
  final ProfileService _service = ProfileService();
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();

    final val = _ctrl.text.trim();
    if (val.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isGmail ? "Enter Gmail address" : "Enter mobile number",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.isGmail &&
        !RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
            .hasMatch(val)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter valid Gmail address"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!widget.isGmail && !RegExp(r'^\+?\d{7,15}$').hasMatch(val)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter valid mobile number (7-15 digits)"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final key = widget.isGmail ? 'gmail' : 'mobileNumber';
      await _service.updateAdminProfile({key: val});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${widget.isGmail ? 'Gmail' : 'Mobile'} Updated Live - No Play Store Update Needed",
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Save failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.isGmail
                              ? "Gmail Instant Edit"
                              : "Mobile Number Instant Edit",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No-Code Instant Data Sync Policy - Play Store Update-Free Sync",
                    style: TextStyle(color: Color(0xFF00FF88), fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<DocumentSnapshot>(
                    stream: _service.adminProfileStream(),
                    builder: (c, snap) {
                      final data =
                          snap.data?.data() as Map<String, dynamic>? ?? {};
                      final current = widget.isGmail
                          ? (data['gmail'] ?? 'Not set')
                          : (data['mobileNumber'] ?? 'Not set');
                      return Text(
                        "Current: $current",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ctrl,
                    keyboardType: widget.isGmail
                        ? TextInputType.emailAddress
                        : TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText:
                          widget.isGmail ? "New Gmail" : "New Mobile Number",
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                      ),
                      child: Text(
                        _saving ? "SAVING..." : "SAVE LIVE - INSTANT SYNC",
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
}

// ================= PAGE 6: GLOBAL 200+ LANGUAGE ENGINE =================
class Page6LanguageEngine extends StatefulWidget {
  const Page6LanguageEngine({super.key});
  @override
  State<Page6LanguageEngine> createState() => _Page6LanguageEngineState();
}

class _Page6LanguageEngineState extends State<Page6LanguageEngine> {
  final ProfileService _service = ProfileService();
  final _searchCtrl = TextEditingController();
  String _selectedCountry = "United States";
  String _selectedLang = "English";
  String _query = "";

  static const List<Map<String, String>> _globalLangs = [
    {"code": "AF", "country": "Afghanistan", "lang": "Pashto"},
    {"code": "AL", "country": "Albania", "lang": "Albanian"},
    {"code": "DZ", "country": "Algeria", "lang": "Arabic"},
    {"code": "AD", "country": "Andorra", "lang": "Catalan"},
    {"code": "AO", "country": "Angola", "lang": "Portuguese"},
    {"code": "AG", "country": "Antigua and Barbuda", "lang": "English"},
    {"code": "AR", "country": "Argentina", "lang": "Spanish"},
    {"code": "AM", "country": "Armenia", "lang": "Armenian"},
    {"code": "AU", "country": "Australia", "lang": "English"},
    {"code": "AT", "country": "Austria", "lang": "German"},
    {"code": "AZ", "country": "Azerbaijan", "lang": "Azerbaijani"},
    {"code": "BS", "country": "Bahamas", "lang": "English"},
    {"code": "BH", "country": "Bahrain", "lang": "Arabic"},
    {"code": "BD", "country": "Bangladesh", "lang": "Bengali (Bangla)"},
    {"code": "BB", "country": "Barbados", "lang": "English"},
    {"code": "BY", "country": "Belarus", "lang": "Belarusian"},
    {"code": "BE", "country": "Belgium", "lang": "Dutch"},
    {"code": "BZ", "country": "Belize", "lang": "English"},
    {"code": "BJ", "country": "Benin", "lang": "French"},
    {"code": "BT", "country": "Bhutan", "lang": "Nepali / English"},
    {"code": "BO", "country": "Bolivia", "lang": "Spanish"},
    {"code": "BA", "country": "Bosnia and Herzegovina", "lang": "Bosnian"},
    {"code": "BW", "country": "Botswana", "lang": "English"},
    {"code": "BR", "country": "Brazil", "lang": "Portuguese"},
    {"code": "BN", "country": "Brunei", "lang": "Malay"},
    {"code": "BG", "country": "Bulgaria", "lang": "Bulgarian"},
    {"code": "BF", "country": "Burkina Faso", "lang": "French"},
    {"code": "BI", "country": "Burundi", "lang": "French"},
    {"code": "CV", "country": "Cabo Verde", "lang": "Portuguese"},
    {"code": "KH", "country": "Cambodia", "lang": "Khmer"},
    {"code": "CM", "country": "Cameroon", "lang": "French"},
    {"code": "CA", "country": "Canada", "lang": "English"},
    {"code": "CF", "country": "Central African Republic", "lang": "French"},
    {"code": "TD", "country": "Chad", "lang": "French"},
    {"code": "CL", "country": "Chile", "lang": "Spanish"},
    {"code": "CN", "country": "China", "lang": "Chinese (Simplified)"},
    {"code": "CO", "country": "Colombia", "lang": "Spanish"},
    {"code": "KM", "country": "Comoros", "lang": "Arabic"},
    {"code": "CG", "country": "Congo", "lang": "French"},
    {"code": "CD", "country": "Congo (DRC)", "lang": "French"},
    {"code": "CR", "country": "Costa Rica", "lang": "Spanish"},
    {"code": "CI", "country": "Cote d'Ivoire", "lang": "French"},
    {"code": "HR", "country": "Croatia", "lang": "Croatian"},
    {"code": "CU", "country": "Cuba", "lang": "Spanish"},
    {"code": "CY", "country": "Cyprus", "lang": "Greek"},
    {"code": "CZ", "country": "Czech Republic", "lang": "Czech"},
    {"code": "DK", "country": "Denmark", "lang": "Danish"},
    {"code": "DJ", "country": "Djibouti", "lang": "French"},
    {"code": "DM", "country": "Dominica", "lang": "English"},
    {"code": "DO", "country": "Dominican Republic", "lang": "Spanish"},
    {"code": "EC", "country": "Ecuador", "lang": "Spanish"},
    {"code": "EG", "country": "Egypt", "lang": "Arabic"},
    {"code": "SV", "country": "El Salvador", "lang": "Spanish"},
    {"code": "GQ", "country": "Equatorial Guinea", "lang": "Spanish"},
    {"code": "ER", "country": "Eritrea", "lang": "Arabic"},
    {"code": "EE", "country": "Estonia", "lang": "Estonian"},
    {"code": "SZ", "country": "Eswatini", "lang": "English"},
    {"code": "ET", "country": "Ethiopia", "lang": "Amharic"},
    {"code": "FJ", "country": "Fiji", "lang": "English"},
    {"code": "FI", "country": "Finland", "lang": "Finnish"},
    {"code": "FR", "country": "France", "lang": "French"},
    {"code": "GF", "country": "French Guiana", "lang": "French"},
    {"code": "GA", "country": "Gabon", "lang": "French"},
    {"code": "GM", "country": "Gambia", "lang": "English"},
    {"code": "GE", "country": "Georgia", "lang": "Georgian"},
    {"code": "DE", "country": "Germany", "lang": "German"},
    {"code": "GH", "country": "Ghana", "lang": "English"},
    {"code": "GR", "country": "Greece", "lang": "Greek"},
    {"code": "GL", "country": "Greenland", "lang": "Danish"},
    {"code": "GD", "country": "Grenada", "lang": "English"},
    {"code": "GT", "country": "Guatemala", "lang": "Spanish"},
    {"code": "GN", "country": "Guinea", "lang": "French"},
    {"code": "GW", "country": "Guinea-Bissau", "lang": "Portuguese"},
    {"code": "GY", "country": "Guyana", "lang": "English"},
    {"code": "HT", "country": "Haiti", "lang": "Haitian Creole"},
    {"code": "HN", "country": "Honduras", "lang": "Spanish"},
    {"code": "HK", "country": "Hong Kong", "lang": "Chinese (Traditional)"},
    {"code": "HU", "country": "Hungary", "lang": "Hungarian"},
    {"code": "IS", "country": "Iceland", "lang": "Icelandic"},
    {"code": "IN", "country": "India", "lang": "Hindi"},
    {"code": "ID", "country": "Indonesia", "lang": "Indonesian"},
    {"code": "IR", "country": "Iran", "lang": "Persian"},
    {"code": "IQ", "country": "Iraq", "lang": "Arabic"},
    {"code": "IE", "country": "Ireland", "lang": "Irish"},
    {"code": "IL", "country": "Israel", "lang": "Hebrew"},
    {"code": "IT", "country": "Italy", "lang": "Italian"},
    {"code": "JM", "country": "Jamaica", "lang": "English"},
    {"code": "JP", "country": "Japan", "lang": "Japanese"},
    {"code": "JO", "country": "Jordan", "lang": "Arabic"},
    {"code": "KZ", "country": "Kazakhstan", "lang": "Kazakh"},
    {"code": "KE", "country": "Kenya", "lang": "Swahili"},
    {"code": "KI", "country": "Kiribati", "lang": "English"},
    {"code": "KP", "country": "Korea (North)", "lang": "Korean"},
    {"code": "KR", "country": "Korea (South)", "lang": "Korean"},
    {"code": "XK", "country": "Kosovo", "lang": "Albanian"},
    {"code": "KW", "country": "Kuwait", "lang": "Arabic"},
    {"code": "KG", "country": "Kyrgyzstan", "lang": "Kyrgyz"},
    {"code": "LA", "country": "Laos", "lang": "Lao"},
    {"code": "LV", "country": "Latvia", "lang": "Latvian"},
    {"code": "LB", "country": "Lebanon", "lang": "Arabic"},
    {"code": "LS", "country": "Lesotho", "lang": "English"},
    {"code": "LR", "country": "Liberia", "lang": "English"},
    {"code": "LY", "country": "Libya", "lang": "Arabic"},
    {"code": "LI", "country": "Liechtenstein", "lang": "German"},
    {"code": "LT", "country": "Lithuania", "lang": "Lithuanian"},
    {"code": "LU", "country": "Luxembourg", "lang": "Luxembourgish"},
    {"code": "MO", "country": "Macau", "lang": "Chinese (Traditional)"},
    {"code": "MG", "country": "Madagascar", "lang": "Malagasy"},
    {"code": "MW", "country": "Malawi", "lang": "Chichewa"},
    {"code": "MY", "country": "Malaysia", "lang": "Malay"},
    {"code": "MV", "country": "Maldives", "lang": "Dhivehi"},
    {"code": "ML", "country": "Mali", "lang": "French"},
    {"code": "MT", "country": "Malta", "lang": "Maltese"},
    {"code": "MH", "country": "Marshall Islands", "lang": "English"},
    {"code": "MR", "country": "Mauritania", "lang": "Arabic"},
    {"code": "MU", "country": "Mauritius", "lang": "English"},
    {"code": "MX", "country": "Mexico", "lang": "Spanish"},
    {"code": "FM", "country": "Micronesia", "lang": "English"},
    {"code": "MD", "country": "Moldova", "lang": "Romanian"},
    {"code": "MC", "country": "Monaco", "lang": "French"},
    {"code": "MN", "country": "Mongolia", "lang": "Mongolian"},
    {"code": "ME", "country": "Montenegro", "lang": "Serbian"},
    {"code": "MA", "country": "Morocco", "lang": "Arabic"},
    {"code": "MZ", "country": "Mozambique", "lang": "Portuguese"},
    {"code": "MM", "country": "Myanmar", "lang": "Burmese"},
    {"code": "NA", "country": "Namibia", "lang": "English"},
    {"code": "NR", "country": "Nauru", "lang": "English"},
    {"code": "NP", "country": "Nepal", "lang": "Nepali"},
    {"code": "NL", "country": "Netherlands", "lang": "Dutch"},
    {"code": "NZ", "country": "New Zealand", "lang": "English"},
    {"code": "NI", "country": "Nicaragua", "lang": "Spanish"},
    {"code": "NE", "country": "Niger", "lang": "French"},
    {"code": "NG", "country": "Nigeria", "lang": "English"},
    {"code": "MK", "country": "North Macedonia", "lang": "Macedonian"},
    {"code": "NO", "country": "Norway", "lang": "Norwegian"},
    {"code": "OM", "country": "Oman", "lang": "Arabic"},
    {"code": "PK", "country": "Pakistan", "lang": "Urdu"},
    {"code": "PW", "country": "Palau", "lang": "English"},
    {"code": "PS", "country": "Palestine", "lang": "Arabic"},
    {"code": "PA", "country": "Panama", "lang": "Spanish"},
    {"code": "PG", "country": "Papua New Guinea", "lang": "English"},
    {"code": "PY", "country": "Paraguay", "lang": "Spanish"},
    {"code": "PE", "country": "Peru", "lang": "Spanish"},
    {"code": "PH", "country": "Philippines", "lang": "Filipino"},
    {"code": "PL", "country": "Poland", "lang": "Polish"},
    {"code": "PT", "country": "Portugal", "lang": "Portuguese"},
    {"code": "PR", "country": "Puerto Rico", "lang": "Spanish"},
    {"code": "QA", "country": "Qatar", "lang": "Arabic"},
    {"code": "RE", "country": "Reunion", "lang": "French"},
    {"code": "RO", "country": "Romania", "lang": "Romanian"},
    {"code": "RU", "country": "Russia", "lang": "Russian"},
    {"code": "RW", "country": "Rwanda", "lang": "Kinyarwanda"},
    {"code": "KN", "country": "Saint Kitts and Nevis", "lang": "English"},
    {"code": "LC", "country": "Saint Lucia", "lang": "English"},
    {"code": "VC", "country": "Saint Vincent and the Grenadines", "lang": "English"},
    {"code": "WS", "country": "Samoa", "lang": "Samoan"},
    {"code": "SM", "country": "San Marino", "lang": "Italian"},
    {"code": "ST", "country": "Sao Tome and Principe", "lang": "Portuguese"},
    {"code": "SA", "country": "Saudi Arabia", "lang": "Arabic"},
    {"code": "SN", "country": "Senegal", "lang": "French"},
    {"code": "RS", "country": "Serbia", "lang": "Serbian"},
    {"code": "SC", "country": "Seychelles", "lang": "English"},
    {"code": "SL", "country": "Sierra Leone", "lang": "English"},
    {"code": "SG", "country": "Singapore", "lang": "English"},
    {"code": "SK", "country": "Slovakia", "lang": "Slovak"},
    {"code": "SI", "country": "Slovenia", "lang": "Slovenian"},
    {"code": "SB", "country": "Solomon Islands", "lang": "English"},
    {"code": "SO", "country": "Somalia", "lang": "Somali"},
    {"code": "ZA", "country": "South Africa", "lang": "Afrikaans"},
    {"code": "SS", "country": "South Sudan", "lang": "English"},
    {"code": "ES", "country": "Spain", "lang": "Spanish"},
    {"code": "LK", "country": "Sri Lanka", "lang": "Sinhala"},
    {"code": "SD", "country": "Sudan", "lang": "Arabic"},
    {"code": "SR", "country": "Suriname", "lang": "Dutch"},
    {"code": "SE", "country": "Sweden", "lang": "Swedish"},
    {"code": "CH", "country": "Switzerland", "lang": "German"},
    {"code": "SY", "country": "Syria", "lang": "Arabic"},
    {"code": "TW", "country": "Taiwan", "lang": "Chinese (Traditional)"},
    {"code": "TJ", "country": "Tajikistan", "lang": "Tajik"},
    {"code": "TZ", "country": "Tanzania", "lang": "Swahili"},
    {"code": "TH", "country": "Thailand", "lang": "Thai"},
    {"code": "TL", "country": "Timor-Leste", "lang": "Portuguese"},
    {"code": "TG", "country": "Togo", "lang": "French"},
    {"code": "TO", "country": "Tonga", "lang": "English"},
    {"code": "TT", "country": "Trinidad and Tobago", "lang": "English"},
    {"code": "TN", "country": "Tunisia", "lang": "Arabic"},
    {"code": "TR", "country": "Turkey", "lang": "Turkish"},
    {"code": "TM", "country": "Turkmenistan", "lang": "Turkmen"},
    {"code": "TV", "country": "Tuvalu", "lang": "English"},
    {"code": "UG", "country": "Uganda", "lang": "English"},
    {"code": "UA", "country": "Ukraine", "lang": "Ukrainian"},
    {"code": "AE", "country": "United Arab Emirates", "lang": "Arabic"},
    {"code": "GB", "country": "United Kingdom", "lang": "English"},
    {"code": "US", "country": "United States", "lang": "English"},
    {"code": "UY", "country": "Uruguay", "lang": "Spanish"},
    {"code": "UZ", "country": "Uzbekistan", "lang": "Uzbek"},
    {"code": "VU", "country": "Vanuatu", "lang": "English"},
    {"code": "VA", "country": "Vatican City", "lang": "Italian"},
    {"code": "VE", "country": "Venezuela", "lang": "Spanish"},
    {"code": "VN", "country": "Vietnam", "lang": "Vietnamese"},
    {"code": "YE", "country": "Yemen", "lang": "Arabic"},
    {"code": "ZM", "country": "Zambia", "lang": "English"},
    {"code": "ZW", "country": "Zimbabwe", "lang": "Shona"},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_profile')
          .doc('main')
          .get();
      if (!mounted || !doc.exists) return;
      final data = doc.data() ?? {};
      setState(() {
        _selectedLang = (data['admin_lang'] ?? 'English').toString();
        _selectedCountry = (data['admin_country'] ?? 'United States').toString();
      });
    } catch (_) {}
  }

  Future<void> _changeLang(Map<String, String> item) async {
    final country = item['country'] ?? 'United States';
    final lang = item['lang'] ?? 'English';
    setState(() {
      _selectedCountry = country;
      _selectedLang = lang;
    });
    try {
      await _service.updateAdminProfile({
        'admin_lang': lang,
        'admin_country': country,
        'admin_country_code': item['code'],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Admin App Language Changed to $lang ($country) - Admin App Only",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _globalLangs.where((item) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return item['country']!.toLowerCase().contains(q) ||
          item['lang']!.toLowerCase().contains(q) ||
          item['code']!.toLowerCase().contains(q);
    }).toList();

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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          "Global Language & Country Selector (204)",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Admin App Exclusive ($_selectedCountry - $_selectedLang) - Will not affect User App",
                    style: const TextStyle(color: Color(0xFF00FF88), fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: "Search country or language...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF00E5FF)),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              "No matching country or language found",
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (c, i) {
                              final item = filtered[i];
                              final isSelected =
                                  _selectedCountry == item['country'] &&
                                      _selectedLang == item['lang'];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                                      : Colors.white10,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF00E5FF)
                                        : Colors.white12,
                                  ),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 38,
                                    height: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF00E5FF)
                                          : Colors.white10,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item['code']!,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.black
                                            : const Color(0xFF00E5FF),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item['country']!,
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF00E5FF)
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  subtitle: Text(
                                    item['lang']!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Color(0xFF00E5FF),
                                        )
                                      : null,
                                  onTap: () => _changeLang(item),
                                ),
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
    );
  }
}