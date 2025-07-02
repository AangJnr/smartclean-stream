#!/bin/bash
set -e

PROJECT_DIR="$HOME/smartclean-stream"
STREAM_DIR="$PROJECT_DIR/stream/cam"

mkdir -p "$STREAM_DIR"
rm -rf "$STREAM_DIR"/*

echo "▶ Generating placeholder HLS stream from video..."

ffmpeg -y -re -i "$PROJECT_DIR/placeholder.mp4" \
  -c:v libx264 -c:a aac -preset veryfast \
  -f hls -hls_time 2 -hls_list_size 3 -hls_flags delete_segments \
  "$STREAM_DIR/index.m3u8"

echo "✅ HLS placeholder stream generated at $STREAM_DIR"
