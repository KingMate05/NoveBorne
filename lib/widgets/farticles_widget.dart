import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nove_console_article/class/farticle.dart';

class FArticlesWidget extends HookWidget {
  final List<FArticle> fArticles;
  final void Function(String value, [bool force]) onScan;

  const FArticlesWidget(
      {super.key, required this.fArticles, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: fArticles.length,
      itemBuilder: (context, index) {
        final item = fArticles[index];
        return Container(
          color: item.asQtesto > 0 ? null : Colors.grey,
          child: ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.arRef),
                Text(item.dpCode ?? ""),
                Text("S.réel: ${item.asQtesto}"),
              ],
            ),
            subtitle: Row(
              children: [
                if (item.images != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 50,
                    ),
                    child: Image.network(
                        'https://api.nove.fr/DATA/fArticle/images/${item.arRef}/sizes/${item.images}',
                        errorBuilder: (BuildContext context, Object exception,
                            StackTrace? stackTrace) {
                      return const Text('Image could not be loaded');
                    }),
                  ),
                Flexible(child: Text(item.arDesign)),
              ],
            ),
            onTap: () {
              var search = item.arCodebarre ?? '';
              if (search == '') {
                search = item.constructeurRef;
              }
              if (search == '') {
                search = item.arRef;
              }
              onScan(search);
            },
          ),
        );
      },
    );
  }
}
