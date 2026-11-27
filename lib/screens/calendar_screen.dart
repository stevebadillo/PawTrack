import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';

class CalendarScreen extends StatefulWidget {
  final AppUser user;

  const CalendarScreen({super.key, required this.user});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDay = DateTime.now();

  void _changeMonth(int increment) {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + increment, 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDay = now;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthTitle =
        DateFormat('MMM. yyyy').format(_focusedMonth).toUpperCase();

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
                          color: Color(0xFF06397b), size: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Calendario',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF06397b),
                    ),
                  ),
                ),
                InkWell(
                  onTap: _goToToday,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Text(
                        '${DateTime.now().day}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF06397b),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Dog>>(
        stream: DataService.dogs(),
        builder: (context, dogSnapshot) {
          final dogs = dogSnapshot.data ?? const <Dog>[];

          return StreamBuilder<List<_CalendarEvent>>(
            stream: _loadAllEvents(dogs),
            builder: (context, eventSnapshot) {
              final events = eventSnapshot.data ?? const <_CalendarEvent>[];

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded,
                                  color: Color(0xFF06397b)),
                              onPressed: () => _changeMonth(-1),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              monthTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF06397b),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded,
                                  color: Color(0xFF06397b)),
                              onPressed: () => _changeMonth(1),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.pets,
                                      size: 14, color: Color(0xFF06397b)),
                                  SizedBox(width: 4),
                                  Text(
                                    'PawTrack',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF06397b),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Expanded(
                                child: _WeekDayLabel('DOM.', isSunday: true)),
                            Expanded(child: _WeekDayLabel('LUN.')),
                            Expanded(child: _WeekDayLabel('MAR.')),
                            Expanded(child: _WeekDayLabel('MIÉ.')),
                            Expanded(child: _WeekDayLabel('JUE.')),
                            Expanded(child: _WeekDayLabel('VIE.')),
                            Expanded(child: _WeekDayLabel('SÁB.')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _WidgetMonthGrid(
                          focusedMonth: _focusedMonth,
                          selectedDay: _selectedDay,
                          events: events,
                          onDaySelected: (day) =>
                              setState(() => _selectedDay = day),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Agenda del ${DateFormat('dd MMMM yyyy').format(_selectedDay)}',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF06397b),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DayEventsList(selectedDay: _selectedDay, events: events),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Stream<List<_CalendarEvent>> _loadAllEvents(List<Dog> dogs) {
    if (dogs.isEmpty) {
      return Stream.value(const <_CalendarEvent>[]);
    }

    final dogStreams = dogs.map((dog) {
      return Stream<List<_CalendarEvent>>.multi((controller) {
        List<Vaccine> latestVaccines = const <Vaccine>[];
        List<MedicalEntry> latestEntries = const <MedicalEntry>[];

        void emitCombined() {
          final dogEvents = <_CalendarEvent>[];

          for (final v in latestVaccines) {
            if (v.nextDate != null) {
              dogEvents.add(
                _CalendarEvent(
                  dogName: dog.name,
                  shortLabel: 'Ref. ${v.name}',
                  title: 'Próximo refuerzo: ${v.name}',
                  date: v.nextDate!,
                  type: 'Vacuna',
                  color: const Color(0xFF16A34A),
                ),
              );
            }
            dogEvents.add(
              _CalendarEvent(
                dogName: dog.name,
                shortLabel: v.name,
                title: 'Vacuna aplicada: ${v.name}',
                date: v.appliedAt,
                type: 'Vacuna',
                color: const Color(0xFF06397b),
              ),
            );
          }

          for (final e in latestEntries) {
            dogEvents.add(
              _CalendarEvent(
                dogName: dog.name,
                shortLabel: e.title,
                title: e.title,
                date: e.date,
                type: 'Historial',
                color: const Color(0xFFD97706),
              ),
            );

            if (e.nextVisit != null) {
              dogEvents.add(
                _CalendarEvent(
                  dogName: dog.name,
                  shortLabel: 'Cita: ${e.title}',
                  title: 'Próxima visita: ${e.title}',
                  date: e.nextVisit!,
                  type: 'Historial',
                  color: const Color(0xFFEA580C),
                ),
              );
            }
          }

          if (!controller.isClosed) {
            controller.add(dogEvents);
          }
        }

        final vacSub = DataService.vaccines(dog.id).listen(
          (vaccines) {
            latestVaccines = vaccines;
            emitCombined();
          },
          onError: controller.addError,
        );

        final medSub = DataService.medicalEntries(dog.id).listen(
          (entries) {
            latestEntries = entries;
            emitCombined();
          },
          onError: controller.addError,
        );

        controller.onCancel = () async {
          await vacSub.cancel();
          await medSub.cancel();
        };
      });
    }).toList();

    return Stream<List<_CalendarEvent>>.multi((controller) {
      final latestByDog =
          List<List<_CalendarEvent>>.filled(dogStreams.length, const []);
      final subs = <StreamSubscription<List<_CalendarEvent>>>[];

      for (var i = 0; i < dogStreams.length; i++) {
        subs.add(
          dogStreams[i].listen(
            (events) {
              latestByDog[i] = events;
              if (!controller.isClosed) {
                controller.add(latestByDog.expand((x) => x).toList());
              }
            },
            onError: controller.addError,
          ),
        );
      }

      controller.onCancel = () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      };
    });
  }
}

