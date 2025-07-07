#!/bin/bash

# Script to test the Twitter Bot container locally

echo "Testing Twitter Bot container locally"
echo "===================================="
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
docker build -t eli5-twitter-bot:local -f Dockerfile.twitter-bot .

if [ $? -ne 0 ]; then
    echo "Failed to build Docker image."
    exit 1
fi

echo "Docker image built successfully."

# Run the Docker container
echo ""
echo "Running Docker container..."
docker run -it --rm \
    -v "$(pwd)/data:/app/data" \
    -v "$(pwd)/config:/app/config" \
    --env-file .env.test \
    --name eli5-twitter-bot \
    eli5-twitter-bot:local

echo ""
echo "Container exited."
echo ""
echo "Check the logs to see if the Twitter Bot is working correctly."
echo "If you want to run the container in the background, use:"
echo "docker run -d -v \"$(pwd)/data:/app/data\" -v \"$(pwd)/config:/app/config\" --env-file .env --name eli5-twitter-bot eli5-twitter-bot:local"
echo ""
