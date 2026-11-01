import 'package:flutter/material.dart';

import '../models/legal_document_catalog.dart';
import '../widgets/onboarding_primary_button.dart';
import '../widgets/onboarding_progress_indicator.dart';

typedef LegalDocumentCatalogLoader = Future<LegalDocumentCatalog> Function();

class LegalDocumentState {
  const LegalDocumentState({
    this.viewed = false,
    this.accepted = false,
    this.version,
    this.readAt,
    this.acceptedAt,
  });

  final bool viewed;
  final bool accepted;
  final String? version;
  final DateTime? readAt;
  final DateTime? acceptedAt;

  LegalDocumentState copyWith({
    bool? viewed,
    bool? accepted,
    String? acceptedVersion,
  }) {
    final nextAccepted = accepted ?? this.accepted;
    return LegalDocumentState(
      viewed: viewed ?? this.viewed,
      accepted: nextAccepted,
      version: accepted == false ? null : acceptedVersion ?? version,
      readAt: viewed == true ? DateTime.now() : readAt,
      acceptedAt: accepted == true
          ? DateTime.now()
          : nextAccepted
          ? acceptedAt
          : null,
    );
  }
}

class LegalSafetyOnboardingPage extends StatefulWidget {
  const LegalSafetyOnboardingPage({
    super.key,
    required this.onContinue,
    this.catalogLoader,
  });

  final VoidCallback onContinue;
  final LegalDocumentCatalogLoader? catalogLoader;

  @override
  State<LegalSafetyOnboardingPage> createState() =>
      _LegalSafetyOnboardingPageState();
}

class _LegalSafetyOnboardingPageState extends State<LegalSafetyOnboardingPage> {
  LegalDocumentState _kvkk = const LegalDocumentState();
  LegalDocumentState _privacy = const LegalDocumentState();
  LegalDocumentState _terms = const LegalDocumentState();
  LegalDocumentState _explicitConsent = const LegalDocumentState();
  bool _securityAcknowledged = false;
  late final Future<LegalDocumentCatalog> _catalog;

  @override
  void initState() {
    super.initState();
    _catalog =
        widget.catalogLoader?.call() ?? LegalDocumentCatalog.loadFromAssets();
  }

  bool _canContinue(LegalDocumentCatalog catalog) {
    bool accepted(String id, LegalDocumentState state) {
      final content = catalog[id];
      return content.canBeAccepted &&
          state.viewed &&
          state.accepted &&
          state.version == content.version;
    }

    return accepted('kvkk', _kvkk) &&
        accepted('privacy', _privacy) &&
        accepted('terms', _terms) &&
        _securityAcknowledged;
  }

