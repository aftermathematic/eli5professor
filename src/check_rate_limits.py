#!/usr/bin/env python
"""
Example script to check Twitter API rate limits using the ratelimit module.
This script demonstrates how to run the ratelimit.py module directly without
running the entire Twitter bot.
"""

import os
import sys
import argparse
import logging
import time
from dotenv import load_dotenv
import tweepy

# Ensure the script can be run from any directory
script_dir = os.path.dirname(os.path.abspath(__file__))
if script_dir not in sys.path:
    sys.path.append(script_dir)

if __name__ == "__main__":
    print("Checking Twitter API rate limits...")
    
    # Import the ratelimit module
    from ratelimit import RateLimitChecker, get_wait_time_from_exception
    
    # Load environment variables from .env file
    load_dotenv()
    
    # Configure argument parser
    parser = argparse.ArgumentParser(description="Check Twitter API rate limits")
    parser.add_argument("--endpoint", "-e", type=str, help="Specific endpoint to check (e.g., 'resources/statuses/mentions_timeline')")
    parser.add_argument("--all", "-a", action="store_true", help="Show all rate limits")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show detailed information")
    parser.add_argument("--explore", "-x", action="store_true", help="Explore rate limit structure")
    args = parser.parse_args()
    
    # Configure logging
    log_level = logging.INFO
    if args.verbose:
        log_level = logging.DEBUG
    
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Check if Twitter credentials are available
    api_key = os.getenv('TWITTER_API_KEY')
    api_secret = os.getenv('TWITTER_API_SECRET')
    access_token = os.getenv('TWITTER_ACCESS_TOKEN')
    access_token_secret = os.getenv('TWITTER_ACCESS_TOKEN_SECRET')
    
    if not all([api_key, api_secret, access_token, access_token_secret]):
        print("Error: Twitter API credentials not found in environment variables.")
        print("Please set TWITTER_API_KEY, TWITTER_API_SECRET, TWITTER_ACCESS_TOKEN, and TWITTER_ACCESS_TOKEN_SECRET.")
        sys.exit(1)
    
    # Create Twitter API client
    auth = tweepy.OAuth1UserHandler(
        api_key, 
        api_secret, 
        access_token, 
        access_token_secret
    )
    api = tweepy.API(auth)
    
    try:
        # Get rate limit status
        rate_limits = RateLimitChecker.check_rate_limit_status(api)
        
        if not rate_limits:
            print("Error: Could not retrieve rate limit information.")
            sys.exit(1)
        
        print("\n=== Twitter API Rate Limits ===\n")
        
        # Twitter v2 endpoints to monitor specifically
        v2_endpoints = [
            'users/:id/mentions',  # GET /2/users/:id/mentions
            'tweets'               # POST /2/tweets
        ]
        
        # Common v1.1 endpoints that are equivalent to the v2 endpoints
        v1_equivalents = {
            'users/:id/mentions': 'statuses/mentions_timeline',
            'tweets': 'statuses/update'
        }
        
        # Categories of interest for v2 endpoints
        v2_categories = {
            'tweets': 'tweets&POST',  # POST /2/tweets
            'users/:id/mentions': 'users'  # GET /2/users/:id/mentions
        }
        
        # Explore mode - show the structure of the rate limit data
        if args.explore:
            print("Exploring rate limit data structure:\n")
            
            # Show top-level keys
            print("Top-level keys:")
            for key in rate_limits.keys():
                print(f"  - {key}")
            print()
            
            # If 'resources' exists, show its structure
            if 'resources' in rate_limits:
                print("Resources categories:")
                for category in rate_limits['resources'].keys():
                    print(f"  - {category}")
                
                # Ask which category to explore
                category = input("\nEnter a category to explore (or press Enter to continue): ")
                if category and category in rate_limits['resources']:
                    print(f"\nEndpoints in '{category}':")
                    for endpoint, data in rate_limits['resources'][category].items():
                        if isinstance(data, dict):
                            limit = data.get('limit', 0)
                            remaining = data.get('remaining', 0)
                            reset = data.get('reset', 0)
                            
                            # Calculate time until reset
                            now = int(time.time())
                            reset_in_seconds = max(reset - now, 0)
                            reset_time = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(reset))
                            
                            print(f"  - {endpoint}")
                            print(f"      Limit: {remaining}/{limit}")
                            print(f"      Reset in: {reset_in_seconds} seconds ({reset_time})")
                        else:
                            print(f"  - {endpoint}: {data}")
            
            print("\nTo check a specific endpoint, use:")
            print("  python check_rate_limits.py --endpoint resources/statuses/mentions_timeline")
            print("  python check_rate_limits.py --endpoint resources/statuses/update")
            sys.exit(0)
        
        # Check specific endpoint
        if args.endpoint:
            parts = args.endpoint.strip('/').split('/')
            current = rate_limits
            
            try:
                for part in parts:
                    current = current[part]
                
                # Skip if data is not a dictionary
                if not isinstance(current, dict):
                    print(f"Endpoint: {args.endpoint}")
                    print(f"  Data: {current}")
                    sys.exit(0)
                
                limit = current.get('limit', 0)
                remaining = current.get('remaining', 0)
                reset = current.get('reset', 0)
                
                # Calculate time until reset
                now = int(time.time())
                reset_in_seconds = max(reset - now, 0)
                reset_time = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(reset))
                
                print(f"Endpoint: {args.endpoint}")
                print(f"  Limit: {remaining}/{limit}")
                print(f"  Reset in: {reset_in_seconds} seconds ({reset_time})")
                
            except (KeyError, TypeError):
                print(f"Error: Endpoint '{args.endpoint}' not found in rate limit data.")
                print("\nAvailable resources:")
                for key in rate_limits.keys():
                    print(f"  - {key}")
                
                if 'resources' in rate_limits:
                    print("\nAvailable categories under 'resources':")
                    for category in rate_limits['resources'].keys():
                        print(f"  - {category}")
                    
                    print("\nFor POST /2/tweets rate limits, try:")
                    print("  --endpoint \"resources/tweets&POST\"  # Note the quotes around the endpoint")
                    
                    print("\nFor GET /2/users/:id/mentions rate limits, try:")
                    print("  --endpoint resources/users")
                    print("  --endpoint resources/statuses/mentions_timeline")
                
                print("\nUse --explore to interactively explore the rate limit structure.")
        
        # Show all rate limits
        elif args.all:
            if 'resources' in rate_limits:
                for category, endpoints in rate_limits['resources'].items():
                    print(f"\nCategory: {category}")
                    
                    # Skip if endpoints is not a dictionary
                    if not isinstance(endpoints, dict):
                        print(f"  Data: {endpoints}")
                        continue
                    
                    for endpoint, data in endpoints.items():
                        # Skip if data is not a dictionary
                        if not isinstance(data, dict):
                            print(f"  Endpoint: {endpoint}")
                            print(f"    Data: {data}")
                            continue
                            
                        limit = data.get('limit', 0)
                        remaining = data.get('remaining', 0)
                        reset = data.get('reset', 0)
                        
                        # Calculate time until reset
                        now = int(time.time())
                        reset_in_seconds = max(reset - now, 0)
                        reset_time = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(reset))
                        
                        print(f"  Endpoint: {endpoint}")
                        print(f"    Limit: {remaining}/{limit}")
                        print(f"    Reset in: {reset_in_seconds} seconds ({reset_time})")
            else:
                # Fall back to original behavior if 'resources' doesn't exist
                for resource, endpoints in rate_limits.items():
                    print(f"\nResource: {resource}")
                    
                    # Skip if endpoints is not a dictionary
                    if not isinstance(endpoints, dict):
                        print(f"  Data: {endpoints}")
                        continue
                    
                    for endpoint, data in endpoints.items():
                        # Skip if data is not a dictionary
                        if not isinstance(data, dict):
                            print(f"  Endpoint: {endpoint}")
                            print(f"    Data: {data}")
                            continue
                            
                        limit = data.get('limit', 0)
                        remaining = data.get('remaining', 0)
                        reset = data.get('reset', 0)
                        
                        # Calculate time until reset
                        now = int(time.time())
                        reset_in_seconds = max(reset - now, 0)
                        reset_time = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(reset))
                        
                        print(f"  Endpoint: {endpoint}")
                        print(f"    Limit: {remaining}/{limit}")
                        print(f"    Reset in: {reset_in_seconds} seconds ({reset_time})")
        
        # Default mode - show specific endpoints
        else:
            print("Twitter API v2 Endpoints:\n")
            print("Monitoring these specific endpoints:")
            print("1. GET /2/users/:id/mentions - For fetching mentions")
            print("2. POST /2/tweets - For posting tweets/replies")
            print("\nCurrent Rate Limits:\n")
            
            # Check if 'resources' exists in the rate limit data
            if 'resources' in rate_limits:
                # Look for v2 endpoints in the resources structure
                v2_found = False
                
                # Check for v2 endpoints in common categories
                categories = ['statuses', 'users', 'tweets', 'tweets&POST', 'application']
                
                for category in categories:
                    if category in rate_limits['resources']:
                        for endpoint, data in rate_limits['resources'][category].items():
                            # Check if this endpoint matches one of our v2 endpoints
                            for v2_endpoint in v2_endpoints:
                                # Try different variations of the endpoint name
                                variations = [
                                    f"/{v2_endpoint}",
                                    v2_endpoint,
                                    f"/2/{v2_endpoint}",
                                    f"/v2/{v2_endpoint}"
                                ]
                                
                                # For users/:id/mentions, also check mentions_timeline
                                if v2_endpoint == 'users/:id/mentions':
                                    variations.extend(['/mentions_timeline', 'mentions_timeline'])
                                
                                # For tweets, also check update
                                if v2_endpoint == 'tweets':
                                    variations.extend(['/update', 'update'])
                                
                                if any(var in endpoint for var in variations):
                                    v2_found = True
                                    
                                    # Skip if data is not a dictionary
                                    if not isinstance(data, dict):
                                        print(f"Endpoint: {v2_endpoint} (v2)")
                                        print(f"  Data: {data}")
                                        print()
                                        continue
                                    
                                    limit = data.get('limit', 0)
                                    remaining = data.get('remaining', 0)
                                    reset = data.get('reset', 0)
                                    
                                    # Calculate time until reset
                                    now = int(time.time())
                                    reset_in_seconds = max(reset - now, 0)
                                    reset_time = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(reset))
                                    
                                    print(f"Endpoint: {v2_endpoint} (v2)")
                                    print(f"  API Path: {endpoint}")
                                    print(f"  Limit: {remaining}/{limit}")
                                    print(f"  Reset in: {reset_in_seconds} seconds ({reset_time})")
                                    print()
                
                # Check specifically for the tweets&POST category that the user is interested in
                if 'tweets&POST' in rate_limits['resources']:
                    print("\nPOST /2/tweets Rate Limits (tweets&POST category):\n")
                    
                    for endpoint, data in rate_limits['resources']['tweets&POST'].items():
                        # Skip if data is not a dictionary
                        if not isinstance(data, dict):
                            print(f"Endpoint: {endpoint}")
                            print(f"  Data: {data}")
                            print()
                            continue
                        
                        limit = data.get('limit', 0)
                        remaining = data.get('remaining', 0)
                        reset = data.get('reset', 0)
                        
                        # Calculate time until reset
                        now = int(time.time())
                        reset_in_seconds = max(reset - now, 0)
                        reset_time = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(reset))
                        
                        print(f"Endpoint: {endpoint}")
                        print(f"  Limit: {remaining}/{limit}")
                        print(f"  Reset in: {reset_in_seconds} seconds ({reset_time})")
                        print()
                    
                    v2_found = True
                
                # If we couldn't find v2 endpoints, show v1.1 equivalents
                if not v2_found:
                    print("Couldn't find v2 endpoint rate limits directly. Showing v1.1 equivalents:\n")
                    
                    for v2_endpoint, v1_endpoint in v1_equivalents.items():
                        found = False
                        
                        # Look for the v1.1 equivalent in the resources
                        for category in categories:
                            if category in rate_limits['resources']:
                                for endpoint, data in rate_limits['resources'][category].items():
                                    if v1_endpoint in endpoint:
                                        found = True
                                        
                                        # Skip if data is not a dictionary
                                        if not isinstance(data, dict):
                                            print(f"Endpoint: {v2_endpoint} (v2)")
                                            print(f"  v1.1 Equivalent: {v1_endpoint}")
                                            print(f"  Data: {data}")
                                            print()
                                            continue
                                        
                                        limit = data.get('limit', 0)
                                        remaining = data.get('remaining', 0)
                                        reset = data.get('reset', 0)
                                        
                                        # Calculate time until reset
                                        now = int(time.time())
                                        reset_in_seconds = max(reset - now, 0)
                                        reset_time = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(reset))
                                        
                                        print(f"Endpoint: {v2_endpoint} (v2)")
                                        print(f"  v1.1 Equivalent: {v1_endpoint}")
                                        print(f"  API Path: {endpoint}")
                                        print(f"  Limit: {remaining}/{limit}")
                                        print(f"  Reset in: {reset_in_seconds} seconds ({reset_time})")
                                        print()
                        
                        if not found:
                            print(f"Endpoint: {v2_endpoint} (v2)")
                            print(f"  v1.1 Equivalent: {v1_endpoint}")
                            print("  Not found in rate limit data")
                            print()
                    
                    print("To explore the full rate limit structure, use:")
                    print("  python check_rate_limits.py --explore")
                    print("  python check_rate_limits.py --all")
                    print("\nIMPORTANT: When using endpoints with special characters like '&', always enclose them in quotes:")
                    print("  python check_rate_limits.py --endpoint \"resources/tweets&POST\"")
            else:
                print("Rate limit data doesn't contain 'resources' key. Structure:")
                for key in rate_limits.keys():
                    print(f"  - {key}")
                
                print("\nUse --explore to interactively explore the rate limit structure.")
    
    except tweepy.errors.TooManyRequests as e:
        # Handle rate limit exception
        seconds_to_wait = get_wait_time_from_exception(e)
        print(f"Rate limit exceeded. Need to wait {seconds_to_wait} seconds before retrying.")
        print(f"Will be available at: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(time.time() + seconds_to_wait))}")
    
    except Exception as e:
        print(f"Error: {e}")
