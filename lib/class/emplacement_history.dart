import 'package:json_annotation/json_annotation.dart';
import 'package:nove_console_article/class/farticle_emplacement_history.dart';

part 'emplacement_history.g.dart';

@JsonSerializable()
class EmplacementHistory {
  int id;
  String? o; // old emplacement
  String n; // new emplacement
  String c; // date of change
  String fArticleId;
  FArticleEmplacementHistory fArticle;

  EmplacementHistory({
    required this.id,
    required this.o,
    required this.n,
    required this.c,
    required this.fArticleId,
    required this.fArticle,
  });

  factory EmplacementHistory.fromJson(Map<String, dynamic> json) =>
      _$EmplacementHistoryFromJson(json);

  Map<String, dynamic> toJson() => _$EmplacementHistoryToJson(this);
}
