import 'package:flutter/material.dart';
import '../services/scan_log_db.dart';

import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
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
      // Prepare CSV data
      List<List<dynamic>> csvData = [
        [
          'SSID',
          'MAC',
          'Channel',
          'Signal',
          'Seen',
          'First Seen',
          'Last Seen',
          'Risk',
          'Security'
        ],
        ..._rows.map((r) => [
              r['ssid'] ?? '<Hidden Network>',
              r['bssid'] ?? '',
              r['channel'] ?? '',
              r['rssi'] ?? '',
              r['seenCount'] ?? '',
              r['firstSeenAt'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(r['firstSeenAt'])
                      .toString()
                  : '',
              r['lastSeenAt'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(r['lastSeenAt'])
                      .toString()
                  : '',
              r['risk'] ?? '',
              r['security'] ?? '',
            ])
      ];
      String csv = const ListToCsvConverter().convert(csvData);
      await Printing.sharePdf(
          bytes: Uint8List.fromList(csv.codeUnits), filename: 'scan_logs.csv');
    } else if (format == 'pdf') {
      // Prepare PDF document
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Scan Logs',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 16),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Text('SSID'),
                        pw.Text('MAC'),
                        pw.Text('Channel'),
                        pw.Text('Signal'),
                        pw.Text('Seen'),
                        pw.Text('First Seen'),
                        pw.Text('Last Seen'),
                        pw.Text('Risk'),
                        pw.Text('Security'),
                      ],
                    ),
                    ..._rows
                        .map((r) => pw.TableRow(
                              children: [
                                pw.Text(r['ssid'] ?? '<Hidden Network>'),
                                pw.Text(r['bssid'] ?? ''),
                                pw.Text('${r['channel'] ?? ''}'),
                                pw.Text('${r['rssi'] ?? ''}'),
                                pw.Text('${r['seenCount'] ?? ''}'),
                                pw.Text(r['firstSeenAt'] != null
                                    ? DateTime.fromMillisecondsSinceEpoch(
                                            r['firstSeenAt'])
                                        .toString()
                                    : ''),
                                pw.Text(r['lastSeenAt'] != null
                                    ? DateTime.fromMillisecondsSinceEpoch(
                                            r['lastSeenAt'])
                                        .toString()
                                    : ''),
                                pw.Text(r['risk'] ?? ''),
                                pw.Text(r['security'] ?? ''),
                              ],
                            ))
                        .toList(),
                  ],
                ),
              ],
            );
          },
        ),
      );
      final pdfBytes = await pdf.save();
      await Printing.sharePdf(bytes: pdfBytes, filename: 'scan_logs.pdf');
    }
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
