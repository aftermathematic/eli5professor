# model_loader.py
import torch
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

# Name of your Hugging Face model.
MODEL_CHECKPOINT = "google/flan-t5-base"  # Can use "google/flan-t5-large" if your hardware allows

# Load tokenizer once
print("[model_loader] Loading tokenizer...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_CHECKPOINT)
print("[model_loader] Tokenizer loaded.")

# Load model once
print("[model_loader] Loading model...")
model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_CHECKPOINT)

# Move model to GPU if available
if torch.cuda.is_available():
    print("[model_loader] CUDA detected. Moving model to GPU.")
    model = model.to("cuda")
else:
    print("[model_loader] Using CPU.")

print("[model_loader] Model loaded and ready.")

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