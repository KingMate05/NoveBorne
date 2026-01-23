import 'package:flutter/material.dart';
import 'identify_screen.dart';

class WelcomeScreen extends StatelessWidget {
  static const routeName = '/';

  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    const primaryOrange = Color(0xFFF36C21);
    final contentMaxWidth = size.width >= 600 ? 520.0 : size.width * 0.9;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/logoNove.png',
                      height: size.height * 0.32,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "Récupération de commande",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.55),
                        fontSize: size.width >= 600 ? 18 : 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: SizedBox(
                    width: double.infinity,
                    height: size.width >= 600 ? 68 : 58,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushReplacementNamed(
                          context, AuthScreen.routeName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryOrange,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: Colors.black.withOpacity(0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        'RÉCUPÉRER UNE COMMANDE',
                        style: TextStyle(
                          fontSize: size.width >= 600 ? 18 : 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
