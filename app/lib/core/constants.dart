class AppConstants {
  AppConstants._();

  static const String appName = 'Starpath';
  static const String currencyName = '灵感币';
  static const String currencyNameEn = 'Spark';

  // Free tier limits
  static const int maxFreeAgents = 3;
  static const int dailyFreeMessages = 20;

  // Currency rewards
  static const int rewardPublishCard = 10;
  static const int rewardReceiveLike = 1;
  static const int rewardReceiveComment = 2;
  static const int rewardDailyCheckIn = 5;

  // Currency costs
  static const int costPerMessage = 1;

  // API
  static const String apiBaseUrl = 'http://localhost:3000/api/v1';
  static const String aiServiceUrl = 'http://localhost:8000';
  static const String wsUrl = 'ws://localhost:3000';
  static const String wsBaseUrl = 'http://localhost:3000';
}
