#!/bin/sh
set -e

arch=$1
version=$2

cd /tmp

# Cleanup any previous installation files
rm -rf "rclone-v$version-linux-$arch.zip" "rclone-v$version-linux-$arch"

# Download and unzip
curl -O "https://downloads.rclone.org/v$version/rclone-v$version-linux-$arch.zip"
unzip "rclone-v$version-linux-$arch.zip"
cd "rclone-v$version-linux-$arch"

# Copy binary file
sudo cp ./rclone /usr/local/bin/
sudo chown "root:root" /usr/local/bin/rclone
sudo chmod 755 /usr/local/bin/rclone

