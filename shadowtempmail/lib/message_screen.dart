import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'models.dart';

class MessageScreen extends StatefulWidget {
  final String messageId;
  final String token;

  const MessageScreen({
    super.key,
    required this.messageId,
    required this.token,
  });

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final ApiService api = ApiService();
  bool loading = true;
  MailMessage? message;

  @override
  void initState() {
    super.initState();
    loadMessage();
  }

  Future<void> loadMessage() async {
    try {
      final data = await api.getMessage(widget.messageId, widget.token);
      setState(() => message = data);
    } catch (e) {
      showSnack("Could not open message");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showSnack("Copied");
  }

  void showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String date(DateTime d) {
    return DateFormat('MMM d, yyyy • h:mm a').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final msg = message;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Message",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : msg == null
              ? const Center(child: Text("Message not found"))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    buildSubjectCard(msg),
                    const SizedBox(height: 16),
                    if (msg.code != null) buildCodeCard(msg.code!),
                    if (msg.code != null) const SizedBox(height: 16),
                    buildBodyCard(msg),
                  ],
                ),
    );
  }

  Widget buildSubjectCard(MailMessage msg) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msg.subject,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 16),
          infoRow("From", msg.fromEmail),
          infoRow("To", msg.toEmail),
          infoRow("Date", date(msg.receivedAt)),
        ],
      ),
    );
  }

  Widget buildCodeCard(String code) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF052E2B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF0F766E)),
      ),
      child: Row(
        children: [
          const Icon(Icons.password_rounded, color: Color(0xFF5EEAD4)),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              code,
              style: const TextStyle(
                color: Color(0xFFCCFBF1),
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          IconButton(
            onPressed: () => copyText(code),
            icon: const Icon(
              Icons.copy_rounded,
              color: Color(0xFF5EEAD4),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBodyCard(MailMessage msg) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: SelectableText(
        msg.textBody.isNotEmpty
            ? msg.textBody
            : "No plain text body available.",
        style: const TextStyle(
          height: 1.45,
          color: Color(0xFFCBD5E1),
          fontSize: 15,
        ),
      ),
    );
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
