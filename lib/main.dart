import 'package:billtrack/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Add to pubspec.yaml: intl: ^0.19.0
import 'firebase_options.dart';
import 'package:auth_buttons/auth_buttons.dart';

import 'package:billtrack/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().init();

  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = !prefs.containsKey('onboarding_seen');

  runApp(BillWiseApp(showOnboarding: showOnboarding));
}

// --- DATA MODEL ---
class Bill {
  final String id;
  final String category;
  final double amount;
  final DateTime dueDate;
  bool isPaid;

  Bill({
    required this.id,
    required this.category,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'isPaid': isPaid,
    };
  }

  factory Bill.fromMap(String id, Map<String, dynamic> map) {
    return Bill(
      id: id,
      category: map['category'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      isPaid: map['isPaid'] ?? false,
    );
  }

  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get userId => FirebaseAuth.instance.currentUser!.uid;

  Stream<List<Bill>> getBills() {
    return _db
        .collection('users')
        .doc(userId)
        .collection('bills')
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Bill.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> addBill(Bill bill) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('bills')
        .doc(bill.id)
        .set(bill.toMap());
  }
}

// --- THEME & CONSTANTS ---
class AppColors {
  static const primary = Color(0xFF1A2B48); // Deep Blue
  static const accent = Color(0xFF2ECC71); // Financial Green
  static const background = Color(0xFFF8F9FA);
  static const cardShadow = Color(0x1A000000);
}

class BillWiseApp extends StatelessWidget {
  final bool showOnboarding;
  const BillWiseApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          // Check if onboarding needs to be shown
          if (showOnboarding && !snapshot.hasData) {
            // Only show onboarding if user is NOT logged in.
            // If they are logged in, we assume they know the drill or we don't want to disrupt them.
            // Or strictly: if (showOnboarding) -> Onboarding, but usually onboarding leads to auth.
            return const OnboardingScreen();
          }

