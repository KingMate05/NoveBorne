import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HidScanController {
  HidScanController({
    required this.snack,
    required this.isBusy,
    required this.onJson,
    this.timeout = const Duration(seconds: 10),
  });

  final void Function(String msg) snack;
  final bool Function() isBusy;
  final Future<void> Function(String json) onJson;
  final Duration timeout;

  // Focus + champ invisible
  final FocusNode _focus = FocusNode(debugLabel: 'hid_focus');
  final TextEditingController _ctrl = TextEditingController();

  // Etat scan
  bool _armed = false;
  bool _consumed = false;

  // Buffer + timers
  String _buffer = "";
  Timer? _scanTimeout;
  Timer? _idleTimer;

  // ---------- API utilisée par l'écran ----------

  /// À mettre dans le widget tree (dans identify_screen)
  Widget buildHiddenField() {
    return SizedBox(
      width: 1,
      height: 1,
      child: Opacity(
        opacity: 0.0,
        child: TextField(
          focusNode: _focus,
          controller: _ctrl,
          enableInteractiveSelection: false,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.none,
          decoration: const InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: _onChanged,
        ),
      ),
    );
  }

  void start() {
    if (isBusy()) return;

    // Reset complet (anti blocage)
    _resetInternal();

    _armed = true;
    _consumed = false;

    _ctrl.clear();
    _buffer = "";

    ensureFocus();
    snack("Prêt à scanner");

    _scanTimeout = Timer(timeout, () {
      if (!_armed || _consumed) return;
      _armed = false;
      _ctrl.clear();
      _buffer = "";
      snack("Scan annulé (timeout)");
      ensureFocus();
    });
  }

  void ensureFocus() {
    // Petit trick: requestFocus peut être ignoré si déjà focus,
    // donc on "toggle" proprement quand nécessaire.
    if (_focus.hasFocus) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _focus.requestFocus();
  }

  void dispose() {
    _scanTimeout?.cancel();
    _idleTimer?.cancel();
    _focus.dispose();
    _ctrl.dispose();
  }

  // ---------- Interne ----------

  void _resetInternal() {
    _scanTimeout?.cancel();
    _idleTimer?.cancel();
    _scanTimeout = null;
    _idleTimer = null;

    _armed = false;
    _consumed = false;

    _ctrl.clear();
    _buffer = "";
  }

  void _onChanged(String value) async {
    // Si pas armé ou déjà consommé, on ignore
    if (!_armed || _consumed) return;

    // Si traitement en cours côté écran (API/orders), on ignore
    if (isBusy()) return;

    _buffer = value;

    // Certains scanners n’envoient pas "Enter".
    // On utilise un idle timer pour finaliser après une micro-pause.
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(milliseconds: 120), () async {
      if (!_armed || _consumed) return;
      if (isBusy()) return;

      final json = _extractCompleteJson(_buffer);
      if (json == null) return;

      // Verrouille avant await
      _consumed = true;
      _armed = false;

      _scanTimeout?.cancel();
      _scanTimeout = null;

      // Reset champ avant traitement pour éviter les doubles
      _ctrl.clear();
      _buffer = "";

      ensureFocus();

      await onJson(json);

      // Après traitement, on reste prêt à recevoir un futur scan
      ensureFocus();
    });

    // Si le JSON devient complet immédiatement, on accélère
    final jsonNow = _extractCompleteJson(_buffer);
    if (jsonNow != null) {
      _idleTimer?.cancel();
      _idleTimer = null;

      _consumed = true;
      _armed = false;

      _scanTimeout?.cancel();
      _scanTimeout = null;

      _ctrl.clear();
      _buffer = "";

      ensureFocus();
      await onJson(jsonNow);
      ensureFocus();
    }
  }

  /// Extrait le premier objet JSON complet trouvé dans une string.
  String? _extractCompleteJson(String input) {
    if (input.isEmpty) return null;

    // enlève les caractères de contrôle (sauf \n \r \t)
    final cleaned = input.replaceAll(
      RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'),
      '',
    );

    final start = cleaned.indexOf('{');
    if (start == -1) return null;

    int depth = 0;
    bool inString = false;
    bool escape = false;

    for (int i = start; i < cleaned.length; i++) {
      final ch = cleaned[i];

      if (inString) {
        if (escape) {
          escape = false;
        } else if (ch == r'\') {
          escape = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      } else {
        if (ch == '"') {
          inString = true;
          continue;
        }
        if (ch == '{') depth++;
        if (ch == '}') depth--;

        if (depth == 0 && i > start) {
          return cleaned.substring(start, i + 1);
        }
      }
    }

    return null;
  }
}
