import 'package:flutter/material.dart';
import '../services/scan_log_db.dart';

import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'dart:typed_data';

class ScanLogsScreen extends StatefulWidget {
  final String? exportFormat;
  const ScanLogsScreen({super.key, this.exportFormat});
  @override
  State<ScanLogsScreen> createState() => _ScanLogsScreenState();
}

class _ScanLogsScreenState extends State<ScanLogsScreen> {
  final _db = ScanLogDb();
  String _risk = '';
  String _security = '';
  String _query = '';
  int? _from; // epoch ms
  int? _to; // epoch ms
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadAndMaybeExport();
  }

  Future<void> _loadAndMaybeExport() async {
    await _load();
    if (widget.exportFormat != null) {
      await _exportLogs(widget.exportFormat!);
    }
  }

  Future<void> _exportLogs(String format) async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs to export.')),
      );
      return;
    }

    if (format == 'csv') {
      // Prepare CSV data with better formatting
      List<List<dynamic>> csvData = [
        [
          'Network Name (SSID)',
          'MAC Address (BSSID)',
          'Security Type',
          'Risk Level',
          'Signal Strength (dBm)',
          'Channel',
          'Times Seen',
          'First Seen',
          'Last Seen'
        ],
        ..._rows.map((r) => [
              r['ssid']?.toString().isNotEmpty == true ? r['ssid'] : 'Hidden Network',
              r['bssid'] ?? 'N/A',
              r['security'] ?? 'Unknown',
              r['risk'] ?? 'Unknown',
              r['rssi'] != null ? '${r['rssi']} dBm' : 'N/A',
              r['channel'] ?? 'N/A',
              r['seenCount'] ?? '1',
              r['firstSeenAt'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(r['firstSeenAt'])
                      .toString().split('.')[0] // Remove microseconds
                  : 'N/A',
              r['lastSeenAt'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(r['lastSeenAt'])
                      .toString().split('.')[0] // Remove microseconds
                  : 'N/A',
            ])
      ];
      String csv = const ListToCsvConverter().convert(csvData);
      await Printing.sharePdf(
          bytes: Uint8List.fromList(csv.codeUnits), filename: 'zync_scan_logs.csv');
    } else if (format == 'pdf') {
      // Prepare PDF document with better layout
      final pdf = pw.Document();
      
      // Split data into chunks for multiple pages if needed
      const int rowsPerPage = 15;
      for (int i = 0; i < _rows.length; i += rowsPerPage) {
        final chunk = _rows.skip(i).take(rowsPerPage).toList();
        
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape, // Landscape for better table fit
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return [
                // Header (only on first page)
                if (i == 0) ...[
                  pw.Header(
                    level: 0,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'ZYNC WiFi Scan Logs',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Generated: ${DateTime.now().toString().split('.')[0]}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Total Networks: ${_rows.length}',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 16),
                ],
                
                // Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2), // SSID
                    1: const pw.FlexColumnWidth(2), // MAC
                    2: const pw.FlexColumnWidth(2), // Security
                    3: const pw.FlexColumnWidth(1), // Risk
                    4: const pw.FlexColumnWidth(1), // Signal
                    5: const pw.FlexColumnWidth(1), // Channel
                    6: const pw.FlexColumnWidth(2), // Last Seen
                  },
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        _pdfCell('Network Name', isHeader: true),
                        _pdfCell('MAC Address', isHeader: true),
                        _pdfCell('Security', isHeader: true),
                        _pdfCell('Risk', isHeader: true),
                        _pdfCell('Signal', isHeader: true),
                        _pdfCell('Channel', isHeader: true),
                        _pdfCell('Last Seen', isHeader: true),
                      ],
                    ),
                    // Data rows
                    ...chunk.map((r) {
                      final riskColor = r['risk'] == 'High' 
                          ? PdfColors.red100
                          : r['risk'] == 'Medium'
                              ? PdfColors.orange100
                              : PdfColors.green100;
                      
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: riskColor),
                        children: [
                          _pdfCell(r['ssid']?.toString().isNotEmpty == true 
                              ? r['ssid'].toString() 
                              : 'Hidden Network'),
                          _pdfCell(r['bssid']?.toString() ?? 'N/A'),
                          _pdfCell(r['security']?.toString() ?? 'Unknown'),
                          _pdfCell(r['risk']?.toString() ?? 'Unknown', isBold: true),
                          _pdfCell(r['rssi'] != null ? '${r['rssi']} dBm' : 'N/A'),
                          _pdfCell(r['channel']?.toString() ?? 'N/A'),
                          _pdfCell(r['lastSeenAt'] != null
                              ? DateTime.fromMillisecondsSinceEpoch(r['lastSeenAt'])
                                  .toString().split('.')[0]
                              : 'N/A', fontSize: 8),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ];
            },
          ),
        );
      }
      
      final pdfBytes = await pdf.save();
      await Printing.sharePdf(bytes: pdfBytes, filename: 'zync_scan_logs.pdf');
    }
  }
  
  pw.Widget _pdfCell(String text, {bool isHeader = false, bool isBold = false, double fontSize = 10}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _db.queryLogs(
      from: _from,
      to: _to,
      risk: _risk.isEmpty ? null : _risk,
      security: _security.isEmpty ? null : _security,
      ssidLike: _query.isEmpty ? null : _query,
      limit: 500,
    );
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Logs',
            style:
                TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear All',
            onPressed: () async {
              await _db.clearAll();
              await _load();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(context),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? const Center(
                        child: Text('No logs yet',
                            style: TextStyle(
                                fontFamily: 'Barlow', color: Colors.grey)),
                      )
                    : ListView.builder(
                        itemCount: _rows.length,
                        itemBuilder: (context, index) {
                          final r = _rows[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: ExpansionTile(
                              leading: _riskDot(r['risk'] as String),
                              title: Text(
                                (((r['ssid'] as String?) ?? '').isEmpty)
                                    ? '<Hidden Network>'
                                    : ((r['ssid'] as String?) ?? ''),
                                style: const TextStyle(
                                    fontFamily: 'Barlow',
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${r['security']} • last seen ${DateTime.fromMillisecondsSinceEpoch(r['lastSeenAt'] as int)}',
                                style: const TextStyle(fontFamily: 'Barlow'),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _row('MAC', r['bssid'] as String),
                                      _row('Channel', '${r['channel']}'),
                                      _row('Signal', '${r['rssi']} dBm'),
                                      _row('Seen', '${r['seenCount']} times'),
                                      _row(
                                          'First seen',
                                          DateTime.fromMillisecondsSinceEpoch(
                                                  r['firstSeenAt'] as int)
                                              .toString()),
                                      _row(
                                          'Last seen',
                                          DateTime.fromMillisecondsSinceEpoch(
                                                  r['lastSeenAt'] as int)
                                              .toString()),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _riskDot(String risk) {
    Color c;
    switch (risk) {
      case 'high':
        c = Colors.red;
        break;
      case 'medium':
        c = Colors.orange;
        break;
      default:
        c = Colors.green;
    }
    return CircleAvatar(radius: 6, backgroundColor: c);
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(k,
                style: const TextStyle(
                    fontFamily: 'Barlow', fontWeight: FontWeight.w600)),
          ),
          Expanded(
              child: Text(v, style: const TextStyle(fontFamily: 'Barlow'))),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search SSID',
              border: OutlineInputBorder(),
            ),
            onChanged: (s) {
              _query = s.trim();
            },
            onSubmitted: (_) => _load(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _risk.isEmpty ? null : _risk,
                  items: const [
                    DropdownMenuItem(value: 'high', child: Text('High risk')),
                    DropdownMenuItem(
                        value: 'medium', child: Text('Medium risk')),
                    DropdownMenuItem(value: 'low', child: Text('Safer')),
                  ],
                  decoration: const InputDecoration(labelText: 'Risk'),
                  onChanged: (v) {
                    _risk = v ?? '';
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _security.isEmpty ? null : _security,
                  items: const [
                    DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                    DropdownMenuItem(value: 'WEP', child: Text('WEP')),
                    DropdownMenuItem(value: 'WPA', child: Text('WPA')),
                    DropdownMenuItem(value: 'WPA2', child: Text('WPA2')),
                    DropdownMenuItem(value: 'WPA3', child: Text('WPA3')),
                  ],
                  decoration: const InputDecoration(labelText: 'Security'),
                  onChanged: (v) {
                    _security = v ?? '';
                    _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Apply filters',
                  style: TextStyle(fontFamily: 'Barlow')),
              onPressed: _load,
            ),
          )
        ],
      ),
    );
  }
}
