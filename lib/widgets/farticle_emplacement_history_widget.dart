import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:nove_console_article/class/emplacement_history_farticle.dart';

class FArticleEmplacementHistoriesWidget extends HookWidget {
  final EmplacementHistoryFArticle emplacementHistoryFArticle;

  const FArticleEmplacementHistoriesWidget(
      {super.key, required this.emplacementHistoryFArticle});

  @override
  Widget build(BuildContext context) {
    var date = DateTime.parse(emplacementHistoryFArticle.c);
    date = date.add(const Duration(hours: -4));
    var formatter = DateFormat('yyyy-MM-dd HH:mm');
    var dateString = formatter.format(date);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(emplacementHistoryFArticle.o),
                  const Icon(Icons.arrow_right_alt),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(emplacementHistoryFArticle.n),
                  ),
                ],
              ),
            ),
          ),
          Text(dateString),
        ],
      ),
    );
  }
}