          if (snapshot.hasData) {
            return const MainNavigationHolder();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}

// --- AUTH SERVICE (As provided, kept intact) ---
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signUp(String name, String email, String password) async {
    try {
      UserCredential res = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await res.user?.updateDisplayName(name);
    } catch (e) {
      debugPrint("Sign Up Error: $e");
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint("Login Error: $e");
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.standard();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Google Auth Error: $e");
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.standard().signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint("Sign out error: $e");
    }
  }
}

// --- 1. SPLASH SCREEN ---
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet_rounded,
              size: 80,
              color: AppColors.accent,
            ),
            const SizedBox(height: 24),
            const Text(
              "BillWise",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            const CircularProgressIndicator(color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

// --- 2. AUTH SCREEN ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final _emailController = TextEditingController();
  final _pwController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            const SizedBox(height: 120),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              isLogin ? "Welcome Back" : "Create Account",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const Text(
              "Manage your bills smarter",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            if (!isLogin)
              _buildField(_nameController, "Full Name", Icons.person_outline),
            _buildField(
              _emailController,
              "Email Address",
              Icons.email_outlined,
            ),
            _buildField(
              _pwController,
              "Password",
              Icons.lock_outline,
              obscure: true,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () async {
                if (isLogin) {
                  await AuthService().login(
                    _emailController.text,
                    _pwController.text,
                  );
                } else {
                  await AuthService().signUp(
                    _nameController.text,
                    _emailController.text,
                    _pwController.text,
                  );
                }
              },
              child: Text(
                isLogin ? "Login" : "Sign Up",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(
                isLogin
                    ? "New here? Create account"
                    : "Already have an account? Login",
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("OR"),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),

            GoogleAuthButton(
              onPressed: () => AuthService().signInWithGoogle(),
              style: AuthButtonStyle(
                buttonType: AuthButtonType.secondary, // Outlined style
                borderRadius: 15,
                height: 55,
                width: double.infinity,
                borderColor: Colors.grey.shade300,
                textStyle: const TextStyle(color: Colors.black87, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.primary),
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// --- 3. MAIN NAVIGATION & STATE ---
class MainNavigationHolder extends StatefulWidget {
  const MainNavigationHolder({super.key});
  @override
  State<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends State<MainNavigationHolder> {
  int _currentIndex = 0;

  void _addBill(Bill bill) {
    FirestoreService().addBill(bill);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Bill>>(
        stream: FirestoreService().getBills(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bills = snapshot.data ?? [];
          final List<Widget> screens = [
            DashboardScreen(bills: bills),
            AnalyticsScreen(bills: bills),
          ];

          return screens[_currentIndex];
        },
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        elevation: 10,
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_max_outlined),
            selectedIcon: Icon(Icons.home_max),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Insights',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddBillSheet(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  void _showAddBillSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => AddBillScreen(onSave: _addBill),
    );
  }
}

// --- 4. DASHBOARD SCREEN ---
class DashboardScreen extends StatelessWidget {
  final List<Bill> bills;
  const DashboardScreen({super.key, required this.bills});

  @override
  Widget build(BuildContext context) {
    double totalPending = bills
        .where((b) => !b.isPaid)
        .fold(0, (sum, item) => sum + item.amount);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 180,
          floating: false,
          pinned: true,
          backgroundColor: AppColors.primary,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text(
              "Your Bills",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            background: Container(
              padding: const EdgeInsets.only(left: 20, bottom: 60),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Total Pending",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    "\$${totalPending.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notification_add, color: Colors.white),
              onPressed: () {
                // Trigger a test notification 5 seconds from now
                NotificationService().scheduleBillReminder(
                  'test_id',
                  'Test Notification',
                  DateTime.now().add(const Duration(seconds: 5)),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Notification scheduled for 5 seconds!"),
                  ),
                );
              },
            ),
            IconButton(
              onPressed: () => AuthService().signOut(),
              icon: const Icon(Icons.logout, color: Colors.white),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final bill = bills[index];
              return _buildBillCard(bill);
            }, childCount: bills.length),
          ),
        ),
      ],
    );
  }

  Widget _buildBillCard(Bill bill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Icon(_getIcon(bill.category), color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.category,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "Due in ${bill.daysUntilDue} days",
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "\$${bill.amount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                DateFormat('MMM dd').format(bill.dueDate),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String cat) {
    if (cat == 'Electricity') return Icons.bolt;
    if (cat == 'Water') return Icons.water_drop;
    return Icons.phone_android;
  }
}

// --- 5. ADD BILL SCREEN ---
class AddBillScreen extends StatefulWidget {
  final Function(Bill) onSave;
  const AddBillScreen({super.key, required this.onSave});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  String selectedCategory = 'Electricity';
  final amountController = TextEditingController();
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  bool reminderEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Add New Bill",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: selectedCategory,
            decoration: const InputDecoration(labelText: "Category"),
            items: [
              'Electricity',
              'Water',
              'Telecom',
            ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() => selectedCategory = val!),
          ),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Amount",
              prefixText: "\$ ",
            ),
          ),
          const SizedBox(height: 15),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Due Date"),
            subtitle: Text(
              DateFormat('EEEE, MMM dd, yyyy').format(selectedDate),
            ),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (date != null) setState(() => selectedDate = date);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Set 2-day Reminder"),
            value: reminderEnabled,
            onChanged: (v) => setState(() => reminderEnabled = v),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            // Inside _AddBillScreenState -> ElevatedButton onPressed:
            onPressed: () {
              if (amountController.text.isNotEmpty) {
                final newBill = Bill(
                  id: DateTime.now().millisecondsSinceEpoch
                      .toString(), // Better ID
                  category: selectedCategory,
                  amount: double.parse(amountController.text),
                  dueDate: selectedDate,
                );

                // 1. Save the bill
                widget.onSave(newBill);

                // 2. Schedule notification if enabled
                if (reminderEnabled) {
                  NotificationService().scheduleBillReminder(
                    newBill.id,
                    newBill.category,
                    newBill.dueDate,
                  );
                }

                Navigator.pop(context);
              }
            },
            child: const Text("Add Bill"),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// --- 6. ANALYTICS SCREEN ---
class AnalyticsScreen extends StatelessWidget {
  final List<Bill> bills;
  const AnalyticsScreen({super.key, required this.bills});

  @override
  Widget build(BuildContext context) {
    // 1. Calculate totals per category
    final Map<String, double> totals = {};
    for (var bill in bills) {
      totals[bill.category] = (totals[bill.category] ?? 0) + bill.amount;
    }

    // 2. Find max value for scaling bars
    double maxTotal = 0;
    if (totals.isNotEmpty) {
      maxTotal = totals.values.reduce((a, b) => a > b ? a : b);
    }

    // 3. Prepare data for display (ensure we have all keys if needed, or just display what we have)
    // We'll display specific categories or all found ones. Let's show all found ones.
    // If no bills, show empty state or default 0.
    
    return Scaffold(
      appBar: AppBar(title: const Text("Spending Trends")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Monthly Distribution",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            
            if (bills.isEmpty)
              const Center(child: Text("No data to display"))
            else
              SizedBox(
                height: 200,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: totals.entries.map((e) {
                    // Safe division
                    double pct = maxTotal > 0 ? e.value / maxTotal : 0;
                    return _buildBar(e.key, pct, e.value);
                  }).toList(),
                ),
              ),

            const SizedBox(height: 40),
            _buildInsightsCard(bills, totals),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(String label, double pct, double amount) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Tooltip(
          message: '\$${amount.toStringAsFixed(2)}',
          child: Container(
            width: 40,
            height: 150 * pct,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label.length > 4 ? label.substring(0, 4) : label, // Truncate if long
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildInsightsCard(List<Bill> bills, Map<String, double> totals) {
    // Simple insight logic
    double totalSpent = bills.fold(0, (sum, b) => sum + b.amount);
    String topCategory = '';
    double topAmount = 0;
    
    if (totals.isNotEmpty) {
       var maxEntry = totals.entries.reduce((a, b) => a.value > b.value ? a : b);
       topCategory = maxEntry.key;
       topAmount = maxEntry.value;
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.insights, color: AppColors.accent),
        title: Text("Total: \$${totalSpent.toStringAsFixed(2)}"),
        subtitle: topCategory.isNotEmpty 
            ? Text("Most spending on $topCategory (\$${topAmount.toStringAsFixed(0)})")
            : const Text("Track your bills to see insights!"),
      ),
    );
  }
}
