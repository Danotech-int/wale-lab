import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../utils/auth_errors.dart';

/// Email ownership is visible without blocking profile onboarding.
class EmailVerificationNotice extends StatefulWidget {
  const EmailVerificationNotice({super.key});

  @override
  State<EmailVerificationNotice> createState() =>
      _EmailVerificationNoticeState();
}

class _EmailVerificationNoticeState extends State<EmailVerificationNotice> {
  bool _busy = false;
  String? _message;

  Future<void> _perform({required bool resend}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final auth = context.read<AuthService>();
    try {
      if (resend) {
        await auth.sendEmailVerification();
      } else {
        await auth.refreshUser();
      }
      if (mounted) {
        setState(() => _message = resend
            ? 'Verification email sent. Check your inbox and spam folder.'
            : 'Your email is not verified yet. Open the link in your email, then check again.');
      }
    } catch (error) {
      if (mounted) setState(() => _message = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.supportsEmailActions || auth.emailVerified) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verify your email: ${auth.user?.email ?? ''}',
                style: Theme.of(context).textTheme.titleSmall),
            const Text(
                'Use the verification link to confirm that this email belongs to you.'),
            Wrap(children: [
              TextButton(
                  onPressed: _busy ? null : () => _perform(resend: true),
                  child: const Text('Resend verification email')),
              TextButton(
                  onPressed: _busy ? null : () => _perform(resend: false),
                  child: const Text("I've verified my email")),
            ]),
            if (_busy) const LinearProgressIndicator(),
            if (_message != null) Text(_message!),
          ],
        ),
      ),
    );
  }
}
