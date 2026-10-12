import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/gps_session_ownership.dart';
import '../../services/local_owner_lifecycle.dart';
import '../../widgets/local_owner_view.dart';
import 'group_drive_models.dart';
import 'group_drive_service.dart';
import 'group_drive_map.dart';

class GroupDriveScreen extends StatelessWidget {
  const GroupDriveScreen({
    super.key,
    required this.lease,
    required this.service,
  });
  final LocalOwnerLease lease;
  final GroupDriveService service;
  @override
  Widget build(BuildContext context) => LocalOwnerView(
    lease: lease,
    builder: (_) {
      if (lease.owner.kind != GpsOwnerKind.account) {
        return const Scaffold(
          body: Center(child: Text('Grup Sürüşü için hesap gerekli.')),
        );
      }
      // This delivery has no real online transport. Do not accidentally mount
      // one behind the simulator UI or start it from production navigation.
      if (!service.isSimulation) return const OwnerAccessUnavailable();
      return _GroupDrivePage(
        key: ObjectKey(service),
        lease: lease,
        service: service,
      );
    },
  );
}

class _GroupDrivePage extends StatefulWidget {
  const _GroupDrivePage({
    super.key,
    required this.lease,
    required this.service,
  });
  final LocalOwnerLease lease;
  final GroupDriveService service;
  @override
  State<_GroupDrivePage> createState() => _GroupDrivePageState();
}

class _GroupDrivePageState extends State<_GroupDrivePage> {
  final _inviteText = TextEditingController();
  late final GroupDriveClient _client;
  StreamSubscription<GroupDriveSnapshot?>? _subscription;
  Timer? _expiryTimer;
  GroupDriveSnapshot? _group;
  bool _busy = false;
  String? _error;
  GroupLocationGrant? _grant;
  int _sequence = 0;
  bool get _current => mounted && widget.lease.isCurrent;

  @override
  void initState() {
    super.initState();
    _client = widget.service.forOwner(widget.lease);
    _subscription = _client.changes.listen((value) {
      if (_current) _showSnapshot(value);
    });
    unawaited(_run(_client.current));
  }

  void _showSnapshot(GroupDriveSnapshot? value) {
    _expiryTimer?.cancel();
    final own = value?.members
        .where((member) => member.accountId == widget.lease.owner.userId)
        .firstOrNull;
    if (value?.id != _grant?.groupId ||
        own?.sharingStatus != GroupSharingStatus.sharing) {
      _grant = null;
    }
    setState(() => _group = value);
    if (value?.isActive == true) {
      final remaining = value!.expiresAt.difference(value.observedAt);
      // One expiry refresh; no heartbeat, location subscription, or polling.
      _expiryTimer = Timer(remaining, () {
        if (_current) unawaited(_run(_client.current));
      });
    }
  }

