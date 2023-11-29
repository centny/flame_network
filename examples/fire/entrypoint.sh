#!/bin/bash
cd /app/
xvfb-run --server-args="-screen 0 800x600x24+32" /app/fire
