# Twitter API Rate Limit Checker

This documentation explains how to use the `ratelimit.py` module to check Twitter API rate limits without running the entire Twitter bot. The tool now specifically monitors the rate limits for the Twitter v2 endpoints used in the ELI5 bot.

## Overview

The `ratelimit.py` module provides utilities for handling Twitter API rate limits by checking the X-RateLimit-Reset response header and calculating wait times. It can be used:

1. As a standalone script to check current rate limits
2. Imported into other Python scripts to handle rate limit exceptions
3. Via the provided `check_rate_limits.py` helper script

## Prerequisites

- Python 3.6 or higher
- Twitter API credentials set in environment variables or a `.env` file:
  - `TWITTER_API_KEY`
  - `TWITTER_API_SECRET`
  - `TWITTER_ACCESS_TOKEN`
  - `TWITTER_ACCESS_TOKEN_SECRET`
- Required Python packages: `tweepy`, `python-dotenv`

## Running as a Standalone Script

You can run `ratelimit.py` directly to check current rate limits:

```bash
# Show common endpoints
python ratelimit.py

# Show all endpoints
python ratelimit.py --all

# Check a specific endpoint
python ratelimit.py --endpoint statuses/update

# Show detailed information
python ratelimit.py --verbose
```

## Using the Helper Script

For convenience, a helper script `check_rate_limits.py` is provided:

```bash
# Show the specific v2 endpoints being monitored
python check_rate_limits.py

# Show all endpoints
python check_rate_limits.py --all

# Check a specific endpoint (with correct path format)
python check_rate_limits.py --endpoint "resources/tweets&POST"  # Note the quotes around the endpoint
python check_rate_limits.py --endpoint resources/statuses/mentions_timeline

# Explore the rate limit structure interactively
python check_rate_limits.py --explore

# Show detailed information
python check_rate_limits.py --verbose
```

The script now specifically monitors these Twitter v2 API endpoints:

1. `GET /2/users/:id/mentions` - Used for fetching mentions in the Twitter bot
2. `POST /2/tweets` - Used for posting replies in the Twitter bot

The script now focuses on the 'tweets&POST' category, which contains the rate limit information for the POST /2/tweets endpoint that you're specifically interested in.

These are the endpoints that are most relevant for the rate limit issues you're experiencing with the Twitter bot.

## Output Example

When you run the script, you'll see output similar to this:

```
=== Twitter API Rate Limits ===

Twitter API v2 Endpoints:

Monitoring these specific endpoints:
1. GET /2/users/:id/mentions - For fetching mentions
2. POST /2/tweets - For posting tweets/replies

Current Rate Limits:

Endpoint: users/:id/mentions (v2)
  v1.1 Equivalent: statuses/mentions_timeline
  API Path: /statuses/mentions_timeline
  Limit: 75/75
  Reset in: 900 seconds (2025-06-22 21:24:14)

Endpoint: tweets (v2)
  v1.1 Equivalent: statuses/update
  API Path: /statuses/update
  Limit: 300/300
  Reset in: 3600 seconds (2025-06-22 21:55:10)

To explore the full rate limit structure, use:
  python check_rate_limits.py --explore
  python check_rate_limits.py --all
```

Or when using the explore mode:

```
=== Twitter API Rate Limits ===

Exploring rate limit data structure:

Top-level keys:
  - rate_limit_context
  - resources

Resources categories:
  - statuses
  - users
  - application
  - favorites
  - friendships
  - followers
  - friends

Enter a category to explore (or press Enter to continue): statuses

Endpoints in 'statuses':
  - /statuses/mentions_timeline
      Limit: 75/75
      Reset in: 900 seconds (2025-06-22 21:24:14)
  - /statuses/user_timeline
      Limit: 900/900
      Reset in: 3600 seconds (2025-06-22 21:55:10)
  - /statuses/update
      Limit: 300/300
      Reset in: 3600 seconds (2025-06-22 21:55:10)

To check a specific endpoint, use:
  python check_rate_limits.py --endpoint resources/statuses/mentions_timeline
  python check_rate_limits.py --endpoint resources/statuses/update
```

## Important Endpoints

### Twitter v2 API Endpoints (Current)

The script now specifically monitors these Twitter v2 API endpoints:

- `tweets&POST` category - Contains rate limits for POST /2/tweets (posting tweets/replies)
- `users/:id/mentions` (GET /2/users/:id/mentions) - Used for fetching mentions

### Twitter v1.1 API Endpoints (Legacy)

The script will fall back to these v1.1 endpoints if v2 rate limit data isn't available:

- `statuses/mentions_timeline` - Getting mentions (v1.1 equivalent)
- `statuses/update` - Posting tweets (v1.1 equivalent)
- `statuses/user_timeline` - Getting user tweets
- `search/tweets` - Searching for tweets

## Programmatic Usage

You can also import the module in your Python code:

```python
from ratelimit import RateLimitChecker
import tweepy

# Create Twitter API client
auth = tweepy.OAuth1UserHandler(api_key, api_secret, access_token, access_token_secret)
api = tweepy.API(auth)

# Check rate limits
rate_limits = RateLimitChecker.check_rate_limit_status(api)

# Check specific endpoint
limit, remaining, reset_in_seconds = RateLimitChecker.check_endpoint_limit(api, 'statuses/update')
print(f"Rate limit for posting tweets: {remaining}/{limit}, resets in {reset_in_seconds} seconds")

# Handle rate limit exceptions
try:
    # Your Twitter API call here
    pass
except tweepy.errors.TooManyRequests as e:
    # Get wait time from exception
    seconds_to_wait = get_wait_time_from_exception(e)
    print(f"Rate limit exceeded. Need to wait {seconds_to_wait} seconds.")
    
    # Optionally wait for the rate limit to reset
    RateLimitChecker.wait_for_reset(seconds_to_wait)
```

## Troubleshooting

If you encounter issues:

1. Ensure your Twitter API credentials are correct and have the necessary permissions
2. Check that you have the required Python packages installed
3. Verify that your `.env` file is in the correct location if you're using one
4. Run with `--verbose` flag to see more detailed information
