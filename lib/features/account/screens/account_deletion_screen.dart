import 'package:flutter/material.dart';
import '../../../services/account_deletion_controller.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key, required this.controller});
  final AccountDeletionController controller;
  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _password = TextEditingController();
  bool _confirmed = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.controller.resume();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _password.dispose();
    super.dispose();
  }

  String get _status => switch (widget.controller.state) {
    AccountDeletionState.idle =>
      'Silme işlemi açık onayın ve mevcut şifrenle başlatılır.',
    AccountDeletionState.pending =>
      'Silme işlemi sürüyor. Henüz tamamlanmadı; güvenle devam edebilirsin.',
    AccountDeletionState.blockedPlanet =>
      'Gezegen yayınlarının ortak yol bağımlılıkları nedeniyle talebin inceleme bekliyor. Hesap silme tamamlanmadı.',
    AccountDeletionState.completed =>
      'Hesabın ve silinebilir sunucu verilerin silindi. Cihazdaki sürüş kayıtlarına dokunulmadı.',
    AccountDeletionState.busy =>
      'Talebin başka bir işlemde yürütülüyor. Biraz sonra tekrar kontrol edebilirsin.',
    AccountDeletionState.failed =>
      'İşlem tamamlanamadı. Şifreni, bağlantını ve aktif sürüş durumunu kontrol edip yeniden deneyebilirsin.',
    AccountDeletionState.receiptUnavailable =>
      'Talep durumu doğrulanamadı. Hesap silindi olarak gösterilemiyor. Giriş yapabiliyorsan aynı cihazdan yeniden onaylayabilirsin.',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hesabımı Sil')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Hesabın, kişisel bulut sürüşlerin, profilin ve sana ait Gezegen yayınları silme işlemine alınır. Bu işlem geri alınamaz. Ortak yol bağımlılıkları çözülemiyorsa silme tamamlanmış sayılmaz.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Cihazdaki sürüş kayıtların silinmez. Hesaptan çıkıldığında bu hesabın yerel alanı görünmez; bu işlem yerel arşiv aktarımı yapmaz. Aktif sürüşünü önce bitirmelisin.',
        ),
        const SizedBox(height: 16),
        Text(_status, key: const ValueKey('account_deletion_status')),
        if (widget.controller.busy) const LinearProgressIndicator(),
        if (widget.controller.state != AccountDeletionState.completed) ...[
          TextField(
            controller: _password,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Mevcut şifren'),
            key: const ValueKey('account_deletion_password'),
          ),
          CheckboxListTile(
            value: _confirmed,
            onChanged: widget.controller.busy
                ? null
                : (v) => setState(() => _confirmed = v ?? false),
            title: const Text(
              'Hesabımı ve sunucudaki kişisel verilerimi silmek istiyorum.',
            ),
            key: const ValueKey('account_deletion_consent'),
          ),
          FilledButton(
            onPressed: !_confirmed || widget.controller.busy
                ? null
                : () async {
                    final password = _password.text;
                    _password.clear();
                    await widget.controller.start(
                      password: password,
                      confirmed: _confirmed,
                    );
                  },
            key: const ValueKey('account_deletion_confirm'),
            child: const Text('Hesabımı Sil'),
          ),
          TextButton(
            onPressed: widget.controller.busy ? null : widget.controller.resume,
            key: const ValueKey('account_deletion_resume'),
            child: const Text('Silme talebini kontrol et / devam et'),
          ),
        ],
      ],
    ),
  );
}
