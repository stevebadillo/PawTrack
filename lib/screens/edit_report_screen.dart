import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../services/data_service.dart';

class EditReportScreen extends StatefulWidget {
  final Report report;
  final AppUser user;
  const EditReportScreen({super.key, required this.report, required this.user});

  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  late final TextEditingController _desc;
  final MapController _mapController = MapController();

  late String _dogStatus;
  late String _incidentType;
  Dog? _dog;
  late double _lat;
  late double _lng;
  Uint8List? _newPhoto;
  bool _removeOriginalPhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _desc = TextEditingController(text: widget.report.description);
    _dogStatus = widget.report.dogStatus.isNotEmpty ? widget.report.dogStatus : 'herido';
    _incidentType = widget.report.incidentType.isNotEmpty ? widget.report.incidentType : 'otro';
    _lat = widget.report.lat != 0 ? widget.report.lat : -1.65595;
    _lng = widget.report.lng != 0 ? widget.report.lng : -78.67508;
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 55,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (x != null) {
        final bytes = await x.readAsBytes();
        if (mounted) {
          setState(() {
            _newPhoto = bytes;
            _removeOriginalPhoto = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo seleccionar la imagen.')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_desc.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor escribe una descripción.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final Map<String, dynamic> updates = {
        'description': _desc.text.trim(),
        'descripcion': _desc.text.trim(),
        'dogStatus': _dogStatus,
        'estadoPerro': _dogStatus,
        'incidentType': _incidentType,
        'tipoIncidencia': _incidentType,
        'lat': _lat,
        'lng': _lng,
      };

      if (_dog != null) {
        updates['dogId'] = _dog!.id;
        updates['dogName'] = _dog!.name;
        updates['perroId'] = _dog!.id;
        updates['perroNombre'] = _dog!.name;
      }

      if (_newPhoto != null) {
        final photoUrl = await DataService.uploadPhoto(_newPhoto!, 'reportes');
        updates['photoUrl'] = photoUrl;
        updates['photoBase64'] = '';
        updates['photos'] = [photoUrl];
        updates['evidencias'] = [photoUrl];
      } else if (_removeOriginalPhoto) {
        updates['photoBase64'] = '';
        updates['photoUrl'] = '';
        updates['photos'] = [];
        updates['evidencias'] = [];
      }

      await DataService.updateReportFull(widget.report.id, updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cambios guardados con éxito.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = (_newPhoto != null) ||
        (!_removeOriginalPhoto &&
            (widget.report.photoBase64.isNotEmpty || widget.report.photoUrl.isNotEmpty));

    final latLng = LatLng(_lat, _lng);

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
                const Text(
                  'Editar reporte',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F2B48),
                  ),
                ),
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
          // Banner Pendiente
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDA4AF).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Pendiente',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: Color(0xFFBE123C),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Puedes editar tu reporte hasta que el personal empiece a revisarlo.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF881337),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Evidencia
          const Text(
            'Evidencia',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (hasPhoto)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 90,
                        height: 90,
                        color: const Color(0xFFF1F5F9),
                        child: _newPhoto != null
                            ? Image.memory(_newPhoto!, fit: BoxFit.contain)
                            : (widget.report.photoBase64.isNotEmpty
                                ? Image.memory(base64Decode(widget.report.photoBase64), fit: BoxFit.contain)
                                : Image.network(widget.report.photoUrl, fit: BoxFit.contain)),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _newPhoto = null;
                            _removeOriginalPhoto = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0D3B73),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              if (hasPhoto) const SizedBox(width: 14),
              InkWell(
                onTap: _pickPhoto,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF93C5FD),
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add, color: Color(0xFF2563EB), size: 26),
                      SizedBox(height: 4),
                      Text(
                        'Añadir',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Estado del perro
          const Text(
            'Estado del perro',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545)),
          ),
          const SizedBox(height: 10),
          _buildDogStatusOptions(),
          const SizedBox(height: 22),

          // Tipo de incidencia
          const Text(
            'Tipo de incidencia',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545)),
          ),
          const SizedBox(height: 10),
          _buildIncidentTypeChips(),
          const SizedBox(height: 22),

          // Detalles del reporte
          const Text(
            'Detalles del reporte',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545)),
          ),
          const SizedBox(height: 10),
          _buildDogDropdown(),
          const SizedBox(height: 14),
          const Text(
            'Descripción',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _desc,
            maxLines: 3,
            decoration: InputDecoration(
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

          // Ubicación
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ubicación',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545)),
              ),
              Text(
                'Ajustar en el mapa',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E5BB0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildMapCard(latLng),
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
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B73),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.shrink()
                  : const Icon(Icons.check, size: 20),
              label: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Guardar cambios',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Dog?>(
                value: _dog,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F2B48)),
                hint: Row(
                  children: [
                    const Icon(Icons.pets_outlined, size: 20, color: Color(0xFF0D3B73)),
                    const SizedBox(width: 10),
                    Text(
                      widget.report.dogName?.isNotEmpty == true
                          ? widget.report.dogName!
                          : 'Sin identificar',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F2B48)),
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
        );
      },
    );
  }

  Widget _buildMapCard(LatLng latLng) {
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
              child: FlutterMap(
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
                          '${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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
