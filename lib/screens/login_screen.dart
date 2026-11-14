import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../services/auth.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/tugak.dart';
import 'home_shell.dart';

/// ============================================================
/// LOGIN — log in, sign up, or continue as a guest (paper, Table 8)
/// ============================================================
///
/// One screen with two modes: "Log in" (email + password) and "Create
/// account" (adds full name and barangay, which the database trigger puts
/// on the new `users` row). Shown when the app starts logged out, and
/// when a guest taps "Log in". Supabase does the checking
/// (services/auth.dart). Looks like a small copy of the landing page's
/// hero (Nov 14 2026): Tugak tipping his hat in a kBlue pool, his bubble
/// above him, the form under him (phones) or beside him (wide screens).
/// Tugak's line when a login or sign-up fails: what's wrong and what to do
/// first, then a dry joke (none when it's serious). Matched on Supabase's
/// error codes (supabase.com/docs/guides/auth/debugging/error-codes), not
/// its English messages. Not an AuthException = no connection.
String tugakAuthLine(Object e) {
  if (e is! AuthException) {
    return "I can't reach the server. Check your connection and try again. It's not you, it's the Wi-Fi.";
  }
  return switch (e.code) {
    'invalid_credentials' =>
      "Wrong email or password. I'd let you in, but the door has standards.",
    'user_already_exists' || 'email_exists' =>
      "That email already has an account. Log in instead, we've met.",
    'weak_password' => 'That password is too easy to guess. Mix in numbers or symbols, make it work for it.',
    'email_address_invalid' || 'validation_failed' =>
      "That email doesn't look right. Check for typos, I already squinted.",
    'over_request_rate_limit' || 'over_email_send_rate_limit' => "Too many tries in a row. Wait a minute, then try again. I'll hold your spot.",
    'email_not_confirmed' || 'confirm_email' =>
      'Confirm your email first: the link is in your inbox. Then log in here.',
    'signup_disabled' =>
      'Sign-ups are closed for now. You can still look around as a guest.',
    _ => e.message, // account_suspended and anything new: Supabase's own words, no joke
  };
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _barangay;
  bool _signUp = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// The first thing missing, in form order, or null when it's all there.
  /// Supabase checks everything again (wrong password, taken email...).
  String? _missing() {
    // Tugak says these (his bubble), so they're in his voice.
    if (_signUp && _name.text.trim().isEmpty) {
      return 'I need your full name first. "Guest" is already taken, by the guests.';
    }
    if (!_email.text.contains('@')) {
      return 'Type your email first. I can read the sky, not your inbox.';
    }
    if (_password.text.length < 6) {
      return 'The password needs at least 6 characters. "frog" got rejected, I tried.';
    }
    if (_signUp && _barangay == null) {
      return 'Pick your barangay, so I know whose streets to watch first.';
    }
    return null;
  }

  // An old "Type your email" must not stay up once the user fixes it.
  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }

  final _bubble = GlobalKey();

  // Tugak says what went wrong. His bubble is at the top: on a phone it can
  // be scrolled out of sight (keyboard up), so bring it back into view.
  void _say(String line) {
    setState(() {
      _busy = false;
      _error = line;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final at = _bubble.currentContext;
      if (at != null && at.mounted) {
        Scrollable.ensureVisible(
          at,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _submit() async {
    final missing = _missing();
    if (missing != null) return _say(missing);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      if (_signUp) {
        await signUp(
          fullName: _name.text.trim(),
          email: email,
          password: _password.text,
          barangay: _barangay!,
        );
      } else {
        await logInWithEmail(email: email, password: _password.text);
      }
      // Tells the browser / phone the login worked, so it offers to save
      // the password.
      TextInput.finishAutofillContext();
      if (!mounted) return;
      // Replace every screen (including a guest's app behind this one),
      // so Back can't return to the logged-out app.
      Navigator.of(context).pushAndRemoveUntil(
        slideRoute(HomeShell(initialTab: launchTab)),
        (_) => false,
      );
    } catch (e) {
      if (mounted) _say(tugakAuthLine(e));
    }
  }

  void _continueAsGuest() {
    final nav = Navigator.of(context);
    // Opened by a guest from inside the app: just go back to it.
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacement(slideRoute(HomeShell(initialTab: launchTab)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _signUp ? 'Join the watch' : 'Welcome back',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kDisplayFont,
              color: c.textPrimary,
              fontSize: 34,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: displayTracking(34),
            ),
          ),
          const SizedBox(height: 8),
          // Nov 14 2026 (Adrian: "boring and hard to read"): shorter lines,
          // Apple's 17 pt body, stronger contrast than the gray caption.
          Text(
            _signUp
                ? 'Free, and it takes a minute. Post floods, vote on what\'s real, and put your barangay first.'
                : 'Your reports, your votes, your barangay. Right where you left them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textPrimary.withValues(alpha: 0.72),
              fontSize: 17,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 26),
          ..._fields(c),
          const SizedBox(height: 20),
          PrimaryButton(
            label: _signUp ? 'Create my account' : 'Log in',
            color: kBlue,
            loading: _busy,
            onPressed: _submit,
          ),
          const SizedBox(height: 14),
          _modeSwitch(c),
          const SizedBox(height: 24),
          SecondaryButton(
            label: 'Just looking? Continue as guest',
            onPressed: _busy ? null : _continueAsGuest,
          ),
          const SizedBox(height: 10),
          Text(
            'Weather, map, reports, hotlines and SOS. No account needed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: FadeSlideIn(
                child: wide
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: Row(
                          children: [
                            Expanded(child: _hello(wide)),
                            const SizedBox(width: 64),
                            SizedBox(width: 400, child: form),
                          ],
                        ),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _hello(wide),
                            const SizedBox(height: 16),
                            form,
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Tugak's welcome: his bubble, then him tipping his hat in the landing
  // hero's kBlue pool. When something's wrong he says it instead (the
  // form has no red error line) and thinks it over.
  Widget _hello(bool wide) {
    final size = wide ? 300.0 : 130.0;
    final error = _error;
    final line =
        error ??
        (_signUp
            ? "One free account and you can post floods and vote on reports. That's the whole deal."
            : "Log in so your flood reports carry your name. Or look around as a guest, I don't check IDs.");
    const fade = Duration(milliseconds: 220);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          key: _bubble,
          constraints: const BoxConstraints(maxWidth: 340),
          // read out when it changes, so screen readers hear the error too
          child: Semantics(
            liveRegion: true,
            child: AnimatedSize(
              duration: fade,
              curve: Curves.easeOutCubic,
              child: AnimatedSwitcher(
                duration: fade,
                child: TugakSay(line, key: ValueKey(line)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                kBlue.withValues(alpha: 0.2),
                kBlue.withValues(alpha: 0),
              ],
            ),
          ),
          child: AnimatedSwitcher(
            duration: fade,
            child: TugakImage(
              key: ValueKey(error == null),
              size: size,
              pose: error == null ? 'tip' : 'think',
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _fields(AppColors c) => [
    if (_signUp) ...[
      AppTextField(
        hint: 'Full name',
        icon: CupertinoIcons.person,
        controller: _name,
        onChanged: _clearError,
        autofillHints: const [AutofillHints.name],
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 10),
    ],
    AppTextField(
      hint: 'Email',
      icon: CupertinoIcons.mail,
      controller: _email,
      onChanged: _clearError,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.next,
    ),
    const SizedBox(height: 10),
    AppTextField(
      hint: _signUp ? 'Password (at least 6 characters)' : 'Password',
      icon: CupertinoIcons.lock,
      controller: _password,
      onChanged: _clearError,
      obscure: !_showPassword,
      autofillHints: [
        _signUp ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textInputAction: _signUp ? TextInputAction.next : TextInputAction.go,
      onSubmitted: _signUp ? null : (_) => _submit(),
      suffix: Semantics(
        button: true,
        label: _showPassword ? 'Hide password' : 'Show password',
        child: PressableScale(
          onTap: () => setState(() => _showPassword = !_showPassword),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              _showPassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
              color: c.textSecondary,
              size: 20,
            ),
          ),
        ),
      ),
    ),
    if (_signUp) ...[
      const SizedBox(height: 10),
      BarangayDropdown(
        value: _barangay,
        onChanged: (b) => setState(() => _barangay = b),
      ),
    ],
  ];

  // "New to AgosAlert? Create an account" / "Have an account? Log in".
  Widget _modeSwitch(AppColors c) {
    return Center(
      child: PressableScale(
        onTap: _busy
            ? null
            : () => setState(() {
                _signUp = !_signUp;
                _error = null;
              }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text.rich(
            TextSpan(
              text: _signUp ? 'Already in? ' : 'New here? ',
              style: TextStyle(color: c.textSecondary, fontSize: 15),
              children: [
                TextSpan(
                  text: _signUp ? 'Log in' : 'Create a free account',
                  style: TextStyle(
                    color: c.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
