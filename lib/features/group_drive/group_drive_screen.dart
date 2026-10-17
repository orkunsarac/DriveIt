import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/gps_session_ownership.dart';
import '../../services/local_owner_lifecycle.dart';
import '../../widgets/local_owner_view.dart';
import 'group_drive_models.dart';
import 'group_drive_service.dart';
import 'group_gps_source.dart';
import 'group_gps_sharing.dart';
import 'group_drive_session.dart';
import 'group_drive_views.dart';

class GroupDriveScreen extends StatelessWidget {
  const GroupDriveScreen({
    super.key,
    required this.lease,
    required this.service,
    this.gpsSource,
    this.session,
    this.onReturnToDrive,
    this.onGoToDrive,
    this.onGoHome,
  });
  final LocalOwnerLease lease;
  final GroupDriveService service;

  /// Explicit controlled Android source. Null keeps the synthetic demo.
  final GroupGpsSource? gpsSource;
  final GroupDriveSession? session;
  final VoidCallback? onReturnToDrive;
  final VoidCallback? onGoToDrive;
  final VoidCallback? onGoHome;
  @override
  Widget build(BuildContext context) => LocalOwnerView(
    lease: lease,
    builder: (_) {
      if (lease.owner.kind != GpsOwnerKind.account) {
        return const Scaffold(
          body: Center(child: Text('Grup Sürüşü için hesap gerekli.')),
        );
      }
      // A remote adapter is mounted only by an explicit post-acceptance build;
      // it still needs the visible-app GPS source before the route is usable.
      if (!service.isSimulation && gpsSource == null) {
        return const OwnerAccessUnavailable();
      }
      return _GroupDrivePage(
        key: ObjectKey(service),
        lease: lease,
        service: service,
        gpsSource: gpsSource,
        session: session,
        onReturnToDrive: onReturnToDrive,
        onGoToDrive: onGoToDrive,
        onGoHome: onGoHome,
      );
    },
  );
}

class _GroupDrivePage extends StatefulWidget {
  const _GroupDrivePage({
    super.key,
    required this.lease,
    required this.service,
    this.gpsSource,
    this.session,
    this.onReturnToDrive,
    this.onGoToDrive,
    this.onGoHome,
  });
  final LocalOwnerLease lease;
  final GroupDriveService service;
  final GroupGpsSource? gpsSource;
  final GroupDriveSession? session;
  final VoidCallback? onReturnToDrive;
  final VoidCallback? onGoToDrive;
  final VoidCallback? onGoHome;
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
  GroupGpsSharing? _gps;
  bool _disposing = false;
  String? _syntheticConsentGroup, _syntheticConsentMembership;
  bool _syntheticAutoStart = false;
  bool get _current => mounted && !_disposing && widget.lease.isCurrent;

  @override
  void initState() {
    super.initState();
    _client = widget.session?.client ?? widget.service.forOwner(widget.lease);
    _group = widget.session?.snapshot;
    _gps = widget.session?.gps;
    if (_gps != null) {
      _gps!.addListener(_onGpsChanged);
    } else if (widget.gpsSource != null) {
      _gps = GroupGpsSharing(
        lease: widget.lease,
        client: _client,
        source: widget.gpsSource!,
        diagnostics: widget.gpsSource is GroupGpsDiagnosticSource
            ? (widget.gpsSource! as GroupGpsDiagnosticSource).diagnostics
            : null,
        clock: () => widget.service.simulationTime,
      );
      _gps!.addListener(_onGpsChanged);
    }
    _subscription = _client.changes.listen(
      (value) {
        if (_current) _showSnapshot(value);
      },
      onError: (Object error) {
        if (_current) {
          setState(
            () => _error = _description(
              error is GroupDriveException ? error.code : 'remote_unavailable',
            ),
          );
        }
      },
    );
    unawaited(_run(_client.current));
  }

  void _onGpsChanged() {
    if (_current) {
      setState(() {
        if (_gps!.errorCode != null) _error = _gpsDescription(_gps!.errorCode!);
      });
    }
  }

