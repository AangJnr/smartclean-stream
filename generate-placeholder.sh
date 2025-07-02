#!/bin/bash
set -e

mkdir -p ./stream/cam
rm -rf ./stream/cam/*

echo "▶ Generating HLS from placeholder.mp4..."

ffmpeg -re -i placeholder.mp4 \
  -c:v libx264 -c:a aac -f hls \
  -hls_time 2 -hls_list_size 3 -hls_flags delete_segments \
  ./stream/cam/index.m3u8

echo "✅ Video placeholder HLS stream generated."
