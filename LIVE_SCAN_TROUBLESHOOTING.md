# Live Scan Feature Troubleshooting Guide

## Overview
The live scan feature allows the Flutter app to connect to the ESP32 device and receive real-time WiFi network scanning data. If you're experiencing issues, follow this troubleshooting guide.

## Common Issues and Solutions

### 1. Connection Issues

#### Problem: "TCP connection failed" error
**Symptoms:**
- App shows "Not connected to ESP32" 
- Connection status remains "Not Connected"

**Solutions:**
1. **Verify ESP32 Power:**
   - Ensure ESP32 is powered on and running
   - Check that the blue LED is blinking

2. **Check WiFi Connection:**
   - Connect your phone to the "ZYNC_Device" WiFi network
   - Password: `zync1234`
   - Verify you're connected to this network in your phone's WiFi settings

3. **Check ESP32 IP Address:**
   - Default IP: `192.168.4.1`
   - Port: `8888`
   - Use the settings button in the app to verify/change the IP

4. **Test Connection:**
   - Use the "Quick Test (192.168.4.1)" button in the app
   - Or run the Python test script: `python test_esp32_connection.py`

### 2. Live Scan Not Working

#### Problem: Live scan starts but no data received
**Symptoms:**
- Live scan shows "Live scanning..." but no networks appear
- Error message: "ESP32 Error: [specific error]"

**Solutions:**
1. **Check ESP32 Serial Output:**
   - Open Arduino IDE Serial Monitor
   - Set baud rate to 115200
   - Look for error messages or debug output

2. **Verify ESP32 Code:**
   - Ensure the latest code is uploaded to ESP32
   - Check that `WiFi.scanNetworks()` is working
   - Verify TCP server is running on port 8888

3. **Restart ESP32:**
   - Power cycle the ESP32 device
   - Wait for it to fully boot up

### 3. App Crashes or Freezes

#### Problem: App becomes unresponsive during live scan
**Symptoms:**
- App freezes when starting live scan
- App crashes when connecting to ESP32

**Solutions:**
1. **Check Permissions:**
   - Ensure WiFi and Location permissions are granted
   - Go to Settings > Permissions and verify all are enabled

2. **Restart App:**
   - Force close the app completely
   - Restart the app

3. **Check Device Compatibility:**
   - Ensure your device supports the required features
   - Update your device's operating system

## Testing the Connection

### Using the Python Test Script
1. **Prerequisites:**
   - Python 3.6+ installed
   - Connected to ZYNC_Device WiFi network

2. **Run the Test:**
   ```bash
   python test_esp32_connection.py
   ```

3. **Expected Output:**
   ```
   ESP32 Connection Test Tool
   ==================================================
   Target: 192.168.4.1:8888
   
   1. Testing basic socket connection...
      ✓ Socket connection successful
   2. Waiting for welcome message...
      ✓ Received: ZYNC_LIVE_SCAN_READY
      ✓ ESP32 is ready for live scan
   ...
   ✓ All tests completed successfully!
   ```

### Manual Testing Steps
1. **Connect to ESP32 WiFi:**
   - SSID: `ZYNC_Device`
   - Password: `zync1234`

2. **Test TCP Connection:**
   - Use a network tool like `telnet` or `nc`
   - Connect to `192.168.4.1:8888`
   - You should receive: `ZYNC_LIVE_SCAN_READY`

3. **Send Commands:**
   - Send: `START_LIVE_SCAN\n`
   - Expected response: `LIVE_SCAN_STARTED`
   - Send: `STOP_LIVE_SCAN\n`
   - Expected response: `LIVE_SCAN_STOPPED`

## ESP32 Debug Information

### Serial Monitor Output
When working correctly, you should see:
```
========================================
ZYNC Device Starting Up...
========================================
=== ZYNC Device Information ===
Device MAC Address: [MAC_ADDRESS]
WiFi AP IP Address: 192.168.4.1
========================================
Starting TCP server...
TCP server started on port 8888
Waiting for app connections...
========================================
App connected for Live Scan!
Client IP Address: [CLIENT_IP]
Client Port: [CLIENT_PORT]
========================================
```

### Common ESP32 Errors
1. **"Scan failed to start"**
   - WiFi hardware issue
   - Try restarting ESP32

2. **"Scan timeout"**
   - WiFi environment too noisy
   - Try changing scan interval in code

3. **"TCP server failed"**
   - Port 8888 already in use
   - Check for other applications using the port

## Advanced Troubleshooting

### Network Configuration Issues
1. **IP Address Conflicts:**
   - Ensure no other device uses `192.168.4.1`
   - Change ESP32 IP in code if needed

2. **Firewall Issues:**
   - Check if firewall blocks port 8888
   - Temporarily disable firewall for testing

### Code Issues
1. **Variable Conflicts:**
   - Fixed: `foundNetworks` variable shadowing in `performLiveScan()`
   - Ensure unique variable names

2. **Memory Issues:**
   - ESP32 may run out of memory during scans
   - Limit scan results to 20 networks

## Getting Help

If you're still experiencing issues:

1. **Collect Debug Information:**
   - ESP32 serial output
   - App error messages
   - Network configuration details

2. **Check for Updates:**
   - Ensure you have the latest code versions
   - Check for known issues in the repository

3. **Report Issues:**
   - Include debug information
   - Describe steps to reproduce
   - Mention your device and OS version

## Prevention

To avoid future issues:

1. **Regular Maintenance:**
   - Restart ESP32 periodically
   - Keep app updated
   - Monitor ESP32 memory usage

2. **Best Practices:**
   - Use stable power supply for ESP32
   - Keep ESP32 firmware updated
   - Test connections before important scans

3. **Environment Considerations:**
   - Avoid extremely noisy WiFi environments
   - Keep ESP32 away from interference sources
   - Ensure good ventilation for ESP32
