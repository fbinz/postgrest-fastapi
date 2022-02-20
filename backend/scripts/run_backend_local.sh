#!/bin/sh

# Start development web server
echo Starting server on 0.0.0.0:8000
python -m uvicorn src.app:app --host 0.0.0.0 --reload