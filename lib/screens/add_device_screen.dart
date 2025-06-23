import 'package:flutter/material.dart';
import 'device_scanning_screen.dart';

class AddDeviceScreen extends StatelessWidget {
  const AddDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Device',
          style: TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.devices_other,
                size: 60,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Add a New Device',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: 'Barlow',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Connect your ZYNC device to start syncing your data',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Barlow', color: Colors.grey),
              ),
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeviceScanningScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text(
                'Start Scanning',
                style: TextStyle(
                  fontFamily: 'Barlow',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
