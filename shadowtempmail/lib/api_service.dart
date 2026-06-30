import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiService {
  static const String baseUrl = "https://your-railway-url.up.railway.app";

  Future<TempAddress> createTempAddress(int expiryDays) async {
    final res = await http.post(
      Uri.parse("$baseUrl/api/v1/address"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"expiryDays": expiryDays}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200 || data["success"] != true) {
      throw Exception(data["error"] ?? "Failed to create address");
    }
    return TempAddress.fromJson(data["address"]);
  }

  Future<List<MailMessage>> getInbox(String addressId, String token) async {
    final res = await http.get(
      Uri.parse("$baseUrl/api/v1/inbox/$addressId"),
      headers: {"x-access-token": token},
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200 || data["success"] != true) {
      throw Exception(data["error"] ?? "Failed to load inbox");
    }
    return (data["messages"] as List)
        .map((e) => MailMessage.fromJson(e))
        .toList();
  }

  Future<MailMessage> getMessage(String messageId, String token) async {
    final res = await http.get(
      Uri.parse("$baseUrl/api/v1/message/$messageId"),
      headers: {"x-access-token": token},
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200 || data["success"] != true) {
      throw Exception(data["error"] ?? "Failed to load message");
    }
    return MailMessage.fromJson(data["message"]);
  }

  Future<TempAddress> extendAddress(
    String addressId,
    String token,
    int expiryDays,
  ) async {
    final res = await http.patch(
      Uri.parse("$baseUrl/api/v1/address/$addressId/extend"),
      headers: {
        "Content-Type": "application/json",
        "x-access-token": token,
      },
      body: jsonEncode({"expiryDays": expiryDays}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200 || data["success"] != true) {
      throw Exception(data["error"] ?? "Failed to reuse address");
    }
    return TempAddress.fromJson(data["address"]);
  }

  Future<void> deleteAddress(String addressId, String token) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/api/v1/address/$addressId"),
      headers: {"x-access-token": token},
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200 || data["success"] != true) {
      throw Exception(data["error"] ?? "Failed to delete address");
    }
  }
}
