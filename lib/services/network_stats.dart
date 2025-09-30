import '../services/scan_log_db.dart';

class NetworkStats {
  static Future<Map<String, int>> getNetworkStats() async {
    final db = ScanLogDb();
    
    // Get stats from the most recent scan session
    final latestSession = await db.getLatestScanSession();
    
    if (latestSession != null) {
      return latestSession;
    }
    
    // If no session exists, return zeros
    return {
      'total': 0,
      'secure': 0,
      'vulnerable': 0,
    };
  }
}
