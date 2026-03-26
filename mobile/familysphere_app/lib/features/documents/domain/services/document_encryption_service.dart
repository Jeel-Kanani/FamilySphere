import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DocumentEncryptionService {
  static const String _keyStorageName = 'offline_document_encryption_key_v1';
  static const String _magicHeader = 'FSDOC1';

  final FlutterSecureStorage _secureStorage;
  final AesGcm _algorithm;
  final Random _random;

  DocumentEncryptionService({
    FlutterSecureStorage? secureStorage,
    AesGcm? algorithm,
    Random? random,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _algorithm = algorithm ?? AesGcm.with256bits(),
        _random = random ?? Random.secure();

  Future<SecretKey> _loadOrCreateKey() async {
    final stored = await _secureStorage.read(key: _keyStorageName);
    if (stored != null && stored.isNotEmpty) {
      return SecretKey(base64Decode(stored));
    }

    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    await _secureStorage.write(
      key: _keyStorageName,
      value: base64Encode(bytes),
    );
    return SecretKey(bytes);
  }

  Future<List<int>> encrypt(List<int> plainBytes) async {
    final key = await _loadOrCreateKey();
    final nonce = List<int>.generate(12, (_) => _random.nextInt(256));
    final secretBox = await _algorithm.encrypt(
      plainBytes,
      secretKey: key,
      nonce: nonce,
    );

    return Uint8List.fromList([
      ...utf8.encode(_magicHeader),
      ...secretBox.nonce,
      ...secretBox.mac.bytes,
      ...secretBox.cipherText,
    ]);
  }

  Future<List<int>> decrypt(List<int> encryptedBytes) async {
    final headerBytes = utf8.encode(_magicHeader);
    if (encryptedBytes.length < headerBytes.length + 12 + 16) {
      throw Exception('Encrypted document is malformed.');
    }

    final header = encryptedBytes.sublist(0, headerBytes.length);
    if (!const ListEquality<int>().equals(header, headerBytes)) {
      throw Exception('Encrypted document header is invalid.');
    }

    final nonceStart = headerBytes.length;
    final macStart = nonceStart + 12;
    final cipherStart = macStart + 16;

    final secretBox = SecretBox(
      encryptedBytes.sublist(cipherStart),
      nonce: encryptedBytes.sublist(nonceStart, macStart),
      mac: Mac(encryptedBytes.sublist(macStart, cipherStart)),
    );

    final key = await _loadOrCreateKey();
    return _algorithm.decrypt(secretBox, secretKey: key);
  }
}

class ListEquality<T> {
  const ListEquality();

  bool equals(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }
}