  Future<void> _consent() async {
    final group = _group;
    if (group == null || !group.isActive || !_current) return;
    final membership = group.members
        .where((m) => m.accountId == widget.lease.owner.userId)
        .single
        .membershipId;
    final accepted = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Sentetik konum paylaşımı'),
        content: const Text(
          'Bu testte yalnız üretilmiş konumlar gruptaki üyelere gösterilir. Gerçek GPS okunmaz ve konum izni istenmez. İstediğin an duraklatabilir veya kapatabilirsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            key: const Key('group_consent_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Onayla ve Başlat'),
          ),
        ],
      ),
    );
    if (accepted != true ||
        !_current ||
        _group?.id != group.id ||
        !_group!.members.any((m) => m.membershipId == membership)) {
      return;
    }
    await _run(() async {
      final grant = await _client.startSharing(group.id, consent: true);
      if (_current) {
        _grant = grant;
        _sequence = 0;
      }
      return _client.current();
    });
  }

  Future<void> _sendSynthetic() async {
    final grant = _grant;
    final group = _group;
    if (!_current || grant == null || group == null) return;
    final member = group.members
        .where((m) => m.membershipId == grant.membershipId)
        .single;
    final sequence = ++_sequence;
    await _run(() async {
      // Fixed fictional test trajectory; never read a device location provider.
      await _client.publishSynthetic(
        grant,
        GroupSyntheticLocation(
          latitude: 10 + member.joinOrder * .01 + sequence * .001,
          longitude: 20 + member.joinOrder * .01 + sequence * .001,
          recordedAt: widget.service.simulationTime,
          sequence: sequence,
        ),
      );
      return _client.current();
    });
  }

  Future<void> _withdrawSharing(bool pause) async {
    final group = _group;
    if (!_current || group?.isActive != true) return;
    _grant = null;
    // Safety controls remain available even while a publish is awaiting the
    // fake transport. Revoke first; its eventual reply cannot restore a point.
    try {
      final result = pause
          ? await _client.pauseSharing(group!.id)
          : await _client.stopSharing(group!.id);
      if (_current) _showSnapshot(result);
    } on GroupDriveException catch (error) {
      if (_current) setState(() => _error = _description(error.code));
    } on StateError {
      if (_current) rethrow;
    }
  }

  Future<void> _run(Future<GroupDriveSnapshot?> Function() action) async {
    if (!_current || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await action();
      if (_current) _showSnapshot(result);
    } on GroupDriveException catch (error) {
      if (_current) setState(() => _error = _description(error.code));
    } on StateError {
      // Revoked owner results never repaint this page. Other programming or
      // storage errors are not silently converted into an empty group.
      if (_current) rethrow;
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(bool end) async {
    final group = _group;
    if (group == null || !group.isActive || !_current) return;
    final agreed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: Text(end ? 'Grubu sonlandır?' : 'Gruptan ayrıl?'),
        content: Text(
          end
              ? 'Bu test grubu bütün katılımcılar için sona erecek.'
              : 'Normal sürüş kaydın devam eder. Yönetici ayrılırsa yetki ilk katılan üyeye geçer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            key: const Key('group_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(end ? 'Sonlandır' : 'Ayrıl'),
          ),
        ],
      ),
    );
    if (agreed != true || !_current) return;
    await _run(() async {
      if (end) {
        await _client.end(group.id);
      } else {
        await _client.leave(group.id);
      }
      return _client.current();
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    unawaited(_client.close());
    _inviteText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final active = group?.isActive == true;
    final own = group?.members
        .where((m) => m.accountId == widget.lease.owner.userId)
        .firstOrNull;
    final admin =
        group?.members.any(
          (member) =>
              member.accountId == widget.lease.owner.userId &&
              member.role == GroupDriveRole.administrator,
        ) ==
        true;
    return Scaffold(
      backgroundColor: const Color(0xff020a18),
      appBar: AppBar(
        title: const Text('Grup Sürüşü'),
        backgroundColor: const Color(0xff020a18),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Yerel test • Fake grup servisi',
              style: TextStyle(
                color: Color(0xffbd82ff),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gerçek çevrimiçi grup değildir. Canlı konum paylaşımı kapalı.',
              style: TextStyle(color: Colors.white70),
            ),
            const Text(
              'Haritadaki bütün noktalar sentetik test verisidir; gerçek GPS okunmaz.',
              style: TextStyle(color: Colors.white70),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  key: const Key('group_error'),
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
            if (group != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                key: const Key('group_map_workspace'),
                height: 280,
                child: GroupDriveMap(lease: widget.lease, group: group),
              ),
              const SizedBox(height: 12),
              Text(
                switch (group.status) {
                  GroupDriveStatus.active => 'Grup aktif',
                  GroupDriveStatus.ended => 'Grup sonlandırıldı',
                  GroupDriveStatus.expired => 'Grubun süresi doldu',
                },
                key: const Key('group_status'),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              Text(
                'Bitiş: ${group.expiresAt.toLocal()} • Uzatma: ${group.extensionCount}/2',
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                'Katılımcılar ${group.members.length}/10',
                key: const Key('group_member_count'),
                style: const TextStyle(color: Colors.white),
              ),
              for (final member in group.members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    member.role == GroupDriveRole.administrator
                        ? Icons.shield_outlined
                        : Icons.person_outline,
                    color: const Color(0xff248fff),
                  ),
                  title: Text(
                    member.displayName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${member.role == GroupDriveRole.administrator ? 'Yönetici' : 'Üye'} • ${_sharingLabel(member.sharingStatus)}${member.location == null ? '' : ' • Sentetik, ${group.observedAt.difference(member.location!.recordedAt).inSeconds} sn önce'}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              if (active) ...[
                Text(
                  'Sentetik paylaşım: ${_sharingLabel(own!.sharingStatus)}',
                  key: const Key('group_sharing_status'),
                  style: const TextStyle(color: Colors.white),
                ),
                if (own.sharingStatus != GroupSharingStatus.sharing ||
                    _grant == null)
                  FilledButton(
                    key: const Key('group_share_start'),
                    onPressed: _busy ? null : _consent,
                    child: Text(
                      own.sharingStatus == GroupSharingStatus.paused
                          ? 'Devam Et'
                          : 'Sentetik Paylaşımı Başlat',
                    ),
                  ),
                if (own.sharingStatus == GroupSharingStatus.sharing) ...[
                  TextButton(
                    key: const Key('group_share_pause'),
                    onPressed: () => _withdrawSharing(true),
                    child: const Text('Paylaşımı Duraklat'),
                  ),
                  FilledButton(
                    key: const Key('group_send_synthetic'),
                    onPressed: _busy || _grant == null ? null : _sendSynthetic,
                    child: const Text('Sentetik Nokta Gönder'),
                  ),
                ],
                if (own.sharingStatus != GroupSharingStatus.off)
                  TextButton(
                    key: const Key('group_share_stop'),
                    onPressed: () => _withdrawSharing(false),
                    child: const Text('Paylaşımı Kapat'),
                  ),
                const Text(
                  'Davet kodu',
                  style: TextStyle(color: Colors.white70),
                ),
                SelectableText(
                  group.invite.code,
                  key: const Key('group_invite_code'),
                  style: const TextStyle(color: Colors.white),
                ),
                SelectableText(
                  group.invite.link.toString(),
                  key: const Key('group_invite_link'),
                  style: const TextStyle(color: Colors.white70),
                ),
                if (admin) ...[
                  TextButton(
                    key: const Key('group_extend'),
                    onPressed: _busy || group.extensionCount >= 2
                        ? null
                        : () => _run(() => _client.extend(group.id)),
                    child: const Text('6 saat uzat'),
                  ),
                  TextButton(
                    key: const Key('group_end'),
                    onPressed: _busy ? null : () => _confirm(true),
                    child: const Text('Grubu Sonlandır'),
                  ),
                ],
                TextButton(
                  key: const Key('group_leave'),
                  onPressed: _busy ? null : () => _confirm(false),
                  child: const Text('Gruptan Ayrıl'),
                ),
              ],
            ],
            if (!active) ...[
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('group_create'),
                onPressed: _busy ? null : () => _run(_client.create),
                child: const Text('Grup Oluştur'),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('group_invite_input'),
                controller: _inviteText,
                enabled: !_busy,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Davet kodu veya bağlantısı',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              FilledButton(
                key: const Key('group_join'),
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => _client.join(
                          GroupDriveInvite.parse(_inviteText.text),
                        ),
                      ),
                child: const Text('Davetle Katıl'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _sharingLabel(GroupSharingStatus status) => switch (status) {
    GroupSharingStatus.off => 'KAPALI',
    GroupSharingStatus.sharing => 'PAYLAŞILIYOR',
    GroupSharingStatus.paused => 'DURAKLATILDI',
  };

  static String _description(String code) => switch (code) {
    'offline' => 'Test servisine ulaşılamadı. Normal sürüş kaydı etkilenmez.',
    'invalid_invite' => 'Davet kodu veya bağlantısı geçersiz.',
    'group_full' => 'Grup dolu; en fazla 10 kişi katılabilir.',
    'group_inactive' => 'Grup sona erdi; katılım ve uzatma kapalı.',
    'admin_required' => 'Bu işlem yalnız yöneticiye açık.',
    'membership_required' => 'Bu gruba erişim yetkin yok.',
    'already_in_group' => 'Önce mevcut gruptan ayrılmalısın.',
    'extension_limit' => 'İki uzatma hakkı kullanıldı.',
    'account_required' => 'Grup Sürüşü için hesap gerekli.',
    'consent_required' => 'Paylaşım için açık onay gerekli.',
    'publication_revoked' =>
      'Paylaşım oturumu kapandı; yeni konum gönderilmedi.',
    'stale_location' => 'Eski veya sırasız sentetik konum reddedildi.',
    'invalid_location' => 'Sentetik konum geçersiz.',
    _ => 'Grup işlemi tamamlanamadı ($code).',
  };
}
