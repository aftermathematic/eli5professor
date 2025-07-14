#!/usr/bin/env python
"""
Script to read mentions from CSV file, generate ELI5 replies, and send each as an embed message to a Discord channel via webhook.
"""

import os
import csv
import re
import time
import requests
import logging
import json
import boto3
import fcntl
import tempfile
from typing import List, Dict, Any, Optional, Set
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger("post_replies")

class Config:
    """Configuration class for the post replies script."""
    def __init__(self):
        self.MENTIONS_CSV = 'mentions.csv'
        # Use environment variable for API URL, fallback to deployed service
        self.ELI5_API_URL = os.getenv('ELI5_API_URL', 'https://8friecshgc.eu-west-3.awsapprunner.com/explain')
        self.NUM_MENTIONS = 10    # 10 mentions per batch
        self.WAIT_MINUTES = 1     # 1 minute wait between batches
        self.TWITTER_ACCOUNT_HANDLE = 'eli5professor'
        
        # Load Discord credentials from AWS Secrets Manager or environment variables
        self.DISCORD_WEBHOOK_URL = self._get_discord_webhook_url()
        
    def _get_discord_webhook_url(self) -> str:
        """Get Discord webhook URL from AWS Secrets Manager or environment variables."""
        # First try environment variable (for local development)
        webhook_url = os.getenv('DISCORD_WEBHOOK_URL')
        if webhook_url:
            # Check if the environment variable contains a secret reference
            if webhook_url.startswith('eli5-discord-bot/discord-credentials-dev:'):
                logger.info("Environment variable contains AWS Secrets Manager reference, resolving...")
                secret_key = webhook_url.split(':')[1]  # Extract the key after the colon
                try:
                    session = boto3.Session()
                    secrets_client = session.client('secretsmanager', region_name='eu-west-3')
                    
                    response = secrets_client.get_secret_value(
                        SecretId='eli5-discord-bot/discord-credentials-dev'
                    )
                    
                    credentials = json.loads(response['SecretString'])
                    resolved_value = credentials.get(secret_key)
                    
                    if resolved_value:
                        logger.info(f"✅ Successfully resolved {secret_key} from AWS Secrets Manager")
                        return resolved_value
                    else:
                        logger.error(f"Key {secret_key} not found in secrets")
                        
                except Exception as e:
                    logger.error(f"Error resolving secret reference: {e}")
            else:
                logger.info("Using Discord webhook URL from environment variable")
                return webhook_url
            
        # Try to get from AWS Secrets Manager
        try:
            logger.info("Attempting to load Discord credentials from AWS Secrets Manager...")
            session = boto3.Session()
            secrets_client = session.client('secretsmanager', region_name='eu-west-3')
            
            response = secrets_client.get_secret_value(
                SecretId='eli5-discord-bot/discord-credentials-dev'
            )
            
            credentials = json.loads(response['SecretString'])
            
            # Get Discord webhook URL from secrets
            webhook_url = credentials.get('DISCORD_WEBHOOK_URL')
            if webhook_url:
                logger.info("✅ Successfully loaded Discord webhook URL from AWS Secrets Manager")
                return webhook_url
            
        except Exception as e:
            logger.warning(f"Could not load from AWS Secrets Manager: {e}")
            
        # Fallback to hardcoded webhook URL
        logger.info("Using fallback Discord webhook URL")
        return 'https://discord.com/api/webhooks/1386452801143705751/1U-yOwx8soK57EwEOMUBAD09fTFHEvWTmV9WKGpmXFnXgBgyspBaZuxK_fzI4Ub9AYXY'

class MentionProcessor:
    """Class to process mentions and extract topics."""
    def __init__(self, config: Config):
        self.config = config

    def extract_topic(self, text: str) -> Optional[str]:
        pattern = rf'@{self.config.TWITTER_ACCOUNT_HANDLE}\b'
        text = re.sub(pattern, '', text, flags=re.IGNORECASE)
        text = re.sub(r'#\w+', '', text)
        topic = text.strip().lstrip(":,-.@!# ")
        return topic if topic else None

