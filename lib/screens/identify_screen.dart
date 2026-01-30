import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../widgets/session_scope.dart';
import 'home_after_auth_screen.dart';

import 'auth_scan_hid.dart';
import 'auth_controller.dart';

// UI extraits
import '../widgets/ui_cards.dart';
import '../widgets/ui_fields.dart';
import '../widgets/kiosk_keyboard.dart';

class AuthScreen extends StatefulWidget {
  static const routeName = '/identify';
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // --- Controllers UI ---
  final _passwordCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _keywordCtrl = TextEditingController();

  // --- UI state ---
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollCtrl = ScrollController();

  bool _kbdOpen = false;
  static const double _kioskKeyboardHeight = 360;
  PersistentBottomSheetController? _kbdSheet;

  bool _showScanAnimation = false;
  bool _submitting = false;

  // --- Admin secret tap ---
  int _adminTapCount = 0;
  DateTime? _lastAdminTapAt;

  // --- Scan HID + logique métier ---
  late final HidScanController _hid;
  late final AuthController _auth;

  // Keys pour scroll vers les champs
  final GlobalKey _pwdKey = GlobalKey();
  final GlobalKey _clientKey = GlobalKey();
  final GlobalKey _keywordKey = GlobalKey();

  // --- UI constants ---
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

    _auth = AuthController(
      getContext: () => context,
      snack: _snack,
      goHome: _goHome,
      setSubmitting: (v) {
        if (!mounted) return;
        setState(() => _submitting = v);
      },
    );

    _hid = HidScanController(
      snack: _snack,
      isBusy: () => _submitting,
      onJson: (json) async {
        if (mounted) setState(() => _showScanAnimation = false);
        await _auth.handleQr(json);
        _hid.ensureFocus();
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hid.ensureFocus();
    });
  }

  @override
  void dispose() {
    _hid.dispose();

    _kbdSheet?.close();
    _scrollCtrl.dispose();

    _passwordCtrl.dispose();
    _clientCtrl.dispose();
    _keywordCtrl.dispose();

    super.dispose();
  }

  // ----------------- Helpers -----------------

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _goHome() async {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, HomeAfterAuthScreen.routeName);
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
                            if (mounted)
                              _snack("Mot de passe admin réinitialisé");
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

  Future<void> _openKioskKeyboard({
    required TextEditingController ctrl,
    required VoidCallback onValidate,
    String title = "Saisie",
  }) async {
    if (!mounted) return;

    // Ferme l’ancien clavier s’il est déjà ouvert
    _kbdSheet?.close();
    _kbdSheet = null;

    final scaffoldState = _scaffoldKey.currentState;
    if (scaffoldState == null) return;

    setState(() => _kbdOpen = true);

    _kbdSheet = scaffoldState.showBottomSheet(
      (ctx) {
        return SizedBox(
          width: MediaQuery.sizeOf(ctx).width,
          child: KioskKeyboard(
            title: title,
            controller: ctrl,
            onValidate: () {
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

    _kbdSheet!.closed.whenComplete(() {
      _kbdSheet = null;
      if (mounted) {
        setState(() => _kbdOpen = false);
        _hid.ensureFocus();
      }
    });
  }

  // ----------------- UI -----------------

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
                controller: _scrollCtrl,
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
                    OutlinedCard(
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
                                await _openKioskKeyboard(
                                  ctrl: _passwordCtrl,
                                  title: "Mot de passe admin",
                                  onValidate: () => _auth.submitAdminPassword(
                                    _passwordCtrl.text,
                                  ),
                                );
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
                          PrimaryButton(
                            label: _submitting ? "Validation..." : "Valider",
                            onTap: _submitting
                                ? () {}
                                : () => _auth.submitAdminPassword(
                                      _passwordCtrl.text,
                                    ),
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

    // 3) Identification client
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
                    // ✅ Récepteur HID invisible (toujours présent)
                    _hid.buildHiddenField(),

                    const SizedBox(height: 3),

                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _onAdminSecretTap,
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

                    // Card 1: Scan QR HID
                    InkCard(
                      onTap: () {
                        setState(() => _showScanAnimation = true);
                        _hid.start();
                      },
                      child: SoftCard(
                        background: cardGrey,
                        borderColor: Colors.transparent,
                        child: Row(
                          children: [
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

                    // Card 2: Num client
                    OutlinedCard(
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
                                      _auth.searchByClient(_clientCtrl.text),
                                );
                              },
                              child: AbsorbPointer(
                                child: RoundedField(
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
                          PrimaryButton(
                            label: _submitting ? "Chargement..." : "Valider",
                            onTap: _submitting
                                ? () {}
                                : () => _auth.searchByClient(_clientCtrl.text),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Card 3: Num commande
                    OutlinedCard(
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
                                  onValidate: () => _auth.searchByKeyword(
                                    _keywordCtrl.text,
                                  ),
                                );
                              },
                              child: AbsorbPointer(
                                child: RoundedField(
                                  controller: _keywordCtrl,
                                  hint: "PM204515",
                                  fill: lightGrey,
                                  readOnly: true,
                                  inputFormatters: uppercaseAlphaNumFormatters,
                                  onSubmitted: (_) {},
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: _submitting ? "Chargement..." : "Valider",
                            onTap: _submitting
                                ? () {}
                                : () => _auth.searchByKeyword(
                                      _keywordCtrl.text,
                                    ),
                          ),
                        ],
                      ),
                    ),

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