class _WeekDayLabel extends StatelessWidget {
  final String text;
  final bool isSunday;
  const _WeekDayLabel(this.text, {this.isSunday = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isSunday ? const Color(0xFFDC2626) : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _WidgetMonthGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final List<_CalendarEvent> events;
  final ValueChanged<DateTime> onDaySelected;

  const _WidgetMonthGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.events,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final weekdayOffset = firstDayOfMonth.weekday % 7;
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final totalCells = ((weekdayOffset + daysInMonth) / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.72,
        crossAxisSpacing: 2,
        mainAxisSpacing: 4,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayNumber = index - weekdayOffset + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final currentDate =
            DateTime(focusedMonth.year, focusedMonth.month, dayNumber);
        final isSunday = currentDate.weekday == DateTime.sunday;
        final isSelected = selectedDay.year == currentDate.year &&
            selectedDay.month == currentDate.month &&
            selectedDay.day == currentDate.day;
        final isToday = DateTime.now().year == currentDate.year &&
            DateTime.now().month == currentDate.month &&
            DateTime.now().day == currentDate.day;

        final dayEvents = events
            .where((e) =>
                e.date.year == currentDate.year &&
                e.date.month == currentDate.month &&
                e.date.day == currentDate.day)
            .toList();

        return GestureDetector(
          onTap: () => onDaySelected(currentDate),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF06397b)
                    : const Color(0xFFF1F5F9),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isToday
                          ? const Color(0xFF16A34A)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isToday
                            ? Colors.white
                            : (isSunday
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF0F2B48)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                ...dayEvents.take(2).map(
                      (ev) => Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: ev.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${ev.dogName}: ${ev.shortLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
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
  }
}

class _DayEventsList extends StatelessWidget {
  final DateTime selectedDay;
  final List<_CalendarEvent> events;

  const _DayEventsList({required this.selectedDay, required this.events});

  @override
  Widget build(BuildContext context) {
    final dayEvents = events
        .where((e) =>
            e.date.year == selectedDay.year &&
            e.date.month == selectedDay.month &&
            e.date.day == selectedDay.day)
        .toList();

    if (dayEvents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'No hay vacunas ni registros médicos para esta fecha.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: dayEvents.map((ev) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 38,
                decoration: BoxDecoration(
                  color: ev.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ev.dogName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      ev.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F2B48),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ev.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  ev.type,
                  style: TextStyle(
                    color: ev.color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CalendarEvent {
  final String dogName;
  final String shortLabel;
  final String title;
  final DateTime date;
  final String type;
  final Color color;

  _CalendarEvent({
    required this.dogName,
    required this.shortLabel,
    required this.title,
    required this.date,
    required this.type,
    required this.color,
  });
}