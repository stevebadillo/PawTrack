import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/data_service.dart';

class ContactsScreen extends StatelessWidget {
  final AppUser user;

  const ContactsScreen({super.key, required this.user});

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiado al portapapeles'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Modal para Crear o Editar un contacto (Solo Personal)
  void _showContactForm(
    BuildContext context, {
    Contact? contact,
  }) {
    final isEditing = contact != null;
    final nameCtrl = TextEditingController(text: contact?.name ?? '');
    final roleCtrl = TextEditingController(text: contact?.role ?? '');
    final phoneCtrl = TextEditingController(text: contact?.phone ?? '');
    final emailCtrl = TextEditingController(text: contact?.email ?? '');
    final descCtrl = TextEditingController(text: contact?.description ?? '');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Editar contacto' : 'Nuevo contacto',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0B2545),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre o Entidad *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: roleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Rol o Subtítulo (opcional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Teléfono (opcional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico (opcional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Descripción (opcional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D3B73),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('El nombre es obligatorio.'),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => saving = true);
                                try {
                                  final data = {
                                    'name': name,
                                    'role': roleCtrl.text.trim(),
                                    'phone': phoneCtrl.text.trim(),
                                    'email': emailCtrl.text.trim(),
                                    'description': descCtrl.text.trim(),
                                  };

                                  if (isEditing) {
                                    // Usamos set con merge para crear el documento si viene de los por defecto (ej. 'c1')
                                    final docRef = FirebaseFirestore.instance
                                        .collection('contactos')
                                        .doc(contact.id.isNotEmpty && !contact.id.startsWith('c')
                                            ? contact.id
                                            : null);
                                    
                                    if (contact.id.isNotEmpty && !contact.id.startsWith('c')) {
                                      await docRef.update(data);
                                    } else {
                                      await FirebaseFirestore.instance
                                          .collection('contactos')
                                          .doc(contact.id.startsWith('c') ? contact.id : null)
                                          .set(data, SetOptions(merge: true));
                                    }
                                  } else {
                                    await FirebaseFirestore.instance
                                        .collection('contactos')
                                        .add(data);
                                  }

                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isEditing
                                            ? 'Contacto actualizado correctamente.'
                                            : 'Contacto creado correctamente.'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => saving = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('Error al guardar: $e')),
                                    );
                                  }
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditing ? 'Guardar cambios' : 'Crear contacto',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Diálogo para confirmar la eliminación
  Future<void> _confirmDelete(
      BuildContext context, Contact contact) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar contacto'),
        content: Text('¿Seguro que deseas eliminar a "${contact.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (!contact.id.startsWith('c')) {
          await FirebaseFirestore.instance
              .collection('contactos')
              .doc(contact.id)
              .delete();
        } else {
          // Si es un contacto por defecto que aún no se guardó en Firestore, solo lo filtramos visualmente o informamos
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este contacto predeterminado no se encuentra en Firestore para eliminar.')),
          );
          return;
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacto eliminado.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo eliminar: $e')),
          );
        }
      }
    }
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
                if (user.isStaff)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => _showContactForm(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D3B73),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.add_rounded,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ),
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

          final emailContact = contacts.firstWhere(
            (c) => c.email.isNotEmpty,
            orElse: () => contacts.first,
          );

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // ── Correo electrónico ──
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Contacto por correo electrónico',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF0B2545),
                          ),
                        ),
                        if (user.isStaff)
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.edit_outlined,
                                size: 18, color: Color(0xFF0D3B73)),
                            onPressed: () => _showContactForm(context,
                                contact: emailContact),
                          ),
                      ],
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
                          Expanded(
                            child: Text(
                              emailContact.email.isNotEmpty
                                  ? emailContact.email
                                  : 'alertas@universidad.edu.ec',
                              style: const TextStyle(
                                color: Color(0xFF0D3B73),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Teléfonos ──
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                c.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF0B2545),
                                ),
                              ),
                            ),
                            if (user.isStaff)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18, color: Color(0xFF0D3B73)),
                                    onPressed: () => _showContactForm(context,
                                        contact: c),
                                  ),
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.only(left: 6),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: Color(0xFFDC2626)),
                                    onPressed: () =>
                                       _confirmDelete(context, c),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (c.role.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            c.role,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _copy(context, c.phone, 'Teléfono'),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_outlined,
                                  size: 16, color: Color(0xFF0D3B73)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.phone,
                                  style: const TextStyle(
                                    color: Color(0xFF0B2545),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
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
