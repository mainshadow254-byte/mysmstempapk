import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';
import 'inbox_screen.dart';
import 'models.dart';
import 'storage_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService api = ApiService();
  final StorageService storage = StorageService();
  List<TempAddress> addresses = [];
  bool loading = true;
  bool creating = false;
  bool checkedForUpdates = false;
  int selectedDays = 1;

  @override
  void initState() {
    super.initState();
    loadAddresses();
  }

  Future<void> loadAddresses() async {
    final saved = await storage.getSavedAddresses();
    setState(() {
      addresses = saved;
      loading = false;
    });

    if (!checkedForUpdates) {
      checkedForUpdates = true;
      await checkForUpdates();
    }
  }

  Future<void> checkForUpdates() async {
    try {
      final update = await api.getAppUpdateInfo();
      final packageInfo = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (!mounted ||
          update.apkUrl.isEmpty ||
          update.latestVersionCode <= currentCode) {
        return;
      }

      showUpdateDialog(update);
    } catch (_) {
      // Update checks should never block the inbox when the user is offline.
    }
  }

  Future<void> openUpdate(AppUpdateInfo update) async {
    final uri = Uri.parse(update.apkUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      showSnack("Could not open update link");
    }
  }

  void showUpdateDialog(AppUpdateInfo update) {
    showDialog<void>(
      context: context,
      barrierDismissible: !update.required,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            "Update ${update.latestVersionName} available",
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            update.message,
            style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.35),
          ),
          actions: [
            if (!update.required)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Later"),
              ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                openUpdate(update);
              },
              icon: const Icon(Icons.system_update_alt_rounded),
              label: const Text("Update"),
            ),
          ],
        );
      },
    );
  }

  Future<void> createAddress() async {
    setState(() => creating = true);
    try {
      final address = await api.createTempAddress(selectedDays);
      await storage.saveAddress(address);
      await loadAddresses();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => InboxScreen(address: address)),
      ).then((_) => loadAddresses());
    } catch (e) {
      showSnack("Failed to create email: ${e.toString()}");
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  void copyEmail(String email) {
    Clipboard.setData(ClipboardData(text: email));
    showSnack("Email copied");
  }

  void showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String formatDate(DateTime date) {
    return DateFormat('MMM d • h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: loadAddresses,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    buildHeader(),
                    const SizedBox(height: 22),
                    buildCreateCard(),
                    const SizedBox(height: 26),
                    buildStatsRow(),
                    const SizedBox(height: 26),
                    buildSectionTitle("Recent temp emails"),
                    const SizedBox(height: 12),
                    if (addresses.isEmpty)
                      buildEmptyState()
                    else
                      ...addresses.map(buildAddressCard),
                  ],
                ),
              ),
      ),
    );
  }

  Widget buildHeader() {
    return Row(
      children: [
        Container(
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.shield_moon_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "ShadowTempMail",
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF8FAFC),
                ),
              ),
              SizedBox(height: 3),
              Text(
                "Secure disposable inboxes",
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildCreateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
            blurRadius: 35,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Generate shadow email",
            style: TextStyle(
              fontSize: 21,
              color: Color(0xFFF8FAFC),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            "Choose expiry duration and create a private temporary inbox.",
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF020617),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedDays,
                isExpanded: true,
                dropdownColor: const Color(0xFF0F172A),
                items: const [
                  DropdownMenuItem(value: 1, child: Text("1 day")),
                  DropdownMenuItem(value: 3, child: Text("3 days")),
                  DropdownMenuItem(value: 7, child: Text("7 days")),
                  DropdownMenuItem(value: 14, child: Text("14 days")),
                  DropdownMenuItem(value: 30, child: Text("30 days")),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => selectedDays = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: creating ? null : createAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: creating
                  ? const SizedBox(
                      height: 23,
                      width: 23,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Create Temp Email",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatsRow() {
    final active = addresses.where((a) => !a.isExpired).length;
    final expired = addresses.where((a) => a.isExpired).length;
    return Row(
      children: [
        Expanded(child: statCard("Active", "$active", Icons.bolt_rounded)),
        const SizedBox(width: 12),
        Expanded(child: statCard("Expired", "$expired", Icons.timer_off)),
      ],
    );
  }

  Widget statCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF06B6D4)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Color(0xFFF8FAFC),
                ),
              ),
              Text(
                title,
                style: const TextStyle(color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: Color(0xFFF8FAFC),
      ),
    );
  }

  Widget buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 50,
            color: Color(0xFF64748B),
          ),
          SizedBox(height: 12),
          Text(
            "No temp emails yet",
            style: TextStyle(
              color: Color(0xFFF8FAFC),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 5),
          Text(
            "Generate your first ShadowTempMail inbox.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget buildAddressCard(TempAddress address) {
    final expired = address.isExpired;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => InboxScreen(address: address)),
        ).then((_) => loadAddresses());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: expired ? const Color(0xFF7F1D1D) : const Color(0xFF1E293B),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color:
                    expired ? const Color(0xFF450A0A) : const Color(0xFF172554),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                expired ? Icons.timer_off_rounded : Icons.alternate_email,
                color:
                    expired ? const Color(0xFFF87171) : const Color(0xFF60A5FA),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expired
                        ? "Expired • tap to reuse"
                        : "Expires ${formatDate(address.expiresAt)}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: expired
                          ? const Color(0xFFF87171)
                          : const Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => copyEmail(address.email),
              icon: const Icon(
                Icons.copy_rounded,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
