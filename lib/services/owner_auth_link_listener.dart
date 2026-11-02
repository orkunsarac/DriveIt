import 'dart:async';
import 'package:app_links/app_links.dart';
import 'owner_auth_callback_delivery.dart';

/// Shared Android link composition for the application and isolated acceptance.
class OwnerAuthLinkListener {
  OwnerAuthLinkListener(this.delivery, {AppLinks? links})
    : _links = links ?? AppLinks();
  final OwnerAuthCallbackDelivery delivery;
  final AppLinks _links;
  StreamSubscription<Uri>? _subscription;
  void start() {
    if (_subscription != null) {
      throw StateError('Callback listener already started');
    }
    _subscription = _links.uriLinkStream.listen(
      (uri) => unawaited(delivery.deliver(uri)),
      onError: (Object _) {},
    );
    unawaited(
      _links
          .getInitialLink()
          .then((uri) {
            if (uri != null) return delivery.deliver(uri);
          })
          .catchError((Object _) {}),
    );
    unawaited(
      _links
          .getLatestLink()
          .then((uri) {
            if (uri != null) return delivery.deliver(uri);
          })
          .catchError((Object _) {}),
    );
  }

  void close() {
    delivery.close();
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}
