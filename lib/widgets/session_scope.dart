import 'package:flutter/material.dart';
import '../state/app_session.dart';
import '../state/orders_store.dart';

class SessionScope extends InheritedNotifier<Listenable> {
  final AppSession session;
  final OrdersStore orders;

  SessionScope({
    super.key,
    required this.session,
    required this.orders,
    required Widget child,
  }) : super(
          notifier: Listenable.merge([session, orders]),
          child: child,
        );

  static SessionScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope introuvable dans l’arbre');
    return scope!;
  }
}
