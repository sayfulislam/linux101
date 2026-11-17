#!/bin/bash

# The server you want to check — change this to your server's IP or hostname
SERVER="162.4.35.67"

# -c 3 = send 3 packets, -W 2 = wait max 2 seconds for each reply
if ping -c 3 -W 2 "$SERVER" > /dev/null 2>&1; then
    echo "✅ SUCCESS: $SERVER is reachable."
    exit 0
else
    echo "❌ FAILED: $SERVER is not responding."
    exit 1
fi
