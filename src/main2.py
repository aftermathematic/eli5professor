#!/usr/bin/env python
"""
Simplified Twitter bot that only fetches mentions and saves them to a CSV file.
Includes rate limit checking before fetching mentions.
"""

import os
import time
import logging
import tweepy
import csv
import datetime
from typing import Optional, Dict, Any, Union, List
from dotenv import load_dotenv
from ratelimit import RateLimitChecker, get_wait_time_from_exception

# Load environment variables from .env file
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('mentions_bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("mentions_bot")

class Config:
    """Configuration class for the Twitter mentions bot."""
    def __init__(self):
        # Twitter API credentials
        self.API_KEY = os.getenv('TWITTER_API_KEY')
        self.API_SECRET = os.getenv('TWITTER_API_SECRET')
        self.ACCESS_TOKEN = os.getenv('TWITTER_ACCESS_TOKEN')
        self.ACCESS_TOKEN_SECRET = os.getenv('TWITTER_ACCESS_TOKEN_SECRET')
        self.BEARER_TOKEN = os.getenv('TWITTER_BEARER_TOKEN')
        self.TWITTER_USER_ID = os.getenv('TWITTER_USER_ID')
        
        # Bot configuration
        self.LAST_SEEN_FILE = os.getenv('LAST_SEEN_FILE', 'last_seen_id.txt')
        self.MENTIONS_CSV = os.getenv('MENTIONS_CSV', 'mentions.csv')
        self.WAIT_BUFFER = 30  # Additional seconds to wait after rate limit reset

class TwitterClient:
    """Class to handle Twitter API interactions."""
    def __init__(self, config: Config):
        self.config = config
        logger.info("Twitter client initialized")
    
    def _create_v1_api(self):
        """Create a new v1.1 API client for each request."""
        auth = tweepy.OAuth1UserHandler(
            self.config.API_KEY, 
            self.config.API_SECRET, 
            self.config.ACCESS_TOKEN, 
            self.config.ACCESS_TOKEN_SECRET
        )
        return tweepy.API(auth)
    
    def _create_v2_client(self):
        """Create a new v2 Client for each request."""
        return tweepy.Client(
            bearer_token=self.config.BEARER_TOKEN,
            consumer_key=self.config.API_KEY,
            consumer_secret=self.config.API_SECRET,
            access_token=self.config.ACCESS_TOKEN,
            access_token_secret=self.config.ACCESS_TOKEN_SECRET
        )
    
    def get_mentions(self, user_id: str, since_id: Optional[int] = None) -> List[Dict[str, Any]]:
        """Fetch mentions for the user."""
        params = {'max_results': 10, 'expansions': 'author_id'}
        if since_id:
            params['since_id'] = since_id
            
        try:
            # Create a fresh client for this request
            client = self._create_v2_client()
            response = client.get_users_mentions(id=user_id, **params)
            
            # Return empty list if no data
            if not response.data:
                return []
            
            # Get user information for each author_id
            author_ids = [tweet.author_id for tweet in response.data if hasattr(tweet, 'author_id')]
            usernames = {}
            
            if author_ids:
                try:
                    # Fetch user information in batches of 100 (Twitter API limit)
                    for i in range(0, len(author_ids), 100):
                        batch = author_ids[i:i+100]
                        users_response = client.get_users(ids=batch)
                        if users_response.data:
                            for user in users_response.data:
                                usernames[user.id] = user.username
                except Exception as e:
                    logger.error(f"Error fetching user information: {e}")
            
            # Add username to each tweet
            mentions = []
            for tweet in response.data:
                # Convert tweet to dictionary
                tweet_dict = {
                    'id': tweet.id,
                    'author_id': tweet.author_id if hasattr(tweet, 'author_id') else None,
                    'text': tweet.text if hasattr(tweet, 'text') else ''
                }
                
                # Add username if available
                if hasattr(tweet, 'author_id') and tweet.author_id in usernames:
                    tweet_dict['username'] = usernames[tweet.author_id]
                else:
                    tweet_dict['username'] = None
                
                mentions.append(tweet_dict)
                
            return mentions
        except tweepy.errors.TooManyRequests as e:
            logger.warning(f"Rate limit hit while fetching mentions: {e}")
            # Get rate limit info from the exception
            seconds_to_wait = get_wait_time_from_exception(e)
            logger.info(f"Need to wait {seconds_to_wait} seconds before retrying")
            raise
        except Exception as e:
            logger.error(f"Error fetching mentions: {e}")
            return []
    
    def check_rate_limit(self) -> Dict[str, Any]:
        """Check current rate limits."""
        try:
            # Create a fresh API client for this request
            api = self._create_v1_api()
            status = api.rate_limit_status()
            
            # Check specifically for the mentions endpoint
            if 'resources' in status and 'users' in status['resources']:
                for endpoint, data in status['resources']['users'].items():
                    if 'mentions' in endpoint:
                        limit = data.get('limit', 0)
                        remaining = data.get('remaining', 0)
                        reset = data.get('reset', 0)
                        
                        # Calculate seconds until reset
                        now = int(time.time())
                        reset_in_seconds = max(reset - now, 0)
                        
                        logger.info(f"Rate limit for mentions: {remaining}/{limit}, resets in {reset_in_seconds} seconds")
                        
                        return {
                            'endpoint': endpoint,
                            'limit': limit,
                            'remaining': remaining,
                            'reset': reset,
                            'reset_in_seconds': reset_in_seconds,
                            'is_rate_limited': remaining <= 0 and reset_in_seconds > 0
                        }
            
            # If we couldn't find the specific endpoint, check for any rate limit
            for resource_type, resources in status.get('resources', {}).items():
                for endpoint, data in resources.items():
                    if data.get('remaining', 1) <= 0:
                        reset = data.get('reset', 0)
                        now = int(time.time())
                        reset_in_seconds = max(reset - now, 0)
                        
                        if reset_in_seconds > 0:
                            logger.warning(f"Rate limit detected for {endpoint}: resets in {reset_in_seconds} seconds")
                            return {
                                'endpoint': endpoint,
                                'limit': data.get('limit', 0),
                                'remaining': 0,
                                'reset': reset,
                                'reset_in_seconds': reset_in_seconds,
                                'is_rate_limited': True
                            }
            
            # No rate limits found
            return {
                'is_rate_limited': False
            }
            
        except Exception as e:
            logger.error(f"Could not retrieve rate limit status: {e}")
            return {'is_rate_limited': False}  # Assume no rate limit if we can't check

class LastSeenIdManager:
    """Class to manage the last seen tweet ID."""
    def __init__(self, config: Config):
        self.config = config
        # Ensure the path is relative to the current directory
        self.last_seen_file = os.path.join('data', os.path.basename(self.config.LAST_SEEN_FILE))
        # Create the data directory if it doesn't exist
        os.makedirs('data', exist_ok=True)
    
    def get_last_seen_id(self) -> Optional[int]:
        """Read the last seen tweet ID to avoid duplicate processing."""
        try:
            with open(self.last_seen_file, 'r') as f:
                return int(f.read().strip())
        except FileNotFoundError:
            logger.info(f"Last seen ID file not found at {self.last_seen_file}")
            return None
        except Exception as e:
            logger.error(f"Error reading last seen ID: {e}")
            return None
    
    def set_last_seen_id(self, last_id: Union[int, str]) -> None:
        """Record the latest processed tweet ID."""
        try:
            with open(self.last_seen_file, 'w') as f:
                f.write(str(last_id))
            logger.debug(f"Updated last seen ID to {last_id}")
        except Exception as e:
            logger.error(f"Error writing last seen ID: {e}")

class MentionsLogger:
    """Class to log tweet mentions to a CSV file."""
    def __init__(self, config: Config):
        self.config = config
        self.csv_file = config.MENTIONS_CSV
        self.seen_tweet_ids = set()
        
        # Load existing tweet IDs from CSV if it exists
        self._load_existing_ids()
        
        logger.info(f"Mentions logger initialized with path: {self.csv_file}")
    
    def _load_existing_ids(self):
        """Load existing tweet IDs from the CSV file to avoid duplicates."""
        try:
            if os.path.exists(self.csv_file):
                with open(self.csv_file, 'r', newline='', encoding='utf-8') as f:
                    reader = csv.reader(f)
                    next(reader, None)  # Skip header
                    for row in reader:
                        if len(row) > 1:  # Ensure row has at least 2 columns
                            self.seen_tweet_ids.add(row[1])  # Tweet ID is in the second column
                logger.info(f"Loaded {len(self.seen_tweet_ids)} existing tweet IDs from CSV")
        except Exception as e:
            logger.error(f"Error loading existing tweet IDs: {e}")
    
    def log_mentions(self, mentions: List[Dict[str, Any]]) -> int:
        """
        Log tweet mentions to the CSV file.
        
        Args:
            mentions: List of tweet mention objects
            
        Returns:
            Number of new mentions added
        """
        if not mentions:
            return 0
        
        new_mentions = 0
        try:
            # Create file with header if it doesn't exist
            file_exists = os.path.exists(self.csv_file)
            
            with open(self.csv_file, 'a', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                
                # Write header if file is new
                if not file_exists:
                    writer.writerow(['timestamp', 'tweet_id', 'author_id', 'username', 'text'])
                
                # Write mentions
                timestamp = datetime.datetime.now().isoformat()
                for tweet in mentions:
                    tweet_id = str(tweet.get('id'))
                    
                    # Skip if we've already seen this tweet
                    if tweet_id in self.seen_tweet_ids:
                        continue
                    
                    writer.writerow([
                        timestamp,
                        tweet_id,
                        tweet.get('author_id'),
                        tweet.get('username'),
                        tweet.get('text', '').replace('\n', ' ').replace('\r', '')
                    ])
                    
                    # Add to seen set
                    self.seen_tweet_ids.add(tweet_id)
                    new_mentions += 1
            
            if new_mentions > 0:
                logger.info(f"Added {new_mentions} new mentions to CSV")
            
            return new_mentions
            
        except Exception as e:
            logger.error(f"Error logging mentions to CSV: {e}")
            return 0

class MentionsBot:
    """Main bot class that fetches Twitter mentions and saves them to CSV."""
    def __init__(self):
        """Initialize the bot with all required components."""
        self.config = Config()
        self.twitter_client = TwitterClient(self.config)
        self.id_manager = LastSeenIdManager(self.config)
        self.mentions_logger = MentionsLogger(self.config)
        
        # Validate required configuration
        self._validate_config()
        
        logger.info("Mentions bot initialized successfully")
    
    def _validate_config(self) -> None:
        """Validate that all required configuration is present."""
        if not self.config.TWITTER_USER_ID:
            logger.error("TWITTER_USER_ID is not set in environment variables")
            raise ValueError("TWITTER_USER_ID is required")
        
        if not all([self.config.API_KEY, self.config.API_SECRET, 
                   self.config.ACCESS_TOKEN, self.config.ACCESS_TOKEN_SECRET]):
            logger.error("Twitter API credentials are not set in environment variables")
            raise ValueError("Twitter API credentials are required")
    
    def fetch_mentions(self) -> None:
        """
        Fetch mentions with rate limit checking.
        
        This method:
        1. Checks for rate limits before fetching
        2. If rate limited, waits until the limit resets
        3. Fetches mentions and saves them to CSV
        """
        # Get the user ID
        user_id = self.config.TWITTER_USER_ID
        try:
            user_id = int(user_id)
        except ValueError:
            pass  # Keep as string if not convertible to int
        
        # Get the last seen tweet ID
        last_seen_id = self.id_manager.get_last_seen_id()
        
        # Check for rate limits before fetching
        rate_limit_info = self.twitter_client.check_rate_limit()
        
        if rate_limit_info.get('is_rate_limited', False):
            # We're rate limited, wait until reset
            reset_in_seconds = rate_limit_info.get('reset_in_seconds', 0)
            total_wait = reset_in_seconds + self.config.WAIT_BUFFER
            
            logger.warning(f"Rate limit in effect. Need to wait {total_wait} seconds before fetching mentions.")
            
            # Wait with status updates every 30 seconds
            remaining = total_wait
            while remaining > 0:
                logger.info(f"Waiting for rate limit to reset: {remaining} seconds remaining...")
                time.sleep(min(30, remaining))
                remaining -= min(30, remaining)
            
            logger.info("Rate limit wait complete. Proceeding to fetch mentions.")
        
        try:
            # Fetch mentions
            logger.info("Fetching mentions...")
            mentions = self.twitter_client.get_mentions(user_id, last_seen_id)
            
            if not mentions:
                logger.info("No new mentions found")
                return
            
            logger.info(f"Found {len(mentions)} new mentions")
            
            # Log mentions to CSV
            new_mentions = self.mentions_logger.log_mentions(mentions)
            logger.info(f"Added {new_mentions} unique mentions to CSV")
            
            # Update last seen ID if we have mentions
            if mentions:
                # Get the most recent mention ID
                most_recent_id = max(tweet.get('id') for tweet in mentions)
                self.id_manager.set_last_seen_id(most_recent_id)
                logger.info(f"Updated last seen ID to {most_recent_id}")
            
        except tweepy.errors.TooManyRequests as e:
            # Handle rate limit exception
            seconds_to_wait = get_wait_time_from_exception(e)
            logger.warning(f"Rate limit hit while fetching mentions. Need to wait {seconds_to_wait} seconds.")
            
            # Wait with status updates every 30 seconds
            remaining = seconds_to_wait + self.config.WAIT_BUFFER
            while remaining > 0:
                logger.info(f"Waiting for rate limit to reset: {remaining} seconds remaining...")
                time.sleep(min(30, remaining))
                remaining -= min(30, remaining)
            
            logger.info("Rate limit wait complete. Will try again on next run.")
            
        except Exception as e:
            logger.error(f"Error fetching mentions: {e}")

def main():
    """Main function to run the mentions bot."""
    try:
        logger.info("Starting Twitter mentions bot...")
        
        # Initialize the bot
        bot = MentionsBot()
        
        # Fetch mentions once
        bot.fetch_mentions()
        
        logger.info("Mentions bot run complete")
        
    except KeyboardInterrupt:
        logger.info("Bot stopped by user")
    except Exception as e:
        logger.critical(f"Fatal error: {e}", exc_info=True)

if __name__ == "__main__":
    main()
