/// Utility constants for the app
class AppConstants {
  // Expense Categories in Arabic
  static const Map<String, String> categoryNames = {
    'food': 'طعام',
    'transport': 'مواصلات',
    'entertainment': 'ترفيه',
    'shopping': 'تسوق',
    'bills': 'فواتير',
    'health': 'صحة',
    'education': 'تعليم',
    'other': 'أخرى',
  };
  
  // Currency
  static const String defaultCurrency = 'SAR';
  
  // Animation durations
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
}

enum AppCurrency {
  sar('SAR', 'ر.س', 'الريال السعودي'),
  yer('YER', 'ر.ي', 'الريال اليمني'),
  usd('USD', '\$', 'الدولار الأمريكي');

  final String code;
  final String symbol;
  final String name;

  const AppCurrency(this.code, this.symbol, this.name);
}
