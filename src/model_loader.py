# model_loader.py
import os
import torch
import logging
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("model_loader")

# Name of your Hugging Face model.
MODEL_CHECKPOINT = "google/flan-t5-base"  # Can use "google/flan-t5-large" if your hardware allows

# Initialize variables
tokenizer = None
model = None

# Check if we're in a Lambda environment
IS_LAMBDA = os.environ.get('AWS_LAMBDA_FUNCTION_NAME') is not None

try:
    # Load tokenizer once
    logger.info("Loading tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_CHECKPOINT)
    logger.info("Tokenizer loaded.")

    # Load model once if not in Lambda or if explicitly requested
    if not IS_LAMBDA or os.environ.get('LOAD_MODEL_IN_LAMBDA', 'false').lower() == 'true':
        logger.info("Loading model...")
        model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_CHECKPOINT)

        # Move model to GPU if available
        if torch.cuda.is_available():
            logger.info("CUDA detected. Moving model to GPU.")
            model = model.to("cuda")
        else:
            logger.info("Using CPU.")

        logger.info("Model loaded and ready.")
    else:
        logger.info("Skipping model loading in Lambda environment.")
except Exception as e:
    logger.error(f"Error loading model or tokenizer: {e}")
    logger.info("Will use OpenAI API only.")

def get_tokenizer():
    """
    Returns the loaded Hugging Face tokenizer.
    """
    return tokenizer

def get_model():
    """
    Returns the loaded Hugging Face model.
    """
    return model
