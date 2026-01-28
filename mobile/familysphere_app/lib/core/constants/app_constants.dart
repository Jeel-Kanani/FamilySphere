// App-wide constants
class AppConstants {
  // App Info
  static const String appName = 'FamilySphere';
  static const String appVersion = '1.0.0';
  
  // Storage Keys
  static const String userBoxKey = 'user_cache';
  static const String documentBoxKey = 'document_cache';
  static const String settingsBoxKey = 'settings_cache';
  
  // File Size Limits (in bytes)
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  
  // Pagination
  static const int documentsPerPage = 20;
  static const int photosPerPage = 30;
  
  // Cache Duration
  static const Duration cacheExpiry = Duration(days: 7);
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
}

// Firebase Collection Names
class FirebaseCollections {
  static const String users = 'users';
  static const String families = 'families';
  static const String documents = 'documents';
  static const String events = 'events';
  static const String tasks = 'tasks';
  static const String albums = 'albums';
  static const String photos = 'photos';
  static const String expenses = 'expenses';
  static const String budgets = 'budgets';
  static const String messages = 'messages';
  static const String healthProfiles = 'health_profiles';
  static const String activityLogs = 'activity_logs';
}

// Document Categories
enum DocumentCategory {
  property,
  vehicle,
  identity,
  education,
  health,
  finance,
  personal,
  other
}

// Privacy Levels
enum PrivacyLevel {
  shared,
  private
}

// User Roles
enum UserRole {
  admin,
  member
}

// Task Categories
enum TaskCategory {
  chores,
  shopping,
  errands,
  homework,
  other
}

// Expense Categories
enum ExpenseCategory {
  groceries,
  utilities,
  education,
  healthcare,
  entertainment,
  transport,
  other
}
