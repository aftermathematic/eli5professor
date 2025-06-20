print("Starting ELI5 Bot")

import os
os.environ["HF_HUB_DISABLE_SYMLINKS_WARNING"] = "1"
# Suppress TensorFlow warnings
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"  # 0=all, 1=no INFO, 2=no INFO/WARNING, 3=no INFO/WARNING/ERROR

import re
import time
import logging
import tweepy
import openai
from typing import Optional, Dict, Any, Union, List, Tuple
from dotenv import load_dotenv
from model_loader import get_model, get_tokenizer
import torch

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("eli5bot.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("eli5bot")

# Load environment variables from .env file
load_dotenv()

# Configuration
class Config:
    """Configuration class for the Twitter ELI5 bot."""
    # Twitter API credentials
    API_KEY = os.getenv('TWITTER_API_KEY')
    API_SECRET = os.getenv('TWITTER_API_SECRET')
    ACCESS_TOKEN = os.getenv('TWITTER_ACCESS_TOKEN')
    ACCESS_TOKEN_SECRET = os.getenv('TWITTER_ACCESS_TOKEN_SECRET')
    BEARER_TOKEN = os.getenv('TWITTER_BEARER_TOKEN')
    TWITTER_ACCOUNT_HANDLE = os.getenv('TWITTER_ACCOUNT_HANDLE')
    TWITTER_USER_ID = os.getenv('TWITTER_USER_ID')
    
    # OpenAI configuration
    OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
    OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-3.5-turbo')
    
    # Bot configuration
    LAST_SEEN_FILE = os.getenv('LAST_SEEN_FILE', 'last_seen_id.txt')
    POLL_INTERVAL = int(os.getenv('POLL_INTERVAL', '960'))  # 16 minutes by default
    MAX_TWEET_LENGTH = 280
    USE_LOCAL_MODEL_FALLBACK = os.getenv('USE_LOCAL_MODEL_FALLBACK', 'true').lower() == 'true'
    
    # Prompt configuration
    ELI5_PROMPT_TEMPLATE = """
You're a funny, helpful assistant that explains things in the simplest, silliest way possible — like you're talking to someone with no background knowledge. Be clear, funny, and very simple, but still informative.
Explain the following like I'm completely clueless and 5 years old. Avoid jargon, use analogies, and make it fun:
{subject}
End your response with '#ELI5'
The response must not exceed 280 characters (including spaces, punctuation, and hashtags)
"""

# Initialize clients
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
        params = {'max_results': 10}
        if since_id:
            params['since_id'] = since_id
            
        try:
            # Create a fresh client for this request
            client = self._create_v2_client()
            mentions = client.get_users_mentions(id=user_id, **params)
            return mentions.data or []
        except tweepy.errors.TooManyRequests as e:
            logger.warning(f"Rate limit hit while fetching mentions: {e}")
            raise
        except Exception as e:
            logger.error(f"Error fetching mentions: {e}")
            return []
    
    def post_reply(self, response_text: str, tweet_id: Union[int, str]) -> Optional[Dict[str, Any]]:
        """Post a reply to a tweet."""
        try:
            # Create a fresh client for this request
            client = self._create_v2_client()
            reply = client.create_tweet(
                text=response_text,
                in_reply_to_tweet_id=tweet_id
            )
            logger.info(f"Replied to tweet {tweet_id}")
            return reply
        except tweepy.errors.TooManyRequests as e:
            logger.warning(f"Rate limit hit while posting reply: {e}")
            raise
        except Exception as e:
            logger.error(f"Error posting reply to tweet {tweet_id}: {e}")
            return None
    
    def check_rate_limit(self) -> Dict[str, Any]:
        """Check current rate limits."""
        try:
            # Create a fresh API client for this request
            api = self._create_v1_api()
            status = api.rate_limit_status()
            return status
        except Exception as e:
            logger.error(f"Could not retrieve rate limit status: {e}")
            return {}

class LLMClient:
    """Class to handle LLM interactions (OpenAI and local model)."""
    def __init__(self, config: Config):
        self.config = config
        
        # Check if OpenAI API key is available
        self.has_openai_key = bool(config.OPENAI_API_KEY)
        if self.has_openai_key:
            logger.info("OpenAI API key found")
        else:
            logger.warning("OpenAI API key not found, will use local model only")
        
        # Initialize local model if fallback is enabled
        self.use_local_model_fallback = config.USE_LOCAL_MODEL_FALLBACK
        if self.use_local_model_fallback:
            try:
                self.tokenizer = get_tokenizer()
                self.model = get_model()
                logger.info("Local model loaded for fallback")
            except Exception as e:
                logger.error(f"Failed to load local model: {e}")
                self.use_local_model_fallback = False
    
    def _create_openai_client(self):
        """Create a fresh OpenAI client for each request."""
        return openai.OpenAI(api_key=self.config.OPENAI_API_KEY)
    
    def generate_eli5_response(self, subject: str) -> str:
        """
        Generate an ELI5 explanation for the given subject.
        
        Args:
            subject: The topic to explain
            
        Returns:
            A simplified explanation formatted for Twitter
        """
        # Format the prompt
        prompt = self.config.ELI5_PROMPT_TEMPLATE.format(subject=subject)
        
        # Try OpenAI first if API key is available
        if self.has_openai_key:
            try:
                return self._generate_with_openai(prompt)
            except Exception as e:
                logger.error(f"OpenAI generation failed: {e}")
                if not self.use_local_model_fallback:
                    return f"Sorry, I couldn't explain '{subject}' right now. Try again later! #ELI5"
        
        # Fall back to local model if OpenAI fails or is not available
        if self.use_local_model_fallback:
            try:
                return self._generate_with_local_model(prompt)
            except Exception as e:
                logger.error(f"Local model generation failed: {e}")
                return f"Sorry, I couldn't explain '{subject}' right now. Try again later! #ELI5"
        
        # If we get here, both methods failed or weren't available
        return f"Sorry, I couldn't explain '{subject}' right now. Try again later! #ELI5"
    
    def _generate_with_openai(self, prompt: str) -> str:
        """Generate response using OpenAI API."""
        # Create a fresh client for this request
        client = self._create_openai_client()
        
        response = client.chat.completions.create(
            model=self.config.OPENAI_MODEL,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=500,
            temperature=0.8
        )
        explanation = response.choices[0].message.content.strip()
        return self._format_for_twitter(explanation)
    
    def _generate_with_local_model(self, prompt: str) -> str:
        """Generate response using local Hugging Face model."""
        # Tokenize the prompt
        inputs = self.tokenizer(prompt, return_tensors="pt", truncation=True, max_length=512)
        
        # Move to GPU if available
        if torch.cuda.is_available():
            inputs = {k: v.to("cuda") for k, v in inputs.items()}
        
        # Generate response
        with torch.no_grad():
            output_ids = self.model.generate(
                **inputs,
                max_length=150,  # Shorter for Twitter
                num_return_sequences=1,
                temperature=0.8,
                do_sample=True
            )
        
        # Decode the response
        explanation = self.tokenizer.decode(output_ids[0], skip_special_tokens=True)
        return self._format_for_twitter(explanation)
    
    def _format_for_twitter(self, explanation: str) -> str:
        """Format the explanation to fit Twitter's character limit and add hashtag."""
        # Ensure the explanation ends with #ELI5
        if "#ELI5" not in explanation:
            if len(explanation) + 6 <= self.config.MAX_TWEET_LENGTH:
                explanation = explanation.rstrip() + " #ELI5"
            else:
                allowed = self.config.MAX_TWEET_LENGTH - 6
                explanation = explanation[:allowed].rstrip() + " #ELI5"
        
        # Truncate if still too long
        if len(explanation) > self.config.MAX_TWEET_LENGTH:
            explanation = explanation[:self.config.MAX_TWEET_LENGTH - 3].rstrip() + "… #ELI5"
        
        return explanation

class LastSeenIdManager:
    """Class to manage the last seen tweet ID."""
    def __init__(self, config: Config):
        self.config = config
    
    def get_last_seen_id(self) -> Optional[int]:
        """Read the last seen tweet ID to avoid duplicate processing."""
        try:
            with open(self.config.LAST_SEEN_FILE, 'r') as f:
                return int(f.read().strip())
        except FileNotFoundError:
            logger.info(f"Last seen ID file not found at {self.config.LAST_SEEN_FILE}")
            return None
        except Exception as e:
            logger.error(f"Error reading last seen ID: {e}")
            return None
    
    def set_last_seen_id(self, last_id: Union[int, str]) -> None:
        """Record the latest processed tweet ID."""
        try:
            with open(self.config.LAST_SEEN_FILE, 'w') as f:
                f.write(str(last_id))
            logger.debug(f"Updated last seen ID to {last_id}")
        except Exception as e:
            logger.error(f"Error writing last seen ID: {e}")

class TweetProcessor:
    """Class to process tweets and extract keywords."""
    def __init__(self, config: Config):
        self.config = config
    
    def extract_keyword(self, text: str) -> Optional[str]:
        """
        Extract the keyword or subject from the tweet.
        Assumes format: '@your_bot_handle <keyword or phrase>'
        """
        pattern = rf'@{self.config.TWITTER_ACCOUNT_HANDLE}\b'
        text = re.sub(pattern, '', text, flags=re.IGNORECASE)
        subject = text.strip().lstrip(":,-.@!# ")
        subject = re.split(r'[@#]', subject)[0].strip()
        return subject if subject else None

class RateLimitHandler:
    """Class to handle rate limit exceptions."""
    @staticmethod
    def get_seconds_until_reset(exception: tweepy.errors.TooManyRequests) -> int:
        """Extract seconds until rate limit resets from Tweepy TooManyRequests exception."""
        reset = None
        if hasattr(exception, 'response') and exception.response is not None:
            reset_str = exception.response.headers.get('x-rate-limit-reset')
            # Print the x-rate-limit-reset header
            logger.info(f"Rate limit header x-rate-limit-reset: {reset_str}")
            
            if reset_str:
                try:
                    reset = int(reset_str)
                    now = int(time.time())
                    seconds_until_reset = max(reset - now, 0)
                    logger.info(f"Calculated seconds until reset: {seconds_until_reset}")
                    return seconds_until_reset
                except Exception as e:
                    logger.error(f"Error parsing rate limit reset time: {e}")
        
        # Default wait time if not found
        default_wait = 16 * 60
        logger.info(f"Using default wait time: {default_wait} seconds")
        return default_wait
    
    @staticmethod
    def wait_for_reset(seconds_left: int) -> None:
        """Wait for the rate limit to reset with progress updates."""
        buffer = 30  # Add a buffer to ensure rate limit has reset
        total_seconds = seconds_left + buffer
        logger.info(f"Rate limit hit. Waiting for {total_seconds} seconds before retrying.")
        
        # Sleep in shorter intervals with progress updates
        sleep_left = total_seconds
        while sleep_left > 0:
            logger.info(f"Sleeping for {sleep_left} seconds...")
            time.sleep(min(30, sleep_left))  # Sleep in shorter intervals
            sleep_left -= min(30, sleep_left)
        logger.info("Rate limit wait complete, resuming operations.")

class ELI5Bot:
    """Main bot class that orchestrates the Twitter ELI5 bot."""
    def __init__(self):
        """Initialize the bot with all required components."""
        self.config = Config()
        self.twitter_client = TwitterClient(self.config)
        self.llm_client = LLMClient(self.config)
        self.id_manager = LastSeenIdManager(self.config)
        self.tweet_processor = TweetProcessor(self.config)
        self.rate_limit_handler = RateLimitHandler()
        
        # Validate required configuration
        self._validate_config()
        
        logger.info("ELI5 Bot initialized successfully")
    
    def _validate_config(self) -> None:
        """Validate that all required configuration is present."""
        if not self.config.TWITTER_USER_ID:
            logger.error("TWITTER_USER_ID is not set in environment variables")
            raise ValueError("TWITTER_USER_ID is required")
        
        if not self.config.TWITTER_ACCOUNT_HANDLE:
            logger.error("TWITTER_ACCOUNT_HANDLE is not set in environment variables")
            raise ValueError("TWITTER_ACCOUNT_HANDLE is required")
        
        if not self.config.OPENAI_API_KEY and not self.llm_client.use_local_model_fallback:
            logger.error("Neither OpenAI API key nor local model fallback is available")
            raise ValueError("Either OPENAI_API_KEY or a local model is required")
    
    def process_mentions(self) -> None:
        """Process new mentions and generate responses."""
        # Get the user ID
        user_id = self.config.TWITTER_USER_ID
        try:
            user_id = int(user_id)
        except ValueError:
            pass  # Keep as string if not convertible to int
        
        # Get the last seen tweet ID
        last_seen_id = self.id_manager.get_last_seen_id()
        
        try:
            # Fetch mentions with a fresh connection
            mentions = self.twitter_client.get_mentions(user_id, last_seen_id)
            if not mentions:
                logger.info("No new mentions found")
                return
            
            logger.info(f"Processing {len(mentions)} new mentions")
            
            # Process each mention
            for tweet in reversed(mentions):  # Process oldest first
                text = tweet.text
                subject = self.tweet_processor.extract_keyword(text)
                
                if subject:
                    # Log the tweet being processed
                    logger.info(f"Processing tweet: {tweet.id} - Subject: {subject}")
                    
                    # Generate response
                    response = self.llm_client.generate_eli5_response(subject)

                    # Log the generated response
                    logger.info(f"Generated response for tweet {tweet.id}: {response}")
                    
                    # Post reply with a fresh connection
                    self.twitter_client.post_reply(response, tweet.id)
                else:
                    logger.info(f"No keyword detected in tweet: {tweet.id}")
                
                # Update last seen ID
                self.id_manager.set_last_seen_id(tweet.id)
        except Exception as e:
            logger.error(f"Error in process_mentions: {e}")
            # Don't re-raise to allow the main loop to continue
    
    def run(self) -> None:
        """Run the bot in a continuous loop."""
        logger.info("Starting Twitter ELI5 bot...")
        
        while True:
            try:
                # Process mentions
                self.process_mentions()
                
                # Use the default poll interval when no rate limit is hit
                total_sleep_time = self.config.POLL_INTERVAL
                logger.info(f"Waiting {total_sleep_time} seconds for new mentions...")
                
                sleep_left = total_sleep_time
                while sleep_left > 0:
                    # Sleep for 30 seconds or the remaining time if less than 30
                    sleep_interval = min(30, sleep_left)
                    time.sleep(sleep_interval)
                    sleep_left -= sleep_interval
                    
                    # Print update if there's still time left
                    if sleep_left > 0:
                        logger.info(f"Still waiting... {sleep_left} seconds remaining until next check")
            
            except tweepy.errors.TooManyRequests as e:
                # Get the actual time until rate limit reset
                seconds_left = self.rate_limit_handler.get_seconds_until_reset(e)
                
                # Use the rate limit reset time instead of the default poll interval
                logger.info(f"Rate limit hit. Using reset time ({seconds_left} seconds) instead of default poll interval.")
                
                # Add a small buffer to ensure rate limit has reset
                buffer = 30
                total_seconds = seconds_left + buffer
                
                # Sleep in shorter intervals with progress updates
                sleep_left = total_seconds
                while sleep_left > 0:
                    logger.info(f"Rate limit cooldown: {sleep_left} seconds remaining...")
                    time.sleep(min(30, sleep_left))
                    sleep_left -= min(30, sleep_left)
                
                logger.info("Rate limit cooldown complete, resuming operations.")

                print("rate limit - seconds_left: ", seconds_left)
            
            except Exception as e:
                logger.error(f"Unexpected error: {e}", exc_info=True)
                logger.info("Attempting to reconnect in 60 seconds...")
                time.sleep(60)

if __name__ == '__main__':
    try:
        bot = ELI5Bot()
        bot.run()
    except KeyboardInterrupt:
        logger.info("Bot stopped by user")
    except Exception as e:
        logger.critical(f"Fatal error: {e}", exc_info=True)
