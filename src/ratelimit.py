"""
Twitter API Rate Limit Handler Module

This module provides utilities for handling Twitter API rate limits by checking
the X-RateLimit-Reset response header and calculating wait times.
"""

import time
import logging
from typing import Dict, Optional, Union, Tuple
import tweepy

# Configure logger
logger = logging.getLogger("eli5bot")

class RateLimitChecker:
    """Class to check and handle Twitter API rate limits."""
    
    @staticmethod
    def extract_rate_limit_info(response_headers: Dict[str, str]) -> Dict[str, Union[int, str]]:
        """
        Extract rate limit information from Twitter API response headers.
        
        Args:
            response_headers: The headers from a Twitter API response
            
        Returns:
            Dictionary containing rate limit information:
            - limit: The rate limit ceiling
            - remaining: The number of requests left for the current window
            - reset: The time when the rate limit will reset (Unix timestamp)
            - reset_in_seconds: Seconds until the rate limit resets
        """
        rate_limit_info = {
            'limit': None,
            'remaining': None,
            'reset': None,
            'reset_in_seconds': None
        }
        
        # Extract rate limit headers
        limit = response_headers.get('x-rate-limit-limit')
        remaining = response_headers.get('x-rate-limit-remaining')
        reset = response_headers.get('x-rate-limit-reset')
        
        # Log the headers for debugging
        logger.debug(f"Rate limit headers: limit={limit}, remaining={remaining}, reset={reset}")
        
        # Parse the values if they exist
        if limit:
            try:
                rate_limit_info['limit'] = int(limit)
            except (ValueError, TypeError):
                logger.warning(f"Could not parse x-rate-limit-limit: {limit}")
        
        if remaining:
            try:
                rate_limit_info['remaining'] = int(remaining)
            except (ValueError, TypeError):
                logger.warning(f"Could not parse x-rate-limit-remaining: {remaining}")
        
        if reset:
            try:
                reset_time = int(reset)
                rate_limit_info['reset'] = reset_time
                
                # Calculate seconds until reset
                now = int(time.time())
                seconds_until_reset = max(reset_time - now, 0)
                rate_limit_info['reset_in_seconds'] = seconds_until_reset
                
                logger.debug(f"Rate limit resets in {seconds_until_reset} seconds")
            except (ValueError, TypeError):
                logger.warning(f"Could not parse x-rate-limit-reset: {reset}")
        
        return rate_limit_info
    
    @staticmethod
    def get_rate_limit_from_exception(exception: tweepy.errors.TooManyRequests) -> Dict[str, Union[int, str]]:
        """
        Extract rate limit information from a Tweepy TooManyRequests exception.
        
        Args:
            exception: The Tweepy TooManyRequests exception
            
        Returns:
            Dictionary containing rate limit information
        """
        rate_limit_info = {
            'limit': None,
            'remaining': 0,  # We know we've hit the limit
            'reset': None,
            'reset_in_seconds': None
        }
        
        if hasattr(exception, 'response') and exception.response is not None:
            headers = exception.response.headers
            return RateLimitChecker.extract_rate_limit_info(headers)
        
        # Default wait time if headers not found
        rate_limit_info['reset_in_seconds'] = 15 * 60  # 15 minutes default
        logger.info(f"No rate limit headers found, using default wait time: {rate_limit_info['reset_in_seconds']} seconds")
        
        return rate_limit_info
    
    @staticmethod
    def check_rate_limit_status(api_client) -> Dict[str, Dict[str, Dict[str, int]]]:
        """
        Check the current rate limit status for all Twitter API endpoints.
        
        Args:
            api_client: A Tweepy API v1.1 client
            
        Returns:
            Dictionary containing rate limit status for all endpoints
        """
        try:
            status = api_client.rate_limit_status()
            logger.debug("Successfully retrieved rate limit status")
            return status
        except Exception as e:
            logger.error(f"Error retrieving rate limit status: {e}")
            return {}
    
    @staticmethod
    def check_endpoint_limit(api_client, endpoint: str) -> Tuple[int, int, int]:
        """
        Check the rate limit for a specific Twitter API endpoint.
        
        Args:
            api_client: A Tweepy API v1.1 client
            endpoint: The endpoint to check (e.g., '/statuses/mentions_timeline')
            
        Returns:
            Tuple of (limit, remaining, reset_in_seconds)
        """
        try:
            status = api_client.rate_limit_status()
            
            # Parse the endpoint path to navigate the nested dictionary
            parts = endpoint.strip('/').split('/')
            
            # Navigate through the status dictionary
            current = status
            for part in parts:
                if part in current:
                    current = current[part]
                else:
                    logger.warning(f"Endpoint {endpoint} not found in rate limit status")
                    return (0, 0, 0)
            
            # Extract the rate limit information
            limit = current.get('limit', 0)
            remaining = current.get('remaining', 0)
            reset = current.get('reset', 0)
            
            # Calculate seconds until reset
            now = int(time.time())
            reset_in_seconds = max(reset - now, 0)
            
            logger.debug(f"Rate limit for {endpoint}: {remaining}/{limit}, resets in {reset_in_seconds} seconds")
            return (limit, remaining, reset_in_seconds)
        
        except Exception as e:
            logger.error(f"Error checking rate limit for endpoint {endpoint}: {e}")
            return (0, 0, 0)
    
    @staticmethod
    def should_wait(remaining: int, threshold: int = 1) -> bool:
        """
        Determine if we should wait before making another request.
        
        Args:
            remaining: Number of requests remaining in the current window
            threshold: Minimum number of requests to keep available
            
        Returns:
            True if we should wait, False otherwise
        """
        return remaining <= threshold
    
    @staticmethod
    def wait_for_reset(seconds_left: int, buffer: int = 60) -> None:
        """
        Wait for the rate limit to reset with progress updates.
        
        Args:
            seconds_left: Seconds until the rate limit resets
            buffer: Additional buffer time in seconds to ensure reset
        """
        total_seconds = seconds_left + buffer
        logger.info(f"Rate limit hit. Waiting for {total_seconds} seconds before retrying.")
        
        # Sleep in shorter intervals with progress updates
        sleep_left = total_seconds
        while sleep_left > 0:
            interval = min(30, sleep_left)  # Update every 30 seconds or less
            logger.info(f"Rate limit cooldown: {sleep_left} seconds remaining...")
            time.sleep(interval)
            sleep_left -= interval
        
        logger.info("Rate limit cooldown complete, resuming operations.")

