#!/bin/bash

cd "$(dirname "$0")"

echo "punff"
echo "─────"
echo ""
echo "1) add photos"
echo "2) camera manager (GUI)"
echo "3) rebuild site"
echo "4) view locally"
echo "5) deploy to server"
echo ""

read -p "> " choice

case $choice in
  1)
    node scripts/new-post.js
    ;;
   2)
    ./launch-camera-manager-py.sh
    ;;
  3)
    ./build.sh
    ;;
  4)
    if command -v python3 &> /dev/null; then
      echo "http://localhost:8000"
      echo "(ctrl+c to stop)"
      python3 -m http.server 8000
    elif command -v python &> /dev/null; then
      echo "http://localhost:8000"
      echo "(ctrl+c to stop)"
      python -m SimpleHTTPServer 8000
    else
      echo "open index.html in browser"
    fi
    ;;
  5)
    ./deploy.sh
    ;;
  *)
    echo "invalid"
    exit 1
    ;;
esac
