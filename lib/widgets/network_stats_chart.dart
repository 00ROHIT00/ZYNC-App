import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class NetworkStatsChart extends StatelessWidget {
  final int totalNetworks;
  final int vulnerableNetworks;
  final int secureNetworks;

  const NetworkStatsChart({
    super.key,
    required this.totalNetworks,
    required this.vulnerableNetworks,
    required this.secureNetworks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Text(
              'Network Security Overview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    color: Colors.green,
                    value: secureNetworks.toDouble(),
                    title: 'Secure\n${secureNetworks}',
                    radius: 55,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    titlePositionPercentageOffset: 0.85,
                  ),
                  PieChartSectionData(
                    color: Colors.red,
                    value: vulnerableNetworks.toDouble(),
                    title: 'Vulnerable\n${vulnerableNetworks}',
                    radius: 55,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    titlePositionPercentageOffset: 0.85,
                  ),
                  PieChartSectionData(
                    color: Colors.blue,
                    value:
                        (totalNetworks - (secureNetworks + vulnerableNetworks))
                            .toDouble(),
                    title:
                        'Others\n${totalNetworks - (secureNetworks + vulnerableNetworks)}',
                    radius: 55,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    titlePositionPercentageOffset: 0.85,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('Secure', Colors.green),
                _buildLegendItem('Vulnerable', Colors.red),
                _buildLegendItem('Others', Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}
