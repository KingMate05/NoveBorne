import 'package:json_annotation/json_annotation.dart';

part 'emplacement.g.dart';

@JsonSerializable()
class Emplacement {
  String dpCode;
  int dpNo;

  Emplacement({
    required this.dpCode,
    required this.dpNo,
  });

  factory Emplacement.fromJson(Map<String, dynamic> json) =>
      _$EmplacementFromJson(json);

  Map<String, dynamic> toJson() => _$EmplacementToJson(this);
}
