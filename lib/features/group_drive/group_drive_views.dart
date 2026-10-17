import 'package:flutter/material.dart';
import '../../services/local_owner_lifecycle.dart';
import 'group_drive_map.dart';
import 'group_drive_models.dart';
import 'group_drive_visuals.dart';

const groupSurface = Color(0xff0c1729);

class GroupDriveEntryView extends StatelessWidget {
  const GroupDriveEntryView({
    super.key,
    required this.invite,
    required this.busy,
    required this.onCreate,
    required this.onJoin,
  });
  final TextEditingController invite;
  final bool busy;
  final VoidCallback onCreate, onJoin;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.route_rounded, size: 64, color: Color(0xff2997ff)),
            const SizedBox(height: 20),
            Text(
              'Birlikte yola çıkın',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Grubunu oluştur veya bir davetle katıl. Canlı konumunu yalnız sen izin verdiğinde paylaşırız.',
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              key: const Key('group_create'),
              onPressed: busy ? null : onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Grup Oluştur'),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(),
            ),
            TextField(
              key: const Key('group_invite_input'),
              controller: invite,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Davet kodu veya bağlantısı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('group_join'),
              onPressed: busy ? null : onJoin,
              child: const Text('Davetle Katıl'),
            ),
          ],
        ),
      ),
    ),
  );
}

class GroupInviteCard extends StatelessWidget {
  const GroupInviteCard({
    super.key,
    required this.group,
    required this.onCopy,
    required this.onShare,
  });
  final GroupDriveSnapshot group;
  final VoidCallback onCopy, onShare;
  @override
  Widget build(BuildContext context) => Card(
    color: groupSurface,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Arkadaşlarını davet et'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  group.invite.code,
                  key: const Key('group_invite_code'),
                ),
              ),
              IconButton(
                key: const Key('group_invite_copy'),
                tooltip: 'Davet kodunu kopyala',
                onPressed: group.invite.code.isEmpty ? null : onCopy,
                icon: const Icon(Icons.copy_rounded),
              ),
              IconButton(
                key: const Key('group_invite_share'),
                tooltip: 'Daveti paylaş',
                onPressed: group.invite.code.isEmpty ? null : onShare,
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ],
          ),
          SelectableText(
            group.invite.link.toString(),
            key: const Key('group_invite_link'),
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    ),
  );
}

class GroupMemberAvatar extends StatelessWidget {
  const GroupMemberAvatar({
    super.key,
    required this.member,
    required this.viewer,
  });
  final GroupDriveMember member;
  final String? viewer;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 22,
    backgroundColor: groupMemberColor(member, viewer),
    foregroundColor: const Color(0xff07101f),
    child: Text(
      groupMemberInitials(member.displayName),
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}

class GroupDriveLobbyView extends StatelessWidget {
  const GroupDriveLobbyView({
    super.key,
    required this.group,
    required this.viewer,
    required this.onCopy,
    required this.onShare,
    required this.onLeave,
    this.onStart,
    required this.memberStatus,
  });
  final GroupDriveSnapshot group;
  final String? viewer;
  final VoidCallback onCopy, onShare, onLeave;
  final VoidCallback? onStart;
  final String Function(GroupDriveMember) memberStatus;
  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('group_lobby'),
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Yola çıkmadan önce',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 10),
      const Text(
        'Davetini paylaş. Yönetici sürüşü başlattığında harita burada açılır. GPS paylaşımı ayrıca onayını ister.',
      ),
      const SizedBox(height: 16),
      Text(
        'Katılımcılar ${group.members.length}/10',
        key: const Key('group_member_count'),
      ),
      for (final member in group.members)
        ListTile(
          leading: GroupMemberAvatar(member: member, viewer: viewer),
          title: Text(member.displayName),
          subtitle: Text(
            '${member.role == GroupDriveRole.administrator ? 'Yönetici' : 'Üye'} • ${memberStatus(member)}',
          ),
          trailing: member.role == GroupDriveRole.administrator
              ? const Icon(Icons.shield_outlined)
              : null,
        ),
      GroupInviteCard(group: group, onCopy: onCopy, onShare: onShare),
      Text(
        'Bitiş: ${group.expiresAt.toLocal()}',
        style: const TextStyle(color: Colors.white60),
      ),
      const SizedBox(height: 20),
      if (onStart != null)
        FilledButton.icon(
          key: const Key('group_start_ride'),
          onPressed: onStart,
          icon: const Icon(Icons.navigation_rounded),
          label: const Text('Grup Sürüşünü Başlat'),
        )
      else
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Yöneticinin başlatması bekleniyor…',
            textAlign: TextAlign.center,
          ),
        ),
      TextButton(
        key: const Key('group_leave'),
        onPressed: onLeave,
        child: const Text('Gruptan Ayrıl'),
      ),
    ],
  );
}

