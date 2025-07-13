import asyncio
import threading
import uvicorn
from fastapi import FastAPI
from main import run_continuous_bot


# Create a simple FastAPI app for health checks
app = FastAPI()


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "discord-bot"}


@app.get("/")
async def root():
    return {"message": "Discord Bot is running"}


def run_health_server():
    """Run the health check server in a separate thread"""
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")


def run_discord_bot():
    """Run the Discord bot"""
    run_continuous_bot()


if __name__ == "__main__":
    # Start the health check server in a separate thread
    health_thread = threading.Thread(target=run_health_server, daemon=True)
    health_thread.start()
    
    # Run the Discord bot in the main thread
    run_discord_bot()
