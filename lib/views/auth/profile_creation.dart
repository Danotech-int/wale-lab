import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/auth_errors.dart';
import '../../utils/themes.dart';
import '../../widgets/app_button.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/email_verification_notice.dart';

class ProfileCreationView extends StatefulWidget {
  const ProfileCreationView({super.key});

  @override
  State<ProfileCreationView> createState() => _ProfileCreationViewState();
}

class _ProfileCreationViewState extends State<ProfileCreationView> {
  final _formKey = GlobalKey<FormState>();
  final _headline = TextEditingController();
  final _bio = TextEditingController();
  final _skills = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _headline.dispose();
    _bio.dispose();
    _skills.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      await auth.createProfile(Profile(
          userId: auth.user!.id,
          headline: _headline.text.trim(),
          bio: _bio.text.trim(),
          skills: _skills.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList()));
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.home, (_) => false);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = authErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PageLayout(
      title: 'Create your profile',
      maxWidth: 680,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EmailVerificationNotice(),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_outline,
                          color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tell us about your experience and the skills you want to grow.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _headline,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Professional headline',
                    hintText: 'e.g. Aspiring Software Engineer',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a headline' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bio,
                  maxLength: 5000,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'About you',
                    hintText:
                        'Share a brief summary of your background and goals',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Tell us about yourself'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _skills,
                  decoration: const InputDecoration(
                    labelText: 'Skills',
                    helperText: 'Separate skills with commas',
                    hintText: 'e.g. Flutter, Dart, Problem Solving',
                  ),
                  validator: (v) {
                    final skills = (v ?? '')
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toSet();
                    if (skills.isEmpty) return 'Enter at least one skill';
                    if (skills.length > 50) return 'Enter up to 50 skills';
                    return null;
                  },
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Save profile',
                  loading: _busy,
                  isFullWidth: true,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
