enum GmailEnvelopeEncoding {
  gzipBase64,
  base64Only,
  plainJson,
}

extension GmailEnvelopeEncodingExt on GmailEnvelopeEncoding {
  static GmailEnvelopeEncoding fromStorage(String? value) {
    switch (value) {
      case 'base64':
        return GmailEnvelopeEncoding.base64Only;
      case 'plain':
        return GmailEnvelopeEncoding.plainJson;
      case 'gzip':
        return GmailEnvelopeEncoding.gzipBase64;
    }
    return GmailEnvelopeEncoding.gzipBase64;
  }

  String get storageValue {
    switch (this) {
      case GmailEnvelopeEncoding.base64Only:
        return 'base64';
      case GmailEnvelopeEncoding.plainJson:
        return 'plain';
      case GmailEnvelopeEncoding.gzipBase64:
        return 'gzip';
    }
  }

  String get headerValue {
    switch (this) {
      case GmailEnvelopeEncoding.base64Only:
        return 'base64';
      case GmailEnvelopeEncoding.plainJson:
        return 'plain';
      case GmailEnvelopeEncoding.gzipBase64:
        return 'gzip';
    }
  }

  static GmailEnvelopeEncoding fromHeader(String? value) {
    if (value == null) {
      return GmailEnvelopeEncoding.gzipBase64;
    }
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'base64':
        return GmailEnvelopeEncoding.base64Only;
      case 'plain':
        return GmailEnvelopeEncoding.plainJson;
      case 'gzip':
        return GmailEnvelopeEncoding.gzipBase64;
    }
    return GmailEnvelopeEncoding.gzipBase64;
  }
}

enum SyncTransportMode {
  gmailOnly,
  directOnly,
  auto,
}

extension SyncTransportModeExt on SyncTransportMode {
  static SyncTransportMode fromStorage(String? value) {
    switch (value) {
      case 'direct':
        return SyncTransportMode.directOnly;
      case 'auto':
        return SyncTransportMode.auto;
      case 'gmail':
        return SyncTransportMode.gmailOnly;
    }
    return SyncTransportMode.gmailOnly;
  }

  String get storageValue {
    switch (this) {
      case SyncTransportMode.directOnly:
        return 'direct';
      case SyncTransportMode.auto:
        return 'auto';
      case SyncTransportMode.gmailOnly:
        return 'gmail';
    }
  }
}
