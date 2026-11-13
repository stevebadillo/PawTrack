import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/data_service.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado al portapapeles'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(66),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Icon(Icons.chevron_left_rounded,
                          color: Color(0xFF0F2B48), size: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Contactos',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F2B48),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D3B73),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.pets, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Contact>>(
        stream: DataService.contacts(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final contacts = snap.data ?? [];
          if (contacts.isEmpty) {
            return const Center(
              child: Text(
                'No hay contactos registrados aún.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            );
          }

          // Find the email-type contact (first one with an email)
          final emailContact = contacts.firstWhere(
            (c) => c.email.isNotEmpty,
            orElse: () => contacts.first,
          );

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // ── Email card at top ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contacto por correo electrónico',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0B2545),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Informa a los responsables de las mascotas',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () =>
                          _copy(context, emailContact.email, 'Correo'),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined,
                              size: 16, color: Color(0xFF0D3B73)),
                          const SizedBox(width: 8),
                          Text(
                            emailContact.email.isNotEmpty
                                ? emailContact.email
                                : 'alertas@universidad.edu.ec',
                            style: const TextStyle(
                              color: Color(0xFF0D3B73),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Phone cards ──
              for (final c in contacts)
                if (c.phone.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF0B2545),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () =>
                              _copy(context, c.phone, 'Teléfono'),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_outlined,
                                  size: 16, color: Color(0xFF0D3B73)),
                              const SizedBox(width: 8),
                              Text(
                                c.phone,
                                style: const TextStyle(
                                  color: Color(0xFF0B2545),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
