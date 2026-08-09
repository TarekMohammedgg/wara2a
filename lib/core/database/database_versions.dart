abstract final class DatabaseVersions {
  static const databaseSchema = 2;
  static const searchTextSchema = 2;
  static const embeddingSchema = 2;

  static const databaseSchemaKey = 'database_schema_version';
  static const searchTextSchemaKey = 'search_text_schema_version';
  static const embeddingSchemaKey = 'embedding_schema_version';
}
