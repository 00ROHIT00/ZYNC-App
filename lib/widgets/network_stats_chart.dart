import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class NetworkStatsChart extends StatelessWidget {
  final int totalNetworks;
  final int vulnerableNetworks;
  final int secureNetworks;
  final bool hasData;
  final bool isConnected;
  final bool hasScanData;

  const NetworkStatsChart({
    super.key,
    required this.totalNetworks,
    required this.vulnerableNetworks,
    required this.secureNetworks,
    this.hasData = true,
    this.isConnected = false,
    this.hasScanData = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Chart
                if (hasData && totalNetworks > 0)
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          color: Colors.green,
                          value: secureNetworks > 0 ? secureNetworks.toDouble() : 0.1,
                          title: secureNetworks > 0 ? 'Secure\n$secureNetworks' : '',
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
                          value: vulnerableNetworks > 0 ? vulnerableNetworks.toDouble() : 0.1,
                          title: vulnerableNetworks > 0 ? 'Vulnerable\n$vulnerableNetworks' : '',
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
                // Overlay for no data states
                if (!hasData || totalNetworks == 0)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.radar,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Perform a live scan to view stats',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontFamily: 'Barlow',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Legend and Total Networks
          if (hasData && totalNetworks > 0) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLegendItem('Secure', Colors.green),
                  _buildLegendItem('Vulnerable', Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total Networks: $totalNetworks',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                fontFamily: 'Barlow',
              ),
            ),
          ],
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
