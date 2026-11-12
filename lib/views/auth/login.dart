import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/auth_errors.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/auth_switch_link.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/page_layout.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await context.read<AuthService>().login(
            _emailController.text.trim(),
            _passwordController.text,
          );

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (_) => false,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = authErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    final auth = context.read<AuthService>();
    if (auth.supportsEmailActions) {
      if (Validators.email(_emailController.text) != null) {
        setState(() =>
            _error = 'Enter your email address above to reset your password.');
        return;
      }
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        await auth.resetPassword(_emailController.text);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'If an account exists for this email, a password reset link has been sent. Check your inbox and spam folder.'),
        ));
      } catch (error) {
        if (mounted) setState(() => _error = authErrorMessage(error));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Password reset is not available yet. '
            'Please contact your Excelerate administrator.'),
      ));
  }

  // Login and Sign Up share PageLayout, field styling, AppButton and
  // AuthSwitchLink so the two screens look and behave the same.
  @override
  Widget build(BuildContext context) => PageLayout(
        title: AppConstants.name,
        appBarTitle: const SizedBox.shrink(),
        maxWidth: 520,
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BrandLogo(showTagline: true)),
                const SizedBox(height: 32),
                Text(
                  'Welcome Back!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Login to continue to your account.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip:
                          _obscurePassword ? 'Show password' : 'Hide password',
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: Validators.password,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _forgotPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_error != null ||
                    context.watch<AuthService>().initializationError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error ??
                          context.watch<AuthService>().initializationError!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 16),
                // The label stays "LOGIN": four test files look for that text.
                AppButton(
                  label: 'LOGIN',
                  loading: _busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 8),
                AuthSwitchLink(
                  prompt: "Don't have an account?",
                  action: 'Sign Up',
                  onTap: _busy
                      ? null
                      : () => Navigator.pushReplacementNamed(
                          context, AppRoutes.signup),
                ),
              ],
            ),
          ),
        ),
      );
}
