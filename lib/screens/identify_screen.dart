import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'home_after_auth_screen.dart';
import '../widgets/session_scope.dart';
import 'qr_camera_screen.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // debugPrint
import 'package:flutter_libserialport/flutter_libserialport.dart';

class AuthScreen extends StatefulWidget {
  static const routeName = '/identify';

  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _passwordCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _keywordCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();
  final FocusNode _scanKeyFocus = FocusNode();
  String _keyBuffer = "";
  Timer? _keyIdleTimer;
  String _hidBuffer = "";
  bool _showScanAnimation = false;

  bool _scanArmed = false; // l’utilisateur a appuyé sur “scanner”
  bool _scanConsumed = false; // on a déjà pris 1 scan

  final FocusNode _hidFocus = FocusNode();
  final TextEditingController _hidCtrl = TextEditingController();

  Timer? _hidIdleTimer; // pour finir le scan même sans "Entrée"
// Keys pour scroll vers les champs
  final GlobalKey _pwdKey = GlobalKey();
  final GlobalKey _clientKey = GlobalKey();
  final GlobalKey _keywordKey = GlobalKey();
  SerialPort? _scanPort;
  SerialPortReader? _scanReader;
  StreamSubscription<Uint8List>? _scanSub;
  final List<int> _scanBuffer = [];

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _kbdOpen = false;
  static const double _kioskKeyboardHeight = 360; // ajuste si besoin (320-420)

  final ScrollController _scrollCtrl = ScrollController();

  PersistentBottomSheetController? _kbdSheet;

  static const String _scannerComPort = "COM5";
  static const int _scannerBaudRate = 9600;

  bool _submitting = false;

  int _adminTapCount = 0;
  DateTime? _lastAdminTapAt;

  static const orange = Color(0xFFF36C21);
  static const lightGrey = Color(0xFFF3F3F3);
  static const cardGrey = Color(0xFFF6F6F6);

