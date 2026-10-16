import 'package:flutter/material.dart';
import '../services/account_drive_transfer.dart';
import '../services/device_drive_archive.dart';
import '../services/local_owner_lifecycle.dart';
import '../widgets/local_owner_view.dart';

class AccountDriveTransferScreen extends StatefulWidget {
  const AccountDriveTransferScreen({super.key, required this.lease});
  final LocalOwnerLease lease;
  @override
  State<AccountDriveTransferScreen> createState() =>
      _AccountDriveTransferScreenState();
}

class _AccountDriveTransferScreenState
    extends State<AccountDriveTransferScreen> {
  int _guestCount = 0;
  bool _legacyAvailable = false, _busy = false;
  String _message = '';
  DeviceDriveArchiveContext? _archive;
  List<LegacyTransferRow>? _rows;
  final Set<String> _selected = {};
  bool get _current => mounted && widget.lease.isCurrent;

  @override
  void initState() {
    super.initState();
    _run(_refresh);
  }

  @override
  void dispose() {
    _archive?.removeListener(_archiveChanged);
    _archive?.dispose();
    super.dispose();
  }

  void _archiveChanged() {
    if (_current && _archive?.isCurrent != true) {
      setState(() {
        _rows = null;
        _selected.clear();
      });
    }
  }

  Future<void> _refresh() async {
    final available = await widget.lease.accountTransferAvailability();
    if (_current) {
      setState(() {
        _guestCount = available.guest;
        _legacyAvailable = available.legacy;
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (_current) {
        setState(
          () => _message =
              error is StateError &&
                  error.message == 'transfer_recording_active'
              ? 'Önce devam eden sürüşü kaydedin. Kayıtlarınız korunuyor.'
              : 'İşlem tamamlanamadı. Doğrulanmış aktarımlar hesapta, tamamlanmamış kayıtlar kaynakta korunur. Hesap veya cihaz doğrulaması değiştiyse yeniden doğrulayarak devam edin.',
        );
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sürüş Aktarımı'),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Şimdi Değil'),
            ),
            FilledButton(
              key: const Key('transfer_confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Onayla'),
            ),
          ],
        ),
      ) ==
      true;
  void _result(AccountTransferResult result) {
    if (_current) {
      setState(
        () => _message =
            '${result.transferred} sürüş aktarıldı, ${result.rejected} sürüş aktarılamadı. '
            '${result.localOnly} sürüş yalnız bu hesapta yerel saklanır; buluta uygun değildir.',
      );
    }
  }

  Future<void> _authorizeLegacy() async {
    final access = await widget.lease.authorizeArchiveTransfer();
    if (!_current) {
      access.dispose();
      return;
    }
    _archive?.removeListener(_archiveChanged);
    _archive?.dispose();
    _archive = access..addListener(_archiveChanged);
    final rows = await widget.lease.legacyTransferRows(access);
    if (_current && access.isCurrent) {
      setState(() {
        _rows = rows;
        _selected.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) => LocalOwnerView(
    lease: widget.lease,
    builder: (context) {
      final valid = _rows?.where((r) => r.incompatibility == null).length ?? 0;
      final invalid =
          _rows?.where((r) => r.incompatibility != null).toList() ??
          <LegacyTransferRow>[];
      return Scaffold(
        appBar: AppBar(title: const Text('Sürüşleri Hesabıma Aktar')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Aktarım yalnız şu anda açık olan hesaba yapılır. Tarih, rota ve kayıtlı ölçümler korunur. Uygun sürüşler bulut senkronizasyonu kuyruğuna alınır.',
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_message, key: const Key('transfer_result')),
              ),
            ListTile(
              title: const Text('Misafir Sürüşleri'),
              subtitle: Text('Aktarılabilecek kayıt: $_guestCount'),
            ),
            FilledButton(
              key: const Key('transfer_guest'),
              onPressed: _busy || _guestCount == 0
                  ? null
                  : () async {
                      if (!await _confirm(
                        'Bu cihazdaki misafir sürüşlerini hesabınıza aktarmak ister misiniz? Doğrulanan sürüşler Misafir geçmişinden kaldırılır.',
                      )) {
                        return;
                      }
                      await _run(() async {
                        _result(await widget.lease.transferGuestToAccount());
                        await _refresh();
                      });
                    },
              child: const Text('Misafir Sürüşlerini Hesabıma Aktar'),
            ),
            if (_legacyAvailable) ...[
              const Divider(height: 32),
              const Text(
                'Eski Cihaz Arşivi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'Eski kayıtların incelenmesi, aktarılması ve seçilmiş uyumsuz kayıtların temizlenmesi cihaz doğrulaması gerektirir.',
              ),
              OutlinedButton(
                key: const Key('transfer_authorize_archive'),
                onPressed: _busy ? null : () => _run(_authorizeLegacy),
                child: const Text('PIN / Biyometri ile Arşivi İncele'),
              ),
              if (_rows != null) ...[
                Text(
                  'Aktarılabilecek: $valid • Aktarılamayan: ${invalid.length}',
                ),
                const Text(
                  'Telemetri bulunmayan geçerli eski rotalar yerel hesap geçmişine aktarılır; buluta gönderilmez, skor uydurulmaz.',
                ),
                FilledButton(
                  key: const Key('transfer_archive'),
                  onPressed: _busy || valid == 0 || _archive?.isCurrent != true
                      ? null
                      : () async {
                          if (!await _confirm(
                            '$valid eski sürüş hesabınıza aktarılacak. Kaynaklar yalnız hedef kayıt doğrulandıktan sonra kaldırılır.',
                          )) {
                            return;
                          }
                          await _run(() async {
                            _result(
                              await widget.lease.transferArchiveToAccount(
                                _archive!,
                              ),
                            );
                            final rows = await widget.lease.legacyTransferRows(
                              _archive!,
                            );
                            if (_current) setState(() => _rows = rows);
                            await _refresh();
                          });
                        },
                  child: const Text('Uyumlu Eski Sürüşleri Aktar'),
                ),
                if (invalid.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'Aktarılamayan Eski Sürüşler',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                for (final row in invalid)
                  CheckboxListTile(
                    value: _selected.contains(row.key),
                    onChanged: _busy || row.fingerprint == null
                        ? null
                        : (value) => setState(() {
                            if (value == true) {
                              _selected.add(row.key);
                            } else {
                              _selected.remove(row.key);
                            }
                          }),
                    title: Text(
                      row.drive?.date.toLocal().toString() ??
                          'Okunamayan kayıt',
                    ),
                    subtitle: Text(row.incompatibility!),
                  ),
                if (invalid.isNotEmpty)
                  OutlinedButton(
                    key: const Key('transfer_cleanup'),
                    onPressed:
                        _busy ||
                            _selected.isEmpty ||
                            _archive?.isCurrent != true
                        ? null
                        : () async {
                            final selected = invalid
                                .where((r) => _selected.contains(r.key))
                                .toList();
                            if (!await _confirm(
                              'Yalnız seçtiğiniz ${selected.length} uyumsuz eski kayıt cihazdan kalıcı olarak silinsin mi? Bu işlem geri alınamaz.',
                            )) {
                              return;
                            }
                            await _run(() async {
                              final count = await widget.lease
                                  .cleanIncompatibleArchive(
                                    _archive!,
                                    selected,
                                    confirmed: true,
                                  );
                              final rows = await widget.lease
                                  .legacyTransferRows(_archive!);
                              if (_current) {
                                setState(() {
                                  _message =
                                      '$count seçilmiş uyumsuz kayıt silindi.';
                                  _rows = rows;
                                  _selected.clear();
                                });
                              }
                              await _refresh();
                            });
                          },
                    child: const Text('Yalnız Seçilmiş Uyumsuz Kayıtları Sil'),
                  ),
              ],
            ],
          ],
        ),
      );
    },
  );
}

/// Mounted inside the owner/epoch navigator. A decline only suppresses this
/// prompt for the unchanged source inventory; Profile remains available.
class GuestTransferPrompt extends StatefulWidget {
  const GuestTransferPrompt({
    super.key,
    required this.lease,
    required this.child,
  });
  final LocalOwnerLease lease;
  final Widget child;
  @override
  State<GuestTransferPrompt> createState() => _GuestTransferPromptState();
}

class _GuestTransferPromptState extends State<GuestTransferPrompt> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!widget.lease.accountTransferAvailable) return;
      try {
        final shouldPrompt = await widget.lease.shouldPromptGuestTransfer();
        if (!shouldPrompt || !mounted || !widget.lease.isCurrent) {
          return;
        }
        final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Misafir Sürüşleri'),
            content: const Text(
              'Bu cihazdaki misafir sürüşlerini hesabınıza aktarmak ister misiniz?',
            ),
            actions: [
              TextButton(
                key: const Key('guest_transfer_decline'),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Şimdi Değil'),
              ),
              FilledButton(
                key: const Key('guest_transfer_accept'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hesabıma Aktar'),
              ),
            ],
          ),
        );
        if (accepted == true && mounted && widget.lease.isCurrent) {
          await Navigator.of(context).pushNamed('/account-transfer');
        }
      } catch (_) {
        /* Profile provides a retry; no source writes on decline. */
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
