import 'dart:io';

Future<String> loadFixture(String relativePath) =>
    File('test/fixtures/$relativePath').readAsString();
