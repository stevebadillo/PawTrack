import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import 'reports_screen.dart';

class DashboardScreen extends StatelessWidget {
  final AppUser user;
  final ValueChanged<int> onOpenTab;
  final VoidCallback onNewReport;

  const DashboardScreen(
      {super.key,
      required this.user,
      required this.onOpenTab,
      required this.onNewReport});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return StreamBuilder<List<Dog>>(
      stream: DataService.dogs(),
      builder: (context, dogsSnapshot) => StreamBuilder<List<Report>>(
        stream: DataService.reports(reporterId: user.isStaff ? null : user.uid),
        builder: (context, reportsSnapshot) {
          final dogs = dogsSnapshot.data ?? const <Dog>[];
          final reports = reportsSnapshot.data ?? const <Report>[];
          final pending = reports.where((r) => r.status != 'resuelto').length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            children: [
              if (user.isStaff) ...[
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings_outlined,
                        size: 18, color: colors.primary),
                    const SizedBox(width: 7),
                    Text('Panel de administración',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            )),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    colors: [colors.primary, const Color(0xFF1A3F8F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hola, ${user.name.split(' ').first}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  )),
                          const SizedBox(height: 8),
                          Text(
                            user.isStaff
                                ? 'Gracias por cuidar a la comunidad canina.'
                                : 'Cada reporte ayuda a proteger a los perros del campus.',
                            style: const TextStyle(
                                color: Colors.white70, height: 1.35),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonalIcon(
                            onPressed: onNewReport,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('Crear reporte'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.pets_rounded,
                        size: 60, color: Colors.white24),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text('Resumen',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.pets_rounded,
                      label: 'Perros registrados',
                      value: dogsSnapshot.hasError ? '—' : '${dogs.length}',
                      color: const Color(0xFF2A5FC4),
                      onTap: () => onOpenTab(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.assignment_late_outlined,
                      label: 'Reportes activos',
                      value: reportsSnapshot.hasError ? '—' : '$pending',
                      color: const Color(0xFFE8521A),
                      onTap: () => onOpenTab(2),
                    ),
                  ),
                ],
              ),
              if (dogsSnapshot.hasError || reportsSnapshot.hasError) ...[
                const SizedBox(height: 12),
                _InfoCard(
                  icon: Icons.cloud_off_outlined,
                  title: 'No se pudo actualizar el resumen',
                  message: 'Comprueba tu conexión y vuelve a intentarlo.',
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text('Actividad reciente',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  TextButton(
                      onPressed: () => onOpenTab(2),
                      child: const Text('Ver todo')),
                ],
              ),
              const SizedBox(height: 4),
              if (!reportsSnapshot.hasData && !reportsSnapshot.hasError)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (reportsSnapshot.hasError)
                const _InfoCard(
                  icon: Icons.error_outline,
                  title: 'No se pudo cargar la actividad',
                  message:
                      'Los datos estarán disponibles cuando se restablezca la conexión.',
                )
              else if (reports.isEmpty)
                const _InfoCard(
                  icon: Icons.volunteer_activism_outlined,
                  title: 'Aún no hay reportes',
                  message:
                      'Cuando se informe una incidencia, aparecerá aquí para darle seguimiento.',
                )
              else
                for (final report in reports.take(3))
                  _RecentReportTile(report: report, onTap: () => onOpenTab(2)),
              if (user.isStaff && dogs.isEmpty && !dogsSnapshot.hasError) ...[
                const SizedBox(height: 18),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: colors.secondaryContainer,
                      child: Icon(Icons.add_home_work_outlined,
                          color: colors.onSecondaryContainer),
                    ),
                    title: const Text('Registra el primer perro',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        'El catálogo aparecerá en los formularios de reporte.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onOpenTab(1),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final VoidCallback onTap;
  const _SummaryCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 14),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54)),
              ],
            ),
          ),
        ),
      );
}

class _RecentReportTile extends StatelessWidget {
  final Report report;
  final VoidCallback onTap;
  const _RecentReportTile({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(Icons.pets, color: statusColor(report.status)),
          ),
          title: Text(report.unidentified
              ? 'Perro sin identificar'
              : (report.dogName ?? 'Perro')),
          subtitle: Text(DateFormat('dd MMM · HH:mm').format(report.createdAt)),
          trailing:
              Icon(Icons.circle, size: 11, color: statusColor(report.status)),
          onTap: onTap,
        ),
      );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, message;
  const _InfoCard(
      {required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon,
                  color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(message,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
