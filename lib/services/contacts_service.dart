import 'dart:convert';
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

/// A tiny in-app phonebook, replacing the `Contacts.txt` +
/// `PhoneNumer.py` telephone-dictionary feature from the desktop app.
class ContactsService {
  static const _key = 'jarvis_contacts';

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
    final contacts = await all();
    for (final c in contacts) {
      if (c.name.toLowerCase().contains(name.toLowerCase())) return c;
    }
    return null;
  }
}
