import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// One decoded ASN.1 DER tag-length-value element: [tag] is the raw tag
/// byte, content spans [contentStart, contentEnd) in the original buffer,
/// and [totalStart] is where the tag byte itself began (needed to re-slice
/// the whole TLV, not just its content, further down).
class _DerElement {
  _DerElement({required this.tag, required this.totalStart, required this.contentStart, required this.contentEnd});

  final int tag;
  final int totalStart;
  final int contentStart;
  final int contentEnd;
}

/// Reads one DER tag-length-value starting at [offset]. Supports both
/// short-form and long-form lengths (definite-length only — X.509
/// certificates never use BER's indefinite-length encoding). Returns null
/// on any malformed/truncated input instead of throwing, so callers can
/// treat "not a valid certificate" as a plain failure.
_DerElement? _readTlv(Uint8List data, int offset) {
  if (offset < 0 || offset >= data.length) return null;
  final tag = data[offset];
  var pos = offset + 1;
  if (pos >= data.length) return null;

  final lengthByte = data[pos];
  pos++;
  int length;
  if (lengthByte & 0x80 == 0) {
    length = lengthByte;
  } else {
    final numLengthBytes = lengthByte & 0x7F;
    if (numLengthBytes == 0 || pos + numLengthBytes > data.length) return null;
    length = 0;
    for (var i = 0; i < numLengthBytes; i++) {
      length = (length << 8) | data[pos + i];
    }
    pos += numLengthBytes;
  }

  final contentStart = pos;
  final contentEnd = contentStart + length;
  if (length < 0 || contentEnd > data.length) return null;
  return _DerElement(tag: tag, totalStart: offset, contentStart: contentStart, contentEnd: contentEnd);
}

const _sequenceTag = 0x30;
// Context-specific, constructed, tag number 0 — the [0] EXPLICIT wrapper
// around TBSCertificate's optional `version` field.
const _explicitVersionTag = 0xA0;

/// Extracts the SubjectPublicKeyInfo (SPKI) from a DER-encoded X.509
/// certificate and returns its SHA-256 hash, base64-encoded — the standard
/// "pin-sha256" pinning value (same thing `openssl x509 -pubkey | openssl
/// pkey -pubin -outform DER | openssl dgst -sha256 -binary | base64`
/// computes, and what curl's `--pinnedpubkey` / HPKP historically used).
///
/// Walks just enough of the fixed X.509 structure to reach
/// `tbsCertificate.subjectPublicKeyInfo` — not a general ASN.1/ BER parser,
/// deliberately scoped to what a well-formed leaf certificate always
/// contains:
/// ```
/// Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signatureValue }
/// TBSCertificate ::= SEQUENCE {
///   version [0] EXPLICIT Version DEFAULT v1,  -- optional
///   serialNumber, signature, issuer, validity, subject,
///   subjectPublicKeyInfo SubjectPublicKeyInfo, ...
/// }
/// ```
/// Returns null (never throws) on anything that doesn't match this shape.
String? spkiSha256Base64FromDer(Uint8List certDer) {
  try {
    final certificate = _readTlv(certDer, 0);
    if (certificate == null || certificate.tag != _sequenceTag) return null;

    final tbsCertificate = _readTlv(certDer, certificate.contentStart);
    if (tbsCertificate == null || tbsCertificate.tag != _sequenceTag) return null;

    var element = _readTlv(certDer, tbsCertificate.contentStart);
    if (element == null) return null;
    if (element.tag == _explicitVersionTag) {
      // Optional `version` field present — skip it, next is serialNumber.
      element = _readTlv(certDer, element.contentEnd);
      if (element == null) return null;
    }

    // element is now serialNumber. Skip it plus the next three fixed
    // fields (signature, issuer, validity) to land on `subject`, then read
    // one more to reach subjectPublicKeyInfo.
    var pos = element.contentEnd;
    for (var i = 0; i < 4; i++) {
      element = _readTlv(certDer, pos);
      if (element == null) return null;
      pos = element.contentEnd;
    }

    final spki = _readTlv(certDer, pos);
    if (spki == null || spki.tag != _sequenceTag) return null;

    final spkiBytes = certDer.sublist(spki.totalStart, spki.contentEnd);
    final hash = sha256.convert(spkiBytes).bytes;
    return base64.encode(hash);
  } catch (_) {
    return null;
  }
}
