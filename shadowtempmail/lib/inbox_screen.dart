import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'message_screen.dart';
import 'models.dart';
import 'storage_service.dart';

class InboxScreen extends StatefulWidget {
  final TempAddress address;

  const InboxScreen({
    super.key,
    required this.address,
  });

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final ApiService api = ApiService();
  final StorageService storage = StorageService();
  late TempAddress address;
  List<MailMessage> messages = [];
  bool loading = true;
  bool extending = false;
  int extendDays = 7;

  @override
  void initState() {
    super.initState();
    address = widget.address;
    loadInbox();
  }

  Future<void> loadInbox() async {
    setState(() => loading = true);
    try {
      final data = await api.getInbox(address.id, address.accessToken);
      setState(() => messages = data);
    } catch (e) {
      showSnack("Could not load inbox");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> extendAddress() async {
    setState(() => extending = true);
    try {
      final updated = await api.extendAddress(
        address.id,
        address.accessToken,
        extendDays,
      );
      await storage.saveAddress(updated);
      setState(() {
        address = updated;
      });
      showSnack("Inbox reused for $extendDays days");
      await loadInbox();
    } catch (e) {
      showSnack("Could not reuse inbox");
    } finally {
      if (mounted) setState(() => extending = false);
    }
  }

  void copyEmail() {
    Clipboard.setData(ClipboardData(text: address.email));
    showSnack("Email copied");
  }

  void copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    showSnack("Code copied");
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
    return DateFormat('MMM d • h:mm a').format(d);
  }

  Future<void> openMessage(MailMessage message) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageScreen(
          messageId: message.id,
          token: address.accessToken,
        ),
      ),
    ).then((_) => loadInbox());
  }

  @override
  Widget build(BuildContext context) {
    final expired = address.isExpired;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Inbox",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadInbox,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            buildEmailCard(expired),
            const SizedBox(height: 18),
            if (expired) buildReuseCard(),
            if (expired) const SizedBox(height: 18),
            buildInboxHeader(),
            const SizedBox(height: 10),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (messages.isEmpty)
              buildEmptyMessages()
            else
              ...messages.map(buildMessageCard),
          ],
        ),
      ),
    );
  }

  Widget buildEmailCard(bool expired) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF172554)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            expired ? "Expired shadow inbox" : "Active shadow inbox",
            style: TextStyle(
              color:
                  expired ? const Color(0xFFF87171) : const Color(0xFF67E8F9),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            address.email,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: Text(
                  expired
                      ? "Reuse this address by extending it."
                      : "Expires ${date(address.expiresAt)}",
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                onPressed: copyEmail,
                icon: const Icon(
                  Icons.copy_rounded,
                  color: Color(0xFFF8FAFC),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildReuseCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF92400E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Reuse this temp email",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Color(0xFFFBBF24),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Reactivate this inbox and continue receiving messages.",
            style: TextStyle(color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: extendDays,
            dropdownColor: const Color(0xFF0F172A),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF020617),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text("1 day")),
              DropdownMenuItem(value: 3, child: Text("3 days")),
              DropdownMenuItem(value: 7, child: Text("7 days")),
              DropdownMenuItem(value: 14, child: Text("14 days")),
              DropdownMenuItem(value: 30, child: Text("30 days")),
            ],
            onChanged: (v) {
              if (v != null) setState(() => extendDays = v);
            },
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: extending ? null : extendAddress,
              child: extending
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.3),
                    )
                  : const Text(
                      "Reactivate Inbox",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInboxHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            "Recent messages",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Color(0xFFF8FAFC),
            ),
          ),
        ),
        IconButton(
          onPressed: loadInbox,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget buildEmptyMessages() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.mark_email_unread_rounded,
            size: 50,
            color: Color(0xFF64748B),
          ),
          SizedBox(height: 12),
          Text(
            "No messages yet",
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 5),
          Text(
            "Send an email to this address and pull to refresh.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget buildMessageCard(MailMessage message) {
    return GestureDetector(
      onTap: () => openMessage(message),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: message.isRead
                ? const Color(0xFF1E293B)
                : const Color(0xFF2563EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF172554),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                message.isRead
                    ? Icons.mail_outline_rounded
                    : Icons.mark_email_unread_rounded,
                color: const Color(0xFF60A5FA),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.fromEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                  if (message.code != null) ...[
                    const SizedBox(height: 7),
                    GestureDetector(
                      onTap: () => copyCode(message.code!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF064E3B),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          "Code: ${message.code}",
                          style: const TextStyle(
                            color: Color(0xFF6EE7B7),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              date(message.receivedAt),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
