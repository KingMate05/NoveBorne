import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:nove_console_article/class/emplacement_history.dart';

class EmplacementHistoryFArticlesWidget extends HookWidget {
  final EmplacementHistory emplacementHistory;
  final void Function(String value, [bool force]) onScan;

  const EmplacementHistoryFArticlesWidget(
      {super.key, required this.emplacementHistory, required this.onScan});

  @override
  Widget build(BuildContext context) {
    var date = DateTime.parse(emplacementHistory.c);
    date = date.add(const Duration(hours: -4));
    var formatter = DateFormat('yyyy-MM-dd HH:mm');
    var dateString = formatter.format(date);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 50,
              ),
              child: emplacementHistory.fArticle.images == null
                  ? const SizedBox.shrink()
                  : Image.network(
                      'https://api.nove.fr/DATA/fArticle/images/${emplacementHistory.fArticle.arRef}/sizes/${emplacementHistory.fArticle.images}',
                      errorBuilder: (BuildContext context, Object exception,
                          StackTrace? stackTrace) {
                      return const Text('Image could not be loaded');
                    }),
            ),
            Text(emplacementHistory.o ?? 'null'),
            const Icon(Icons.arrow_right_alt),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(emplacementHistory.n),
            ),
            Text(dateString),
          ],
        ),
      ),
      subtitle: Text(emplacementHistory.fArticle.arDesign),
      onTap: () {
        var search = emplacementHistory.fArticle.arCodebarre ?? '';
        if (search == '') {
          search = emplacementHistory.fArticle.constructeurRef;
        }
        if (search == '') {
          search = emplacementHistory.fArticle.arRef;
        }
        onScan(search);
      },
    );
  }
}
