import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_contacts/flutter_contacts.dart' as device;
import 'package:shared_preferences/shared_preferences.dart';

class Contact {
  final String name;
  final String phone;
  final String email;

  Contact({required this.name, required this.phone, this.email = ''});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'email': email};

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        name: json['name'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String? ?? '',
      );
}

/// Looks up contacts from the phone's real address book (so JARVIS can call
/// or message anyone in it without the user re-typing every name/number
/// into the app), falling back to a small in-app list for entries not in
/// the phone's contacts (or on platforms without one, e.g. web).
class ContactsService {
  static const _key = 'jarvis_contacts';

  Future<bool> hasDeviceAccess() async {
    if (kIsWeb) return false;
    return device.FlutterContacts.requestPermission(readonly: true);
  }

  Future<List<Contact>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Contact.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _save(List<Contact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(contacts.map((c) => c.toJson()).toList()));
  }

  Future<void> add(Contact contact) async {
    final contacts = await all();
    contacts.removeWhere((c) => c.name.toLowerCase() == contact.name.toLowerCase());
    contacts.add(contact);
    await _save(contacts);
  }

  Future<void> remove(String name) async {
    final contacts = await all();
    contacts.removeWhere((c) => c.name.toLowerCase() == name.toLowerCase());
    await _save(contacts);
  }

  Future<Contact?> find(String name) async {
    final fromDevice = await _findOnDevice(name);
    if (fromDevice != null) return fromDevice;

    final contacts = await all();
    for (final c in contacts) {
      if (c.name.toLowerCase().contains(name.toLowerCase())) return c;
    }
    return null;
  }

  Future<Contact?> _findOnDevice(String name) async {
    if (kIsWeb) return null;
    try {
      if (!await device.FlutterContacts.requestPermission(readonly: true)) return null;
      final lower = name.toLowerCase();
      final all = await device.FlutterContacts.getContacts(withProperties: true);
      for (final c in all) {
        if (!c.displayName.toLowerCase().contains(lower)) continue;
        final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
        if (phone.isEmpty) continue;
        final email = c.emails.isNotEmpty ? c.emails.first.address : '';
        return Contact(name: c.displayName, phone: phone, email: email);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
