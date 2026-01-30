import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlobalScanListener extends StatefulWidget {
  final Widget child;
  final Future<void> Function(String raw) onScan;

  const GlobalScanListener({
    super.key,
    required this.child,
    required this.onScan,
  });

  @override
  State<GlobalScanListener> createState() => _GlobalScanListenerState();
}

class _GlobalScanListenerState extends State<GlobalScanListener> {
  String _buffer = "";
  Timer? _idleTimer;

  bool _handlingScan = false;
  DateTime _lastScanAt = DateTime.fromMillisecondsSinceEpoch(0);

  String _lastPayload = "";
  DateTime _lastPayloadAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _idleTimer?.cancel();
    super.dispose();
  }

  String? _extractCompleteJson(String input) {
    final start = input.indexOf('{');
    if (start == -1) return null;

    int depth = 0;
    bool inString = false;
    bool escape = false;

    for (int i = start; i < input.length; i++) {
      final ch = input[i];

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
          return input.substring(start, i + 1);
        }
      }
    }
    return null;
  }

  Future<void> _finalizeIfPossible() async {
    if (_handlingScan) return;

    final json = _extractCompleteJson(_buffer);
    if (json == null) return;

    // cooldown anti-double-scan
    final now = DateTime.now();
    if (now.difference(_lastScanAt) < const Duration(milliseconds: 500)) {
      _buffer = "";
      return;
    }
    _lastScanAt = now;

    _handlingScan = true;
    final payload = json;

    // ✅ anti-double-scan: même payload reçu 2 fois (Enter + LF, ou double envoi)
    final now2 = DateTime.now();
    if (payload == _lastPayload &&
        now2.difference(_lastPayloadAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastPayload = payload;
    _lastPayloadAt = now2;

    _buffer = "";

    try {
      await widget.onScan(payload);
    } finally {
      _handlingScan = false;
    }
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Enter => fin immédiate
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _idleTimer?.cancel();
      _finalizeIfPossible();
      return false;
    }

    final ch = event.character;
    if (ch != null && ch.isNotEmpty) {
      _buffer += ch;

      // fin par pause si pas de Enter
      _idleTimer?.cancel();
      _idleTimer = Timer(const Duration(milliseconds: 120), () {
        _finalizeIfPossible();
      });
    }

    return false; // on ne bloque pas les autres handlers
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
