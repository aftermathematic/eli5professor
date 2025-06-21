FROM python:3.10-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir fastapi uvicorn[standard] pydantic

# Copy source code and configuration
COPY src/ ./src/
COPY config/ ./config/
COPY .env .

# Create volume mount point for persistent data
VOLUME /app/data

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV LAST_SEEN_FILE=/app/data/last_seen_id.txt

# Run the bot
CMD ["python", "src/main.py"]
