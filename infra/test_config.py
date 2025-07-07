import yaml
import os
import sys

def load_config(config_path="config/config.yml"):
    """Load configuration from YAML file."""
    try:
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
        return config
    except Exception as e:
        print(f"Error loading configuration from {config_path}: {e}")
        return {}

def print_config(config, indent=0):
    """Print configuration in a readable format."""
    for key, value in config.items():
        if isinstance(value, dict):
            print(" " * indent + f"{key}:")
            print_config(value, indent + 2)
        else:
            print(" " * indent + f"{key}: {value}")

if __name__ == "__main__":
    # Get config path from command line argument or use default
    config_path = sys.argv[1] if len(sys.argv) > 1 else "config/config.yml"
    
    print(f"Loading configuration from {config_path}...")
    config = load_config(config_path)
    
    if config:
        print("\nConfiguration loaded successfully:")
        print_config(config)
    else:
        print("\nFailed to load configuration.")
