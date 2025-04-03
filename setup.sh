#!/bin/bash

if [ "$1" == "--install" ]; then
  echo "Checking dependencies..."
  apt install coreutils 1> /dev/null
  echo "All dependencies installed."

  cp bku.sh /usr/local/bin/bku 
  echo "BKU installed to /usr/local/bin/bku."
fi

if [ "$1" == "--uninstall" ]; then
  echo "Checking BKU installation..."

  if [ ! -f /user/local/bin/bku ]; then
    echo "Error: BKU is not installed in /usr/local/bin/bku."
    echo "   Nothing to uninstall."
  fi

  rm -rf /usr/local/bin/bku
fi