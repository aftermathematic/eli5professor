#!/usr/bin/env python
"""
Script to set the Discord bot's avatar image.
This should be run once to set the bot's profile picture.
"""

import os
import discord
import asyncio
import logging
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("avatar_setter")

async def set_bot_avatar():
    """Set the bot's avatar image."""
    
    # Get Discord token
    token = os.getenv('DISCORD_BOT_TOKEN')
    if not token:
        logger.error("DISCORD_BOT_TOKEN environment variable is required")
        return
    
    # Set up intents
    intents = discord.Intents.default()
    client = discord.Client(intents=intents)
    
    @client.event
    async def on_ready():
        logger.info(f"Logged in as: {client.user}")
        
        # Try to set avatar from a URL (using a simple professor/academic icon)
        try:
            # You can replace this URL with any image URL you prefer
            # This is a simple academic/professor icon from a free icon service
            avatar_url = "https://cdn-icons-png.flaticon.com/512/3135/3135715.png"
            
            import aiohttp
            async with aiohttp.ClientSession() as session:
                async with session.get(avatar_url) as resp:
                    if resp.status == 200:
                        avatar_data = await resp.read()
                        await client.user.edit(avatar=avatar_data)
                        logger.info("Successfully set bot avatar!")
                    else:
                        logger.error(f"Failed to download avatar image: {resp.status}")
        except Exception as e:
            logger.error(f"Error setting avatar: {e}")
        
        await client.close()
    
    try:
        await client.start(token)
    except Exception as e:
        logger.error(f"Error starting client: {e}")

if __name__ == "__main__":
    asyncio.run(set_bot_avatar())