class ELI5Generator:
    """Class to generate ELI5 explanations using the API."""
    def __init__(self, config: Config):
        self.config = config

    def generate_explanation(self, topic: str) -> str:
        try:
            response = requests.post(
                self.config.ELI5_API_URL,
                json={"subject": topic},
                timeout=30
            )
            if response.status_code == 200:
                data = response.json()
                return data.get('explanation', f"Sorry, I couldn't explain '{topic}' right now. #ELI5")
            else:
                logger.error(f"API request failed with status code {response.status_code}: {response.text}")
                return f"Sorry, I couldn't explain '{topic}' right now. #ELI5"
        except Exception as e:
            logger.error(f"Error generating explanation for '{topic}': {e}")
            return f"Sorry, I couldn't explain '{topic}' right now. #ELI5"

class DiscordClient:
    """Class to send messages to a Discord webhook."""
    def __init__(self, webhook_url: str):
        self.webhook_url = webhook_url

    def send_message(self, title: str, description: str, author_name: str) -> bool:
        payload = {
            "username": "eli5professor",
            "embeds": [
                {
                    "title": title,
                    "description": description,
                    "author": {
                        "name": author_name
                    }
                }
            ]
        }
        try:
            resp = requests.post(self.webhook_url, json=payload, timeout=10)
            if resp.status_code in (200, 204):
                logger.info(f"Successfully posted to Discord: {title}")
                return True
            else:
                logger.error(f"Discord webhook failed! Status: {resp.status_code}, Body: {resp.text}")
                return False
        except Exception as e:
            logger.error(f"Error posting to Discord: {e}")
            return False

