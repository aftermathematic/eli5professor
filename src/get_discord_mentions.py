#!/usr/bin/env python
"""
Script to listen for mentions of a specific user (TARGET_USER_ID, e.g. @eliprofessor) in a Discord channel,
and add only the keyword after the mention to the mentions.csv file.
Includes robust diagnostics and MLOps-quality traceability.
"""

import os
import csv
import time
import discord
import logging
import asyncio
import re
from datetime import datetime, timedelta
from typing import Set
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configure logging for full diagnostics
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger("discord_mentions")

class Config:
    """Configuration class for the Discord mentions script."""
    def __init__(self):
        self.MENTIONS_CSV = 'mentions.csv'
        self.CHECK_INTERVAL_SECONDS = 20
        self.TARGET_MENTION = 'eliprofessor'
        self.DISCORD_TOKEN = os.getenv('DISCORD_BOT_TOKEN')
        self.DISCORD_CHANNEL_ID = int(os.getenv('DISCORD_CHANNEL_ID', '0'))
        self.DISCORD_SERVER_ID = int(os.getenv('DISCORD_SERVER_ID', '0'))
        self.TARGET_USER_ID = int(os.getenv('TARGET_USER_ID', '0'))

        if not self.DISCORD_TOKEN:
            raise ValueError("DISCORD_BOT_TOKEN environment variable is required")
        if self.DISCORD_CHANNEL_ID == 0:
            raise ValueError("DISCORD_CHANNEL_ID environment variable is required")
        if self.DISCORD_SERVER_ID == 0:
            raise ValueError("DISCORD_SERVER_ID environment variable is required")
        if self.TARGET_USER_ID == 0:
            raise ValueError("TARGET_USER_ID environment variable is required")

