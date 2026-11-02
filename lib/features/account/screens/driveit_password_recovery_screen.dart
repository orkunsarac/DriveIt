import 'package:flutter/material.dart';

import '../../../services/supabase_account_service.dart';

/// Shown only after Supabase emits passwordRecovery with a recovered session.
class DriveItPasswordRecoveryScreen extends StatefulWidget {
  const DriveItPasswordRecoveryScreen({
    super.key,
    this.accountGateway,
    this.isRecoveryContextCurrent,
  });

  final DriveItAccountGateway? accountGateway;
  final bool Function()? isRecoveryContextCurrent;

  @override
  State<DriveItPasswordRecoveryScreen> createState() =>
      _DriveItPasswordRecoveryScreenState();
}

class _DriveItPasswordRecoveryScreenState
    extends State<DriveItPasswordRecoveryScreen> {
  late final DriveItAccountGateway _account;
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _completed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _account = widget.accountGateway ?? SupabaseAccountService.instance;
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.isRecoveryContextCurrent?.call() == false) {
      setState(
        () => _error =
            'Oturum değişti. Yeni bir parola sıfırlama bağlantısı iste.',
      );
      return;
    }
    final validation =
        AccountInputRules.validatePassword(_password.text) ??
        AccountInputRules.validatePasswordConfirmation(
          _password.text,
          _confirmation.text,
        );
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _account.completePasswordRecovery(_password.text);
      if (!mounted) return;
      _password.clear();
      _confirmation.clear();
      setState(() => _completed = true);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is AccountServiceException
            ? error.message
            : 'Bağlantı geçersiz veya süresi dolmuş olabilir. Yeni bir parola sıfırlama bağlantısı iste.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parolayı yenile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              _completed
                  ? 'Parolan güncellendi.'
                  : 'Hesabın için yeni bir parola belirle.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!_completed) ...[
              const SizedBox(height: 20),
              TextField(
                key: const Key('recovery-new-password'),
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'Yeni parola'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('recovery-confirm-password'),
                controller: _confirmation,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Parolayı tekrar yaz',
                ),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                Text(error, key: const Key('recovery-error')),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('recovery-save'),
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Kaydediliyor…' : 'Parolayı güncelle'),
              ),
            ] else
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Uygulamaya dön'),
              ),
          ],
        ),
      ),
    );
  }
}
