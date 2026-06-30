class TempAddress {
  final String id;
  final String email;
  final String accessToken;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? lastUsedAt;
  final bool isActive;
  final int messageCount;
  final DateTime? lastMessageAt;

  TempAddress({
    required this.id,
    required this.email,
    required this.accessToken,
    required this.createdAt,
    required this.expiresAt,
    this.lastUsedAt,
    this.isActive = true,
    this.messageCount = 0,
    this.lastMessageAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt) || !isActive;

  factory TempAddress.fromJson(Map<String, dynamic> json) {
    return TempAddress(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      accessToken: json['access_token'] ?? json['accessToken'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: DateTime.parse(json['expires_at']),
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'])
          : null,
      isActive: json['is_active'] ?? true,
      messageCount: json['message_count'] ?? 0,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "email": email,
      "access_token": accessToken,
      "created_at": createdAt.toIso8601String(),
      "expires_at": expiresAt.toIso8601String(),
      "last_used_at": lastUsedAt?.toIso8601String(),
      "is_active": isActive,
      "message_count": messageCount,
      "last_message_at": lastMessageAt?.toIso8601String(),
    };
  }
}

class MailMessage {
  final String id;
  final String fromEmail;
  final String toEmail;
  final String subject;
  final String textBody;
  final String? htmlBody;
  final DateTime receivedAt;
  final bool isRead;
  final String? code;

  MailMessage({
    required this.id,
    required this.fromEmail,
    required this.toEmail,
    required this.subject,
    required this.textBody,
    this.htmlBody,
    required this.receivedAt,
    required this.isRead,
    this.code,
  });

  factory MailMessage.fromJson(Map<String, dynamic> json) {
    return MailMessage(
      id: json['id'] ?? '',
      fromEmail: json['from_email'] ?? '',
      toEmail: json['to_email'] ?? '',
      subject: json['subject'] ?? '(No subject)',
      textBody: json['text_body'] ?? '',
      htmlBody: json['html_body'],
      receivedAt: DateTime.parse(json['received_at']),
      isRead: json['is_read'] ?? false,
      code: json['code'],
    );
  }
}
