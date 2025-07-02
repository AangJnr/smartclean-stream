#!/bin/bash
set -e

mkdir -p ./stream/cam
rm -rf ./stream/cam/*

echo "▶ Generating placeholder HLS stream from video..."

ffmpeg -y -re -i placeholder.mp4 \
  -c:v libx264 -c:a aac -preset veryfast \
  -f hls -hls_time 2 -hls_list_size 3 -hls_flags delete_segments \
  ./stream/cam/index.m3u8

echo "✅ HLS placeholder stream generated at ./stream/cam/"