def get_rate_limit_info(response_headers: Dict[str, str]) -> Dict[str, Union[int, str]]:
    """
    Convenience function to extract rate limit info from response headers.
    
    Args:
        response_headers: The headers from a Twitter API response
        
    Returns:
        Dictionary containing rate limit information
    """
    return RateLimitChecker.extract_rate_limit_info(response_headers)

def get_wait_time_from_exception(exception: tweepy.errors.TooManyRequests) -> int:
    """
    Get the wait time in seconds from a rate limit exception.
    
    Args:
        exception: The Tweepy TooManyRequests exception
        
    Returns:
        Seconds to wait before retrying (with a 30-second safety buffer)
    """
    rate_limit_info = RateLimitChecker.get_rate_limit_from_exception(exception)
    seconds = rate_limit_info.get('reset_in_seconds', 16 * 60)  # Default to 16 minutes

    # Add a 30-second safety buffer if the reset time is greater than 0
    if seconds > 0:
        seconds += 30
        logger.info(f"Adding 30-second safety buffer to rate limit reset time. Total wait: {seconds} seconds")

    return seconds

def handle_rate_limit_exception(exception: tweepy.errors.TooManyRequests, wait: bool = True) -> int:
    """
    Handle a rate limit exception by extracting wait time and optionally waiting.
    
    Args:
        exception: The Tweepy TooManyRequests exception
        wait: Whether to wait for the rate limit to reset
        
    Returns:
        Seconds until rate limit reset
    """
    seconds_to_wait = get_wait_time_from_exception(exception)
    
    if wait:
        RateLimitChecker.wait_for_reset(seconds_to_wait)
    
    return seconds_to_wait


# Main execution block for standalone usage
if __name__ == "__main__":
    import os
    import argparse
    from dotenv import load_dotenv
    
    # Load environment variables from .env file
    load_dotenv()
    
    # Configure argument parser
    parser = argparse.ArgumentParser(description="Check Twitter API rate limits")
    parser.add_argument("--endpoint", "-e", type=str, help="Specific endpoint to check (e.g., 'statuses/mentions_timeline')")
    parser.add_argument("--all", "-a", action="store_true", help="Show all rate limits")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show detailed information")
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
        exit(1)
    
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
            exit(1)
        
        print("\n=== Twitter API Rate Limits ===\n")
        
        # Common important endpoints to check
        important_endpoints = [
            'statuses/mentions_timeline',
            'statuses/user_timeline', 
            'search/tweets',
            'favorites/list',
            'statuses/lookup',
            'statuses/show/:id',
            'statuses/retweets/:id',
            'statuses/update'
        ]
        
        if args.endpoint:
            # Check specific endpoint
            parts = args.endpoint.strip('/').split('/')
            current = rate_limits
            
            try:
                for part in parts:
                    current = current[part]
                
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
                print("Available resources:")
                for resource in rate_limits.keys():
                    print(f"  - {resource}")
        
        elif args.all:
            # Show all rate limits
            for resource, endpoints in rate_limits.items():
                print(f"\nResource: {resource}")
                
                for endpoint, data in endpoints.items():
                    # Skip if data is not a dictionary (some endpoints might return strings or other types)
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
            # Show important endpoints
            print("Common Endpoints:\n")
            
            for endpoint in important_endpoints:
                parts = endpoint.strip('/').split('/')
                current = rate_limits
                
                try:
                    for part in parts:
                        if part in current:
                            current = current[part]
                        else:
                            # Skip this endpoint if not found
                            raise KeyError(f"Part {part} not found")
                    
                    limit = current.get('limit', 0)
                    remaining = current.get('remaining', 0)
                    reset = current.get('reset', 0)
                    
                    # Calculate time until reset
                    now = int(time.time())
                    reset_in_seconds = max(reset - now, 0)
                    reset_time = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(reset))
                    
                    print(f"Endpoint: {endpoint}")
                    print(f"  Limit: {remaining}/{limit}")
                    print(f"  Reset in: {reset_in_seconds} seconds ({reset_time})")
                    print()
                
                except (KeyError, TypeError):
                    # Skip endpoints that don't exist in the rate limit data
                    continue
            
            print("\nRun with --all to see all endpoints or --endpoint to check a specific endpoint.")
    
    except tweepy.errors.TooManyRequests as e:
        # Handle rate limit exception
        seconds_to_wait = get_wait_time_from_exception(e)
        print(f"Rate limit exceeded. Need to wait {seconds_to_wait} seconds before retrying.")
        print(f"Will be available at: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(time.time() + seconds_to_wait))}")
    
    except Exception as e:
        print(f"Error: {e}")
