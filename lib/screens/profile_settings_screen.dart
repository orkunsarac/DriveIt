import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../features/my_world/services/my_world_settings_service.dart';
import '../services/profile_storage_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({
    super.key,
    this.worldSettings,
    this.profileLoader,
    this.imagePicker,
  });

  final MyWorldSettingsStore? worldSettings;
  final Future<ProfileStorageService> Function()? profileLoader;
  final ImagePicker? imagePicker;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  static const _background = Color(0xff020a18);
  static const _surface = Color(0xff07162b);
  static const _blue = Color(0xff248fff);
  late final MyWorldSettingsStore _worldSettings;
  late final ImagePicker _picker;
  ProfileStorageService? _profile;
  Uint8List? _photo;
  String? _name;
  String _version = '…';
  bool _loading = true;
  bool _photoBusy = false;
  bool _settingBusy = false;
  late bool _showIntro;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _worldSettings = widget.worldSettings ?? const HiveMyWorldSettingsStore();
    _showIntro = !_worldSettings.skipIntroAnimation;
    _picker = widget.imagePicker ?? ImagePicker();
    _loadProfile();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {
      if (mounted) setState(() => _version = 'Kullanılamıyor');
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile =
          await (widget.profileLoader ?? ProfileStorageService.open)();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _name = profile.name;
        _photo = profile.photo;
        _loading = false;
        _loadError = null;
      });
      // Android may recreate the activity while its gallery is in front.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        setState(() => _photoBusy = true);
        try {
          final lost = await _picker.retrieveLostData();
          if (lost.exception != null) throw lost.exception!;
          if (lost.files?.isNotEmpty == true) {
            await _savePickedPhoto(lost.files!.first);
          }
        } catch (_) {
          _message('Fotoğraf geri alınamadı. Galeriden yeniden seçebilirsin.');
        } finally {
          if (mounted) setState(() => _photoBusy = false);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Profil yüklenemedi. Tekrar dene.';
        });
      }
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _savePickedPhoto(XFile file) async {
    if (!mounted || _profile == null) return;
    if (await file.length() > ProfileStorageService.maximumPhotoBytes) {
      throw ArgumentError('Lütfen 2 MB altında bir fotoğraf seç.');
    }
    final bytes = await file.readAsBytes();
    // Verify decoding before replacing a working avatar. Downsampling also
    // bounds the memory needed for a large but highly compressed input.
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 512,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
    await _profile!.savePhoto(bytes);
    if (mounted) setState(() => _photo = _profile!.photo);
  }

  Future<void> _pickPhoto() async {
    if (_photoBusy || _profile == null) return;
    setState(() => _photoBusy = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (file == null) return;
      // Native crop UI is available on mobile. Desktop/widget-test platforms
      // have no cropper host, so retain the existing safe picker path there.
      if (file.path.isNotEmpty &&
          (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
        final cropped = await ImageCropper().cropImage(
          sourcePath: file.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 90,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Profil fotoğrafını kırp',
              toolbarColor: _surface,
              toolbarWidgetColor: Colors.white,
              activeControlsWidgetColor: _blue,
              lockAspectRatio: true,
            ),
            IOSUiSettings(title: 'Profil fotoğrafını kırp'),
          ],
        );
        if (cropped == null) return;
        await _savePickedPhoto(XFile(cropped.path));
      } else {
        await _savePickedPhoto(file);
      }
    } on ArgumentError catch (error) {
      _message(error.message.toString());
    } catch (_) {
      _message('Fotoğraf seçilemedi veya kaydedilemedi. Lütfen yeniden dene.');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _editName() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initialName: _name),
    );
    if (value == null || !mounted || _profile == null) return;
    try {
      await _profile!.saveName(value);
      if (mounted) setState(() => _name = _profile!.name);
    } catch (_) {
      _message('İsim kaydedilemedi. Lütfen yeniden dene.');
    }
  }

  Future<void> _setIntro(bool value) async {
    setState(() => _settingBusy = true);
    try {
      await _worldSettings.setSkipIntroAnimation(!value);
      if (mounted) {
        setState(() => _showIntro = !_worldSettings.skipIntroAnimation);
      }
    } catch (_) {
      _message('Ayar kaydedilemedi. Lütfen yeniden dene.');
    } finally {
      if (mounted) setState(() => _settingBusy = false);
    }
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: Colors.white70),
    ),
  );

  Widget _card(Widget child) => Material(
    color: _surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: Color(0xff315071), width: .75),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      title: const Text('Profil & Ayarlar'),
      backgroundColor: _background,
      surfaceTintColor: Colors.transparent,
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section('PROFİL'),
                _card(
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _blue, width: 1.2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22248fff),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _photo == null
                                ? const ColoredBox(
                                    color: _background,
                                    child: Icon(
                                      Icons.person_outline,
                                      size: 46,
                                      color: Colors.white54,
                                    ),
                                  )
                                : Image.memory(
                                    _photo!,
                                    fit: BoxFit.cover,
                                    cacheWidth: 256,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.person_outline,
                                      size: 46,
                                      color: Colors.white54,
                                    ),
                                  ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loading || _photoBusy || _profile == null
                              ? null
                              : _pickPhoto,
                          style: TextButton.styleFrom(foregroundColor: _blue),
                          child: Text(
                            _photoBusy
                                ? 'Fotoğraf işleniyor…'
                                : _photo == null
                                ? 'Fotoğraf Ekle'
                                : 'Fotoğrafı Değiştir',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _loading || _profile == null
                              ? null
                              : _editName,
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: Text(
                            _name ?? 'İsim Belirle',
                            textAlign: TextAlign.center,
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            textStyle: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (_loading)
                          const LinearProgressIndicator(
                            minHeight: 2,
                            color: _blue,
                          ),
                        if (_loadError != null)
                          TextButton(
                            onPressed: _loadProfile,
                            child: Text(_loadError!),
                          ),
                      ],
                    ),
                  ),
                ),
                _section('AYARLAR'),
                _section('DÜNYA'),
                _card(
                  SwitchListTile.adaptive(
                    key: const Key('world_intro_enabled_switch'),
                    title: const Text('Açılış Animasyonu'),
                    subtitle: const Text(
                      'Dünya açılırken giriş animasyonunu göster.',
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    activeTrackColor: _blue,
                    value: _showIntro,
                    onChanged: _settingBusy ? null : _setIntro,
                  ),
                ),
                _section('UYGULAMA'),
                _card(
                  Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.info_outline, color: _blue),
                        title: const Text('DriveIt Hakkında'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: _surface,
                            title: const Text('DriveIt'),
                            content: const Text(
                              'Sürüşlerini kaydet, analiz et ve kendi sürüş dünyanı oluştur.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Kapat'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xff315071)),
                      ListTile(
                        title: const Text('Sürüm'),
                        trailing: Text(
                          _version,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({this.initialName});
  final String? initialName;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;
  String? _error;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Lütfen bir isim yaz.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xff07162b),
    title: const Text('İsmini Belirle'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: ProfileStorageService.maximumNameLength,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _save(),
      decoration: InputDecoration(labelText: 'İsim', errorText: _error),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('İptal'),
      ),
      TextButton(onPressed: _save, child: const Text('Kaydet')),
    ],
  );
}