class MentionsWriter:
    """Class to write mentions to a CSV file."""
    def __init__(self, config: Config):
        self.config = config
        self.ensure_csv_exists()

    def ensure_csv_exists(self) -> None:
        """Ensure the mentions CSV file exists with the correct headers."""
        if not os.path.exists(self.config.MENTIONS_CSV):
            with open(self.config.MENTIONS_CSV, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow(['timestamp', 'tweet_id', 'author_id', 'author_username', 'text'])
            logger.info(f"Created new mentions CSV file: {self.config.MENTIONS_CSV}")

    def add_mention(self, message_id: str, author_id: str, author_username: str, keyword: str) -> None:
        """Add a new mention to the CSV file."""
        timestamp = datetime.now().isoformat()
        try:
            with open(self.config.MENTIONS_CSV, 'a', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow([timestamp, message_id, author_id, author_username, keyword])
            logger.info(f"Added new mention from {author_username} ({author_id}) to CSV")
        except Exception as e:
            logger.error(f"Error adding mention to CSV: {e}")

class DiscordListener:
    """Class to listen for mentions in a Discord channel."""
    def __init__(self, config: Config, mentions_writer: MentionsWriter):
        self.config = config
        self.mentions_writer = mentions_writer

        # Set up intents
        intents = discord.Intents.default()
        intents.message_content = True   # Required for reading content and mentions
        intents.guilds = True

        self.client = discord.Client(intents=intents)
        self.processed_messages: Set[str] = set()
        self.last_check_time = datetime.now()
        self.setup_event_handlers()

    def was_target_mentioned(self, message: discord.Message) -> bool:
        """
        Detects if the bot itself is mentioned AND the message contains #eli5 hashtag.
        """
        # Check if the bot itself is mentioned
        bot_mentioned = self.client.user in message.mentions if self.client.user else False
        
        # Also check for the configured TARGET_USER_ID as fallback
        target_id = self.config.TARGET_USER_ID
        target_mentioned = (
            any(u.id == target_id for u in message.mentions) or
            f"<@{target_id}>" in message.content or
            f"<@!{target_id}>" in message.content
        )
        
        # Check for #eli5 hashtag (case insensitive)
        has_eli5_hashtag = "#eli5" in message.content.lower()
        
        # Bot mentioned OR target mentioned, AND has #eli5 hashtag
        mentioned = bot_mentioned or target_mentioned
        valid_mention = mentioned and has_eli5_hashtag
        
        logger.debug(f"[mention detection] mentions: {[(u.name, u.id) for u in message.mentions]}, "
                     f"bot_id: {self.client.user.id if self.client.user else 'None'}, "
                     f"TARGET_USER_ID: {target_id}, Bot mentioned? {bot_mentioned}, "
                     f"Target mentioned? {target_mentioned}, Has #eli5? {has_eli5_hashtag}, Valid? {valid_mention}")
        return valid_mention

    def extract_keyword(self, message: discord.Message) -> str:
        """
        Remove the mention (e.g., <@1298992235148218481> or <@!1298992235148218481>)
        and return the remaining text stripped.
        """
        content = message.content
        
        # Remove bot mention if present
        if self.client.user:
            bot_id = self.client.user.id
            bot_pattern = re.compile(rf'<@!?\s*{bot_id}>\s*')
            content = bot_pattern.sub('', content)
        
        # Also remove TARGET_USER_ID mention as fallback
        target_id = self.config.TARGET_USER_ID
        target_pattern = re.compile(rf'<@!?\s*{target_id}>\s*')
        content = target_pattern.sub('', content)
        
        return content.strip()

    async def set_bot_avatar_if_needed(self) -> None:
        """Set the bot's avatar if it doesn't have one."""
        try:
            if self.client.user and not self.client.user.avatar:
                logger.info("Bot has no avatar set, attempting to set one...")
                
                # Use a simple professor/academic icon
                avatar_url = "https://cdn-icons-png.flaticon.com/512/3135/3135715.png"
                
                import aiohttp
                async with aiohttp.ClientSession() as session:
                    async with session.get(avatar_url) as resp:
                        if resp.status == 200:
                            avatar_data = await resp.read()
                            await self.client.user.edit(avatar=avatar_data)
                            logger.info("Successfully set bot avatar!")
                        else:
                            logger.warning(f"Failed to download avatar image: {resp.status}")
            else:
                logger.info("Bot already has an avatar set")
        except Exception as e:
            logger.warning(f"Could not set bot avatar: {e}")

    def setup_event_handlers(self) -> None:
        """Set up Discord event handlers with diagnostics."""

        @self.client.event
        async def on_ready():
            logger.info(f"Logged in as: {self.client.user} (ID: {self.client.user.id})")
            logger.info(f"Connected guilds: {[f'{g.name} ({g.id})' for g in self.client.guilds]}")
            
            # Try to set avatar if not already set
            await self.set_bot_avatar_if_needed()
            
            # Log all text channels the bot can see in the relevant guild
            for guild in self.client.guilds:
                if guild.id == self.config.DISCORD_SERVER_ID:
                    logger.info(f"Channels in '{guild.name}':")
                    for channel in guild.text_channels:
                        logger.info(f"    Channel: {channel.name} (ID: {channel.id})")
            logger.info(f"Listening for mentions of user ID {self.config.TARGET_USER_ID} in channel {self.config.DISCORD_CHANNEL_ID}")
            self.client.loop.create_task(self.periodic_check_mentions())

        @self.client.event
        async def on_message(message):
            logger.debug(
                f"[on_message] Received in guild: {getattr(message.guild, 'id', '?')}, "
                f"channel: {message.channel.id} by {message.author} ({message.author.id}): "
                f"{message.content!r} | mentions: {[u.id for u in message.mentions]}"
            )

            if message.channel.id != self.config.DISCORD_CHANNEL_ID:
                return

            if self.was_target_mentioned(message):
                if str(message.id) not in self.processed_messages:
                    logger.info(f"[MENTION DETECTED] From: {message.author.name} (id={message.author.id}) | Content: {message.content!r}")
                    keyword = self.extract_keyword(message)
                    self.mentions_writer.add_mention(
                        message_id=str(message.id),
                        author_id=str(message.author.id),
                        author_username=message.author.name,
                        keyword=keyword
                    )
                    self.processed_messages.add(str(message.id))

    async def check_for_mentions(self) -> None:
        """Check for mentions in the target channel (history scan)."""
        try:
            guild = self.client.get_guild(self.config.DISCORD_SERVER_ID)
            if not guild:
                logger.warning(f"Could not find server with ID {self.config.DISCORD_SERVER_ID}")
                return

            channel = guild.get_channel(self.config.DISCORD_CHANNEL_ID)
            if not channel:
                logger.warning(f"Could not find channel with ID {self.config.DISCORD_CHANNEL_ID} in server {guild.name}")
                return

            logger.debug(f"[history check] Checking history after {self.last_check_time - timedelta(minutes=5)}")

            after_time = self.last_check_time - timedelta(minutes=5)
            messages = []

            async for message in channel.history(after=after_time, limit=100):
                logger.debug(
                    f"[history message] ID: {message.id} | author: {message.author} ({message.author.id}) | "
                    f"content: {message.content!r} | mentions: {[u.id for u in message.mentions]}"
                )
                messages.append(message)

            self.last_check_time = datetime.now()

            for message in messages:
                if self.was_target_mentioned(message):
                    if str(message.id) not in self.processed_messages:
                        logger.info(f"[MENTION DETECTED - HISTORY] From: {message.author.name} (id={message.author.id}) | Content: {message.content!r}")
                        keyword = self.extract_keyword(message)
                        self.mentions_writer.add_mention(
                            message_id=str(message.id),
                            author_id=str(message.author.id),
                            author_username=message.author.name,
                            keyword=keyword
                        )
                        self.processed_messages.add(str(message.id))

            if len(self.processed_messages) > 1000:
                self.processed_messages = set(list(self.processed_messages)[-500:])

        except Exception as e:
            logger.error(f"Error checking for mentions: {e}")

    async def periodic_check_mentions(self) -> None:
        """Periodically check for mentions in the target channel."""
        while True:
            await asyncio.sleep(self.config.CHECK_INTERVAL_SECONDS)
            logger.info("Performing periodic check for mentions...")
            await self.check_for_mentions()

    async def start(self) -> None:
        """Start the Discord client."""
        try:
            await self.client.start(self.config.DISCORD_TOKEN)
        except Exception as e:
            logger.error(f"Error starting Discord client: {e}")

    def run(self) -> None:
        """Run the Discord client in the current thread."""
        try:
            asyncio.run(self.start())
        except KeyboardInterrupt:
            logger.info("Discord listener stopped by user")
        except Exception as e:
            logger.error(f"Error in Discord listener: {e}", exc_info=True)

def main():
    try:
        logger.info("Starting Discord mentions listener...")
        config = Config()
        mentions_writer = MentionsWriter(config)
        discord_listener = DiscordListener(config, mentions_writer)
        discord_listener.run()
    except KeyboardInterrupt:
        logger.info("Script stopped by user")
    except Exception as e:
        logger.error(f"Error in Discord mentions script: {e}", exc_info=True)

if __name__ == "__main__":
    main()
