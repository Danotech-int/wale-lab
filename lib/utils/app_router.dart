import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../views/admin/application_review.dart';
import '../views/admin/candidate_shortlisting.dart';
import '../views/admin/dashboard.dart';
import '../views/admin/interview_scheduler.dart';
import '../views/admin/post_opportunity.dart';
import '../views/auth/login.dart';
import '../views/auth/profile_creation.dart';
import '../views/auth/signup.dart';
import '../views/learner/applications.dart';
import '../views/learner/assessments.dart';
import '../views/learner/badges.dart';
import '../views/learner/cv_upload.dart';
import '../views/learner/dashboard.dart';
import '../views/learner/programs_list.dart';
import '../views/learner/opportunities.dart';
import '../views/shared/program_details_loader.dart';
import '../widgets/page_layout.dart';
import 'constants.dart';

abstract final class AppRouter {
  static const _notFound = PageLayout(
      title: 'Page not found',
      child:
          Text('This page is unavailable. Please return to your dashboard.'));

  static String? _programIdFrom(String? name) {
    final segments = Uri.tryParse(name ?? '')?.pathSegments ?? const <String>[];
    return segments.length == 2 &&
            segments.first == 'program-details' &&
            segments[1].isNotEmpty
        ? segments[1]
        : null;
  }

  static Route<dynamic> generate(RouteSettings settings) {
    final programId = _programIdFrom(settings.name);
    if (programId != null) {
      return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              AuthGuard(child: ProgramDetailsLoader(programId: programId)));
    }
    final Widget screen;
    switch (settings.name) {
      case AppRoutes.home:
      case AppRoutes.login:
        screen = const SessionGate();
      case AppRoutes.signup:
        screen = const SessionGate(guestView: SignupView());
      case AppRoutes.profileCreation:
        screen = const AuthGuard(
            allowIncompleteProfile: true, child: ProfileCreationView());
      case AppRoutes.dashboard:
        screen =
            const AuthGuard(role: UserRole.learner, child: DashboardView());
      case AppRoutes.adminDashboard:
        screen =
            const AuthGuard(role: UserRole.admin, child: AdminDashboardView());
      case AppRoutes.cvUpload:
        screen = const AuthGuard(role: UserRole.learner, child: CvUploadView());
      case AppRoutes.programs:
        screen = const AuthGuard(child: ProgramsListView());
      case AppRoutes.programDetails:
        screen = _notFound;
      case AppRoutes.assessments:
        screen =
            const AuthGuard(role: UserRole.learner, child: AssessmentsView());
      case AppRoutes.badges:
        screen = const AuthGuard(role: UserRole.learner, child: BadgesView());
      case AppRoutes.applications:
        screen =
            const AuthGuard(role: UserRole.learner, child: ApplicationsView());
      case AppRoutes.opportunities:
        screen =
            const AuthGuard(role: UserRole.learner, child: OpportunitiesView());
      case AppRoutes.postOpportunity:
        screen =
            const AuthGuard(role: UserRole.admin, child: PostOpportunityView());
      case AppRoutes.applicationReview:
        screen = const AuthGuard(
            role: UserRole.admin, child: ApplicationReviewView());
      case AppRoutes.candidateShortlisting:
        screen = const AuthGuard(
            role: UserRole.admin, child: CandidateShortlistingView());
      case AppRoutes.interviewScheduler:
        screen = AuthGuard(
            role: UserRole.admin,
            child: InterviewSchedulerView(
                applicationId: settings.arguments is String
                    ? settings.arguments as String
                    : null));
      default:
        screen = _notFound;
    }
    return MaterialPageRoute<void>(settings: settings, builder: (_) => screen);
  }
}

class SessionGate extends StatelessWidget {
  const SessionGate({super.key, this.guestView = const LoginView()});
  final Widget guestView;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.user == null) return guestView;
    if (auth.user!.role == UserRole.learner && !auth.user!.profileCompleted) {
      return const ProfileCreationView();
    }
    return auth.user!.role == UserRole.admin
        ? const AdminDashboardView()
        : const DashboardView();
  }
}

class AuthGuard extends StatelessWidget {
  const AuthGuard(
      {super.key,
      required this.child,
      this.role,
      this.allowIncompleteProfile = false});
  final Widget child;
  final UserRole? role;
  final bool allowIncompleteProfile;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = auth.user;
    if (user == null) return const LoginView();
    if (role != null && user.role != role) {
      return const PageLayout(
          title: 'Access restricted',
          child: Text('You do not have access to this workspace.'));
    }
    if (!allowIncompleteProfile &&
        user.role == UserRole.learner &&
        !user.profileCompleted) {
      return const ProfileCreationView();
    }
    return child;
  }
}
