import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/network_statistics.dart';

class NetworkStatsPieChart extends StatelessWidget {
  final NetworkStatistics statistics;

  const NetworkStatsPieChart({
    super.key,
    required this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    if (statistics.totalNetworks == 0) {
      return const Center(
        child: Text(
          'No network data available',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Barlow',
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Network Security Stats',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Barlow',
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _createSections(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(
                          'Total Networks',
                          statistics.totalNetworks.toString(),
                          Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        _buildLegendItem(
                          'Secure',
                          statistics.secureNetworks.toString(),
                          const Color(0xFF4CAF50),
                        ),
                        const SizedBox(height: 12),
                        _buildLegendItem(
                          'Vulnerable',
                          statistics.vulnerableNetworks.toString(),
                          const Color(0xFFF44336),
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
    );
  }

  List<PieChartSectionData> _createSections() {
    return statistics.pieChartItems.map((value) {
      final double percentage = value.value / statistics.totalNetworks * 100;
      return PieChartSectionData(
        color: Color(value.color),
        value: value.value.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 90,
        titleStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Barlow',
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Barlow',
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Barlow',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
