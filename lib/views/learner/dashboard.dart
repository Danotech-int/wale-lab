import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/program_repository.dart';
import '../../utils/constants.dart';
import '../../widgets/dashboard_announcements.dart';
import '../../widgets/dashboard_layout.dart';
import '../../widgets/dashboard_overview.dart';
import '../../widgets/email_verification_notice.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  static Future<int> _registeredPrograms(BuildContext context) async =>
      (await context.read<ProgramRepository>().fetchPrograms())
          .programs
          .where((program) => program.isRegistered)
          .length;

  @override
  Widget build(BuildContext context) => DashboardLayout(
        title: 'Talent dashboard',
        workspace: 'YOUR LEARNING JOURNEY',
        name: context.watch<AuthService>().user!.name,
        introduction:
            'Build your skills and take the next step in your career.',
        announcements: const Column(children: [
          EmailVerificationNotice(),
          DashboardAnnouncements(role: UserRole.learner),
        ]),
        primaryAction: const DashboardAction(
          title: 'Explore programs',
          description: 'Find your next learning opportunity.',
          route: AppRoutes.programs,
          icon: Icons.school_outlined,
        ),
        overview: const DashboardOverview(metrics: [
          DashboardMetric.computed(
            label: 'Registered programs',
            loadCount: _registeredPrograms,
            route: AppRoutes.programs,
            icon: Icons.school_outlined,
          ),
          DashboardMetric(
            label: 'Your badges',
            path: '/badges/me',
            route: AppRoutes.badges,
            icon: Icons.workspace_premium_outlined,
          ),
          DashboardMetric(
            label: 'Your applications',
            path: '/applications/me',
            route: AppRoutes.applications,
            icon: Icons.work_outline,
          ),
        ]),
        actionsTitle: 'Your next steps',
        actions: const [
          DashboardAction(
            title: 'Job opportunities',
            description: 'Explore published roles and apply to join a team.',
            route: AppRoutes.opportunities,
            icon: Icons.business_center_outlined,
          ),
          DashboardAction(
            title: 'Development programs',
            description:
                'Discover courses, workshops and career opportunities.',
            route: AppRoutes.programs,
            icon: Icons.school_outlined,
          ),
          DashboardAction(
            title: 'Upload your CV',
            description: 'Share your experience with recruiters.',
            route: AppRoutes.cvUpload,
            icon: Icons.upload_file_outlined,
          ),
          DashboardAction(
            title: 'Assessments',
            description: 'Explore your strengths and track your progress.',
            route: AppRoutes.assessments,
            icon: Icons.quiz_outlined,
          ),
          DashboardAction(
            title: 'Your badges',
            description:
                'Celebrate the skills and achievements you have earned.',
            route: AppRoutes.badges,
            icon: Icons.workspace_premium_outlined,
          ),
          DashboardAction(
            title: 'Your applications',
            description: 'Follow the progress of your submitted applications.',
            route: AppRoutes.applications,
            icon: Icons.work_outline,
          ),
        ],
      );
}
