#!/usr/bin/env python
"""
Discord ELI5 Bot - Main implementation using existing get_discord_mentions.py
"""

import os
import asyncio
import logging
import csv
import time
from datetime import datetime
from dotenv import load_dotenv
from get_discord_mentions import main as run_discord_listener
from post_replies import process_mentions_and_reply

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('eli5bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("discord_eli5bot_main")

def lambda_handler(event, context):
    """
    AWS Lambda handler function for the ELI5 Discord bot.
    
    Args:
        event: AWS Lambda event object
        context: AWS Lambda context object
        
    Returns:
        Dict with statusCode and body
    """
    try:
        logger.info("Lambda function invoked for Discord bot")
        logger.info(f"Event: {event}")
        
        # Process any existing mentions in the CSV file
        process_mentions_and_reply()
        
        return {
            'statusCode': 200,
            'body': 'Successfully processed Discord mentions'
        }
    except Exception as e:
        logger.error(f"Error in lambda_handler: {e}", exc_info=True)
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }

def run_continuous_bot():
    """Run the Discord bot continuously (for local/container deployment)."""
    logger.info("Starting Discord ELI5 bot in continuous mode...")
    
    # Start the Discord listener in a separate process/thread
    import threading
    
    def run_listener():
        try:
            run_discord_listener()
        except Exception as e:
            logger.error(f"Discord listener error: {e}", exc_info=True)
    
    # Start Discord listener thread
    listener_thread = threading.Thread(target=run_listener, daemon=True)
    listener_thread.start()
    
    # Main loop to process mentions
    while True:
        try:
            logger.info("Processing mentions from CSV...")
            process_mentions_and_reply()
            
            # Wait before next processing cycle
            time.sleep(30)  # Process every 30 seconds
            
        except KeyboardInterrupt:
            logger.info("Bot stopped by user")
            break
        except Exception as e:
            logger.error(f"Error in main loop: {e}", exc_info=True)
            time.sleep(60)  # Wait longer on error

if __name__ == '__main__':
    try:
        # Check if running in Lambda environment
        if os.getenv('AWS_LAMBDA_FUNCTION_NAME'):
            logger.info("Running in Lambda environment")
        else:
            # Run continuous bot for local/container deployment
            run_continuous_bot()
    except KeyboardInterrupt:
        logger.info("Bot stopped by user")
    except Exception as e:
        logger.critical(f"Fatal error: {e}", exc_info=True)