  Future<void> _showDocument(
    LegalDocumentContent document,
    LegalDocumentState state,
    ValueChanged<LegalDocumentState> update,
  ) async {
    update(state.copyWith(viewed: true));
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF071522),
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                document.status == LegalDocumentStatus.approved
                    ? 'Sürüm ${document.version}'
                    : 'HUKUKİ İNCELEME BEKLİYOR — bu içerik kabul edilemez.',
                key: ValueKey('document_status_${document.id}'),
                style: TextStyle(
                  color: document.canBeAccepted
                      ? const Color(0xFF45D69B)
                      : const Color(0xFFFFC266),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                document.body,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kapat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSafety() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF071522),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Sürüş Güvenliği',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'DriveIt sürüş sırasında telefonla etkileşime geçilmesini gerektirmez. Sürüşü hareket etmeden önce başlat. Araç kullanırken telefonla ilgilenme ve trafik kurallarına uy.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .75),
            height: 1.4,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              setState(() => _securityAcknowledged = true);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LegalDocumentCatalog>(
      future: _catalog,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            backgroundColor: Color(0xFF020B18),
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Yasal belgeler yüklenemedi. Devam edebilmek için belgelerin geçerli biçimde sunulması gerekir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        }
        final catalog = snapshot.data;
        if (catalog == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF020B18),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildContent(context, catalog);
      },
    );
  }

  Widget _buildContent(BuildContext context, LegalDocumentCatalog catalog) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/onboarding/legal_background_phone.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [.28, .48, 1],
                colors: [
                  Colors.transparent,
                  Color(0x66020B18),
                  Color(0xF2020B18),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              final compact = height < 720;
              final horizontalPadding = (width * .07).clamp(22.0, 36.0);
              final gap = compact ? 5.0 : 7.0;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  height * .028,
                  horizontalPadding,
                  (height * .02).clamp(14.0, 24.0),
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/onboarding/driveit_wordmark.png',
                      width: width * .37,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: compact ? 12 : height * .025),
                    Text(
                      'Yasal ve Güvenlik',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (width * .074).clamp(27.0, 34.0),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: compact ? 6 : 9),
                    Text(
                      catalog.documents.values.any((doc) => !doc.canBeAccepted)
                          ? 'Bazı belgeler hukuk incelemesinde; bunlar kabul edilemez.'
                          : 'Devam etmeden önce önemli bilgileri incele.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .7),
                        fontSize: compact ? 11.5 : 13,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(height: compact ? 9 : 12),
                    _documentCard(
                      compact: compact,
                      document: catalog['kvkk'],
                      icon: Icons.description_rounded,
                      state: _kvkk,
                      label: 'Metni okudum ve bilgilendirildim.',
                      update: (value) => setState(() => _kvkk = value),
                    ),
                    SizedBox(height: gap),
                    _documentCard(
                      compact: compact,
                      document: catalog['privacy'],
                      icon: Icons.shield_rounded,
                      state: _privacy,
                      label: "Gizlilik Politikası'nı okudum.",
                      update: (value) => setState(() => _privacy = value),
                    ),
                    SizedBox(height: gap),
                    _documentCard(
                      compact: compact,
                      document: catalog['terms'],
                      icon: Icons.rule_rounded,
                      state: _terms,
                      label: "Kullanım Koşulları'nı kabul ediyorum.",
                      update: (value) => setState(() => _terms = value),
                    ),
                    SizedBox(height: gap),
                    _documentCard(
                      compact: compact,
                      document: catalog['consent'],
                      icon: Icons.fact_check_rounded,
                      state: _explicitConsent,
                      label: '',
                      optional: true,
                      update: (value) =>
                          setState(() => _explicitConsent = value),
                    ),
                    SizedBox(height: gap),
                    _safetyCard(compact),
                    SizedBox(height: compact ? 9 : 12),
                    FractionallySizedBox(
                      widthFactor: .913,
                      child: IgnorePointer(
                        ignoring: !_canContinue(catalog),
                        child: AnimatedOpacity(
                          opacity: _canContinue(catalog) ? 1 : .46,
                          duration: const Duration(milliseconds: 180),
                          child: OnboardingPrimaryButton(
                            label: 'Kabul Et ve Devam Et',
                            onPressed: widget.onContinue,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    const OnboardingProgressIndicator(currentPage: 4),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _documentCard({
    required bool compact,
    required LegalDocumentContent document,
    required IconData icon,
    required LegalDocumentState state,
    required String label,
    required ValueChanged<LegalDocumentState> update,
    bool optional = false,
  }) {
    final title = document.title;
    return Material(
      color: const Color(0xFF061323).withValues(alpha: .74),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        key: ValueKey('open_$title'),
        onTap: () => _showDocument(document, state, update),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: EdgeInsets.fromLTRB(12, compact ? 6 : 8, 8, compact ? 4 : 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0x99168EFF)),
            boxShadow: const [
              BoxShadow(color: Color(0x24118EFF), blurRadius: 9),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: const Color(0xFF29A9FF),
                    size: compact ? 19 : 21,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 12.5 : 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (optional)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF15314B).withValues(alpha: .8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        document.canBeAccepted
                            ? 'Koşullu'
                            : 'İnceleme bekliyor',
                        style: TextStyle(
                          color: Color(0xFF9BCFF2),
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  const SizedBox(width: 5),
                  Icon(
                    state.viewed
                        ? Icons.visibility_rounded
                        : Icons.open_in_new_rounded,
                    color: state.viewed
                        ? const Color(0xFF45D69B)
                        : const Color(0xFF86A5BB),
                    size: 17,
                  ),
                ],
              ),
              if (!optional && document.canBeAccepted) ...[
                SizedBox(height: compact ? 1 : 3),
                Row(
                  children: [
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: Transform.scale(
                        scale: 1.16,
                        child: Checkbox(
                          key: ValueKey('checkbox_$title'),
                          value: state.accepted,
                          onChanged: state.viewed && document.canBeAccepted
                              ? (value) => update(
                                  state.copyWith(
                                    accepted: value ?? false,
                                    acceptedVersion: document.version,
                                  ),
                                )
                              : null,
                          side: const BorderSide(color: Color(0xFF7897AC)),
                          activeColor: const Color(0xFF148FFF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: state.viewed ? .78 : .42,
                          ),
                          fontSize: compact ? 9.8 : 10.8,
                          height: 1.12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (!document.canBeAccepted && !optional)
                Padding(
                  padding: const EdgeInsets.only(top: 5, bottom: 5),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Hukuki inceleme bekleniyor — kabul alınmıyor.',
                      key: ValueKey('pending_$title'),
                      style: const TextStyle(
                        color: Color(0xFFFFC266),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _safetyCard(bool compact) {
    return Material(
      color: const Color(0xFF071522).withValues(alpha: .78),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        key: const ValueKey('open_security_warning'),
        onTap: _showSafety,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: compact ? 43 : 47,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0x99168EFF)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.health_and_safety_rounded,
                color: Color(0xFF29A9FF),
                size: 21,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Sürüş Güvenliği',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Icon(
                _securityAcknowledged
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: _securityAcknowledged
                    ? const Color(0xFF45D69B)
                    : const Color(0xFFA4B6C4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
