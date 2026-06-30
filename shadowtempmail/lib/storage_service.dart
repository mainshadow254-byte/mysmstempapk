import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class StorageService {
  static const String addressesKey = "shadow_saved_temp_addresses";
  static const String activeTokenKey = "shadow_active_access_token";

  Future<List<TempAddress>> getSavedAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(addressesKey);
    if (raw == null || raw.isEmpty) return [];
    final List list = jsonDecode(raw);
    return list.map((e) => TempAddress.fromJson(e)).toList();
  }

  Future<void> saveAddress(TempAddress address) async {
    final addresses = await getSavedAddresses();
    addresses.removeWhere((a) => a.id == address.id);
    addresses.insert(0, address);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      addressesKey,
      jsonEncode(addresses.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(activeTokenKey, address.accessToken);
  }

  Future<void> deleteAddress(String id) async {
    final addresses = await getSavedAddresses();
    addresses.removeWhere((a) => a.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      addressesKey,
      jsonEncode(addresses.map((e) => e.toJson()).toList()),
    );
  }

  Future<String?> getActiveToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(activeTokenKey);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(addressesKey);
    await prefs.remove(activeTokenKey);
  }
}
