#!/usr/bin/env python
"""
Simple Discord bot that runs the mention listener and reply poster without API dependencies.
"""

import asyncio
import threading
import uvicorn
import logging
import time
from fastapi import FastAPI

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('eli5bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("discord_bot_simple")

# Create a simple FastAPI app for health checks
app = FastAPI()

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "discord-bot", "version": "1.0.2", "deployment_test": "simple-bot"}

@app.get("/")
async def root():
    return {"message": "Discord Bot is running (simple version)"}

def run_health_server():
    """Run the health check server in a separate thread"""
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")

def run_discord_listener():
    """Run the Discord mention listener"""
    try:
        from get_discord_mentions import main as run_listener
        logger.info("Starting Discord mention listener...")
        run_listener()
    except Exception as e:
        logger.error(f"Error in Discord listener: {e}", exc_info=True)

def run_reply_processor():
    """Run the reply processor"""
    try:
        from post_replies import MentionsReader, Config as PostRepliesConfig
        import os
        import csv
        
        logger.info("Starting reply processor...")
        config = PostRepliesConfig()
        
        # Ensure mentions.csv exists
        if not os.path.exists('mentions.csv'):
            logger.info("Creating empty mentions.csv file...")
            with open('mentions.csv', 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow(['timestamp', 'tweet_id', 'author_id', 'author_username', 'text'])
        
        mentions_reader = MentionsReader(config)
        
        while True:
            try:
                logger.info("Processing mentions from CSV...")
                mentions_reader.process_mentions()
                time.sleep(30)  # Process every 30 seconds
            except KeyboardInterrupt:
                logger.info("Reply processor stopped by user")
                break
            except Exception as e:
                logger.error(f"Error in reply processor: {e}", exc_info=True)
                time.sleep(60)  # Wait longer on error
                
    except Exception as e:
        logger.error(f"Error starting reply processor: {e}", exc_info=True)

if __name__ == "__main__":
    logger.info("Starting simple Discord bot...")
    
    # Start the health check server in a separate thread
    health_thread = threading.Thread(target=run_health_server, daemon=True)
    health_thread.start()
    logger.info("Health server started")
    
    # Start the Discord listener in a separate thread
    listener_thread = threading.Thread(target=run_discord_listener, daemon=True)
    listener_thread.start()
    logger.info("Discord listener started")
    
    # Run the reply processor in the main thread
    run_reply_processor()
