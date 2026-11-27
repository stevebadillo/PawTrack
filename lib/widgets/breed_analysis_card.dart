import 'package:flutter/material.dart';

import '../models/models.dart';

class BreedAnalysisCard extends StatelessWidget {
  final List<BreedPrediction> breeds;
  const BreedAnalysisCard({super.key, required this.breeds});

  @override
  Widget build(BuildContext context) {
    if (breeds.isEmpty) return const SizedBox.shrink();
    final total = breeds.fold<double>(0, (sum, breed) => sum + breed.score);
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.pets, size: 18, color: Color(0xFF0D3B73)),
          SizedBox(width: 8),
          Text('Razas estimadas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0B2545))),
        ]),
        const SizedBox(height: 12),
        ...breeds.map((breed) {
          final relative = total > 0 ? breed.score / total * 100 : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: Text(breed.name, style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w600))),
              Text('${relative.round()}%', style: const TextStyle(color: Color(0xFF0D3B73), fontWeight: FontWeight.w800)),
            ]),
          );
        }),
        const Text('Distribución relativa entre las razas detectadas por IA; no representa porcentaje genético.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      ]),
    );
  }
}
