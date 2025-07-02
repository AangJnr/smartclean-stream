#!/bin/bash
set -e
cd "$(dirname "$0")"

mkdir -p ./stream/cam
rm -rf ./stream/cam/*

echo "▶ Generating placeholder HLS stream from video..."

ffmpeg -y -re -i placeholder.mp4 \
  -c:v libx264 -c:a aac -preset veryfast \
  -f hls \
  -hls_time 1 \                      # shorter segments (1s)
  -hls_list_size 5 \
  -hls_flags independent_segments \
  ./stream/cam/index.m3u8

echo "✅ Placeholder stream ready."