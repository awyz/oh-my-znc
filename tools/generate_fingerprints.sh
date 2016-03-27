#!/bin/bash
fp=$(openssl s_client -showcerts -connect $1 </dev/null | openssl x509 -noout -sha256 -fingerprint | grep "Fingerprint" | tr '=' ' ' | awk '{print $3}')
server=$(echo $1 | tr ':' ' ' | awk '{print $1}')
port=$(echo $1 | tr ':' ' ' | awk '{print $2}')
echo $server","$port","$fp