class MentionsReader:
    """Class to read and process mentions from a CSV file with distributed locking."""
    def __init__(self, config: Config):
        self.config = config
        self.mention_processor = MentionProcessor(config)
        self.eli5_generator = ELI5Generator(config)
        self.discord_client = DiscordClient(self.config.DISCORD_WEBHOOK_URL)
        self.lock_file_path = '/tmp/eli5_mentions_processing.lock'
        self.processed_ids_file = '/tmp/eli5_processed_ids.txt'

    def read_mentions(self) -> List[Dict[str, Any]]:
        mentions = []
        try:
            with open(self.config.MENTIONS_CSV, 'r', newline='', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    mentions.append(row)
            logger.info(f"Read {len(mentions)} mentions from CSV")
            return mentions
        except Exception as e:
            logger.error(f"Error reading mentions from CSV: {e}")
            return []

    def get_oldest_mentions(self, num_mentions: int = 10) -> List[Dict[str, Any]]:
        mentions = self.read_mentions()
        mentions.sort(key=lambda x: x.get('timestamp', ''))
        oldest_mentions = mentions[:num_mentions]
        logger.info(f"Selected {len(oldest_mentions)} oldest mentions")
        return oldest_mentions

    def remove_mentions_from_csv(self, tweet_ids: Set[str]) -> None:
        if not tweet_ids:
            return
        try:
            all_mentions = []
            with open(self.config.MENTIONS_CSV, 'r', newline='', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                fieldnames = reader.fieldnames
                for row in reader:
                    if row.get('tweet_id') not in tweet_ids:
                        all_mentions.append(row)
            with open(self.config.MENTIONS_CSV, 'w', newline='', encoding='utf-8') as f:
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()
                writer.writerows(all_mentions)
            logger.info(f"Removed {len(tweet_ids)} mentions from CSV")
        except Exception as e:
            logger.error(f"Error removing mentions from CSV: {e}")

    def load_processed_ids(self) -> Set[str]:
        """Load previously processed tweet IDs from file."""
        processed_ids = set()
        try:
            if os.path.exists(self.processed_ids_file):
                with open(self.processed_ids_file, 'r') as f:
                    processed_ids = set(line.strip() for line in f if line.strip())
                logger.info(f"Loaded {len(processed_ids)} previously processed IDs")
        except Exception as e:
            logger.error(f"Error loading processed IDs: {e}")
        return processed_ids

    def save_processed_id(self, tweet_id: str) -> None:
        """Save a processed tweet ID to file."""
        try:
            with open(self.processed_ids_file, 'a') as f:
                f.write(f"{tweet_id}\n")
        except Exception as e:
            logger.error(f"Error saving processed ID {tweet_id}: {e}")

    def acquire_lock(self) -> Optional[int]:
        """Acquire a file lock to prevent multiple instances from processing simultaneously."""
        try:
            lock_fd = os.open(self.lock_file_path, os.O_CREAT | os.O_WRONLY | os.O_TRUNC)
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            logger.info("🔒 Acquired processing lock")
            return lock_fd
        except (OSError, IOError) as e:
            logger.info("⏳ Another instance is already processing mentions, skipping...")
            return None

    def release_lock(self, lock_fd: int) -> None:
        """Release the file lock."""
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            os.close(lock_fd)
            os.unlink(self.lock_file_path)
            logger.info("🔓 Released processing lock")
        except Exception as e:
            logger.error(f"Error releasing lock: {e}")

    def process_mentions(self) -> bool:
        # Try to acquire lock to prevent multiple instances from processing simultaneously
        lock_fd = self.acquire_lock()
        if lock_fd is None:
            return False  # Another instance is processing
        
        try:
            # Load previously processed IDs to avoid duplicates
            processed_ids = self.load_processed_ids()
            
            mentions = self.get_oldest_mentions(self.config.NUM_MENTIONS)
            if not mentions:
                logger.warning("No mentions found to process")
                return False

            processed_tweet_ids = set()

            for i, mention in enumerate(mentions, 1):
                text = mention.get('text', '')
                tweet_id = mention.get('tweet_id', '')
                
                # Skip if already processed
                if tweet_id in processed_ids:
                    logger.info(f"Skipping already processed mention {tweet_id}")
                    continue
                
                topic = self.mention_processor.extract_topic(text)
                if not topic:
                    logger.warning(f"Could not extract topic from mention: {text}")
                    continue
                    
                explanation = self.eli5_generator.generate_explanation(topic)
                author_id = mention.get('author_id', 'unknown') 
                username = mention.get('author_username', 'unknown')

                print(f"\n--- Mention {i} ---")
                print(f"Tweet ID: {tweet_id}")
                print(f"Author ID: @{author_id}")
                print(f"Text: {text}")
                print(f"Topic: {topic}")
                print(f"Reply: {explanation}")
                print("-" * 50)

                # Send to Discord
                ok = self.discord_client.send_message(
                    title=topic,
                    description=explanation,
                    author_name=f"@{username}"
                )
                if ok:
                    processed_tweet_ids.add(tweet_id)
                    self.save_processed_id(tweet_id)  # Save immediately to prevent duplicates
                    # Remove this specific mention from CSV immediately to prevent reprocessing
                    self.remove_mentions_from_csv({tweet_id})
                    logger.info(f"✅ Successfully processed mention {i}/{len(mentions)} - {tweet_id}")
                else:
                    logger.warning(f"❌ Failed to post to Discord for mention {i}/{len(mentions)} - {tweet_id}")

            # Final cleanup - remove any remaining processed mentions from the CSV
            if processed_tweet_ids:
                self.remove_mentions_from_csv(processed_tweet_ids)

            # Check if there are more mentions to process
            remaining_mentions = self.read_mentions()
            return len(remaining_mentions) > 0
            
        finally:
            # Always release the lock
            self.release_lock(lock_fd)

def main():
    try:
        logger.info("Starting post replies script...")
        config = Config()
        mentions_reader = MentionsReader(config)
        while True:
            mentions_reader.process_mentions()
            # Wait before checking for new mentions again
            logger.info("Waiting 30 seconds before checking for new mentions...")
            time.sleep(30)
    except KeyboardInterrupt:
        logger.info("Script stopped by user")
    except Exception as e:
        logger.error(f"Error in post replies script: {e}", exc_info=True)

if __name__ == "__main__":
    main()
