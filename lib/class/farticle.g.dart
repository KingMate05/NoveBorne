// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'farticle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FArticle _$FArticleFromJson(Map<String, dynamic> json) => FArticle(
      arRef: json['arRef'] as String,
      arDesign: json['arDesign'] as String,
      images: json['images'] as String?,
      constructeurRef: json['constructeurRef'] as String,
      arCodebarre: json['arCodebarre'] as String?,
      asQtesto: json['asQtesto'] as int,
      asQteprepa: json['asQteprepa'] as int,
      asQteres: json['asQteres'] as int,
      asQtecom: json['asQtecom'] as int,
      dpCode: json['dpCode'] as String?,
      dpNo: json['dpNo'] as String?,
      driverId: json['driverId'] as String?,
      driverImage: json['driverImage'] as String?,
      driverName: json['driverName'] as String?,
      fArtstockCbMarq: json['fArtstockCbMarq'] as String?,
      emplacementHistories: (json['emplacementHistories'] as List<dynamic>)
          .map((e) =>
              EmplacementHistoryFArticle.fromJson(e as Map<String, dynamic>))
          .toList(),
      surstock: json['surstock'] as String?,
    );

Map<String, dynamic> _$FArticleToJson(FArticle instance) => <String, dynamic>{
      'arRef': instance.arRef,
      'arDesign': instance.arDesign,
      'images': instance.images,
      'constructeurRef': instance.constructeurRef,
      'arCodebarre': instance.arCodebarre,
      'asQtesto': instance.asQtesto,
      'asQteprepa': instance.asQteprepa,
      'asQteres': instance.asQteres,
      'asQtecom': instance.asQtecom,
      'fArtstockCbMarq': instance.fArtstockCbMarq,
      'dpCode': instance.dpCode,
      'dpNo': instance.dpNo,
      'driverId': instance.driverId,
      'driverImage': instance.driverImage,
      'driverName': instance.driverName,
      'emplacementHistories': instance.emplacementHistories,
      'surstock': instance.surstock,
    };
