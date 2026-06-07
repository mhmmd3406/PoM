class AppConstants {
  AppConstants._();

  static const bool debugBypassAuth =
      bool.fromEnvironment('BYPASS_AUTH', defaultValue: false);

  // Stripe — replace with real publishable key before going live
  static const String stripePublishableKey = 'pk_live_REPLACE_ME';

  // LinkedIn OAuth
  static const String linkedInClientId = 'REPLACE_ME';
  static const String linkedInRedirectUri = 'https://app.pom.app/auth/callback';
  static const String linkedInAuthBaseUrl =
      'https://www.linkedin.com/oauth/v2/authorization';
  static const String linkedInScope = 'r_liteprofile%20r_emailaddress';

  // Firestore collection names
  static const String usersCollection = 'users';
  static const String checkinsCollection = 'checkins';
  static const String companiesCollection = 'companies';
  static const String platformConfigCollection = 'platform_config';
  static const String insightsCollection = 'insights';
  static const String subscriptionsCollection = 'subscriptions';

  // Dynamic thresholds — fallback defaults
  // These are overridden by Firestore platform_config/thresholds
  static const int defaultCompanyMinN = 15;
  static const int defaultDepartmentMinN = 10;
  static const int defaultCompanyFilter = 200;
  static const int checkinCooldownDays = 7;

  // KVKK
  static const String currentKvkkVersion = '1.0';

  // Legal & support links (profile → Hesap & Gizlilik / PoM Hakkında).
  // Point these at the published legal pages before launch.
  static const String kvkkUrl = 'https://pom.app/kvkk';
  static const String privacyUrl = 'https://pom.app/gizlilik';
  static const String supportEmail = 'destek@pom.app';

  // Subscription plans
  static const String planFree = 'free';
  static const String planPro = 'pro';
  static const String planEnterprise = 'enterprise';
  static const String planDaas = 'daas';

  // Credit packs (amounts in credits, prices in TRY)
  static const List<Map<String, dynamic>> creditPacks = [
    {'credits': 10, 'price': 49, 'label': '10 Kredi'},
    {'credits': 50, 'price': 199, 'label': '50 Kredi'},
    {'credits': 100, 'price': 349, 'label': '100 Kredi'},
  ];

  // Subscription plan prices (TRY / month)
  static const Map<String, int> planPrices = {
    planFree: 0,
    planPro: 199,
    planEnterprise: 999,
  };

  // Check-in dimensions
  static const List<String> checkinDimensions = [
    'Genel Ruh Hali',
    'İş Stresi',
    'Takım Uyumu',
    'Kişisel Gelişim',
    'İş-Yaşam Dengesi',
  ];

  // Radar chart colors (hex)
  static const int colorPersonal = 0xFF2196F3;   // Blue
  static const int colorCompany = 0xFF4CAF50;    // Green
  static const int colorBenchmark = 0xFF9E9E9E;  // Gray
}
