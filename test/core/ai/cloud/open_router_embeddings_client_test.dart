import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/ai/cloud/open_router_embeddings_client.dart';
import 'package:wara2a/core/ai/embedding/open_router_embedding_artifact.dart';

void main() {
  test('parses OpenRouter embeddings payload into a 1536-d vector', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close(force: true));
    server.listen((request) async {
      expect(request.uri.path, '/embeddings');
      expect(request.headers.value('authorization'), 'Bearer test-key');
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      expect(body['model'], OpenRouterEmbeddingArtifact.modelId);
      expect(body['input'], 'query text');
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'model': OpenRouterEmbeddingArtifact.modelId,
          'data': [
            {
              'embedding': List<double>.generate(
                OpenRouterEmbeddingArtifact.dimensions,
                (index) => index == 0 ? 0.5 : 0.0,
              ),
            },
          ],
        }),
      );
      await request.response.close();
    });

    final client = OpenRouterEmbeddingsClient(
      apiKey: 'test-key',
      baseUrl: 'http://${server.address.host}:${server.port}/embeddings',
    );
    addTearDown(client.dispose);

    final result = await client.embed(
      const OpenRouterEmbeddingRequest(input: 'query text'),
    );
    expect(result.dimensions, 1536);
    expect(result.vector, hasLength(1536));
    expect(result.vector.first, 0.5);
    expect(result.modelId, OpenRouterEmbeddingArtifact.modelId);
  });
}
