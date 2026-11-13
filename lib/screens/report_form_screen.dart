import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/location_service.dart';

// ============================================================================
// PANTALLA DE CREACIÓN DE REPORTE (ReportFormScreen)
// Permite a estudiantes y personal reportar una incidencia canina adjuntando
// fotografía, estado del perro, tipo de incidencia, descripción y ubicación GPS.
// ============================================================================
class ReportFormScreen extends StatefulWidget {
  final AppUser user;
  const ReportFormScreen({super.key, required this.user});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _desc = TextEditingController();
  final MapController _mapController = MapController();

  Uint8List? _photo;
  Dog? _dog; // null = sin identificar
  double? _lat = -1.65595;
  double? _lng = -78.67508;
  bool _saving = false;
  String? _locError;

  // Opciones seleccionadas de estado del perro y tipo de incidencia
  String _dogStatus = 'herido'; // 'con_vida', 'herido', 'sin_vida', 'no_se'
  String _incidentType = 'perdido'; // 'perdido', 'agresivo', 'otro'

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    try {
      final p = await LocationService.current();
      if (!mounted) return;
      setState(() {
        _lat = p.latitude;
        _lng = p.longitude;
        _locError = null;
      });
      _mapController.move(LatLng(p.latitude, p.longitude), 16.5);
    } catch (e) {
      if (mounted) setState(() => _locError = e.toString());
    }
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(
        source: src,
        imageQuality: 55,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (x != null) {
        final bytes = await x.readAsBytes();
        if (mounted) setState(() => _photo = bytes);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo acceder a la cámara o galería.')),
        );
      }
    }
  }

  Future<void> _send() async {
    if (_desc.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor escribe una breve descripción de la incidencia.')),
      );
      return;
    }

    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor añade una foto o evidencia de la incidencia.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final photoB64 = base64Encode(_photo!);
      await DataService.addReport({
        'description': _desc.text.trim(),
        'photoUrl': '',
        'photoBase64': photoB64,
        'photos': [photoB64],
        'evidencias': [photoB64],
        'dogStatus': _dogStatus,
        'estadoPerro': _dogStatus,
        'incidentType': _incidentType,
        'tipoIncidencia': _incidentType,
        'lat': _lat ?? -1.65595,
        'lng': _lng ?? -78.67508,
        'dogId': _dog?.id,
        'dogName': _dog?.name,
        'reporterId': widget.user.uid,
        'reporterName': widget.user.name,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte enviado con éxito. ¡Muchas gracias!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar el reporte: $e')),
        );
      }
      if (mounted) setState(() => _saving = false);
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back button
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
                      child: Icon(Icons.chevron_left_rounded, color: Color(0xFF0F2B48), size: 26),
                    ),
                  ),
                ),
                // Title
                const Text(
                  'Reportar incidencia',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F2B48),
                  ),
                ),
                // Top right Paw badge -> Lleva al inicio
                InkWell(
                  onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D3B73),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.pets, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
        children: [
          // 1. Evidencia
          const Text(
            'Evidencia',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B2545),
            ),
          ),
          const SizedBox(height: 10),
          _buildEvidenceCard(),
          const SizedBox(height: 22),

          // 2. Estado del perro
          const Text(
            'Estado del perro',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B2545),
            ),
          ),
          const SizedBox(height: 10),
          _buildDogStatusOptions(),
          const SizedBox(height: 22),

          // 3. Tipo de incidencia
          const Text(
            'Tipo de incidencia',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B2545),
            ),
          ),
          const SizedBox(height: 10),
          _buildIncidentTypeChips(),
          const SizedBox(height: 22),

          // 4. Detalles del reporte
          const Text(
            'Detalles del reporte',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B2545),
            ),
          ),
          const SizedBox(height: 10),
          _buildDogDropdown(),
          const SizedBox(height: 14),
          const Text(
            'Descripción',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _desc,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '¿Qué está pasando?',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              fillColor: Colors.white,
              filled: true,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF0D3B73), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // 5. Ubicación
          const Text(
            'Ubicación',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B2545),
            ),
          ),
          const SizedBox(height: 10),
          _buildMapCard(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B73),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
              onPressed: _saving ? null : _send,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Enviar reporte',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEvidenceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6E2F2), width: 1.2),
      ),
      child: Column(
        children: [
          if (_photo != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    height: 170,
                    color: const Color(0xFFF1F5F9),
                    child: Image.memory(
                      _photo!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () => setState(() => _photo = null),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D3B73),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ] else ...[
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: Color(0xFF64748B),
                size: 26,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Añade fotos o videos de la incidencia',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B73),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Cámara', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D3B73),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Galería', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDogStatusOptions() {
    final options = [
      {'key': 'con_vida', 'label': 'Con vida', 'icon': Icons.favorite, 'color': const Color(0xFF10B981)},
      {'key': 'herido', 'label': 'Herido', 'icon': Icons.add, 'color': const Color(0xFFF97316)},
      {'key': 'sin_vida', 'label': 'Sin vida', 'icon': Icons.close, 'color': const Color(0xFF64748B)},
      {'key': 'no_se', 'label': 'No sé', 'icon': Icons.help_outline, 'color': const Color(0xFF64748B)},
    ];

    return Row(
      children: options.map((opt) {
        final key = opt['key'] as String;
        final label = opt['label'] as String;
        final icon = opt['icon'] as IconData;
        final color = opt['color'] as Color;
        final isSelected = _dogStatus == key;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => setState(() => _dogStatus = key),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0D3B73) : const Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? const Color(0xFF0D3B73) : const Color(0xFF0F2B48),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0D3B73) : const Color(0xFFCBD5E1),
                          width: isSelected ? 5 : 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIncidentTypeChips() {
    final types = [
      {'key': 'perdido', 'label': 'Perdido'},
      {'key': 'agresivo', 'label': 'Agresivo'},
      {'key': 'otro', 'label': 'Otro'},
    ];

    return Row(
      children: types.map((t) {
        final key = t['key'] as String;
        final label = t['label'] as String;
        final isSelected = _incidentType == key;

        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: InkWell(
            onTap: () => setState(() => _incidentType = key),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0D3B73) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF0D3B73) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    const Icon(Icons.check, color: Colors.white, size: 15),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : const Color(0xFF0F2B48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDogDropdown() {
    return StreamBuilder<List<Dog>>(
      stream: DataService.dogs(),
      builder: (context, snap) {
        final dogs = snap.data ?? <Dog>[];

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Dog?>(
                    value: _dog,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F2B48)),
                    hint: Row(
                      children: const [
                        Icon(Icons.pets_outlined, size: 20, color: Color(0xFF0D3B73)),
                        SizedBox(width: 10),
                        Text(
                          'Sin identificar',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F2B48)),
                        ),
                      ],
                    ),
                    items: [
                      DropdownMenuItem<Dog?>(
                        value: null,
                        child: Row(
                          children: const [
                            Icon(Icons.pets_outlined, size: 20, color: Color(0xFF0D3B73)),
                            SizedBox(width: 10),
                            Text(
                              'Sin identificar',
                              style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F2B48)),
                            ),
                          ],
                        ),
                      ),
                      for (final d in dogs)
                        DropdownMenuItem<Dog?>(
                          value: d,
                          child: Row(
                            children: [
                              const Icon(Icons.pets, size: 20, color: Color(0xFF0D3B73)),
                              const SizedBox(width: 10),
                              Text(
                                d.name,
                                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F2B48)),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _dog = v),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  'Elige el perro si lo reconoces.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapCard() {
    final latLng = LatLng(_lat ?? -1.65595, _lng ?? -78.67508);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: latLng,
                      initialZoom: 16.5,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _lat = point.latitude;
                          _lng = point.longitude;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'ec.edu.espoch.pawtrack',
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: latLng,
                            radius: 36,
                            useRadiusInMeter: false,
                            color: const Color(0xFF1E5BB0).withOpacity(0.18),
                            borderColor: const Color(0xFF1E5BB0),
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: latLng,
                            width: 36,
                            height: 36,
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFFF97316),
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: InkWell(
                      onTap: _locate,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.my_location, color: Color(0xFF0F2B48), size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D3B73),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ubicación adjunta',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: Color(0xFF0F2B48),
                          ),
                        ),
                        Text(
                          '${_lat?.toStringAsFixed(5) ?? '-1.65595'}, ${_lng?.toStringAsFixed(5) ?? '-78.67508'}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _locate,
                    icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
                    tooltip: 'Actualizar GPS',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
