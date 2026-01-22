import 'package:json_annotation/json_annotation.dart';
import 'package:nove_console_article/class/emplacement_history_farticle.dart';

part 'farticle.g.dart';

@JsonSerializable()
class FArticle {
  String arRef;
  String arDesign;
  String? images;
  String constructeurRef;
  String? arCodebarre;
  int asQtesto;
  int asQteprepa;
  int asQteres;
  int asQtecom;
  String? fArtstockCbMarq;
  String? dpCode;
  String? dpNo;
  String? driverId;
  String? driverImage;
  String? driverName;
  List<EmplacementHistoryFArticle> emplacementHistories;
  String? surstock;

  FArticle({
    required this.arRef,
    required this.arDesign,
    required this.images,
    required this.constructeurRef,
    required this.arCodebarre,
    required this.asQtesto,
    required this.asQteprepa,
    required this.asQteres,
    required this.asQtecom,
    required this.dpCode,
    required this.dpNo,
    required this.driverId,
    required this.driverImage,
    required this.driverName,
    required this.fArtstockCbMarq,
    required this.emplacementHistories,
    required this.surstock,
  });

  factory FArticle.fromJson(Map<String, dynamic> json) =>
      _$FArticleFromJson(json);

  Map<String, dynamic> toJson() => _$FArticleToJson(this);
}