class _GroupControl extends StatelessWidget {
  const _GroupControl({
    required this.controlKey,
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final Key controlKey;
  final String label, tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Tooltip(
      message: tooltip,
      child: TextButton(
        key: controlKey,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 1),
          minimumSize: const Size(0, 56),
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 23),
            const SizedBox(height: 3),
            Text(label, maxLines: 1, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ),
  );
}

class GroupDriveLiveView extends StatefulWidget {
  const GroupDriveLiveView({
    super.key,
    required this.group,
    required this.lease,
    required this.isSimulation,
    required this.isSharing,
    required this.onBack,
    required this.onSharing,
    required this.onLeave,
    required this.onSettings,
    required this.memberStatus,
    required this.onGoToDrive,
    this.onReturnToDrive,
    this.onSynthetic,
    this.onStopSharing,
  });
  final GroupDriveSnapshot group;
  final LocalOwnerLease lease;
  final bool isSimulation, isSharing;
  final VoidCallback onBack, onSharing, onLeave, onSettings;
  final VoidCallback onGoToDrive;
  final VoidCallback? onReturnToDrive, onSynthetic, onStopSharing;
  final String Function(GroupDriveMember) memberStatus;
  @override
  State<GroupDriveLiveView> createState() => _GroupDriveLiveViewState();
}

class _GroupDriveLiveViewState extends State<GroupDriveLiveView> {
  final _camera = GroupMapCamera();
  double _extent = .16;
  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final own = widget.group.members
        .where((m) => m.accountId == widget.lease.owner.userId)
        .firstOrNull;
    final others = widget.group.members
        .where((m) => m.membershipId != own?.membershipId)
        .toList();
    final safe = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, bounds) => Stack(
        fit: StackFit.expand,
        children: [
          GroupDriveMap(
            key: const Key('group_map_workspace'),
            lease: widget.lease,
            group: widget.group,
            isSimulation: widget.isSimulation,
            camera: _camera,
            padding: EdgeInsets.only(
              top: safe.top + 76,
              bottom: bounds.maxHeight * _extent + 20,
            ),
          ),
          Positioned(
            top: 0,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: Card(
                color: groupSurface.withValues(alpha: .96),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      _GroupControl(
                        controlKey: const Key('group_back_home'),
                        label: 'Geri',
                        tooltip: 'DriveIt ana ekranı',
                        icon: Icons.arrow_back,
                        onPressed: widget.onBack,
                      ),
                      _GroupControl(
                        controlKey: Key(
                          widget.isSharing
                              ? 'group_share_pause'
                              : 'group_share_start',
                        ),
                        label: widget.isSharing ? 'Duraklat' : 'Devam',
                        tooltip: widget.isSharing
                            ? 'Konum paylaşımını duraklat'
                            : 'Konum paylaşımına devam et',
                        icon: widget.isSharing
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        onPressed: widget.onSharing,
                      ),
                      _GroupControl(
                        controlKey: const Key('group_go_to_drive'),
                        label: 'Sürüş',
                        tooltip: 'Sürüşe Git',
                        icon: Icons.directions_car,
                        onPressed: widget.onReturnToDrive ?? widget.onGoToDrive,
                      ),
                      _GroupControl(
                        controlKey: const Key('group_leave'),
                        label: 'Çık',
                        tooltip: 'Gruptan ayrıl',
                        icon: Icons.logout_rounded,
                        onPressed: widget.onLeave,
                      ),
                      _GroupControl(
                        controlKey: const Key('group_settings'),
                        label: 'Ayarlar',
                        tooltip: 'Grup ayarları',
                        icon: Icons.tune_rounded,
                        onPressed: widget.onSettings,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: bounds.maxHeight * _extent + 24,
            child: FloatingActionButton.small(
              key: const Key('group_fit_all'),
              heroTag: null,
              tooltip: 'Tüm Grubu Göster',
              onPressed: _camera.showAll,
              child: const Icon(Icons.zoom_out_map_rounded),
            ),
          ),
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (n) {
              if ((n.extent - _extent).abs() > .005) {
                setState(() => _extent = n.extent);
              }
              return false;
            },
            child: DraggableScrollableSheet(
              initialChildSize: .16,
              minChildSize: .16,
              maxChildSize: .82,
              snap: true,
              snapSizes: const [.16, .46, .82],
              builder: (context, scroll) => Container(
                key: const Key('group_participant_panel'),
                decoration: const BoxDecoration(
                  color: groupSurface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: ListView(
                  controller: scroll,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, safe.bottom + 16),
                  children: [
                    Row(
                      children: [
                        Text(
                          '${widget.group.members.length}/10',
                          key: const Key('group_member_count'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white30,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 26),
                      ],
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 72,
                      child: ListenableBuilder(
                        listenable: _camera,
                        builder: (context, _) => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (own != null)
                              _profile(
                                own,
                                mine: true,
                                selected:
                                    _camera.membershipId == own.membershipId,
                              ),
                            if (own != null) const SizedBox(width: 8),
                            Expanded(
                              child: ListView.separated(
                                key: const Key('group_other_profiles'),
                                scrollDirection: Axis.horizontal,
                                itemCount: others.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, i) => _profile(
                                  others[i],
                                  selected:
                                      _camera.membershipId ==
                                      others[i].membershipId,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_extent > .26) ...[
                      const Divider(),
                      for (final member in [?own, ...others])
                        ListTile(
                          key: ValueKey('group_focus_${member.membershipId}'),
                          contentPadding: EdgeInsets.zero,
                          leading: GroupMemberAvatar(
                            member: member,
                            viewer: widget.lease.owner.userId,
                          ),
                          title: Text(member.displayName),
                          subtitle: Text(
                            '${member.role == GroupDriveRole.administrator ? 'Yönetici' : 'Üye'} • ${widget.memberStatus(member)}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Konuma odaklan',
                            onPressed: _hasLocation(member)
                                ? () => _camera.follow(member.membershipId)
                                : null,
                            icon: const Icon(Icons.my_location),
                          ),
                        ),
                      if (own != null)
                        Text(
                          widget.memberStatus(own),
                          key: const Key('group_sharing_status'),
                        ),
                      if (_extent > .62)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Konumlar 15 saniye güncel kalır. Paylaşım kapalı olan üyeler haritada gösterilmez. Konum geçmişi saklanmaz.',
                          ),
                        ),
                      if (widget.onSynthetic != null)
                        TextButton(
                          key: const Key('group_send_synthetic'),
                          onPressed: widget.onSynthetic,
                          child: const Text('Sentetik Nokta Gönder'),
                        ),
                      if (widget.onStopSharing != null)
                        TextButton(
                          key: const Key('group_share_stop'),
                          onPressed: widget.onStopSharing,
                          child: const Text('Paylaşımı Kapat'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasLocation(GroupDriveMember member) =>
      member.sharingStatus == GroupSharingStatus.sharing &&
      member.location != null &&
      isGroupGpsTimestampFresh(
        member.location!.recordedAt,
        widget.group.observedAt,
      );
  Widget _profile(
    GroupDriveMember member, {
    bool mine = false,
    bool selected = false,
  }) => SizedBox(
    width: 62,
    child: InkWell(
      key: ValueKey('group_profile_${member.membershipId}'),
      borderRadius: BorderRadius.circular(14),
      onTap: _hasLocation(member)
          ? () => _camera.follow(member.membershipId)
          : null,
      child: Column(
        children: [
          AnimatedContainer(
            key: selected
                ? ValueKey('group_profile_selected_${member.membershipId}')
                : null,
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: GroupMemberAvatar(
              member: member,
              viewer: widget.lease.owner.userId,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mine ? 'Sen' : member.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    ),
  );
}
