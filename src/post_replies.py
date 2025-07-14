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
        self.DISCORD_WEBHOOK_URL = os.getenv('DISCORD_WEBHOOK_URL', 'https://discord.com/api/webhooks/1386452801143705751/1U-yOwx8soK57EwEOMUBAD09fTFHEvWTmV9WKGpmXFnXgBgyspBaZuxK_fzI4Ub9AYXY')

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
    """Class to read and process mentions from a CSV file."""
    def __init__(self, config: Config):
        self.config = config
        self.mention_processor = MentionProcessor(config)
        self.eli5_generator = ELI5Generator(config)
        self.discord_client = DiscordClient(self.config.DISCORD_WEBHOOK_URL)

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

    def process_mentions(self) -> bool:
        mentions = self.get_oldest_mentions(self.config.NUM_MENTIONS)
        if not mentions:
            logger.warning("No mentions found to process")
            return False

        processed_tweet_ids = set()

        for i, mention in enumerate(mentions, 1):
            text = mention.get('text', '')
            tweet_id = mention.get('tweet_id', '')
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
                logger.info(f"Successfully processed mention {i}/{len(mentions)}")
            else:
                logger.warning(f"Failed to post to Discord for mention {i}/{len(mentions)}")

        # Remove processed mentions from the CSV
        if processed_tweet_ids:
            self.remove_mentions_from_csv(processed_tweet_ids)

        # Check if there are more mentions to process
        remaining_mentions = self.read_mentions()
        return len(remaining_mentions) > 0

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
