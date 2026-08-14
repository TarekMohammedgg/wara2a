abstract final class DatabaseVersions {
  static const databaseSchema = 4;
  static const searchTextSchema = 4;
  static const embeddingSchema = 4;

  static const databaseSchemaKey = 'database_schema_version';
  static const searchTextSchemaKey = 'search_text_schema_version';
  static const embeddingSchemaKey = 'embedding_schema_version';
}
