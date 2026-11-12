import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../state/submission_controller.dart';
import '../utils/constants.dart';
import '../utils/auth_errors.dart';
import '../utils/validators.dart';
import 'app_button.dart';
import 'auth_switch_link.dart';
import 'brand_logo.dart';
import 'page_layout.dart';

class AuthForm extends StatefulWidget {
  const AuthForm({super.key, this.signup = false});
  final bool signup;
  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _invitation = TextEditingController();

  // Form values and the submit status (idle -> submitting -> success/error)
  // live in one controller; the screen only reads from it.
  late final SubmissionController _form = SubmissionController(
    initialValues: const {
      'name': '',
      'email': '',
      'password': '',
      'invitation': '',
    },
  );
  bool get _busy => _form.isSubmitting;
  String? _error;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => _form.setValue('name', _name.text));
    _email.addListener(() => _form.setValue('email', _email.text));
    _password.addListener(() => _form.setValue('password', _password.text));
    _invitation
        .addListener(() => _form.setValue('invitation', _invitation.text));
    _form.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _form.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _invitation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    // The controller blocks repeat taps while the request is running.
    final ok = await _form.submit((values) async {
      final auth = context.read<AuthService>();
      try {
        if (widget.signup) {
          await auth.signup(values['name']!, values['email']!,
              values['password']!, values['invitation']!);
        } else {
          await auth.login(values['email']!, values['password']!);
        }
      } catch (error) {
        throw ApiException(authErrorMessage(error));
      }
    });
    if (!mounted) return;
    if (ok) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
    } else if (_form.message != null) {
      setState(() => _error = _form.message);
      // Back to idle so a retry starts clean (typed values are kept).
      _form.reset(keepValues: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requiresInvitation = context.watch<AuthService>().requiresInvitation;
    return PageLayout(
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
                      widget.signup
                          ? 'Join your talent community'
                          : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                      widget.signup
                          ? (requiresInvitation
                              ? 'Create an account with your private invitation.'
                              : 'Create an account with your email address.')
                          : 'Sign in to continue your development journey.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  if (widget.signup) ...[
                    TextFormField(
                        controller: _name,
                        maxLength: 120,
                        decoration:
                            const InputDecoration(labelText: 'Full name'),
                        autofillHints: const [AutofillHints.name],
                        validator: (value) =>
                            Validators.required(value, 'Enter your name')),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: Validators.email),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: [
                        widget.signup
                            ? AutofillHints.newPassword
                            : AutofillHints.password
                      ],
                      decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword))),
                      validator: (value) => Validators.password(value,
                          checkLength: widget.signup)),
                  if (widget.signup && requiresInvitation) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _invitation,
                        decoration:
                            const InputDecoration(labelText: 'Invitation code'),
                        validator: (value) => Validators.required(
                            value, 'Enter your invitation code')),
                  ],
                  if (_error != null ||
                      context.watch<AuthService>().initializationError != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                            _error ??
                                context
                                    .watch<AuthService>()
                                    .initializationError!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  const SizedBox(height: 24),
                  AppButton(
                      label: widget.signup ? 'Create account' : 'Sign in',
                      loading: _busy,
                      onPressed: _submit),
                  const SizedBox(height: 8),
                  AuthSwitchLink(
                      prompt: widget.signup
                          ? 'Already a member?'
                          : (requiresInvitation
                              ? 'Have an invitation?'
                              : "Don't have an account?"),
                      action: widget.signup ? 'Sign in' : 'Create an account',
                      onTap: _busy
                          ? null
                          : () => Navigator.pushReplacementNamed(
                              context,
                              widget.signup
                                  ? AppRoutes.login
                                  : AppRoutes.signup)),
                ],
              ))),
    );
  }
}
