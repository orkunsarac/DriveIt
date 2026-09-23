import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/supabase_account_service.dart';
import '../screens/driveit_account_screen.dart';
import '../screens/driveit_account_settings_screen.dart';

class DriveItAccountSection extends StatefulWidget {
  const DriveItAccountSection({super.key, this.accountGateway});

  final DriveItAccountGateway? accountGateway;

  @override
  State<DriveItAccountSection> createState() => _DriveItAccountSectionState();
}

class _DriveItAccountSectionState extends State<DriveItAccountSection> {
  static const _blue = Color(0xff248fff);
  late final DriveItAccountGateway _service;
  StreamSubscription<dynamic>? _authSubscription;
  DriveItAccountProfile? _account;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  String? get _effectiveCloudName => DriveItEffectiveProfile.displayName(
    localName: null,
    hasSession: true,
    cloudProfile: _account,
    cloudProfileLoaded: !_loading && _error == null,
    cloudProfileFailed: _error != null,
  );

  String? get _effectiveCloudUsername => DriveItEffectiveProfile.username(
    localUsername: null,
    hasSession: true,
    cloudProfile: _account,
    cloudProfileLoaded: !_loading && _error == null,
    cloudProfileFailed: _error != null,
  );

  @override
  void initState() {
    super.initState();
    _service = widget.accountGateway ?? SupabaseAccountService.instance;
    if (_service.isAvailable) {
      _authSubscription = _service.authStateChanges.listen(
        (_) => _loadAccount(),
      );
    }
    _loadAccount();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    if (!mounted) return;
    if (!_service.isAvailable || !_service.hasSession) {
      setState(() {
        _account = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final account = await _service.fetchCurrentProfile();
      if (!mounted) return;
      setState(() {
        _account = account;
        _loading = false;
        _error = account == null ? 'Hesap bilgileri henüz hazır değil.' : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Hesap bilgileri alınamadı. Yeniden deneyebilirsin.';
        });
      }
    }
  }

  Future<void> _openAccount({
    DriveItAccountMode mode = DriveItAccountMode.choices,
  }) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DriveItAccountScreen(initialMode: mode),
      ),
    );
    await _loadAccount();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DriveItAccountSettingsScreen(accountGateway: _service),
      ),
    );
    await _loadAccount();
  }

  Future<void> _confirmSignOut() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff07162b),
        title: const Text('Çıkış yapılsın mı?'),
        content: const Text(
          'DriveIt hesabından çıkış yapılacak. Cihazındaki profil, sürüşler ve diğer yerel veriler korunur.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('driveit_logout_cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            key: const ValueKey('driveit_logout_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Çıkış Yap',
              style: TextStyle(color: Color(0xffff8a8a)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _signOut();
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // This only clears the Supabase session. Local Hive/profile/drive data
      // is intentionally not touched.
      await _service.signOut();
      await _loadAccount();
    } catch (_) {
      if (mounted) setState(() => _error = 'Çıkış yapılamadı. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showCloseAccountNotice() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff07162b),
        title: const Text('DriveIt Hesabını Kapat'),
        content: const Text(
          'Hesap kapatma şu anda güvenli sunucu işlemiyle desteklenmiyor. Cihazındaki sürüşler, profil ve diğer yerel veriler korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _button(
    String label,
    VoidCallback? onPressed, {
    bool primary = false,
    Key? key,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return SizedBox(
      width: double.infinity,
      child: primary
          ? FilledButton(
              key: key,
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: shape,
              ),
              child: Text(label),
            )
          : OutlinedButton(
              key: key,
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xff315071)),
                shape: shape,
              ),
              child: Text(label),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = _service.isAvailable;
    final signedIn = available && _service.hasSession;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff07162b),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xff315071), width: .75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'DriveIt Hesabı',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          if (!available)
            const Text(
              'Çevrimiçi hesap hizmeti şu anda kullanılamıyor.',
              style: TextStyle(color: Colors.white70),
            )
          else if (_loading)
            const LinearProgressIndicator(minHeight: 2, color: _blue)
          else if (!signedIn)
            const Text(
              'DriveIt Gezegeni ve çevrimiçi özellikler için hesabını bağla. Yerel sürüşlerin ve profilin hesap olmadan da kullanılabilir.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            )
          else ...[
            if (_error == null)
              Text(
                _effectiveCloudName ?? 'Hesap bilgileri yükleniyor…',
                key: const Key('driveit_cloud_display_name'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (_effectiveCloudUsername != null)
              Text(
                _effectiveCloudUsername!,
                style: const TextStyle(color: Colors.white70),
              ),
            if (_account?.email != null)
              Text(
                _account!.email!,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xffff8a8a), fontSize: 12),
            ),
            if (signedIn)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _loadAccount,
                  child: const Text('Yeniden Dene'),
                ),
              ),
          ],
          if (available && !signedIn && !_loading) ...[
            const SizedBox(height: 12),
            _button(
              'Hesap Oluştur',
              () => _openAccount(mode: DriveItAccountMode.create),
              primary: true,
            ),
            _button(
              'Giriş Yap',
              () => _openAccount(mode: DriveItAccountMode.login),
            ),
          ],
          if (signedIn && !_loading) ...[
            const SizedBox(height: 12),
            _button(
              'Ayarlar',
              _busy ? null : _openSettings,
              key: const ValueKey('driveit_account_settings'),
            ),
            _button(
              _busy ? 'Çıkış yapılıyor…' : 'Hesaptan Çıkış Yap',
              _busy ? null : _confirmSignOut,
              key: const ValueKey('driveit_account_logout'),
              primary: true,
            ),
            TextButton(
              onPressed: _showCloseAccountNotice,
              child: const Text(
                'DriveIt Hesabını Kapat',
                style: TextStyle(color: Color(0xffe58b91)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
