import 'package:objectbox/objectbox.dart';

@Entity()
class DatabaseMetadataEntity {
  DatabaseMetadataEntity({
    this.id = 0,
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  @Id()
  int id;

  @Unique()
  String key;

  String value;

  @Property(type: PropertyType.date)
  DateTime updatedAt;
}
