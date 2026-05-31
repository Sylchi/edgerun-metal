#!/usr/bin/env bash
set -euo pipefail

CAM_IF="${1:-3-1:1.0}"
VIDEO_DEV="${2:-/dev/video0}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: missing required command: $1" >&2
    exit 1
  }
}

need v4l2-ctl
need readlink
need ls

if [ ! -e "$VIDEO_DEV" ]; then
  echo "error: video device not found: $VIDEO_DEV" >&2
  exit 1
fi

echo "camera-live: before"
ls -l /dev/video* 2>/dev/null || true

echo "camera-live: probing capabilities"
v4l2-ctl -d "$VIDEO_DEV" --all >/tmp/camera_pre.txt 2>&1 || true

echo "camera-live: unbind ${CAM_IF}"
sudo sh -c "echo ${CAM_IF} > /sys/bus/usb/drivers/uvcvideo/unbind"
sleep 1

echo "camera-live: bind ${CAM_IF}"
sudo sh -c "echo ${CAM_IF} > /sys/bus/usb/drivers/uvcvideo/bind"
sleep 2

echo "camera-live: after"
ls -l /dev/video* 2>/dev/null || true

if [ -e "$VIDEO_DEV" ]; then
  readlink -f "/sys/class/video4linux/$(basename "$VIDEO_DEV")/device/driver" || true
fi

echo "camera-live: formats"
v4l2-ctl -d "$VIDEO_DEV" --list-formats-ext | sed -n '1,80p'

echo "camera-live: streaming sanity"
v4l2-ctl -d "$VIDEO_DEV" --stream-mmap=3 --stream-count=20 --stream-to=/dev/null >/tmp/camera_stream.txt 2>&1 || true
sed -n '1,60p' /tmp/camera_stream.txt

echo "camera-live: done"
