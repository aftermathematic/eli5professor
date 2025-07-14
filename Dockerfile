FROM python:3.10-slim AS builder

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/app/deps \
    fastapi \
    uvicorn[standard] \
    pydantic \
    python-dotenv \
    openai \
    transformers \
    pyyaml \
    requests \
    discord.py \
    mlflow \
    pandas \
    scikit-learn && \
    pip install --no-cache-dir --target=/app/deps torch --index-url https://download.pytorch.org/whl/cpu

# Use a smaller base image for the final stage
FROM python:3.10-slim

WORKDIR /app

# Copy only the necessary dependencies
COPY --from=builder /app/deps /app/deps
ENV PYTHONPATH=/app/deps:$PYTHONPATH

# Copy source code and configuration
COPY src/ ./src/
COPY config/ ./config/
COPY .env .
COPY data/ /app/data/

# Create volume mount point for persistent data
VOLUME /app/data

# Ensure data directory exists
RUN mkdir -p /app/data

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV LAST_SEEN_FILE=/app/data/last_seen_id.txt

# Default command to run the API
CMD ["python", "-m", "uvicorn", "src.app:app", "--host", "0.0.0.0", "--port", "8000"]
