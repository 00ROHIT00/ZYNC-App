import '../services/scan_log_db.dart';

class NetworkStats {
  static Future<Map<String, int>> getNetworkStats() async {
    final db = ScanLogDb();
    final logs = await db.queryLogs();

    int secureCount = 0;
    int vulnerableCount = 0;

    for (final log in logs) {
      if (log['risk'] == 'Low') {
        secureCount++;
      } else if (log['risk'] == 'High' || log['risk'] == 'Medium') {
        vulnerableCount++;
      }
    }

    return {
      'total': logs.length,
      'secure': secureCount,
      'vulnerable': vulnerableCount,
    };
  }
}