  void _showSnapshot(GroupDriveSnapshot? value) {
    _gps?.updateGroup(value);
    _expiryTimer?.cancel();
    final own = value?.members
        .where((member) => member.accountId == widget.lease.owner.userId)
        .firstOrNull;
    if (value?.id != _grant?.groupId ||
        own?.sharingStatus != GroupSharingStatus.sharing) {
      _grant = null;
    }
    setState(() => _group = value);
    if (value?.id != _syntheticConsentGroup ||
        own?.membershipId != _syntheticConsentMembership ||
        value?.isActive != true) {
      _syntheticConsentGroup = null;
      _syntheticConsentMembership = null;
      _syntheticAutoStart = false;
    } else if (_syntheticAutoStart && value!.isRunning) {
      _syntheticAutoStart = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_current && _group?.id == value.id) {
          unawaited(_beginSharing(value, false));
        }
      });
    }
    if (value?.isActive == true) {
      final remaining = value!.expiresAt.difference(value.observedAt);
      // One expiry refresh; no heartbeat, location subscription, or polling.
      _expiryTimer = Timer(remaining, () {
        if (_current) unawaited(_run(_client.current));
      });
    }
  }

  Future<({bool share, bool background})?> _sharingChoice({
    bool entry = false,
  }) async {
    var backgroundConsent = false;
    final backgroundSupported = _gps?.source is BackgroundGroupGpsSource;
    final accepted = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            entry
                ? 'Grup için konum paylaşımı'
                : _gps == null
                ? 'Sentetik konum paylaşımı'
                : 'Cihaz GPS konumunu paylaş',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry)
                  const Text(
                    'Paylaşım isteğe bağlıdır. Lobide GPS başlamaz; sürüş başladığında, uygulama görünürken başlar. Android konum izni ayrıca istenir.',
                  ),
                Text(
                  _gps == null
                      ? 'Bu testte yalnız üretilmiş konumlar gruptaki üyelere gösterilir. Gerçek GPS okunmaz ve konum izni istenmez. İstediğin an duraklatabilir veya kapatabilirsin.'
                      : (widget.service.isSimulation
                            ? 'Konum izni gereklidir. Bu cihazın GPS noktaları yalnız yerel fake grupta gösterilir; uzak sunucuya gönderilmez. Paylaşım uygulama görünürken çalışır; arka plana veya ekran kilidine geçince duraklar. İstediğin an duraklatabilir veya kapatabilirsin.'
                            : 'Konum izni gereklidir. GPS noktaları yalnız bu grubun yetkili üyelerine geçici olarak iletilir; geçmiş rota olarak saklanmaz. Arka plan seçeneğini açmazsan ekran kilidinde paylaşım duraklar. İstediğin an durdurabilirsin.'),
                ),
                if (backgroundSupported)
                  CheckboxListTile(
                    key: const Key('group_background_consent'),
                    value: backgroundConsent,
                    onChanged: (value) =>
                        update(() => backgroundConsent = value == true),
                    title: const Text('Ekran kilidinde ve arka planda paylaş'),
                    subtitle: const Text(
                      'Kalıcı bildirim gösterilir. Bildirime dokunarak paylaşımı durdurabilirsin.',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: entry ? const Key('group_entry_consent_without') : null,
              onPressed: () => Navigator.pop(context, false),
              child: Text(entry ? 'Konum paylaşmadan devam et' : 'Vazgeç'),
            ),
            TextButton(
              key: Key(
                entry ? 'group_entry_consent_share' : 'group_consent_confirm',
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                entry ? 'Konumumu paylaşarak devam et' : 'Onayla ve Başlat',
              ),
            ),
          ],
        ),
      ),
    );
    if (!_current || accepted == null || (!entry && !accepted)) return null;
    return (share: accepted, background: accepted && backgroundConsent);
  }

  Future<void> _enter(Future<GroupDriveSnapshot> Function() action) async {
    if (!_current || _busy) return;
    final choice = await _sharingChoice(entry: true);
    if (choice == null || !_current) return;
    GroupDriveSnapshot? joined;
    await _run(() async => joined = await action());
    if (!_current || joined == null || !choice.share) return;
    final group = joined!;
    if (_gps != null) {
      _gps!.rememberConsent(group, backgroundConsent: choice.background);
    } else {
      _syntheticConsentGroup = group.id;
      _syntheticConsentMembership = group.members
          .singleWhere((m) => m.accountId == widget.lease.owner.userId)
          .membershipId;
      _syntheticAutoStart = !group.isRunning;
      if (group.isRunning) await _beginSharing(group, false);
    }
  }

  Future<void> _consent() async {
    final group = _group;
    if (group == null || !group.isRunning || !_current) return;
    if (_gps?.hasSharingConsent(group) == true) {
      await _beginSharing(group, _gps!.consentedBackground);
      return;
    }
    if (_gps == null &&
        _syntheticConsentGroup == group.id &&
        group.members.any(
          (m) =>
              m.membershipId == _syntheticConsentMembership &&
              m.accountId == widget.lease.owner.userId,
        )) {
      await _beginSharing(group, false);
      return;
    }
    final membership = group.members
        .singleWhere((m) => m.accountId == widget.lease.owner.userId)
        .membershipId;
    final choice = await _sharingChoice();
    if (choice == null ||
        !_current ||
        _group?.id != group.id ||
        !_group!.members.any((m) => m.membershipId == membership)) {
      return;
    }
    _gps?.rememberConsent(
      group,
      backgroundConsent: choice.background,
      startWhenRunning: false,
    );
    if (_gps == null) {
      _syntheticConsentGroup = group.id;
      _syntheticConsentMembership = membership;
    }
    await _beginSharing(group, choice.background);
  }

  Future<void> _beginSharing(
    GroupDriveSnapshot group,
    bool backgroundConsent,
  ) async {
    await _run(() async {
      if (_gps != null) {
        await _gps!.start(
          group.id,
          consent: true,
          backgroundConsent: backgroundConsent,
        );
        return _client.current();
      }
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

  Future<void> _copyInviteCode(String code) async {
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted || !_current) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Davet kodu kopyalandı')));
  }

  Future<void> _withdrawSharing(bool pause) async {
    final group = _group;
    if (!_current || group?.isActive != true) return;
    _grant = null;
    // Safety controls remain available even while a publish is awaiting the
    // fake transport. Revoke first; its eventual reply cannot restore a point.
    try {
      final result = _gps != null
          ? (pause ? await _gps!.pause(group!.id) : await _gps!.stop(group!.id))
          : (pause
                ? await _client.pauseSharing(group!.id)
                : await _client.stopSharing(group!.id));
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
    } on GroupGpsException catch (error) {
      if (_current) setState(() => _error = _gpsDescription(error.code));
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
              ? 'Bu grup bütün katılımcılar için sona erecek.'
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
    _disposing = true;
    _expiryTimer?.cancel();
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    _inviteText.dispose();
    final gps = _gps;
    gps?.removeListener(_onGpsChanged);
    if (widget.session != null) {
      // The navigator-owned session survives route disposal.
    } else if (gps != null) {
      unawaited(
        gps.close().whenComplete(() async {
          gps.dispose();
          await _client.close();
        }),
      );
    } else {
      unawaited(_client.close());
    }
    super.dispose();
  }

  Future<void> _shareInvite(GroupDriveSnapshot group) async {
    if (!_current) return;
    try {
      await const MethodChannel(
        'driveit/group_invite',
      ).invokeMethod<void>('share', {'link': group.invite.link.toString()});
    } on PlatformException {
      if (_current) {
        setState(() => _error = 'Davet paylaşılamadı; kodu kopyalayabilirsin.');
      }
    } on MissingPluginException {
      if (_current) {
        setState(
          () =>
              _error = 'Bu cihazda paylaşım açılamadı; kodu kopyalayabilirsin.',
        );
      }
    }
  }

  void _settings() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: groupSurface,
      showDragHandle: true,
      builder: (sheetContext) => LocalOwnerView(
        lease: widget.lease,
        builder: (_) => StreamBuilder<GroupDriveSnapshot?>(
          stream: _client.changes,
          initialData: _group,
          builder: (context, state) {
            final group = state.data;
            if (group?.isActive != true) {
              return const SizedBox(
                height: 100,
                child: Center(child: Text('Grup sona erdi.')),
              );
            }
            final admin = group!.members.any(
              (m) =>
                  m.accountId == widget.lease.owner.userId &&
                  m.role == GroupDriveRole.administrator,
            );
            void action(VoidCallback callback) {
              Navigator.pop(sheetContext);
              if (_current) callback();
            }

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .8,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Grup ayarları',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GroupInviteCard(
                      group: group,
                      onCopy: () => _copyInviteCode(group.invite.code),
                      onShare: () => _shareInvite(group),
                    ),
                    Text(
                      'Bitiş: ${group.expiresAt.toLocal()} • Uzatma: ${group.extensionCount}/2',
                    ),
                    for (final member in group.members)
                      ListTile(
                        leading: GroupMemberAvatar(
                          member: member,
                          viewer: widget.lease.owner.userId,
                        ),
                        title: Text(member.displayName),
                        subtitle: Text(
                          member.role == GroupDriveRole.administrator
                              ? 'Yönetici'
                              : 'Üye',
                        ),
                        trailing:
                            admin &&
                                member.accountId != widget.lease.owner.userId
                            ? IconButton(
                                tooltip: 'Üyeyi çıkar',
                                icon: const Icon(Icons.person_remove_outlined),
                                onPressed: () => action(() => _ban(member)),
                              )
                            : null,
                      ),
                    if (admin) ...[
                      TextButton(
                        key: const Key('group_extend'),
                        onPressed: _busy || group.extensionCount >= 2
                            ? null
                            : () => action(
                                () => _run(() => _client.extend(group.id)),
                              ),
                        child: const Text('6 saat uzat'),
                      ),
                      TextButton(
                        key: const Key('group_end'),
                        onPressed: _busy
                            ? null
                            : () => action(() => _confirm(true)),
                        child: const Text('Grubu Sonlandır'),
                      ),
                    ],
                    TextButton(
                      onPressed: () => action(() => _confirm(false)),
                      child: const Text('Gruptan Ayrıl'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _ban(GroupDriveMember member) async {
    final group = _group;
    if (!_current || group == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Üyeyi gruptan çıkar?'),
        content: Text('${member.displayName} bu gruba erişimini kaybedecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
    if (accepted == true && _current) {
      await _run(() => _client.ban(group.id, member.accountId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final active = group?.isActive == true;
    final own = group?.members
        .where((m) => m.accountId == widget.lease.owner.userId)
        .firstOrNull;
    final admin = own?.role == GroupDriveRole.administrator;
    final sharing =
        own?.sharingStatus == GroupSharingStatus.sharing &&
        (_gps == null ? _grant != null : _gps!.active);
    final running = active && group!.isRunning;
    final message = _error == null
        ? null
        : Material(
            color: const Color(0xff38251b),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: Text(_error!, key: const Key('group_error'))),
                  TextButton(
                    key: const Key('group_retry'),
                    onPressed: _busy ? null : () => _run(_client.current),
                    child: const Text('Yeniden Dene'),
                  ),
                ],
              ),
            ),
          );
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff2997ff),
          brightness: Brightness.dark,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xff020a18),
        appBar: running
            ? null
            : AppBar(
                title: Text(active ? 'Grup Lobisi' : 'Grup Sürüşü'),
                backgroundColor: const Color(0xff020a18),
                actions: [
                  if (active)
                    IconButton(
                      key: const Key('group_settings'),
                      tooltip: 'Grup ayarları',
                      onPressed: _settings,
                      icon: const Icon(Icons.tune),
                    ),
                ],
              ),
        body: running
            ? Stack(
                children: [
                  Positioned.fill(
                    child: GroupDriveLiveView(
                      key: ValueKey('running_${group.id}'),
                      group: group,
                      lease: widget.lease,
                      isSimulation: widget.service.isSimulation,
                      isSharing: sharing,
                      onBack: () {
                        if (widget.onGoHome != null) {
                          widget.onGoHome!();
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      },
                      onReturnToDrive: widget.onReturnToDrive,
                      onGoToDrive:
                          widget.onGoToDrive ??
                          () {
                            Navigator.of(context).pushNamed('/drive');
                          },
                      onSharing: sharing
                          ? () => _withdrawSharing(true)
                          : () {
                              if (!_busy) _consent();
                            },
                      onLeave: () => _confirm(false),
                      onSettings: _settings,
                      memberStatus: (member) => _memberSharingLabel(
                        member,
                        isOwn: member.accountId == widget.lease.owner.userId,
                      ),
                      onSynthetic: _gps == null && _grant != null
                          ? _sendSynthetic
                          : null,
                      onStopSharing:
                          own?.sharingStatus != GroupSharingStatus.off
                          ? () => _withdrawSharing(false)
                          : null,
                    ),
                  ),
                  if (_busy)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(child: LinearProgressIndicator()),
                    ),
                  if (message != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: MediaQuery.sizeOf(context).height * .21,
                      child: message,
                    ),
                ],
              )
            : SafeArea(
                child: Column(
                  children: [
                    if (_busy) const LinearProgressIndicator(),
                    ?message,
                    Expanded(
                      child: active
                          ? GroupDriveLobbyView(
                              group: group!,
                              viewer: widget.lease.owner.userId,
                              memberStatus: _memberSharingLabel,
                              onCopy: () => _copyInviteCode(group.invite.code),
                              onShare: () => _shareInvite(group),
                              onLeave: () => _confirm(false),
                              onStart: admin && !_busy
                                  ? () =>
                                        _run(() => _client.startRide(group.id))
                                  : null,
                            )
                          : Column(
                              children: [
                                if (group != null)
                                  Text(
                                    group.status == GroupDriveStatus.expired
                                        ? 'Grubun süresi doldu'
                                        : 'Grup sonlandırıldı',
                                    key: const Key('group_status'),
                                  ),
                                Expanded(
                                  child: GroupDriveEntryView(
                                    invite: _inviteText,
                                    busy: _busy,
                                    onCreate: () => _enter(_client.create),
                                    onJoin: () => _enter(
                                      () => _client.join(
                                        GroupDriveInvite.parse(
                                          _inviteText.text,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  static String _sharingLabel(GroupSharingStatus status) => switch (status) {
    GroupSharingStatus.off => 'KAPALI',
    GroupSharingStatus.sharing => 'PAYLAŞILIYOR',
    GroupSharingStatus.paused => 'DURAKLATILDI',
  };

  String _memberSharingLabel(GroupDriveMember member, {bool isOwn = false}) {
    if (member.sharingStatus != GroupSharingStatus.sharing) {
      return _sharingLabel(member.sharingStatus);
    }
    final point = member.location;
    final observedAt = _group?.observedAt;
    if (point != null &&
        observedAt != null &&
        isGroupGpsTimestampFresh(point.recordedAt, observedAt)) {
      return point.origin == GroupLocationOrigin.deviceGps
          ? 'CANLI GPS YAYINDA'
          : 'SENTETİK TEST KONUMU YAYINDA';
    }
    if (point != null) return 'GPS ÖRNEĞİ ESKİ • YENİ KONUM BEKLENİYOR';
    if (!isOwn || _gps?.sampleState == null) return 'KONUM BEKLENİYOR';
    return switch (_gps!.sampleState!) {
      'waiting_for_gps' => 'GPS ÖRNEĞİ BEKLENİYOR',
      'publishing' => 'GPS ÖRNEĞİ GÖNDERİLİYOR',
      'published' => 'SUNUCU YAYINI KABUL ETTİ • HARİTA BEKLENİYOR',
      final state when state.startsWith('rejected_') =>
        'GPS ÖRNEĞİ REDDEDİLDİ: ${_sampleRejectLabel(state.substring(9))}',
      _ => 'KONUM BEKLENİYOR',
    };
  }

  static String _sampleRejectLabel(String reason) => switch (reason) {
    'mocked' => 'MOCK KONUM',
    'before_grant' => 'PAYLAŞIM BAŞLANGICINDAN ESKİ',
    'future_timestamp' => 'GELECEK ZAMAN DAMGASI',
    'stale' => '15 SANİYEDEN ESKİ',
    'invalid_accuracy' => 'GEÇERSİZ DOĞRULUK',
    'accuracy_over_75m' => 'DOĞRULUK 75 M ÜZERİNDE',
    'invalid_coordinates' || 'coordinates_out_of_range' => 'GEÇERSİZ KOORDİNAT',
    'non_monotonic_timestamp' => 'SIRASIZ ZAMAN DAMGASI',
    _ => 'GEÇERSİZ GPS ÖRNEĞİ',
  };

  static String _description(String code) => switch (code) {
    'ride_not_started' =>
      'GPS paylaşımı için yöneticinin sürüşü başlatması gerekiyor.',
    'backend_upgrade_required' =>
      'Grup Sürüşü güncellemesi sunucuda henüz hazır değil.',
    'device_clock_out_of_sync' =>
      'Cihaz saati sunucuyla uyumlu değil. Telefonun otomatik tarih ve saat ayarını açıp yeniden dene. GPS paylaşımı başlamadı.',
    'realtime_unavailable' =>
      'Canlı konum kanalına bağlanılamadı. Yeniden bağlanmayı dene.',
    'remote_unavailable' =>
      'Grup sunucusuna ulaşılamadı. İnternet bağlantını kontrol edip yeniden dene.',
    'membership_banned' => 'Bu gruba katılımın yönetici tarafından engellendi.',
    'membership_conflict' =>
      'Grup üyeliği doğrulanamadı. Yeniden katılım için sunucu güncellemesi gerekiyor.',
    'offline' => 'Grup servisine ulaşılamadı. Normal sürüş kaydı etkilenmez.',
    'invalid_invite' => 'Davet kodu veya bağlantısı geçersiz.',
    'group_full' => 'Grup dolu; en fazla 10 kişi katılabilir.',
    'group_inactive' => 'Grup sona erdi; katılım ve uzatma kapalı.',
    'admin_required' ||
    'administrator_required' => 'Bu işlem yalnız yöneticiye açık.',
    'membership_required' => 'Bu gruba erişim yetkin yok.',
    'already_in_group' => 'Önce mevcut gruptan ayrılmalısın.',
    'extension_limit' => 'İki uzatma hakkı kullanıldı.',
    'account_required' => 'Grup Sürüşü için hesap gerekli.',
    'consent_required' => 'Paylaşım için açık onay gerekli.',
    'publication_revoked' =>
      'Paylaşım oturumu kapandı; yeni konum gönderilmedi.',
    'stale_location' => 'Eski veya sırasız sentetik konum reddedildi.',
    'invalid_location' => 'Sentetik konum geçersiz.',
    'group_generation_revoked' =>
      'Grup yetkisi değişti; konum paylaşımı durduruldu.',
    'location_invalid_or_stale' =>
      'Eski veya geçersiz GPS örneği sunucu tarafından reddedildi.',
    'response_invalid' => 'Sunucudan beklenmeyen grup yanıtı alındı.',
    _ => 'Grup işlemi tamamlanamadı ($code).',
  };
  static String _gpsDescription(String code) => switch (code) {
    'notification_permission_required' =>
      'Paylaşım bildiriminin görünmesi için bildirim izni gerekli. Paylaşım başlamadı.',
    'permission_denied' ||
    'permission_denied_forever' ||
    'permission_revoked' =>
      'Konum izni yok. GPS paylaşımı kapalı; izin verip yeniden başlatabilirsin.',
    'location_disabled' => 'Konum servisi kapalı. Paylaşım başlamadı.',
    'background_paused' =>
      'GPS paylaşımı arka planda duraklatıldı. Devam etmek için yeniden onayla.',
    'foreground_required' ||
    'context_changed' => 'Paylaşım için uygulamaya dönüp yeniden onayla.',
    _ => 'GPS paylaşımı kesildi ($code). Normal sürüş kaydı korunuyor.',
  };
}
