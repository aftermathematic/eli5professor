import os
import re
import time
import tweepy
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Authentication credentials
API_KEY = os.getenv('TWITTER_API_KEY')
API_SECRET = os.getenv('TWITTER_API_SECRET')
ACCESS_TOKEN = os.getenv('TWITTER_ACCESS_TOKEN')
ACCESS_TOKEN_SECRET = os.getenv('TWITTER_ACCESS_TOKEN_SECRET')
BEARER_TOKEN = os.getenv('TWITTER_BEARER_TOKEN')
TWITTER_ACCOUNT_HANDLE = os.getenv('TWITTER_ACCOUNT_HANDLE')
TWITTER_USER_ID = os.getenv('TWITTER_USER_ID')

# v1.1 Auth for rate_limit_status (mainly for visibility)
auth = tweepy.OAuth1UserHandler(API_KEY, API_SECRET, ACCESS_TOKEN, ACCESS_TOKEN_SECRET)
api = tweepy.API(auth)

# v2 Client for fetching mentions and (later) posting replies
client = tweepy.Client(
    bearer_token=BEARER_TOKEN,
    consumer_key=API_KEY,
    consumer_secret=API_SECRET,
    access_token=ACCESS_TOKEN,
    access_token_secret=ACCESS_TOKEN_SECRET
)

LAST_SEEN_FILE = 'last_seen_id.txt'

def get_seconds_until_reset(exception):
    """Extract seconds until rate limit resets from Tweepy TooManyRequests exception."""
    reset = None
    if hasattr(exception, 'response') and exception.response is not None:
        reset_str = exception.response.headers.get('x-rate-limit-reset')
        if reset_str:
            try:
                reset = int(reset_str)
                now = int(time.time())
                return max(reset - now, 0)
            except Exception:
                pass
    # Default wait time if not found
    return 20 * 60

def get_user_id_with_retry():
    while True:
        try:
            user = client.get_user(username=TWITTER_ACCOUNT_HANDLE)

            print(f"User ID for @{TWITTER_ACCOUNT_HANDLE} is {user.data.id}")

            return user.data.id
        except tweepy.errors.TooManyRequests as e:
            seconds_left = get_seconds_until_reset(e)
            buffer = 60  # seconds
            print(f"Rate limit hit while fetching user id.")

            sleep_left = seconds_left + buffer
            # Sleep until the rate limit resets, print updates every 10 seconds
            while sleep_left > 0:
                print(f"Sleeping for {sleep_left} seconds...")
                time.sleep(10)
                sleep_left -= 10

            #time.sleep(seconds_left + buffer)
        except Exception as e:
            print(f"Error fetching user info: {e}")
            time.sleep(60)

def get_last_seen_id():
    """Read the last seen tweet ID to avoid duplicate processing."""
    try:
        with open(LAST_SEEN_FILE, 'r') as f:
            return int(f.read().strip())
    except FileNotFoundError:
        return None

def set_last_seen_id(last_id):
    """Record the latest processed tweet ID."""
    with open(LAST_SEEN_FILE, 'w') as f:
        f.write(str(last_id))

def extract_keyword(text):
    """
    Extract the keyword or subject from the tweet.
    Assumes format: '@eli5professor <keyword or phrase>'
    """
    # Remove your handle
    pattern = rf'@{TWITTER_ACCOUNT_HANDLE}\b'
    text = re.sub(pattern, '', text, flags=re.IGNORECASE)
    # Strip whitespace and leading punctuation
    subject = text.strip().lstrip(":,-.@!# ")
    # Stop at another mention or hashtag (if any)
    subject = re.split(r'[@#]', subject)[0].strip()
    return subject if subject else None

def generate_eli5_response(subject):
    """
    Placeholder for LLM/AI: returns a fake ELI5 answer.
    Replace with your model or API call.
    """
    return f"Here's an ELI5 explanation for '{subject}': [your AI-powered answer here!]"

def process_mentions(user_id):
    """
    Fetch and process new mentions of your account.
    For testing, prints responses instead of replying.
    """
    last_seen_id = get_last_seen_id()
    params = {'max_results': 10}
    if last_seen_id:
        params['since_id'] = last_seen_id

    mentions = client.get_users_mentions(id=user_id, **params)

    if not mentions.data:
        return

    for tweet in reversed(mentions.data):
        text = tweet.text
        subject = extract_keyword(text)
        if subject:
            print("==== Matched Tweet ====")
            print(f"Text: {text}")
            print(f"Extracted subject: {subject}")
            response = generate_eli5_response(subject)
            print("ELI5 response (not posted):")
            print(response)
            print("=" * 24)
            # For testing, do not reply!
            # To activate tweeting, uncomment below:
            # try:
            #     client.create_tweet(
            #         text=response,
            #         in_reply_to_tweet_id=tweet.id
            #     )
            #     print("Replied to tweet.")
            # except tweepy.errors.TooManyRequests as e:
            #     seconds_left = get_seconds_until_reset(e)
            #     print(f"Rate limit hit while replying. Sleeping for {seconds_left} seconds...")
            #     time.sleep(seconds_left)
            #     break
            # except Exception as e:
            #     print(f"Error sending reply: {e}")
        else:
            print("No keyword/subject detected in tweet.")
        set_last_seen_id(tweet.id)

def check_rate_limit():
    """
    Print current v1.1 API rate limits.
    Only useful for v1.1 endpoints (e.g., media, oauth on Free tier)
    """
    try:
        status = api.rate_limit_status()
        print("Rate limit status:", status)
        print(status["resources"]["statuses"])
    except Exception as e:
        print("Could not retrieve rate limit status:", e)

if __name__ == '__main__':

    print("==============================")
    print("Starting Twitter ELI5 bot...")
    print("==============================")

    #user_id = get_user_id_with_retry()
    user_id = TWITTER_USER_ID
    while True:
        try:
            process_mentions(user_id)

            print("Waiting for new mentions...")
            # Check rate limits every 10 minutes
            check_rate_limit()

            time.sleep(1200)  # Poll every minute
        except tweepy.errors.TooManyRequests as e:
            seconds_left = get_seconds_until_reset(e)
            buffer = 60  # seconds
            print(f"Rate limit hit while fetching mentions.")

            sleep_left = seconds_left + buffer
            # Sleep until the rate limit resets, print updates every 10 seconds
            while sleep_left > 0:
                print(f"Sleeping for {sleep_left} seconds...")
                time.sleep(10)
                sleep_left -= 10

            #time.sleep(seconds_left + buffer)
        except Exception as e:
            print(f"Unexpected error: {e}")
            time.sleep(60)