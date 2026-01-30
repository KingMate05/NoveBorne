import 'package:flutter/material.dart';

class KioskKeyboard extends StatefulWidget {
  const KioskKeyboard({
    super.key,
    required this.title,
    required this.controller,
    required this.onValidate,
  });

  final String title;
  final TextEditingController controller;
  final VoidCallback onValidate;

  @override
  State<KioskKeyboard> createState() => _KioskKeyboardState();
}

class _KioskKeyboardState extends State<KioskKeyboard> {
  bool _shiftOnce = false; // maj pour 1 seule lettre
  bool _capsLock = false; // maj verrouillée
  bool _numbers = false;

  DateTime? _lastShiftTapAt;
  static const _doubleTapDelay = Duration(milliseconds: 350);

  bool get _isUpper => _capsLock || _shiftOnce;

  void _insert(String v) {
    final toAdd = _numbers ? v : (_isUpper ? v.toUpperCase() : v);

    final next = (widget.controller.text + toAdd)
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), ''); // filtre dur

    widget.controller.value = widget.controller.value.copyWith(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
      composing: TextRange.empty,
    );

    // Android-like: shift one-shot s’éteint après une lettre
    if (!_numbers && _shiftOnce && !_capsLock) {
      setState(() => _shiftOnce = false);
    }
  }

  void _backspace() {
    final t = widget.controller.text;
    if (t.isEmpty) return;

    final next = t.substring(0, t.length - 1);
    widget.controller.value = widget.controller.value.copyWith(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
      composing: TextRange.empty,
    );
  }

  void _clear() {
    widget.controller.clear();
  }

  void _tapShift() {
    final now = DateTime.now();

    final isDoubleTap = _lastShiftTapAt != null &&
        now.difference(_lastShiftTapAt!) <= _doubleTapDelay;

    _lastShiftTapAt = now;

    setState(() {
      if (isDoubleTap) {
        // Double tap => caps lock ON
        _capsLock = true;
        _shiftOnce = false;
      } else {
        // Tap simple:
        // - si caps lock actif => OFF
        // - sinon => one-shot toggle
        if (_capsLock) {
          _capsLock = false;
          _shiftOnce = false;
        } else {
          _shiftOnce = !_shiftOnce;
        }
      }
    });
  }

  Widget _key({
    required Widget child,
    required VoidCallback onTap,
    bool primary = false,
    bool special = false,
  }) {
    final bg = primary
        ? const Color(0xFFF36C21)
        : special
            ? Colors.grey.shade300
            : Colors.grey.shade200;

    final fg = primary ? Colors.white : Colors.black87;

    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: child,
      ),
    );
  }

  String _case(String s) => _numbers ? s : (_isUpper ? s.toUpperCase() : s);

  List<String> get row1 => _numbers
      ? ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']
      : ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];

  List<String> get row2 => _numbers
      ? ['-', '/', ':', ';', '(', ')', '€', '&', '@']
      : ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];

  List<String> get row3 => _numbers
      ? ['.', ',', '?', '!', '\'']
      : ['z', 'x', 'c', 'v', 'b', 'n', 'm'];

  Widget _buildRow(List<String> keys, {EdgeInsets padding = EdgeInsets.zero}) {
    return Padding(
      padding: padding,
      child: Row(
        children: keys
            .map(
              (k) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _key(
                    onTap: () => _insert(_case(k)),
                    child: Text(
                      _case(k),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Actions rapides
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _key(
                        special: true,
                        onTap: _clear,
                        child: const Text(
                          "Effacer",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _key(
                        primary: true,
                        onTap: widget.onValidate,
                        child: const Text(
                          "OK",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              _buildRow(row1),
              const SizedBox(height: 8),
              _buildRow(row2,
                  padding: const EdgeInsets.symmetric(horizontal: 14)),
              const SizedBox(height: 8),

              // Row 3: Shift + lettres + backspace
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _key(
                        special: true,
                        onTap: _tapShift,
                        child: Icon(
                          _capsLock
                              ? Icons.keyboard_capslock
                              : Icons.arrow_upward,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: Row(
                      children: row3
                          .map(
                            (k) => Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: _key(
                                  onTap: () => _insert(_case(k)),
                                  child: Text(
                                    _case(k),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _key(
                        special: true,
                        onTap: _backspace,
                        child: const Icon(Icons.backspace, size: 22),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Bottom row: 123/ABC + espace + OK
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _key(
                        special: true,
                        onTap: () => setState(() => _numbers = !_numbers),
                        child: Text(
                          _numbers ? "ABC" : "123",
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _key(
                        onTap: () => _insert(" "),
                        child: const Text(
                          "Espace",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _key(
                        primary: true,
                        onTap: widget.onValidate,
                        child: const Text(
                          "OK",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
