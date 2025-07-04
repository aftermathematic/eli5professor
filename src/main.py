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
import csv
import datetime
import random
import yaml
import os.path
from typing import Optional, Dict, Any, Union, List, Tuple
from dotenv import load_dotenv
from model_loader import get_model, get_tokenizer
import torch

# Load environment variables from .env file
load_dotenv()

# Configuration Loader
class ConfigLoader:
    """Class to load configuration from YAML file."""
    @staticmethod
    def load_config(config_path: str = "config/config.yml") -> Dict[str, Any]:
        """Load configuration from YAML file."""
        try:
            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
            return config
        except Exception as e:
            print(f"Error loading configuration from {config_path}: {e}")
            print("Using default configuration")
            return {}

# Load configuration
config_data = ConfigLoader.load_config()

# Configure logging
logging_config = config_data.get('logging', {})
logging.basicConfig(
    level=getattr(logging, logging_config.get('level', 'INFO')),
    format=logging_config.get('format', '%(asctime)s - %(name)s - %(levelname)s - %(message)s'),
    handlers=[
        logging.FileHandler(logging_config.get('log_file', 'eli5bot.log')),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("eli5bot")

# Configuration
class Config:
    """Configuration class for the Twitter ELI5 bot."""
    def __init__(self, config_data: Dict[str, Any]):
        self.config_data = config_data
        
        # Twitter API credentials
        self.API_KEY = os.getenv('TWITTER_API_KEY')
        self.API_SECRET = os.getenv('TWITTER_API_SECRET')
        self.ACCESS_TOKEN = os.getenv('TWITTER_ACCESS_TOKEN')
        self.ACCESS_TOKEN_SECRET = os.getenv('TWITTER_ACCESS_TOKEN_SECRET')
        self.BEARER_TOKEN = os.getenv('TWITTER_BEARER_TOKEN')
        self.TWITTER_ACCOUNT_HANDLE = os.getenv('TWITTER_ACCOUNT_HANDLE')
        self.TWITTER_USER_ID = os.getenv('TWITTER_USER_ID')
        
        # OpenAI configuration
        self.OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
        self.OPENAI_MODEL = self._get_config('openai.model', os.getenv('OPENAI_MODEL', 'gpt-3.5-turbo'))
        
        # Bot configuration
        self.LAST_SEEN_FILE = self._get_config('paths.last_seen_file', os.getenv('LAST_SEEN_FILE', 'last_seen_id.txt'))
        self.POLL_INTERVAL = int(self._get_config('twitter.poll_interval', os.getenv('POLL_INTERVAL', '960')))
        self.MAX_TWEET_LENGTH = int(self._get_config('twitter.max_tweet_length', 280))
        self.USE_LOCAL_MODEL_FALLBACK = self._get_config('openai.use_local_model_fallback', 
                                                        os.getenv('USE_LOCAL_MODEL_FALLBACK', 'true').lower() == 'true')
        
        # Dataset configuration
        self.DATASET_PATH = self._get_config('dataset.examples_dataset_path', 
                                            os.getenv('DATASET_PATH', 'data/dataset.csv'))
        self.ELI5_DATASET_PATH = self._get_config('dataset.eli5_dataset_path', 'data/eli5_dataset.csv')
        self.NUM_EXAMPLES = int(self._get_config('dataset.num_examples', 
                                                os.getenv('NUM_EXAMPLES', '3')))
        
        # Prompt configuration
        self.ELI5_PROMPT_TEMPLATE = self._get_config('prompts.eli5_prompt_template', """
Explain the following like I'm 5 years old. Keep it under 260 characters:
{subject}

End your response with '#ELI5'
""")
        
        self.SYSTEM_PROMPT = self._get_config('prompts.system_prompt', 
                                             "You are an assistant that explains concepts to 5-year-olds. Mimic the style and tone of the examples provided. Keep responses under 260 characters and end with #ELI5.")
    
    def _get_config(self, key_path: str, default: Any) -> Any:
        """Get a configuration value from the YAML config using dot notation."""
        keys = key_path.split('.')
        value = self.config_data
        
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return default
        
        return value

class DatasetLoader:
    """Class to load and process the dataset of examples."""
    def __init__(self, dataset_path: str = "data/dataset.csv"):
        self.dataset_path = dataset_path
        self.examples = []
        self._load_dataset()
        logger.info(f"Dataset loader initialized with {len(self.examples)} examples from {dataset_path}")
    
    def _load_dataset(self) -> None:
        """Load examples from the dataset file."""
        try:
            with open(self.dataset_path, 'r', newline='', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if 'term' in row and 'explanation' in row:
                        self.examples.append({
                            'term': row['term'],
                            'explanation': row['explanation']
                        })
        except Exception as e:
            logger.error(f"Error loading dataset: {e}")
    
    def get_random_examples(self, num_examples: int = 3) -> List[Dict[str, str]]:
        """Get a random selection of examples from the dataset."""
        if not self.examples:
            return []
        
        # Return random examples, but no more than what's available
        num_to_return = min(num_examples, len(self.examples))
        return random.sample(self.examples, num_to_return)

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
        
        # Load dataset examples
        self.dataset_loader = DatasetLoader(config.DATASET_PATH)
        logger.info(f"Loaded {len(self.dataset_loader.examples)} examples from dataset")
    
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
        """Generate response using OpenAI API with few-shot examples."""
        # Create a fresh client for this request
        client = self._create_openai_client()
        
        # Get random examples from the dataset
        examples = self.dataset_loader.get_random_examples(self.config.NUM_EXAMPLES)
        
        # Create messages array with system prompt and examples
        messages = [
            {"role": "system", "content": self.config.SYSTEM_PROMPT}
        ]
        
        # Add examples as conversation pairs
        for example in examples:
            messages.append({"role": "user", "content": f"Explain {example['term']} like I'm 5 years old"})
            messages.append({"role": "assistant", "content": example['explanation']})
        
        # Add the current request
        messages.append({"role": "user", "content": prompt})
        
        # Generate response
        response = client.chat.completions.create(
            model=self.config.OPENAI_MODEL,
            messages=messages,
            max_tokens=self.config._get_config('openai.max_tokens', 500),
            temperature=self.config._get_config('openai.temperature', 0.8)
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

class DatasetLogger:
    """Class to log tweet data to a dataset file."""
    def __init__(self, dataset_path: str = "data/eli5_dataset.csv"):
        self.dataset_path = dataset_path
        logger.info(f"Dataset logger initialized with path: {dataset_path}")
    
    def log_interaction(self, tweet_id: Union[int, str], subject: str, response: str) -> None:
        """
        Log a tweet interaction to the dataset file.
        
        Args:
            tweet_id: The ID of the tweet
            subject: The extracted subject from the tweet
            response: The generated ELI5 response
        """
        try:
            timestamp = datetime.datetime.now().isoformat()
            
            # Escape any commas, quotes, or newlines in the text fields
            subject_escaped = subject.replace('"', '""')
            response_escaped = response.replace('"', '""')
            
            # Write to CSV file
            with open(self.dataset_path, 'a', newline='', encoding='utf-8') as f:
                writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
                writer.writerow([timestamp, tweet_id, subject_escaped, response_escaped])
            
            logger.info(f"Logged interaction for tweet {tweet_id} to dataset")
        except Exception as e:
            logger.error(f"Error logging to dataset: {e}")

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
        self.config = Config(config_data)
        self.twitter_client = TwitterClient(self.config)
        self.llm_client = LLMClient(self.config)
        self.id_manager = LastSeenIdManager(self.config)
        self.tweet_processor = TweetProcessor(self.config)
        self.rate_limit_handler = RateLimitHandler()
        self.dataset_logger = DatasetLogger(self.config.ELI5_DATASET_PATH)
        
        # Log the number of examples loaded from the dataset
        logger.info(f"Loaded {len(self.llm_client.dataset_loader.examples)} examples from dataset for few-shot learning")
        
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
                    
                    # Log to dataset
                    self.dataset_logger.log_interaction(tweet.id, subject, response)
                    
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
