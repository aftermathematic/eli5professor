#!/usr/bin/env python
"""
Simple test script to verify MLflow integration is working.
"""

import os
import sys
import mlflow
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def test_mlflow():
    """Test MLflow tracking functionality."""
    print("Testing MLflow integration...")
    
    # Set up MLflow
    tracking_uri = "file:./mlruns"
    experiment_name = "eli5-discord-bot-test"
    
    mlflow.set_tracking_uri(tracking_uri)
    print(f"MLflow tracking URI: {tracking_uri}")
    
    # Create experiment
    try:
        experiment = mlflow.get_experiment_by_name(experiment_name)
        if experiment is None:
            mlflow.create_experiment(experiment_name)
            print(f"Created new experiment: {experiment_name}")
        else:
            print(f"Using existing experiment: {experiment_name}")
        
        mlflow.set_experiment(experiment_name)
        
        # Log a test run
        with mlflow.start_run():
            # Log parameters
            mlflow.log_param("test_subject", "gravity")
            mlflow.log_param("model_used", "test_model")
            
            # Log metrics
            mlflow.log_metric("response_time_seconds", 0.5)
            mlflow.log_metric("response_length", 50)
            mlflow.log_metric("success", 1)
            
            # Log text artifact
            mlflow.log_text("This is a test response #ELI5", "test_response.txt")
            
            # Log tags
            mlflow.set_tag("request_type", "test")
            mlflow.set_tag("model_type", "test_model")
            
            print("Successfully logged test run to MLflow!")
        
        print("MLflow integration test PASSED!")
        return True
        
    except Exception as e:
        print(f"MLflow integration test FAILED: {e}")
        return False

if __name__ == "__main__":
    success = test_mlflow()
    sys.exit(0 if success else 1)
