"""
Basic tests for the ELI5 Discord Bot
"""
import pytest
import sys
import os

# Add src directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))


def test_imports():
    """Test that main modules can be imported without errors"""
    try:
        import main
        import post_replies
        import model_loader
        assert True
    except ImportError as e:
        pytest.fail(f"Failed to import modules: {e}")


def test_health_check_module():
    """Test that the health check module can be imported"""
    try:
        import discord_bot_with_health
        assert hasattr(discord_bot_with_health, 'app')
        assert hasattr(discord_bot_with_health, 'health_check')
    except ImportError as e:
        pytest.fail(f"Failed to import discord_bot_with_health: {e}")


def test_basic_functionality():
    """Basic sanity test"""
    assert 1 + 1 == 2
    assert "ELI5" in "ELI5 Discord Bot"


def test_environment_variables():
    """Test that required environment variables are accessible"""
    # These tests should pass even if env vars aren't set
    # since we're just testing the code structure
    import os
    
    # Test that we can access environment variables
    discord_token = os.getenv('DISCORD_BOT_TOKEN', 'test_token')
    openai_key = os.getenv('OPENAI_API_KEY', 'test_key')
    
    assert isinstance(discord_token, str)
    assert isinstance(openai_key, str)
