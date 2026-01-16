import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Import for AppColors and AuthScreen

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _completeOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      pages: [
        PageViewModel(
          title: "Welcome to BillWise",
          body: "Manage your utility bills smarter and easier than ever before.",
          image: const Center(
            child: Icon(Icons.account_balance_wallet_rounded, 
                  size: 100.0, color: AppColors.primary),
          ),
          decoration: const PageDecoration(
            pageColor: Colors.white,
            titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: AppColors.primary),
            bodyTextStyle: TextStyle(fontSize: 16.0),
          ),
        ),
        PageViewModel(
          title: "Track Your Spending",
          body: "Keep an eye on your monthly expenses with detailed analytics.",
          image: const Center(
            child: Icon(Icons.analytics_outlined, 
                  size: 100.0, color: AppColors.accent),
          ),
          decoration: const PageDecoration(
             pageColor: Colors.white,
            titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: AppColors.primary),
            bodyTextStyle: TextStyle(fontSize: 16.0),
          ),
        ),
        PageViewModel(
          title: "Never Miss a Due Date",
          body: "Get timely reminders before your bills are due.",
          image: const Center(
            child: Icon(Icons.notifications_active_outlined, 
                  size: 100.0, color: Colors.orange),
          ),
          decoration: const PageDecoration(
             pageColor: Colors.white,
            titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: AppColors.primary),
            bodyTextStyle: TextStyle(fontSize: 16.0),
          ),
        ),
      ],
      onDone: () => _completeOnboarding(context),
      onSkip: () => _completeOnboarding(context),
      showSkipButton: true,
      skip: const Text("Skip", style: TextStyle(fontWeight: FontWeight.bold)),
      next: const Icon(Icons.arrow_forward),
      done: const Text("Done", style: TextStyle(fontWeight: FontWeight.w600)),
      dotsDecorator: DotsDecorator(
        size: const Size.square(10.0),
        activeSize: const Size(20.0, 10.0),
        activeColor: AppColors.primary,
        color: Colors.black26,
        spacing: const EdgeInsets.symmetric(horizontal: 3.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0)
        ),
      ),
    );
  }
}
