abstract final class AppConstants {
  static const name = 'Excelerate Talent Hub';
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const useMock = bool.fromEnvironment('USE_MOCK');
  static const requestTimeout = Duration(seconds: 30);
  static const maxCvBytes = 5 * 1024 * 1024;
}

abstract final class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const profileCreation = '/profile/create';
  static const dashboard = '/learner/dashboard';
  static const adminDashboard = '/admin/dashboard';
  static const cvUpload = '/learner/cv';
  static const programs = '/learner/programs';
  static const programDetails = '/program-details';
  static String programDetailsFor(String id) =>
      '$programDetails/${Uri.encodeComponent(id)}';
  static const assessments = '/learner/assessments';
  static const badges = '/learner/badges';
  static const applications = '/learner/applications';
  static const opportunities = '/learner/opportunities';
  static const postOpportunity = '/admin/opportunities/new';
  static const applicationReview = '/admin/applications';
  static const candidateShortlisting = '/admin/shortlist';
  static const interviewScheduler = '/admin/interviews';
}
