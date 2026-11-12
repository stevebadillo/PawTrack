import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/dog_fact_service.dart';
import 'contacts_screen.dart';
import 'reports_screen.dart';

// ============================================================================
// PANTALLA DE INICIO / PANEL PRINCIPAL (DashboardScreen)
// Muestra el saludo personalizado, el resumen del personal o la tarjeta para
// crear un reporte (estudiantes), los accesos rápidos a Mapa y Contactos, y la
// lista de actividad reciente.
// ============================================================================
class DashboardScreen extends StatelessWidget {
  final AppUser user;
  final ValueChanged<int> onOpenTab;
  final VoidCallback onNewReport;

  const DashboardScreen({
    super.key,
    required this.user,
    required this.onOpenTab,
    required this.onNewReport,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Report>>(
      stream: DataService.reports(reporterId: user.isStaff ? null : user.uid),
      builder: (context, reportsSnapshot) {
        final reports = reportsSnapshot.data ?? const <Report>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
          children: [
            // Bloque 1: Saludo de bienvenida al usuario
            Text(
              'Hola, ${user.name.split(' ').first}',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0B2545),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gracias por cuidar a la comunidad canina.',
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF5A6E85),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),

            // Bloque 2: Resumen para el personal (reportes, caninos y estudiantes)
            // o tarjeta destacada "Reporta una incidencia" para los estudiantes
            if (user.isStaff)
              _StaffSummaryBanner(reportCount: reports.length)
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D3B73), Color(0xFF144788)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D3B73).withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CustomPaint(
                    painter: _HeroRipplePainter(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Reporta una\nincidencia',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.15,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              // Insignia circular de huella con punto de alerta naranja
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.22),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.pets,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      width: 13,
                                      height: 13,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF97316),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF0D3B73),
                                          width: 2,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '!',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 7.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Botón tipo píldora "Crear reporte"
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(30),
                              onTap: onNewReport,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D3B73),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_outlined,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Crear reporte',
                                      style: TextStyle(
                                        color: Color(0xFF0D3B73),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFF0D3B73),
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 18),

            // Bloque 3: Dos tarjetas de acceso rápido (Mapa y Contactos)
            Row(
              children: [
                Expanded(
                  child: _QuickCard(
                    title: 'Mapa',
                    icon: Icons.map_outlined,
                    onTap: () => onOpenTab(3),
                    backgroundWidget: const _MapCardBackground(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _QuickCard(
                    title: 'Contactos',
                    icon: Icons.groups_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactsScreen()),
                    ),
                    backgroundWidget: const _ContactsCardBackground(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bloque exclusivo para estudiantes: Dog Facts API & Recomendaciones Educativas
            if (!user.isStaff) ...[
              const _StudentEducationSection(),
              const SizedBox(height: 24),
            ],

            // Bloque 4: Encabezado de la sección "Actividad reciente"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Actividad reciente',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0B2545),
                  ),
                ),
                TextButton(
                  onPressed: () => onOpenTab(2),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF1E5BB0),
                  ),
                  child: const Text(
                    'Ver todo',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Bloque 5: Lista de los últimos reportes registrados
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: reports.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      child: Center(
                        child: Text(
                          'No hay actividad reciente registrada.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: reports.length > 5 ? 5 : reports.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        final r = reports[index];
                        return _ReportRowItem(
                          report: r,
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            builder: (_) => ReportSheet(report: r, user: user),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// Resumen para el personal: total de reportes, caninos y estudiantes.
class _StaffSummaryBanner extends StatelessWidget {
  final int reportCount;

  const _StaffSummaryBanner({
    required this.reportCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0D3B73),
            Color(0xFF144788),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D3B73).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: StreamBuilder<List<Dog>>(
        stream: DataService.dogs(),
        builder: (context, dogsSnapshot) {
          final dogCount = dogsSnapshot.hasData
              ? dogsSnapshot.data!.length.toString()
              : '--';

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('usuarios')
                .where('role', isEqualTo: 'estudiante')
                .snapshots(),
            builder: (context, studentsSnapshot) {
              final studentCount = studentsSnapshot.hasData
                  ? studentsSnapshot.data!.docs.length.toString()
                  : '--';

              return Row(
                children: [
                  Expanded(
                    child: _SummaryMetric(
                      icon: Icons.assignment_rounded,
                      count: reportCount.toString(),
                      label: 'Reportes',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _SummaryMetric(
                      icon: Icons.pets_rounded,
                      count: dogCount,
                      label: 'Caninos',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _SummaryMetric(
                      icon: Icons.school_rounded,
                      count: studentCount,
                      label: 'Estudiantes',
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// Tarjeta individual de métrica (icono, cantidad y etiqueta).
class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String count;
  final String label;

  const _SummaryMetric({
    required this.icon,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    count,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRowItem extends StatelessWidget {
  final Report report;
  final VoidCallback onTap;

  const _ReportRowItem({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = report.status;
    final isResolved = status == 'resuelto';
    final isInReview = status == 'en_revision' || status == 'en_atencion';

    final pillBg = isResolved
        ? const Color(0xFFEAF8F0)
        : (isInReview ? const Color(0xFFFEF5E7) : const Color(0xFFFEF2F2));
    final pillColor = isResolved
        ? const Color(0xFF15803D)
        : (isInReview ? const Color(0xFFB45309) : const Color(0xFFDC2626));
    final pillText = isResolved
        ? 'Resuelto'
        : (isInReview ? 'En revisión' : 'Pendiente');

    final title = report.unidentified
        ? 'Sin identificar'
        : (report.dogName?.isNotEmpty == true ? report.dogName! : 'Sin identificar');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Contenedor con ícono de huella del reporte
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Icon(
                  Icons.pets,
                  color: Color(0xFF1E5BB0),
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Nombre del perro y fecha del reporte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: Color(0xFF0B2545),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('dd MMM · HH:mm').format(report.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Etiqueta de estado (Pendiente, En revisión, Resuelto)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: pillColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    pillText,
                    style: TextStyle(
                      color: pillColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
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

class _QuickCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Widget backgroundWidget;

  const _QuickCard({
    required this.title,
    required this.icon,
    required this.onTap,
    required this.backgroundWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 124,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                backgroundWidget,
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D3B73),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(icon, color: Colors.white, size: 20),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0B2545),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapCardBackground extends StatelessWidget {
  const _MapCardBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, double.infinity),
      painter: _MapBackgroundPainter(),
    );
  }
}

class _MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle map road illustration
    final roadPaint = Paint()
      ..color = const Color(0xFFEBF1FB)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    final campusPaint = Paint()
      ..color = const Color(0xFFEDF8ED).withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    // Green zone at the bottom-right
    final greenRect = Rect.fromLTWH(size.width * 0.55, size.height * 0.45, size.width * 0.45, size.height * 0.55);
    canvas.drawRRect(RRect.fromRectAndRadius(greenRect, const Radius.circular(8)), campusPaint);

    // Roads
    final roadPath = Path();
    roadPath.moveTo(size.width * 0.65, 0);
    roadPath.lineTo(size.width * 0.70, size.height);
    canvas.drawPath(roadPath, roadPaint);

    final roadPath2 = Path();
    roadPath2.moveTo(0, size.height * 0.48);
    roadPath2.lineTo(size.width, size.height * 0.45);
    canvas.drawPath(roadPath2, roadPaint);

    // Small blue location dot on the road
    final dotPaint = Paint()..color = const Color(0xFF1E5BB0);
    canvas.drawCircle(Offset(size.width * 0.46, size.height * 0.47), 3.5, dotPaint);

    // Orange location pin marker
    final pinX = size.width * 0.73;
    final pinY = size.height * 0.32;

    final pinPaint = Paint()..color = const Color(0xFFF97316);
    canvas.drawCircle(Offset(pinX, pinY - 4), 6, pinPaint);

    final pinPath = Path()
      ..moveTo(pinX - 5, pinY - 3)
      ..lineTo(pinX + 5, pinY - 3)
      ..lineTo(pinX, pinY + 6)
      ..close();
    canvas.drawPath(pinPath, pinPaint);

    final innerWhite = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(pinX, pinY - 4), 2.2, innerWhite);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// SECCIÓN EDUCATIVA Y DOG FACTS API (EXCLUSIVA PARA ESTUDIANTES)
// Muestra curiosidades caninas obtenidas de Dog Facts API y recomendaciones
// para la convivencia y cuidado de los perros en el campus universitario.
// ============================================================================
class _StudentEducationSection extends StatefulWidget {
  const _StudentEducationSection();

  @override
  State<_StudentEducationSection> createState() => _StudentEducationSectionState();
}

class _StudentEducationSectionState extends State<_StudentEducationSection> {
  String? _fact;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFact();
  }

  Future<void> _loadFact() async {
    setState(() => _loading = true);
    final fact = await DogFactService.fetchFact();
    if (mounted) {
      setState(() {
        _fact = fact;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recommendations = DogFactService.getRecommendations();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado de la sección
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Color(0xFF1E5BB0),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Dato curioso del día',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0B2545),
                  ),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Cargar otro dato',
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF1E5BB0),
                      size: 20,
                    ),
              onPressed: _loading ? null : _loadFact,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Tarjeta principal con la curiosidad de la API
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B2545).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'DOG FACTS API',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.pets, size: 16, color: Color(0xFF94A3B8)),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedCrossFade(
                firstChild: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                secondChild: Text(
                  _fact ?? 'Cargando curiosidad canina...',
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                crossFadeState: _loading
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Subtítulo de recomendaciones
        const Text(
          'Recomendaciones y cuidado en el campus',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0B2545),
          ),
        ),
        const SizedBox(height: 10),

        // Carrusel horizontal de recomendaciones educativas
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = recommendations[index];
              return Container(
                width: 230,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          item['icon'] == 'restaurant'
                              ? Icons.restaurant_outlined
                              : item['icon'] == 'hotel'
                                  ? Icons.hotel_outlined
                                  : item['icon'] == 'health_and_safety'
                                      ? Icons.health_and_safety_outlined
                                      : Icons.pets_outlined,
                          size: 18,
                          color: const Color(0xFF0D3B73),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item['title']!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B2545),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        item['desc']!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


class _ContactsCardBackground extends StatelessWidget {
  const _ContactsCardBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 14,
      right: 14,
      child: SizedBox(
        width: 60,
        height: 28,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              child: _avatarBubble(const Color(0xFFD3E0F3)),
            ),
            Positioned(
              left: 16,
              child: _avatarBubble(const Color(0xFFCBDDF7)),
            ),
            Positioned(
              left: 32,
              child: _avatarBubble(const Color(0xFFBFD4F4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarBubble(Color color) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}


