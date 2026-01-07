import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'البداية الذكية',
      description: 'وازن حياتك المالية بكل سهولة وذكاء مع Balanceer.',
      image: 'assets/images/onboarding/welcome.png',
      color: AppTheme.primaryColor,
    ),
    OnboardingData(
      title: 'بساطة التدوين',
      description: 'أضف مصاريفك اليومية في ثوانٍ معدودة وبضغطة زر واحدة.',
      image: 'assets/images/onboarding/expense.png',
      color: AppTheme.secondaryColor,
    ),
    OnboardingData(
      title: 'التحكم الكامل',
      description: 'حدد ميزانياتك الشهرية وراقب استهلاكك لتصل لأهدافك.',
      image: 'assets/images/onboarding/budget.png',
      color: AppTheme.accentOrange,
    ),
    OnboardingData(
      title: 'الرؤية العميقة',
      description: 'رسوم بيانية وتحاليل دقيقة تساعدك على فهم نمط إنفاقك.',
      image: 'assets/images/onboarding/analytics.png',
      color: AppTheme.accentBlue,
    ),
    OnboardingData(
      title: 'الأمان والسحاب',
      description: 'بياناتك محفوظة بأمان ومزامنة عبر جميع أجهزتك بالسحاب.',
      image: 'assets/images/onboarding/cloud.png',
      color: AppTheme.primaryLight,
    ),
    OnboardingData(
      title: 'إدارة الديون',
      description: 'تتبع الديون المستحقة لك وعليك بسهولة، ولا تنسى حقوقك المالية.',
      image: 'assets/images/onboarding/debt.png',
      color: AppTheme.accentRed,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 1.5,
                colors: [
                  _pages[_currentPage].color.withValues(alpha: 0.15),
                  AppTheme.scaffoldBackground,
                ],
              ),
            ),
          ),

          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() => _currentPage = page);
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return _OnboardingPage(data: _pages[index]);
            },
          ),

          // Top Skip Button
          Positioned(
            top: 60,
            left: 20,
            child: TextButton(
              onPressed: _completeOnboarding,
              child: Text(
                'تخطي',
                style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 60,
            left: 30,
            right: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Indicators
                Row(
                  children: List.generate(
                    _pages.length,
                    (index) => _buildIndicator(index == _currentPage),
                  ),
                ),

                // Next Button
                GestureDetector(
                  onTap: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                      );
                    } else {
                      _completeOnboarding();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 60,
                    width: _currentPage == _pages.length - 1 ? 140 : 60,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _currentPage == _pages.length - 1
                          ? Text(
                              'ابدأ الآن',
                              style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ).animate().fadeIn()
                          : const Icon(Icons.arrow_forward_ios, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : AppTheme.textMuted.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final OnboardingData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image with Glassmorphism shadow
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: size.width * 0.7,
                width: size.width * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      data.color.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ).animate().scale(duration: 1200.ms, curve: Curves.easeOutBack),
              Image.asset(
                data.image,
                height: size.width * 0.8,
                fit: BoxFit.contain,
              ).animate().moveY(begin: 20, end: 0, duration: 800.ms, curve: Curves.easeOut),
            ],
          ),
          const SizedBox(height: 60),

          // Text Content
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: AppTheme.darkTheme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 32,
              color: AppTheme.textPrimary,
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 20),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 18,
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final String image;
  final Color color;

  OnboardingData({
    required this.title,
    required this.description,
    required this.image,
    required this.color,
  });
}