  final List<TextInputFormatter> uppercaseAlphaNumFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
    TextInputFormatter.withFunction((oldValue, newValue) {
      return newValue.copyWith(
        text: newValue.text.toUpperCase(),
        selection: newValue.selection,
      );
    }),
  ];

  @override
  void initState() {
    super.initState();

    // Donne le focus au champ invisible après le premier build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scanKeyFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _hidFocus.dispose();
    _hidCtrl.dispose();
    _scanTimeout?.cancel();
    _kbdSheet?.close();
    _stopHardwareScannerListening();
    _passwordCtrl.dispose();
    _clientCtrl.dispose();
    _keywordCtrl.dispose();
    _qrCtrl.dispose();
    _scrollCtrl.dispose();
    _keyIdleTimer?.cancel();
    _scanKeyFocus.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onAdminSecretTap() {
    final now = DateTime.now();

    if (_lastAdminTapAt == null ||
        now.difference(_lastAdminTapAt!) > const Duration(seconds: 2)) {
      _adminTapCount = 0;
    }

    _lastAdminTapAt = now;
    _adminTapCount++;

    if (_adminTapCount >= 5) {
      _adminTapCount = 0;
      _openAdminSheet();
    }
  }

  String? _extractCompleteJson(String input) {
    if (input.isEmpty) return null;

    // 1) Enlève les caractères de contrôle qui cassent tout (0x00..0x1F)
    //    (on garde \n \r \t car souvent présents dans les QR multi-lignes)
    final cleaned = input.replaceAll(
        RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '');

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

  void _onScanKeyEvent(KeyEvent event) async {
    if (!_scanArmed || _scanConsumed || _submitting) return;
    if (event is! KeyDownEvent) return;

    final key = event.character;

    // Certains scanners envoient Enter à la fin
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final json = _extractCompleteJson(_keyBuffer);
      if (json != null) {
        setState(() {
          _scanConsumed = true;
          _scanArmed = false;
        });
        final payload = json;
        _keyBuffer = "";
        await _handleQr(payload);
      }
      return;
    }

    // Ajoute les caractères tapés
    if (key != null && key.isNotEmpty) {
      _keyBuffer += key;

      // Petit timer: si pas d’ENTER, on tente de finaliser après une pause
      _keyIdleTimer?.cancel();
      _keyIdleTimer = Timer(const Duration(milliseconds: 120), () async {
        final json = _extractCompleteJson(_keyBuffer);
        if (json == null) return;

        if (!mounted) return;
        if (!_scanArmed || _scanConsumed || _submitting) return;

        setState(() {
          _scanConsumed = true;
          _scanArmed = false;
        });

        final payload = json;
        _keyBuffer = "";
        await _handleQr(payload);
      });
    }
  }

  void _openAdminSheet() {
    final session = SessionScope.of(context).session;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Menu admin",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.restart_alt),
                    label: const Text("Réinitialiser le mot de passe admin"),
                    onPressed: _submitting
                        ? null
                        : () async {
                            Navigator.of(ctx).pop();
                            await session.resetPassword();
                            _passwordCtrl.clear();
                            if (mounted) {
                              _snack("Mot de passe admin réinitialisé");
                            }
                          },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text("Fermer"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onHidChanged(String value) async {
    // On ignore si pas armé ou déjà consommé
    if (!_scanArmed || _scanConsumed) return;

    // Si on traite déjà, on évite d’empiler des scans
    if (_submitting) return;

    _hidBuffer = value;

    // 1) tentative JSON complet
    final json = _extractCompleteJson(_hidBuffer);

    // 2) si pas complet, on laisse continuer
    if (json == null) return;

    // 3) verrou immédiat
    setState(() {
      _scanConsumed = true;
      _scanArmed = false;
    });

    _scanTimeout?.cancel();
    _scanTimeout = null;

    // 4) clear champ/buffer avant traitement
    _hidCtrl.clear();
    _hidBuffer = "";

    // 5) focus revient au récepteur pour éviter que le scanner écrive ailleurs
    if (mounted) _hidFocus.requestFocus();

    await _handleQr(json);

    // 6) après traitement, on garde le focus prêt pour le prochain scan
    if (mounted) _hidFocus.requestFocus();
  }

  Timer? _scanTimeout;

  void _prepareHidScan() {
    if (_submitting) return;

    setState(() {
      _scanArmed = true;
      _scanConsumed = false;
    });

    _hidCtrl.clear();
    _hidBuffer = "";
    _hidFocus.requestFocus();
    _snack("Prêt à scanner");

    _scanTimeout?.cancel();
    _scanTimeout = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      if (_scanArmed && !_scanConsumed) {
        setState(() => _scanArmed = false);
        _hidCtrl.clear();
        _hidBuffer = "";
        _snack("Scan annulé (timeout)");
      }
    });
  }

  void _resetHidScanState({bool keepSubmitting = false}) {
    _scanTimeout?.cancel();
    _keyIdleTimer?.cancel();

    _hidCtrl.clear();
    _hidBuffer = "";
    _keyBuffer = "";

    setState(() {
      _scanArmed = false;
      _scanConsumed = false;
      if (!keepSubmitting) _submitting = false;
    });

    // Re-focus sur le récepteur HID
    if (mounted) _hidFocus.requestFocus();
  }

  void _startHidScan() {
    // Si ça restait bloqué (bug réseau, exception, etc.), on repart clean
    _resetHidScanState();

    setState(() {
      _scanArmed = true;
      _scanConsumed = false;
    });

    _hidCtrl.clear();
    _hidBuffer = "";
    _hidFocus.requestFocus();
    _snack("Prêt à scanner");

    _scanTimeout = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      if (_scanArmed && !_scanConsumed) {
        setState(() => _scanArmed = false);
        _hidCtrl.clear();
        _hidBuffer = "";
        _snack("Scan annulé (timeout)");
        _hidFocus.requestFocus();
      }
    });
  }

  Future<void> _scrollToField(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;

    // RenderBox du champ
    final box = ctx.findRenderObject();
    if (box is! RenderBox) return;

    // Position du champ à l'écran
    final fieldTopLeft = box.localToGlobal(Offset.zero);
    final fieldBottomY = fieldTopLeft.dy + box.size.height;

    final screenH = MediaQuery.of(context).size.height;

    // zone visible au-dessus du clavier custom
    final visibleBottomY = screenH - _kioskKeyboardHeight - 16;

    if (fieldBottomY <= visibleBottomY) return; // déjà visible

    final delta = fieldBottomY - visibleBottomY;

    final target = (_scrollCtrl.offset + delta)
        .clamp(0.0, _scrollCtrl.position.maxScrollExtent);

    await _scrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _scanWithHardwareScannerOnce() async {
    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      // Ouvre COM5
      final port = SerialPort(_scannerComPort);
      if (!port.openReadWrite()) {
        _snack("Impossible d'ouvrir $_scannerComPort");
        return;
      }
      debugPrint("🟢 COM ouvert: $_scannerComPort");

      final cfg = SerialPortConfig()
        ..baudRate = _scannerBaudRate
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = 1
        ..setFlowControl(SerialPortFlowControl.none);

      port.config = cfg;

      _scanPort = port;
      _scanReader = SerialPortReader(port);

      _scanBuffer.clear();
      debugPrint(
          "✅ Écoute démarrée sur $_scannerComPort (baud $_scannerBaudRate). Scanne un QR…");

      final completer = Completer<String>();

      _scanSub = _scanReader!.stream.listen((chunk) {
        _scanBuffer.addAll(chunk);

        // On considère "scan terminé" quand on voit CR ou LF
        final endIdx = _scanBuffer.indexWhere((b) => b == 0x0D || b == 0x0A);
        if (endIdx == -1) return;

        final lineBytes = _scanBuffer.sublist(0, endIdx);
        completer.complete(_cleanScannerPayload(lineBytes));
      }, onError: (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      });

      // Timeout sécurité (évite d’écouter à l’infini)
      final payload =
          await completer.future.timeout(const Duration(seconds: 20));

      debugPrint("📦 RAW (nettoyé) = $payload");

      // Si tu veux juste afficher dans console, on s’arrête là.
      // Plus tard, tu pourras appeler: await _handleQr(payload);

      _snack("Scan reçu (voir console)");
    } on TimeoutException {
      _snack("Timeout: aucun scan détecté");
    } catch (e) {
      _snack("Erreur scanner: $e");
    } finally {
      await _stopHardwareScannerListening();
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _cleanScannerPayload(List<int> bytes) {
    // 1) Retire les caractères de contrôle au début (dont 0x1A = 26 -> \000026)
    while (bytes.isNotEmpty && bytes.first < 32) {
      bytes = bytes.sublist(1);
    }

    if (bytes.isEmpty) return "";

    // 2) Decode
    final s = latin1.decode(bytes, allowInvalid: true).trim();

    // 3) Optionnel: ne garder que la partie JSON si jamais il y a du bruit autour
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return s.substring(start, end + 1);
    }

    return s;
  }

  Future<void> _stopHardwareScannerListening() async {
    await _scanSub?.cancel();
    _scanSub = null;

    _scanReader?.close();
    _scanReader = null;

    _scanPort?.close();
    _scanPort?.dispose();
    _scanTimeout?.cancel();
    _scanPort = null;
  }

  Future<void> _goHome() async {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, HomeAfterAuthScreen.routeName);
  }

  Future<void> _scanWithCamera() async {
    if (_submitting) return;

    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrCameraScreen()),
    );

    if (raw == null) return;
    await _handleQr(raw);
  }

  /// QR JSON attendu:
  /// { "ctNum": "I51357", "doPiece": "PM204515" }
  /// Si doPiece est présent -> search keywords + pré-sélection.
  Future<void> _handleQr(String raw) async {
    final scope = SessionScope.of(context);
    debugPrint("QR RAW = [$raw]");

    final orders = scope.orders;
    final extracted = _extractCompleteJson(raw) ?? raw;
    final trimmed = extracted.trim();
    if (trimmed.isEmpty) {
      _snack("QR vide");
      return;
    }

    debugPrint("QR TRIMMED = [$trimmed]");

    setState(() => _submitting = true);
    try {
      final decoded = jsonDecode(trimmed);

      if (decoded is! Map) {
        throw Exception("QR invalide: pas un objet JSON");
      }

      final m = decoded.cast<String, dynamic>();

      final doPiece = m['doPiece']?.toString().trim();
      final ctNumRaw = (m['ctNum'] ?? m['client'])?.toString() ?? "";
      final ctNum =
          ctNumRaw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

      if (doPiece != null && doPiece.isNotEmpty) {
        await orders.loadByKeyword(doPiece);
        if (orders.orders.isEmpty) {
          _snack("Commande introuvable: $doPiece");
          return;
        }

        orders.selectedPieces
          ..clear()
          ..add(orders.orders.first.doPiece);

        await _goHome();
        return;
      }

      if (ctNum.isNotEmpty) {
        await orders.loadByClient(ctNum);
        if (orders.orders.isEmpty) {
          _snack("Aucune commande trouvée pour: $ctNum");
          return;
        }
        await _goHome();
        return;
      }

      _snack("QR invalide: clés attendues ctNum / doPiece");
    } catch (e) {
      _snack("Erreur QR: $e");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _searchByClient(String doTiers) async {
    final orders = SessionScope.of(context).orders;

    final v = doTiers.trim();
    if (v.isEmpty) {
      _snack("Numéro client vide");
      return;
    }

    setState(() => _submitting = true);
    try {
      await orders.loadByClient(v);
      if (orders.orders.isEmpty) {
        _snack("Aucune commande trouvée pour: $v");
        return;
      }
      await _goHome();
    } catch (e) {
      _snack("Erreur: $e");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openKioskKeyboard({
    required TextEditingController ctrl,
    required VoidCallback onValidate,
    String title = "Saisie",
    bool disableScanPause = false,
  }) async {
    if (!mounted) return;

    // Optionnel: pause scan pendant saisie
    if (!disableScanPause) {
      setState(() {
        _scanArmed = false;
        _scanConsumed = false;
      });
      _scanTimeout?.cancel();
    }

    // Ferme l’ancien clavier s’il est déjà ouvert
    _kbdSheet?.close();
    _kbdSheet = null;

    // Ouvre un bottom sheet NON modal => on peut cliquer derrière ✅
    final scaffoldState = _scaffoldKey.currentState;
    if (scaffoldState == null) return;
    setState(() => _kbdOpen = true);

    _kbdSheet = scaffoldState.showBottomSheet(
      (ctx) {
        return SizedBox(
          width: MediaQuery.sizeOf(ctx).width,
          child: _KioskKeyboard(
            title: title,
            controller: ctrl,
            onValidate: () {
              // on ferme le clavier puis on exécute
              _kbdSheet?.close();
              _kbdSheet = null;
              onValidate();
            },
          ),
        );
      },
      backgroundColor: Colors.transparent,
      elevation: 0,
    );

    // Si l’utilisateur ferme le sheet (drag/back), on nettoie
    _kbdSheet!.closed.whenComplete(() {
      _kbdSheet = null;
      if (mounted) {
        setState(() =>
            _kbdOpen = false); // ✅ enlève l'espace quand le clavier se ferme
        _scanKeyFocus.requestFocus();
      }
    });
  }

  Future<void> _searchByKeyword(String keyword) async {
    final orders = SessionScope.of(context).orders;
    final v = keyword.trim();
    if (v.isEmpty) {
      _snack("Numéro de commande vide");
      return;
    }

    setState(() => _submitting = true);
    try {
      await orders.loadByKeyword(v);
      if (orders.orders.isEmpty) {
        _snack("Commande introuvable: $v");
        return;
      }

      orders.selectedPieces
        ..clear()
        ..add(orders.orders.first.doPiece);

      await _goHome();
    } catch (e) {
      _snack("Erreur: $e");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitAdminPassword() async {
    final session = SessionScope.of(context).session;
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      await session.setPasswordAndLogin(_passwordCtrl.text);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final contentMaxWidth = size.width >= 600 ? 520.0 : size.width * 0.92;

    final scope = SessionScope.of(context);
    final session = scope.session;

    // 1) Chargement global (init session)
    if (session.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2) Mot de passe admin requis
    if (session.needsPassword) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: SingleChildScrollView(
                controller: _scrollCtrl, // ✅ AJOUT
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    const Text(
                      "INITIALISATION",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: orange,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Entrez le mot de passe admin (stocké localement).",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.45),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _OutlinedCard(
                      borderColor: orange,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "Mot de passe admin",
                            style: TextStyle(
                              color: orange,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            key: _pwdKey,
                            child: GestureDetector(
                              onTap: () async {
                                await _scrollToField(_pwdKey);

                                await _openKioskKeyboard(
                                  ctrl: _passwordCtrl,
                                  title: "Mot de passe admin",
                                  disableScanPause: true,
                                  onValidate: _submitAdminPassword,
                                );

                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  _scrollToField(_pwdKey);
                                });
                              },
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: _passwordCtrl,
                                  obscureText: true,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    hintText: "••••••••",
                                    filled: true,
                                    fillColor: lightGrey,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _PrimaryButton(
                            label: _submitting ? "Validation..." : "Valider",
                            onTap: _submitting ? () {} : _submitAdminPassword,
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () async {
                                    await session.resetPassword();
                                    _passwordCtrl.clear();
                                    _snack("Mot de passe réinitialisé");
                                  },
                            child: const Text("Réinitialiser le mot de passe"),
                          ),
                          if (session.error != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              session.error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ],
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

    // 3) Identification client (UI front + logique back)
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _submitting,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  22 + (_kbdOpen ? _kioskKeyboardHeight : 0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 3),

                    // Title (tap secret admin)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _onAdminSecretTap, // 👈 5 taps rapides
                      child: const Text(
                        "IDENTIFIEZ VOUS",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: orange,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Choisir une méthode d'identification",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.45),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 59),
                    _InkCard(
                      onTap: () {
                        setState(() => _showScanAnimation = true); // optionnel
                        _startHidScan();
                      },
                      child: _SoftCard(
                        background: cardGrey,
                        borderColor: Colors.transparent,
                        child: Row(
                          children: [
                            // ✅ QR icon à gauche (on le garde)
                            Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.black.withOpacity(0.08),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.qr_code_2,
                                  size: 86,
                                  color: Colors.black.withOpacity(0.75),
                                ),
                              ),
                            ),

                            const SizedBox(width: 14),

                            // ✅ Textes
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Scanner mon\nQR code",
                                    style: TextStyle(
                                      color: orange,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Scanner le QR code sur le\nsite web",
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.45),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _submitting
                                        ? "Traitement..."
                                        : "Touchez pour scanner",
                                    style: TextStyle(
                                      color: orange.withOpacity(0.9),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ✅ Lottie à droite dans l’espace vide
                            if (_showScanAnimation) ...[
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: Lottie.asset(
                                  'assets/lottie/scan.json',
                                  repeat: true,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Card 2: Client number
                    _OutlinedCard(
                      borderColor: orange,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.person,
                                  color: Colors.black87, size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Entrer mon numéro\nclient",
                                  style: TextStyle(
                                    color: orange,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            key: _clientKey,
                            child: GestureDetector(
                              onTap: () async {
                                await _openKioskKeyboard(
                                  ctrl: _clientCtrl,
                                  title: "Numéro client",
                                  onValidate: () =>
                                      _searchByClient(_clientCtrl.text),
                                  disableScanPause: true,
                                );

                                // ✅ après ouverture du clavier: scroll le champ
                                if (!mounted) return;
                                await _scrollToField(_clientKey);
                              },
                              child: AbsorbPointer(
                                child: _RoundedField(
                                  controller: _clientCtrl,
                                  hint: "I51357",
                                  fill: lightGrey,
                                  readOnly: true,
                                  inputFormatters: uppercaseAlphaNumFormatters,
                                  onSubmitted: (_) {},
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _PrimaryButton(
                            label: _submitting ? "Chargement..." : "Valider",
                            onTap: _submitting
                                ? () {}
                                : () => _searchByClient(_clientCtrl.text),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Card 3: Order number
                    _OutlinedCard(
                      borderColor: orange,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.receipt_long,
                                  color: Colors.black87, size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Entrer mon numéro\nde commande",
                                  style: TextStyle(
                                    color: orange,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            key: _keywordKey,
                            child: GestureDetector(
                              onTap: () async {
                                await _openKioskKeyboard(
                                  ctrl: _keywordCtrl,
                                  title: "Numéro de commande",
                                  onValidate: () =>
                                      _searchByKeyword(_keywordCtrl.text),
                                );

                                // ✅ après ouverture du clavier: scroll le champ
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) async {
                                  final ctx = _keywordKey.currentContext;
                                  if (ctx == null) return;
                                  await Scrollable.ensureVisible(
                                    ctx,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                    alignment: 0.2,
                                  );
                                });
                              },
                              child: AbsorbPointer(
                                child: _RoundedField(
                                  controller: _keywordCtrl,
                                  hint: "PM204515",
                                  fill: lightGrey,
                                  onSubmitted: (_) {},
                                  inputFormatters: uppercaseAlphaNumFormatters,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _PrimaryButton(
                            label: _submitting ? "Chargement..." : "Valider",
                            onTap: _submitting
                                ? () {}
                                : () => _searchByKeyword(_keywordCtrl.text),
                          ),
                        ],
                      ),
                    ),

                    // Optionnel: debug "coller QR JSON" (caché en bas)
                    // const SizedBox(height: 18),
                    // ExpansionTile(
                    //   tilePadding: EdgeInsets.zero,
                    //   title: Text(
                    //     "Option avancée: coller un QR (JSON)",
                    //     style: TextStyle(
                    //       color: Colors.black.withOpacity(0.55),
                    //       fontWeight: FontWeight.w700,
                    //       fontSize: 13,
                    //     ),
                    //   ),
                    //   children: [
                    //     const SizedBox(height: 8),
                    //     TextField(
                    //       controller: _qrCtrl,
                    //       decoration: InputDecoration(
                    //         hintText: '{"ctNum":"I51357","doPiece":"PM204515"}',
                    //         filled: true,
                    //         fillColor: lightGrey,
                    //         border: OutlineInputBorder(
                    //           borderRadius: BorderRadius.circular(14),
                    //           borderSide: BorderSide.none,
                    //         ),
                    //       ),
                    //       minLines: 1,
                    //       maxLines: 4,
                    //     ),
                    //     const SizedBox(height: 10),
                    //     _PrimaryButton(
                    //       label: _submitting
                    //           ? "Traitement..."
                    //           : "Valider le texte",
                    //       onTap: _submitting
                    //           ? () {}
                    //           : () => _handleQr(_qrCtrl.text),
                    //     ),
                    //     const SizedBox(height: 6),
                    //   ],
                    // ),

                    if (_submitting) ...[
                      const SizedBox(height: 18),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- UI components (repris du front) ---------------- */

class _SoftCard extends StatelessWidget {
  final Widget child;
  final Color background;
  final Color borderColor;

  const _SoftCard({
    required this.child,
    required this.background,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _OutlinedCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;

  const _OutlinedCard({
    required this.child,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.6),
      ),
      child: child,
    );
  }
}

class _RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color fill;
  final ValueChanged<String> onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;

  const _RoundedField({
    required this.controller,
    required this.hint,
    required this.fill,
    required this.onSubmitted,
    this.inputFormatters,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.done,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: fill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF36C21);

    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _InkCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _InkCard({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: child,
      ),
    );
  }
}

class _KioskKeyboard extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final VoidCallback onValidate;

  const _KioskKeyboard({
    required this.title,
    required this.controller,
    required this.onValidate,
  });

  @override
  State<_KioskKeyboard> createState() => _KioskKeyboardState();
}

class _KioskKeyboardState extends State<_KioskKeyboard> {
  bool _shiftOnce = false; // maj pour 1 seule lettre
  bool _capsLock = false; // maj verrouillée
  bool _numbers = false;

  DateTime? _lastShiftTapAt; // pour détecter le double tap
  static const _doubleTapDelay = Duration(milliseconds: 350);

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

    // ✅ Comportement Android: shift one-shot s’éteint après une lettre
    if (!_numbers && _shiftOnce && !_capsLock) {
      setState(() => _shiftOnce = false);
    }
  }

  void _backspace() {
    final t = widget.controller.text;
    if (t.isEmpty) return;
    widget.controller.text = t.substring(0, t.length - 1);
    widget.controller.selection =
        TextSelection.collapsed(offset: widget.controller.text.length);
  }

  bool get _isUpper => _capsLock || _shiftOnce;

  void _tapShift() {
    final now = DateTime.now();

    final isDoubleTap = _lastShiftTapAt != null &&
        now.difference(_lastShiftTapAt!) <= _doubleTapDelay;

    _lastShiftTapAt = now;

    setState(() {
      if (isDoubleTap) {
        // Double tap => verrouillage maj
        _capsLock = true;
        _shiftOnce = false;
      } else {
        // Tap simple:
        // - si caps lock actif => on désactive
        // - sinon => one-shot ON/OFF
        if (_capsLock) {
          _capsLock = false;
          _shiftOnce = false;
        } else {
          _shiftOnce = !_shiftOnce;
        }
      }
    });
  }

  void _clear() => widget.controller.clear();

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
            .map((k) => Expanded(
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
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ prend toute la largeur, sans overlay, sans champ preview
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
              // Header léger
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

              // Actions rapides (sans preview)
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

              // Row 3 avec Shift + Backspace
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
                              : (_shiftOnce
                                  ? Icons.arrow_upward
                                  : Icons.arrow_upward),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: Row(
                      children: row3
                          .map((k) => Expanded(
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
                              ))
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
