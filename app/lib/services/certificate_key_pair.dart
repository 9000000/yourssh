import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:dartssh2/src/ssh_hostkey.dart';

class CertificateKeyPair implements SSHKeyPair {
  final SSHKeyPair _inner;
  final Uint8List _certBytes;

  CertificateKeyPair(this._inner, this._certBytes);

  static Future<CertificateKeyPair> load({
    required String keyPath,
    required String certPath,
    String? passphrase,
  }) async {
    final pem = await File(keyPath).readAsString();
    final inner = SSHKeyPair.fromPem(pem, passphrase ?? '').first;

    final certLine = await File(certPath).readAsString();
    final parts = certLine.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      throw FormatException('Invalid cert file (expected "algo base64 [comment]"): $certPath');
    }
    final certBytes = base64.decode(parts[1]);
    return CertificateKeyPair(inner, certBytes);
  }

  @override
  String get name => type;

  @override
  String get type {
    if (_certBytes.length < 4) throw FormatException('Cert blob too short');
    final nameLen = ByteData.view(
      _certBytes.buffer, _certBytes.offsetInBytes, 4,
    ).getUint32(0, Endian.big);
    if (_certBytes.length < 4 + nameLen) {
      throw FormatException('Cert blob truncated');
    }
    return utf8.decode(_certBytes.sublist(4, 4 + nameLen));
  }

  @override
  SSHHostKey toPublicKey() => _RawBlobHostKey(_certBytes);

  @override
  SSHSignature sign(Uint8List data) => _inner.sign(data);

  // ignore: override_on_non_overriding_member
  Future<SSHSignature> signAsync(Uint8List data) async => _inner.sign(data);

  @override
  String toPem() => throw UnsupportedError('CertificateKeyPair cannot be serialized to PEM');
}

class _RawBlobHostKey implements SSHHostKey {
  final Uint8List _bytes;
  const _RawBlobHostKey(this._bytes);

  @override
  Uint8List encode() => _bytes;
}
