import os
import yaml
import logging
from typing import Dict, Any, Optional
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel, Field
from dotenv import load_dotenv
import openai
import random
import csv
import datetime
import torch
from src.model_loader import get_model, get_tokenizer

# Load environment variables
load_dotenv()

# Initialize FastAPI app
app = FastAPI(
    title="ELI5 API",
    description="API for generating 'Explain Like I'm 5' explanations with a passive-aggressive tone",
    version="1.0.0",
)

# Configuration Loader
class ConfigLoader:
    """Class to load configuration from YAML file."""
    @staticmethod
    def load_config(config_path: str = "config/config.yml") -> Dict[str, Any]:
        """Load configuration from YAML file."""
        try:
            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
            return config
        except Exception as e:
            print(f"Error loading configuration from {config_path}: {e}")
            print("Using default configuration")
            return {}

# Load configuration
config_data = ConfigLoader.load_config()

# Configure logging
logging_config = config_data.get('logging', {})
logging.basicConfig(
    level=getattr(logging, logging_config.get('level', 'INFO')),
    format=logging_config.get('format', '%(asctime)s - %(name)s - %(levelname)s - %(message)s'),
    handlers=[
        logging.FileHandler(logging_config.get('log_file', 'eli5bot.log')),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("eli5api")

# Configuration
class Config:
    """Configuration class for the ELI5 API."""
    def __init__(self, config_data: Dict[str, Any]):
        self.config_data = config_data
        
        # OpenAI configuration
        self.OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
        self.OPENAI_MODEL = self._get_config('openai.model', os.getenv('OPENAI_MODEL', 'gpt-3.5-turbo'))
        
        # Model configuration
        self.USE_LOCAL_MODEL_FALLBACK = self._get_config('openai.use_local_model_fallback', 
                                                        os.getenv('USE_LOCAL_MODEL_FALLBACK', 'true').lower() == 'true')
        
        # Dataset configuration
        self.DATASET_PATH = self._get_config('dataset.examples_dataset_path', 
                                            os.getenv('DATASET_PATH', 'data/dataset.csv'))
        self.NUM_EXAMPLES = int(self._get_config('dataset.num_examples', 
                                                os.getenv('NUM_EXAMPLES', '3')))
        
        # Prompt configuration
        self.ELI5_PROMPT_TEMPLATE = self._get_config('prompts.eli5_prompt_template', """
You're a passive-aggressive assistant that explains things in a condescending way to someone with no background knowledge. Be sarcastic, use a mocking tone, and make the person feel slightly bad for not knowing this already.

Explain the following like I'm 5 years old, but with a passive-aggressive tone. Keep it under 260 characters:
{subject}

End your response with '#ELI5'
""")
        
        self.SYSTEM_PROMPT = self._get_config('prompts.system_prompt', 
                                             "You are a passive-aggressive assistant that explains concepts in a condescending way to 5-year-olds. Your responses should be sarcastic, slightly mocking, and make the person feel a bit bad for not knowing this already. Keep responses under 260 characters and end with #ELI5.")
        
        # API configuration
        self.MAX_RESPONSE_LENGTH = int(self._get_config('api.max_response_length', 280))
    
    def _get_config(self, key_path: str, default: Any) -> Any:
        """Get a configuration value from the YAML config using dot notation."""
        keys = key_path.split('.')
        value = self.config_data
        
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return default
        
        return value

class DatasetLoader:
    """Class to load and process the dataset of examples."""
    def __init__(self, dataset_path: str = "data/dataset.csv"):
        self.dataset_path = dataset_path
        self.examples = []
        self._load_dataset()
        logger.info(f"Dataset loader initialized with {len(self.examples)} examples from {dataset_path}")
    
    def _load_dataset(self) -> None:
        """Load examples from the dataset file."""
        try:
            with open(self.dataset_path, 'r', newline='', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if 'term' in row and 'explanation' in row:
                        self.examples.append({
                            'term': row['term'],
                            'explanation': row['explanation']
                        })
        except Exception as e:
            logger.error(f"Error loading dataset: {e}")
    
    def get_random_examples(self, num_examples: int = 3) -> list:
        """Get a random selection of examples from the dataset."""
        if not self.examples:
            return []
        
        # Return random examples, but no more than what's available
        num_to_return = min(num_examples, len(self.examples))
        return random.sample(self.examples, num_to_return)

class LLMClient:
    """Class to handle LLM interactions (OpenAI and local model)."""
    def __init__(self, config: Config):
        self.config = config
        
        # Check if OpenAI API key is available
        self.has_openai_key = bool(config.OPENAI_API_KEY)
        if self.has_openai_key:
            logger.info("OpenAI API key found")
        else:
            logger.warning("OpenAI API key not found, will use local model only")
        
        # Initialize local model if fallback is enabled
        self.use_local_model_fallback = config.USE_LOCAL_MODEL_FALLBACK
        if self.use_local_model_fallback:
            try:
                self.tokenizer = get_tokenizer()
                self.model = get_model()
                logger.info("Local model loaded for fallback")
            except Exception as e:
                logger.error(f"Failed to load local model: {e}")
                self.use_local_model_fallback = False
        
        # Load dataset examples
        self.dataset_loader = DatasetLoader(config.DATASET_PATH)
        logger.info(f"Loaded {len(self.dataset_loader.examples)} examples from dataset")
    
    def _create_openai_client(self):
        """Create a fresh OpenAI client for each request."""
        return openai.OpenAI(api_key=self.config.OPENAI_API_KEY)
    
    def generate_eli5_response(self, subject: str, max_length: Optional[int] = None) -> str:
        """
        Generate an ELI5 explanation for the given subject.
        
        Args:
            subject: The topic to explain
            max_length: Optional maximum length of the response
            
        Returns:
            A simplified explanation
        """
        # Format the prompt
        prompt = self.config.ELI5_PROMPT_TEMPLATE.format(subject=subject)
        
        # Use provided max_length if available, otherwise use default
        response_max_length = max_length if max_length is not None else self.config.MAX_RESPONSE_LENGTH
        
        # Try OpenAI first if API key is available
        if self.has_openai_key:
            try:
                return self._generate_with_openai(prompt, max_length)
            except Exception as e:
                logger.error(f"OpenAI generation failed: {e}")
                if not self.use_local_model_fallback:
                    return f"Sorry, I couldn't explain '{subject}' right now. Try again later! #ELI5"
        
        # Fall back to local model if OpenAI fails or is not available
        if self.use_local_model_fallback:
            try:
                return self._generate_with_local_model(prompt, max_length)
            except Exception as e:
                logger.error(f"Local model generation failed: {e}")
                return f"Sorry, I couldn't explain '{subject}' right now. Try again later! #ELI5"
        
        # If we get here, both methods failed or weren't available
        return f"Sorry, I couldn't explain '{subject}' right now. Try again later! #ELI5"
    
    def _generate_with_openai(self, prompt: str, max_length: Optional[int] = None) -> str:
        """Generate response using OpenAI API with few-shot examples."""
        # Create a fresh client for this request
        client = self._create_openai_client()
        
        # Get random examples from the dataset
        examples = self.dataset_loader.get_random_examples(self.config.NUM_EXAMPLES)
        
        # Create messages array with system prompt and examples
        messages = [
            {"role": "system", "content": self.config.SYSTEM_PROMPT}
        ]
        
        # Add examples as conversation pairs
        for example in examples:
            messages.append({"role": "user", "content": f"Explain {example['term']} like I'm 5 years old"})
            messages.append({"role": "assistant", "content": example['explanation']})
        
        # Add the current request
        messages.append({"role": "user", "content": prompt})
        
        # Generate response
        response = client.chat.completions.create(
            model=self.config.OPENAI_MODEL,
            messages=messages,
            max_tokens=self.config._get_config('openai.max_tokens', 500),
            temperature=self.config._get_config('openai.temperature', 0.8)
        )
        explanation = response.choices[0].message.content.strip()
        return self._format_response(explanation, max_length)
    
    def _generate_with_local_model(self, prompt: str, max_length: Optional[int] = None) -> str:
        """Generate response using local Hugging Face model."""
        # Tokenize the prompt
        inputs = self.tokenizer(prompt, return_tensors="pt", truncation=True, max_length=512)
        
        # Move to GPU if available
        if torch.cuda.is_available():
            inputs = {k: v.to("cuda") for k, v in inputs.items()}
        
        # Generate response
        with torch.no_grad():
            output_ids = self.model.generate(
                **inputs,
                max_length=150,  # Shorter for responses
                num_return_sequences=1,
                temperature=0.8,
                do_sample=True
            )
        
        # Decode the response
        explanation = self.tokenizer.decode(output_ids[0], skip_special_tokens=True)
        return self._format_response(explanation, max_length)
    
    def _format_response(self, explanation: str, max_length: Optional[int] = None) -> str:
        """Format the explanation and add hashtag if needed."""
        # Use provided max_length if available, otherwise use default
        response_max_length = max_length if max_length is not None else self.config.MAX_RESPONSE_LENGTH
        
        # Ensure the explanation ends with #ELI5
        if "#ELI5" not in explanation:
            if len(explanation) + 6 <= response_max_length:
                explanation = explanation.rstrip() + " #ELI5"
            else:
                allowed = response_max_length - 6
                explanation = explanation[:allowed].rstrip() + " #ELI5"
        
        # Truncate if still too long
        if len(explanation) > response_max_length:
            explanation = explanation[:response_max_length - 3].rstrip() + "… #ELI5"
        
        return explanation

# Initialize global components
config = Config(config_data)
llm_client = LLMClient(config)

# Pydantic models for request/response
class ExplainRequest(BaseModel):
    subject: str = Field(..., description="The subject to explain like I'm 5", min_length=1, max_length=200, example="quantum physics")
    max_length: Optional[int] = Field(None, description="Maximum length of the explanation", ge=50, le=500)

class ExplainResponse(BaseModel):
    subject: str = Field(..., description="The subject that was explained")
    explanation: str = Field(..., description="The ELI5 explanation")

# API endpoints
@app.get("/")
async def root():
    """Root endpoint that returns basic API information."""
    return {
        "name": "ELI5 API",
        "description": "API for generating 'Explain Like I'm 5' explanations with a passive-aggressive tone",
        "version": "1.0.0",
        "endpoints": {
            "/explain": "POST - Generate an ELI5 explanation for a given subject",
            "/health": "GET - Check API health status"
        }
    }

class DatasetLogger:
    """Class to log API requests and responses to a dataset file."""
    def __init__(self, dataset_path: str = "data/eli5_dataset.csv"):
        self.dataset_path = dataset_path
        logger.info(f"Dataset logger initialized with path: {dataset_path}")
    
    def log_interaction(self, subject: str, response: str, tweet_id: str = "api_request") -> None:
        """
        Log an interaction to the dataset file.
        
        Args:
            subject: The subject that was explained
            response: The generated ELI5 response
            tweet_id: The ID of the tweet or "api_request" for API requests
        """
        try:
            timestamp = datetime.datetime.now().isoformat()
            
            # Escape any commas, quotes, or newlines in the text fields
            subject_escaped = subject.replace('"', '""')
            response_escaped = response.replace('"', '""')
            
            # Write to CSV file
            with open(self.dataset_path, 'a', newline='', encoding='utf-8') as f:
                writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
                writer.writerow([timestamp, tweet_id, subject_escaped, response_escaped])
            
            logger.info(f"Logged interaction for subject '{subject}' to dataset")
        except Exception as e:
            logger.error(f"Error logging to dataset: {e}")

# Initialize dataset logger
dataset_logger = DatasetLogger(config._get_config('dataset.eli5_dataset_path', 'data/eli5_dataset_v1.csv'))

@app.post("/explain", response_model=ExplainResponse)
async def explain(request: ExplainRequest):
    """Generate an ELI5 explanation for the given subject."""
    try:
        # Validate input
        if not request.subject.strip():
            raise HTTPException(status_code=400, detail="Subject cannot be empty")
        
        # Generate explanation
        explanation = llm_client.generate_eli5_response(request.subject, request.max_length)
        
        # Log the interaction to the dataset
        dataset_logger.log_interaction(request.subject, explanation)
        
        # Return response
        return {
            "subject": request.subject,
            "explanation": explanation
        }
    except Exception as e:
        logger.error(f"Error generating explanation: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to generate explanation: {str(e)}")

@app.get("/health")
async def health():
    """Health check endpoint."""
    # Check if OpenAI API key is available
    openai_status = "available" if llm_client.has_openai_key else "unavailable"
    
    # Check if local model is available
    local_model_status = "available" if llm_client.use_local_model_fallback else "unavailable"
    
    # Check if dataset is loaded
    dataset_status = "loaded" if len(llm_client.dataset_loader.examples) > 0 else "not loaded"
    
    return {
        "status": "healthy",
        "openai_api": openai_status,
        "local_model": local_model_status,
        "dataset": dataset_status,
        "examples_count": len(llm_client.dataset_loader.examples)
    }

# Run the application
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
