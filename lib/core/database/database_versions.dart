abstract final class DatabaseVersions {
  static const databaseSchema = 3;
  static const searchTextSchema = 3;
  static const embeddingSchema = 3;

  static const databaseSchemaKey = 'database_schema_version';
  static const searchTextSchemaKey = 'search_text_schema_version';
  static const embeddingSchemaKey = 'embedding_schema_version';
}
