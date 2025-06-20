import os
import json
import time
import tweepy
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

def get_rate_limit_status():
    """
    Connect to the Twitter API and retrieve the current rate limit status.
    This is useful for debugging rate limit issues.
    """
    # Get Twitter API credentials from environment variables
    api_key = os.getenv('TWITTER_API_KEY')
    api_secret = os.getenv('TWITTER_API_SECRET')
    access_token = os.getenv('TWITTER_ACCESS_TOKEN')
    access_token_secret = os.getenv('TWITTER_ACCESS_TOKEN_SECRET')
    
    # Check if credentials are available
    if not all([api_key, api_secret, access_token, access_token_secret]):
        print("Error: Twitter API credentials not found in environment variables.")
        print("Make sure you have a .env file with the following variables:")
        print("TWITTER_API_KEY, TWITTER_API_SECRET, TWITTER_ACCESS_TOKEN, TWITTER_ACCESS_TOKEN_SECRET")
        return
    
    try:
        # Create OAuth1 authentication handler
        auth = tweepy.OAuth1UserHandler(
            api_key, 
            api_secret, 
            access_token, 
            access_token_secret
        )
        
        # Create API instance
        api = tweepy.API(auth)
        
        # Get rate limit status
        status = api.rate_limit_status()
        
        # Format the full status as JSON for the log file
        formatted_json = json.dumps(status, indent=2)
        
        # Write full status to log file (overwrite mode)
        with open("rate_limit_status.log", "w") as log_file:
            # Add timestamp
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            log_file.write(f"Twitter API Rate Limit Status {timestamp}\n\n")
            log_file.write(formatted_json)
            log_file.write("\n")
        
        print(f"Full rate limit status written to rate_limit_status.log")
        
        # Get current Unix timestamp
        current_time = int(time.time())
        
        # Print debug information about the current time
        print(f"Current Unix timestamp: {current_time}")
        print(f"Current time: {datetime.fromtimestamp(current_time).strftime('%Y-%m-%d %H:%M:%S')}")
        
        # Print endpoints with rate limit information
        print("\nEndpoints with rate limit information:")
        print("=====================================")
        
        # Track if we found any endpoints
        found_endpoints = False
        
        # Iterate through all resources and endpoints
        for resource_category, endpoints in status['resources'].items():
            for endpoint, data in endpoints.items():
                # Only process endpoints with remaining < limit (those that have been used)
                #if data['remaining'] < data['limit']:
                found_endpoints = True
                
                # Get the reset timestamp
                reset_timestamp = data['reset']
                
                # Calculate seconds until reset
                seconds_until_reset = max(0, reset_timestamp - current_time)
                
                # Format reset time as human-readable
                reset_time = datetime.fromtimestamp(reset_timestamp).strftime('%Y-%m-%d %H:%M:%S')
                
                print(f"Resource: {resource_category}")
                print(f"Endpoint: {endpoint}")
                print(f"Remaining: {data['remaining']}/{data['limit']} requests")
                print(f"Reset timestamp: {reset_timestamp}")
                print(f"Reset in: {seconds_until_reset} seconds ({reset_time})")
                print("-" * 50)
        
        if not found_endpoints:
            print("No endpoints with usage found.")
        
    except tweepy.errors.TweepyException as e:
        print(f"Error connecting to Twitter API: {e}")
    except Exception as e:
        print(f"Unexpected error: {e}")

if __name__ == "__main__":
    print("Checking Twitter API rate limit status...")
    get_rate_limit_status()
