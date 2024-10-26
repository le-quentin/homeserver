#!/bin/sh
set -e

version=1.68.1
arch=$1

cd /tmp

# Download and unzip
curl -O "https://downloads.rclone.org/v$version/rclone-v$version-linux-$arch.zip"
unzip "rclone-v$version-linux-$arch.zip"
cd rclone-*-linux-$arch

# Copy binary file
sudo cp rclone /usr/local/bin/
sudo chown "root:root" /usr/local/bin/rclone
sudo chmod 755 /usr/local/bin/rclone

