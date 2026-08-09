abstract final class DatabaseVersions {
  static const databaseSchema = 1;
  static const searchTextSchema = 1;
  static const embeddingSchema = 1;

  static const databaseSchemaKey = 'database_schema_version';
  static const searchTextSchemaKey = 'search_text_schema_version';
  static const embeddingSchemaKey = 'embedding_schema_version';
}
