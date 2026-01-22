import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nove_console_article/class/emplacement.dart';
import 'package:nove_console_article/class/farticle.dart';
import 'package:nove_console_article/widgets/farticle_emplacement_history_widget.dart';
import 'package:nove_console_article/widgets/scan_reader.dart';

class NewEmplacementWidget extends HookWidget {
  final FArticle fArticle;
  final Emplacement? newEmplacement;
  final void Function(String? value) onChangeEmplacement;
  final bool surStock;

  const NewEmplacementWidget({
    super.key,
    required this.fArticle,
    required this.newEmplacement,
    required this.onChangeEmplacement,
    required this.surStock,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text((surStock ? (fArticle.surstock) : (fArticle.dpCode)) ?? "",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const Icon(Icons.arrow_right_alt),
            Text(newEmplacement!.dpCode,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: () {
                onChangeEmplacement(null);
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                onChangeEmplacement(newEmplacement!.dpCode);
              },
              child: const Text('Valider'),
            ),
          ],
        )
      ],
    );
  }
}
