#!/usr/bin/env python3
"""
ESP32 Connection Test Script
This script helps test the connection to the ESP32 device for debugging purposes.
"""

import socket
import time
import sys

def test_esp32_connection(ip="192.168.4.1", port=8888):
    """Test connection to ESP32 device"""
    print(f"Testing connection to ESP32 at {ip}:{port}")
    print("=" * 50)
    
    try:
        # Test 1: Basic socket connection
        print("1. Testing basic socket connection...")
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(10)
        sock.connect((ip, port))
        print("   ✓ Socket connection successful")
        
        # Test 2: Wait for welcome message
        print("2. Waiting for welcome message...")
        sock.settimeout(5)
        try:
            data = sock.recv(1024).decode('utf-8').strip()
            print(f"   ✓ Received: {data}")
            if "ZYNC_LIVE_SCAN_READY" in data:
                print("   ✓ ESP32 is ready for live scan")
            else:
                print("   ⚠ ESP32 sent unexpected message")
        except socket.timeout:
            print("   ⚠ No welcome message received (timeout)")
        
        # Test 3: Send START_LIVE_SCAN command
        print("3. Testing START_LIVE_SCAN command...")
        sock.send("START_LIVE_SCAN\n".encode())
        print("   ✓ Command sent")
        
        # Test 4: Wait for response
        print("4. Waiting for response...")
        sock.settimeout(10)
        try:
            data = sock.recv(1024).decode('utf-8').strip()
            print(f"   ✓ Received: {data}")
            if "LIVE_SCAN_STARTED" in data:
                print("   ✓ Live scan started successfully")
            elif "LIVE_SCAN_ERROR" in data:
                print(f"   ❌ ESP32 error: {data}")
            else:
                print(f"   ⚠ Unexpected response: {data}")
        except socket.timeout:
            print("   ⚠ No response received (timeout)")
        
        # Test 5: Send STOP_LIVE_SCAN command
        print("5. Testing STOP_LIVE_SCAN command...")
        sock.send("STOP_LIVE_SCAN\n".encode())
        print("   ✓ Command sent")
        
        # Test 6: Wait for stop response
        print("6. Waiting for stop response...")
        sock.settimeout(5)
        try:
            data = sock.recv(1024).decode('utf-8').strip()
            print(f"   ✓ Received: {data}")
            if "LIVE_SCAN_STOPPED" in data:
                print("   ✓ Live scan stopped successfully")
            else:
                print(f"   ⚠ Unexpected response: {data}")
        except socket.timeout:
            print("   ⚠ No stop response received (timeout)")
        
        # Test 7: Test ping/pong
        print("7. Testing ping/pong...")
        sock.send("PING\n".encode())
        print("   ✓ Ping sent")
        
        sock.settimeout(3)
        try:
            data = sock.recv(1024).decode('utf-8').strip()
            print(f"   ✓ Received: {data}")
        except socket.timeout:
            print("   ⚠ No pong received (timeout)")
        
        sock.close()
        print("\n" + "=" * 50)
        print("✓ All tests completed successfully!")
        return True
        
    except socket.timeout as e:
        print(f"   ❌ Connection timeout: {e}")
    except ConnectionRefusedError:
        print("   ❌ Connection refused - ESP32 not listening on port 8888")
    except socket.gaierror as e:
        print(f"   ❌ DNS resolution failed: {e}")
    except Exception as e:
        print(f"   ❌ Unexpected error: {e}")
    
    print("\n" + "=" * 50)
    print("❌ Connection test failed!")
    return False

def main():
    """Main function"""
    print("ESP32 Connection Test Tool")
    print("=" * 50)
    
    # Check command line arguments
    if len(sys.argv) > 1:
        ip = sys.argv[1]
    else:
        ip = "192.168.4.1"
    
    if len(sys.argv) > 2:
        try:
            port = int(sys.argv[2])
        except ValueError:
            print("Invalid port number")
            return
    else:
        port = 8888
    
    print(f"Target: {ip}:{port}")
    print()
    
    # Run the test
    success = test_esp32_connection(ip, port)
    
    if not success:
        print("\nTroubleshooting tips:")
        print("1. Ensure ESP32 is powered on")
        print("2. Check that ESP32 WiFi AP 'ZYNC_Device' is active")
        print("3. Verify you're connected to the ZYNC_Device network")
        print("4. Check ESP32 serial output for errors")
        print("5. Try restarting the ESP32 device")
        print("6. Verify the ESP32 code is uploaded and running")
        sys.exit(1)

if __name__ == "__main__":
    main()
