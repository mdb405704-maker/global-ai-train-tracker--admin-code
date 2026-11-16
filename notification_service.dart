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

class NoticeService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> sendNotice({
    required String title,
    required String message,
    required String type,
    required String audience,
    String? countryCode,
    String? specificUserId,
    required String scheduleOption,
    Timestamp? scheduledAt,
    required String platform,
    required bool verifyChecked,
  }) async {
    final admin = _auth.currentUser;
    if (admin == null) {
      throw Exception("Admin not authenticated - Dual Admin Check Failed");
    }

    final cleanTitle = title.trim();
    final cleanMsg = message.trim();

    final data = {
      'title': cleanTitle,
      'message': cleanMsg,
      'type': type,
      'audience': audience,
      'country_code': audience == 'Specific Country' ? countryCode : null,
      'specificUserId': audience == 'Specific Users' ? specificUserId : null,
      'scheduleOption': scheduleOption,
      'scheduledAt': scheduledAt,
      'sentFrom': platform,
      'sentBy': admin.email ?? admin.uid,
      'senderUid': admin.uid,
      'verifyChecked': verifyChecked,
      'createdAt': FieldValue.serverTimestamp(),
      'status': scheduleOption == 'Send Now' ? 'SENT' : 'SCHEDULED',
      'fcmPayload': {
        'notification': {'title': cleanTitle, 'body': cleanMsg},
        'data': {
          'type': type,
          'url': type == 'link' ? cleanMsg : '',
          'sender': admin.uid,
          'platform': platform,
        },
        'topic': audience == 'All Users'
            ? 'all_users'
            : (countryCode ?? 'filtered'),
      },
    };

    if (scheduleOption == 'Send Now') {
      await _db.collection('notices_history').add(data);
      await _db.collection('fcm_jobs').add({
        'payload': data['fcmPayload'],
        'audience': audience,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sync directly with user app's official_notices collection
      await _db.collection('official_notices').add({
        'title': cleanTitle,
        'content': type == 'text' ? cleanMsg : '',
        'url': type == 'link' ? cleanMsg : '',
        'type': type,
        'country_filter':
            audience == 'Specific Country' ? (countryCode ?? 'ALL') : 'ALL',
        'is_active': true,
        'view_count': 0,
        'copy_count': 0,
        'created_at': FieldValue.serverTimestamp(),
      });
    } else {
      await _db.collection('scheduled_notices').add(data);
      await _db
          .collection('notices_history')
          .add({...data, 'status': 'SCHEDULED'});
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SendOfficialNoticeScreen(),
    ),
  );
}

class SendOfficialNoticeScreen extends StatefulWidget {
  const SendOfficialNoticeScreen({super.key});
  @override
  State<SendOfficialNoticeScreen> createState() =>
      _SendOfficialNoticeScreenState();
}

class _SendOfficialNoticeScreenState extends State<SendOfficialNoticeScreen> {
  final _service = NoticeService();
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _userCtrl = TextEditingController();

  String _noticeType = 'Text Notice';
  String _audience = 'All Users';
  String _country = 'BD';
  String _schedule = 'Send Now';
  DateTime? _scheduledDT;
  bool _verify = true;
  bool _loading = false;

  static const List<Map<String, String>> _globalCountries = [
    {"code": "AF", "name": "Afghanistan"},
    {"code": "AL", "name": "Albania"},
    {"code": "DZ", "name": "Algeria"},
    {"code": "AD", "name": "Andorra"},
    {"code": "AO", "name": "Angola"},
    {"code": "AG", "name": "Antigua and Barbuda"},
    {"code": "AR", "name": "Argentina"},
    {"code": "AM", "name": "Armenia"},
    {"code": "AU", "name": "Australia"},
    {"code": "AT", "name": "Austria"},
    {"code": "AZ", "name": "Azerbaijan"},
    {"code": "BS", "name": "Bahamas"},
    {"code": "BH", "name": "Bahrain"},
    {"code": "BD", "name": "Bangladesh"},
    {"code": "BB", "name": "Barbados"},
    {"code": "BY", "name": "Belarus"},
    {"code": "BE", "name": "Belgium"},
    {"code": "BZ", "name": "Belize"},
    {"code": "BJ", "name": "Benin"},
    {"code": "BT", "name": "Bhutan"},
    {"code": "BO", "name": "Bolivia"},
    {"code": "BA", "name": "Bosnia and Herzegovina"},
    {"code": "BW", "name": "Botswana"},
    {"code": "BR", "name": "Brazil"},
    {"code": "BN", "name": "Brunei"},
    {"code": "BG", "name": "Bulgaria"},
    {"code": "BF", "name": "Burkina Faso"},
    {"code": "BI", "name": "Burundi"},
    {"code": "CV", "name": "Cabo Verde"},
    {"code": "KH", "name": "Cambodia"},
    {"code": "CM", "name": "Cameroon"},
    {"code": "CA", "name": "Canada"},
    {"code": "CF", "name": "Central African Republic"},
    {"code": "TD", "name": "Chad"},
    {"code": "CL", "name": "Chile"},
    {"code": "CN", "name": "China"},
    {"code": "CO", "name": "Colombia"},
    {"code": "KM", "name": "Comoros"},
    {"code": "CG", "name": "Congo"},
    {"code": "CD", "name": "Congo (DRC)"},
    {"code": "CR", "name": "Costa Rica"},
    {"code": "CI", "name": "Cote d'Ivoire"},
    {"code": "HR", "name": "Croatia"},
    {"code": "CU", "name": "Cuba"},
    {"code": "CY", "name": "Cyprus"},
    {"code": "CZ", "name": "Czech Republic"},
    {"code": "DK", "name": "Denmark"},
    {"code": "DJ", "name": "Djibouti"},
    {"code": "DM", "name": "Dominica"},
    {"code": "DO", "name": "Dominican Republic"},
    {"code": "EC", "name": "Ecuador"},
    {"code": "EG", "name": "Egypt"},
    {"code": "SV", "name": "El Salvador"},
    {"code": "GQ", "name": "Equatorial Guinea"},
    {"code": "ER", "name": "Eritrea"},
    {"code": "EE", "name": "Estonia"},
    {"code": "SZ", "name": "Eswatini"},
    {"code": "ET", "name": "Ethiopia"},
    {"code": "FJ", "name": "Fiji"},
    {"code": "FI", "name": "Finland"},
    {"code": "FR", "name": "France"},
    {"code": "GF", "name": "French Guiana"},
    {"code": "GA", "name": "Gabon"},
    {"code": "GM", "name": "Gambia"},
    {"code": "GE", "name": "Georgia"},
    {"code": "DE", "name": "Germany"},
    {"code": "GH", "name": "Ghana"},
    {"code": "GR", "name": "Greece"},
    {"code": "GL", "name": "Greenland"},
    {"code": "GD", "name": "Grenada"},
    {"code": "GT", "name": "Guatemala"},
    {"code": "GN", "name": "Guinea"},
    {"code": "GW", "name": "Guinea-Bissau"},
    {"code": "GY", "name": "Guyana"},
    {"code": "HT", "name": "Haiti"},
    {"code": "HN", "name": "Honduras"},
    {"code": "HK", "name": "Hong Kong"},
    {"code": "HU", "name": "Hungary"},
    {"code": "IS", "name": "Iceland"},
    {"code": "IN", "name": "India"},
    {"code": "ID", "name": "Indonesia"},
    {"code": "IR", "name": "Iran"},
    {"code": "IQ", "name": "Iraq"},
    {"code": "IE", "name": "Ireland"},
    {"code": "IL", "name": "Israel"},
    {"code": "IT", "name": "Italy"},
    {"code": "JM", "name": "Jamaica"},
    {"code": "JP", "name": "Japan"},
    {"code": "JO", "name": "Jordan"},
    {"code": "KZ", "name": "Kazakhstan"},
    {"code": "KE", "name": "Kenya"},
    {"code": "KI", "name": "Kiribati"},
    {"code": "KP", "name": "Korea (North)"},
    {"code": "KR", "name": "Korea (South)"},
    {"code": "XK", "name": "Kosovo"},
    {"code": "KW", "name": "Kuwait"},
    {"code": "KG", "name": "Kyrgyzstan"},
    {"code": "LA", "name": "Laos"},
    {"code": "LV", "name": "Latvia"},
    {"code": "LB", "name": "Lebanon"},
    {"code": "LS", "name": "Lesotho"},
    {"code": "LR", "name": "Liberia"},
    {"code": "LY", "name": "Libya"},
    {"code": "LI", "name": "Liechtenstein"},
    {"code": "LT", "name": "Lithuania"},
    {"code": "LU", "name": "Luxembourg"},
    {"code": "MO", "name": "Macau"},
    {"code": "MG", "name": "Madagascar"},
    {"code": "MW", "name": "Malawi"},
    {"code": "MY", "name": "Malaysia"},
    {"code": "MV", "name": "Maldives"},
    {"code": "ML", "name": "Mali"},
    {"code": "MT", "name": "Malta"},
    {"code": "MH", "name": "Marshall Islands"},
    {"code": "MR", "name": "Mauritania"},
    {"code": "MU", "name": "Mauritius"},
    {"code": "MX", "name": "Mexico"},
    {"code": "FM", "name": "Micronesia"},
    {"code": "MD", "name": "Moldova"},
    {"code": "MC", "name": "Monaco"},
    {"code": "MN", "name": "Mongolia"},
    {"code": "ME", "name": "Montenegro"},
    {"code": "MA", "name": "Morocco"},
    {"code": "MZ", "name": "Mozambique"},
    {"code": "MM", "name": "Myanmar"},
    {"code": "NA", "name": "Namibia"},
    {"code": "NR", "name": "Nauru"},
    {"code": "NP", "name": "Nepal"},
    {"code": "NL", "name": "Netherlands"},
    {"code": "NZ", "name": "New Zealand"},
    {"code": "NI", "name": "Nicaragua"},
    {"code": "NE", "name": "Niger"},
    {"code": "NG", "name": "Nigeria"},
    {"code": "MK", "name": "North Macedonia"},
    {"code": "NO", "name": "Norway"},
    {"code": "OM", "name": "Oman"},
    {"code": "PK", "name": "Pakistan"},
    {"code": "PW", "name": "Palau"},
    {"code": "PS", "name": "Palestine"},
    {"code": "PA", "name": "Panama"},
    {"code": "PG", "name": "Papua New Guinea"},
    {"code": "PY", "name": "Paraguay"},
    {"code": "PE", "name": "Peru"},
    {"code": "PH", "name": "Philippines"},
    {"code": "PL", "name": "Poland"},
    {"code": "PT", "name": "Portugal"},
    {"code": "PR", "name": "Puerto Rico"},
    {"code": "QA", "name": "Qatar"},
    {"code": "RE", "name": "Reunion"},
    {"code": "RO", "name": "Romania"},
    {"code": "RU", "name": "Russia"},
    {"code": "RW", "name": "Rwanda"},
    {"code": "KN", "name": "Saint Kitts and Nevis"},
    {"code": "LC", "name": "Saint Lucia"},
    {"code": "VC", "name": "Saint Vincent and the Grenadines"},
    {"code": "WS", "name": "Samoa"},
    {"code": "SM", "name": "San Marino"},
    {"code": "ST", "name": "Sao Tome and Principe"},
    {"code": "SA", "name": "Saudi Arabia"},
    {"code": "SN", "name": "Senegal"},
    {"code": "RS", "name": "Serbia"},
    {"code": "SC", "name": "Seychelles"},
    {"code": "SL", "name": "Sierra Leone"},
    {"code": "SG", "name": "Singapore"},
    {"code": "SK", "name": "Slovakia"},
    {"code": "SI", "name": "Slovenia"},
    {"code": "SB", "name": "Solomon Islands"},
    {"code": "SO", "name": "Somalia"},
    {"code": "ZA", "name": "South Africa"},
    {"code": "SS", "name": "South Sudan"},
    {"code": "ES", "name": "Spain"},
    {"code": "LK", "name": "Sri Lanka"},
    {"code": "SD", "name": "Sudan"},
    {"code": "SR", "name": "Suriname"},
    {"code": "SE", "name": "Sweden"},
    {"code": "CH", "name": "Switzerland"},
    {"code": "SY", "name": "Syria"},
    {"code": "TW", "name": "Taiwan"},
    {"code": "TJ", "name": "Tajikistan"},
    {"code": "TZ", "name": "Tanzania"},
    {"code": "TH", "name": "Thailand"},
    {"code": "TL", "name": "Timor-Leste"},
    {"code": "TG", "name": "Togo"},
    {"code": "TO", "name": "Tonga"},
    {"code": "TT", "name": "Trinidad and Tobago"},
    {"code": "TN", "name": "Tunisia"},
    {"code": "TR", "name": "Turkey"},
    {"code": "TM", "name": "Turkmenistan"},
    {"code": "TV", "name": "Tuvalu"},
    {"code": "UG", "name": "Uganda"},
    {"code": "UA", "name": "Ukraine"},
    {"code": "AE", "name": "United Arab Emirates"},
    {"code": "GB", "name": "United Kingdom"},
    {"code": "US", "name": "United States"},
    {"code": "UY", "name": "Uruguay"},
    {"code": "UZ", "name": "Uzbekistan"},
    {"code": "VU", "name": "Vanuatu"},
    {"code": "VA", "name": "Vatican City"},
    {"code": "VE", "name": "Venezuela"},
    {"code": "VN", "name": "Vietnam"},
    {"code": "YE", "name": "Yemen"},
    {"code": "ZM", "name": "Zambia"},
    {"code": "ZW", "name": "Zimbabwe"},
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t == null || !mounted) return;
    setState(() {
      _scheduledDT = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _send() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    final title = _titleCtrl.text.trim();
    final message = _msgCtrl.text.trim();
    final specificUser = _userCtrl.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Title & Message required"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_noticeType == 'Link Notice' &&
        !message.startsWith('http://') &&
        !message.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Link Notice must start with http:// or https://"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_audience == 'Specific Users' && specificUser.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter target User ID or Email"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_schedule == 'Schedule for later') {
      if (_scheduledDT == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select schedule date and time"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_scheduledDT!.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Scheduled time must be in the future"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (_verify) {
      final platLabel = MediaQuery.of(context).size.width > 800 ? 'WEB' : 'APK';
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF0A192F),
          title: const Text(
            "Verify Before Send",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Send '$title' to $_audience?\nPlatform: $platLabel",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A4DA1),
              ),
              child: const Text(
                "Confirm Send",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final plat = MediaQuery.of(context).size.width > 800 ? 'WEB' : 'APK';
      await _service.sendNotice(
        title: title,
        message: message,
        type: _noticeType == 'Text Notice' ? 'text' : 'link',
        audience: _audience,
        countryCode: _country,
        specificUserId: specificUser.isEmpty ? null : specificUser,
        scheduleOption: _schedule,
        scheduledAt:
            _scheduledDT != null ? Timestamp.fromDate(_scheduledDT!) : null,
        platform: plat,
        verifyChecked: _verify,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _schedule == 'Send Now'
                ? "Notice Sent to $_audience - FCM & App Updated"
                : "Scheduled for $_scheduledDT",
          ),
          backgroundColor: Colors.green,
        ),
      );
      _titleCtrl.clear();
      _msgCtrl.clear();
      _userCtrl.clear();
      setState(() {
        _scheduledDT = null;
        _schedule = 'Send Now';
      });
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

  Widget _typeCard(String title, IconData icon, bool sel, VoidCallback tap) =>
      InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sel
                ? const Color(0xFF0A4DA1).withValues(alpha: 0.12)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? const Color(0xFF0A4DA1) : Colors.black12,
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: sel ? const Color(0xFF0A4DA1) : Colors.black45,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: sel ? const Color(0xFF0A4DA1) : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _scheduleCard(
    String title,
    IconData icon,
    bool sel,
    VoidCallback tap,
  ) =>
      InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sel
                ? const Color(0xFF0A2A5C).withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? const Color(0xFF0A2A5C) : Colors.black12,
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: sel ? const Color(0xFF0A2A5C) : Colors.black45,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: sel ? const Color(0xFF0A2A5C) : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE8E8E8),
                Color(0xFFC0C0C0),
                Color(0xFFD9D9D9),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.10,
                  child: Icon(Icons.train, size: 500, color: Colors.grey.shade700),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWeb ? 700 : double.infinity,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.93),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (Navigator.canPop(context))
                                  Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF0A4DA1)
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.arrow_back,
                                        color: Color(0xFF0A4DA1),
                                      ),
                                      onPressed: () {
                                        if (Navigator.canPop(context)) {
                                          Navigator.pop(context);
                                        }
                                      },
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFFFA500),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.train,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    "Send Official Notice",
                                    style: TextStyle(
                                      color: Color(0xFF0A192F),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  isWeb ? "WEB" : "APK",
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF0A4DA1),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Dual-Admin: Main Admin MD BELAL HOSSEN + Verified Sub-Admins - Firestore Rule: isApproved==true",
                              style: TextStyle(color: Colors.black54, fontSize: 9),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Notice Type",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF0A192F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _typeCard(
                                    "Text Notice",
                                    Icons.description,
                                    _noticeType == 'Text Notice',
                                    () => setState(
                                      () => _noticeType = 'Text Notice',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _typeCard(
                                    "Link Notice",
                                    Icons.link,
                                    _noticeType == 'Link Notice',
                                    () => setState(
                                      () => _noticeType = 'Link Notice',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "Title of Notice:",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0A192F),
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _titleCtrl,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    "Enter the official communication subject...",
                                hintStyle: const TextStyle(
                                  color: Colors.black38,
                                  fontSize: 11,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _noticeType == 'Link Notice'
                                  ? "Official Website URL:"
                                  : "Message / Description:",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0A192F),
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _msgCtrl,
                              maxLines: _noticeType == 'Link Notice' ? 2 : 5,
                              keyboardType: _noticeType == 'Link Notice'
                                  ? TextInputType.url
                                  : TextInputType.multiline,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: _noticeType == 'Link Notice'
                                    ? "https://..."
                                    : "Type the full message content here...",
                                hintStyle: const TextStyle(
                                  color: Colors.black38,
                                  fontSize: 11,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.black38,
                                    size: 18,
                                  ),
                                  onPressed: () => _msgCtrl.clear(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "Target Audience",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF0A192F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _audience,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: "All Users",
                                  child: Text("All Users (Default selected)"),
                                ),
                                DropdownMenuItem(
                                  value: "Specific Country",
                                  child: Text("Specific Country"),
                                ),
                                DropdownMenuItem(
                                  value: "Specific Users",
                                  child: Text("Specific Users"),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _audience = v);
                              },
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                labelText: "Audience",
                                labelStyle: const TextStyle(color: Colors.black54),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_audience == 'Specific Country')
                              DropdownButtonFormField<String>(
                                value: _country,
                                isExpanded: true,
                                menuMaxHeight: 350,
                                dropdownColor: Colors.white,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                ),
                                items: _globalCountries
                                    .map(
                                      (c) => DropdownMenuItem<String>(
                                        value: c['code'],
                                        child: Text(
                                          "${c['code']} - ${c['name']}",
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _country = v);
                                },
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  labelText: "Country Code (204 Countries)",
                                  labelStyle:
                                      const TextStyle(color: Colors.black54),
                                  filled: true,
                                  fillColor: Colors.white,
                                  helperText:
                                      "Query: collection('users').where('country_code', isEqualTo: selectedCountry)",
                                ),
                              ),
                            if (_audience == 'Specific Users')
                              TextField(
                                controller: _userCtrl,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  hintText: "User ID or Email",
                                  hintStyle: const TextStyle(
                                    color: Colors.black38,
                                    fontSize: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            const SizedBox(height: 14),
                            const Text(
                              "Scheduling & Verification",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF0A192F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _scheduleCard(
                                    "Send Now",
                                    Icons.bolt,
                                    _schedule == 'Send Now',
                                    () => setState(() => _schedule = 'Send Now'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _scheduleCard(
                                    "Schedule for later",
                                    Icons.schedule,
                                    _schedule == 'Schedule for later',
                                    () {
                                      setState(
                                        () => _schedule = 'Schedule for later',
                                      );
                                      _pick();
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (_scheduledDT != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  "Scheduled: $_scheduledDT -> stored in scheduled_notices collection",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF0A4DA1),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Checkbox(
                                  value: _verify,
                                  onChanged: (v) =>
                                      setState(() => _verify = v ?? true),
                                  activeColor: const Color(0xFF0A4DA1),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _verify = !_verify),
                                    child: const Text(
                                      "Verify Before Send - confirmation popup before final submission. Prevents accidental sends",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0A192F),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _send,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0A2A5C),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 12,
                                  shadowColor: const Color(0xFF0A4DA1)
                                      .withValues(alpha: 0.6),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _schedule == 'Send Now'
                                            ? "Send Notice"
                                            : "Schedule Notice",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Android APK: SendNoticeScreen.dart - Package com.globaltraintracker.admin - WEB: /notices/send - Logs to notices_history & official_notices - 100% Ad-Free",
                              style: TextStyle(
                                fontSize: 7.5,
                                color: Colors.black38,
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