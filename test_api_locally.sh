#!/bin/bash

# Script to test the ELI5 API container locally

echo "Testing ELI5 API container locally"
echo "=================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install it first:"
    echo "https://docs.docker.com/get-docker/"
    exit 1
fi

# Create data directory if it doesn't exist
mkdir -p data

# Build the Docker image
echo "Building Docker image..."
docker build -t eli5-api:local .

if [ $? -ne 0 ]; then
    echo "Failed to build Docker image."
    exit 1
fi

echo "Docker image built successfully."

# Run the Docker container
echo ""
echo "Running Docker container..."
docker run -it --rm \
    -v "$(pwd)/config:/app/config" \
    -p 8000:8000 \
    --env-file .env \
    --name eli5-api \
    eli5-api:local \
    python -m uvicorn src.app:app --host 0.0.0.0 --port 8000

echo ""
echo "Container exited."
echo ""
echo "Check the logs to see if the API is working correctly."
echo "If you want to run the container in the background, use:"
echo "docker run -d -v \"$(pwd)/config:/app/config\" -p 8000:8000 --env-file .env --name eli5-api eli5-api:local python -m uvicorn src.app:app --host 0.0.0.0 --port 8000"
echo ""
echo "You can access the API at: http://localhost:8000"
echo "API documentation is available at: http://localhost:8000/docs"
echo ""
