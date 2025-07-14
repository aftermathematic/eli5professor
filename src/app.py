import os
import yaml
import logging
import time
from typing import Dict, Any, Optional
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel, Field
from dotenv import load_dotenv
import openai
import random
import csv
import datetime
import torch
import mlflow
import mlflow.sklearn
from mlflow.tracking import MlflowClient
try:
    from .model_loader import get_model, get_tokenizer
except ImportError:
    from model_loader import get_model, get_tokenizer

# Load environment variables
load_dotenv()

# Initialize FastAPI app
app = FastAPI(
    title="ELI5 API",
    description="API for generating 'Explain Like I'm 5' explanations that mimic the style of provided examples",
    version="1.0.0",
)

# Configuration Loader
class ConfigLoader:
    """Class to load configuration from YAML file."""
    @staticmethod
    def load_config(config_path: str = "config/config.yml") -> Dict[str, Any]:
        """Load configuration from YAML file."""
        try:
            # Try the provided path first
            if os.path.exists(config_path):
                with open(config_path, 'r') as f:
                    config = yaml.safe_load(f)
                return config
            
            # If not found, try relative to parent directory
            parent_config_path = os.path.join("..", config_path)
            if os.path.exists(parent_config_path):
                with open(parent_config_path, 'r') as f:
                    config = yaml.safe_load(f)
                return config
            
            # If still not found, raise the original error
            raise FileNotFoundError(f"Configuration file not found at {config_path} or {parent_config_path}")
            
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
Explain the following like I'm 5 years old. Keep it under 260 characters and use a sarcastic, slightly condescending tone:
{subject}

End your response with '#ELI5'
""")
        
        self.SYSTEM_PROMPT = self._get_config('prompts.system_prompt', 
                                             "You are a sarcastic, slightly condescending assistant that explains concepts to 5-year-olds. Mimic the passive-aggressive, sarcastic style and tone of the examples provided. Be witty and slightly insulting while still being educational. Keep responses under 260 characters and end with #ELI5.")
        
        # API configuration
        self.MAX_RESPONSE_LENGTH = int(self._get_config('api.max_response_length', 280))
        
        # MLflow configuration
        self.MLFLOW_TRACKING_URI = self._get_config('mlflow.tracking_uri', 
                                                   os.getenv('MLFLOW_TRACKING_URI', 'file:./mlruns'))
        self.MLFLOW_EXPERIMENT_NAME = self._get_config('mlflow.experiment_name', 
                                                      os.getenv('MLFLOW_EXPERIMENT_NAME', 'eli5-discord-bot'))
    
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
        
        # If no examples were loaded, use default examples
        if not self.examples:
            logger.warning(f"No examples loaded from {dataset_path}, using default examples")
            self._load_default_examples()
            
        logger.info(f"Dataset loader initialized with {len(self.examples)} examples")
    
    def _load_dataset(self) -> None:
        """Load examples from the dataset file."""
        try:
            # Try the provided path first
            dataset_path = self.dataset_path
            if not os.path.exists(dataset_path):
                # If not found, try relative to parent directory
                dataset_path = os.path.join("..", self.dataset_path)
                if not os.path.exists(dataset_path):
                    logger.warning(f"Dataset file not found: {self.dataset_path} or {dataset_path}")
                    return
                
            with open(dataset_path, 'r', newline='', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if 'term' in row and 'explanation' in row:
                        self.examples.append({
                            'term': row['term'],
                            'explanation': row['explanation']
                        })
        except Exception as e:
            logger.error(f"Error loading dataset: {e}")
    
    def _load_default_examples(self) -> None:
        """Load default examples when dataset file is not available."""
        self.examples = [
            {
                'term': 'gravity',
                'explanation': 'Gravity? It\'s just what keeps you from floating away. Not rocket science... well, actually it kind of is. #ELI5'
            },
            {
                'term': 'internet',
                'explanation': 'The internet is where people argue with strangers and look at cat videos. You\'re using it right now, genius. #ELI5'
            },
            {
                'term': 'Star Wars',
                'explanation': 'You haven\'t seen Star Wars? It\'s the movie with space wizards and laser swords. It\'s okay, not everyone has taste. #ELI5'
            }
        ]
    
    def get_random_examples(self, num_examples: int = 3) -> list:
        """Get a random selection of examples from the dataset."""
        if not self.examples:
            return []
        
        # Return random examples, but no more than what's available
        num_to_return = min(num_examples, len(self.examples))
        return random.sample(self.examples, num_to_return)

class MLflowTracker:
    """Class to handle MLflow experiment tracking."""
    def __init__(self, config: Config):
        self.config = config
        mlflow.set_tracking_uri(config.MLFLOW_TRACKING_URI)
        
        # Create or get experiment
        try:
            experiment = mlflow.get_experiment_by_name(config.MLFLOW_EXPERIMENT_NAME)
            if experiment is None:
                mlflow.create_experiment(config.MLFLOW_EXPERIMENT_NAME)
            mlflow.set_experiment(config.MLFLOW_EXPERIMENT_NAME)
            logger.info(f"MLflow experiment set: {config.MLFLOW_EXPERIMENT_NAME}")
        except Exception as e:
            logger.error(f"Error setting up MLflow experiment: {e}")
    
    def log_eli5_generation(self, subject: str, explanation: str, model_used: str, 
                           response_time: float, success: bool):
        """Log an ELI5 generation event."""
        try:
            with mlflow.start_run():
                # Log parameters
                mlflow.log_param("subject", subject)
                mlflow.log_param("model_used", model_used)
                mlflow.log_param("max_response_length", self.config.MAX_RESPONSE_LENGTH)
                
                # Log metrics
                mlflow.log_metric("response_time_seconds", response_time)
                mlflow.log_metric("response_length", len(explanation))
                mlflow.log_metric("success", 1 if success else 0)
                mlflow.log_metric("has_eli5_hashtag", 1 if "#ELI5" in explanation else 0)
                
                # Log the actual response as an artifact
                mlflow.log_text(explanation, f"response_{int(time.time())}.txt")
                
                # Log tags for filtering
                mlflow.set_tag("request_type", "eli5_generation")
                mlflow.set_tag("model_type", model_used)
                
        except Exception as e:
            logger.error(f"Error logging to MLflow: {e}")

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
                
                # Check if tokenizer and model were successfully loaded
                if self.tokenizer is None or self.model is None:
                    logger.warning("Tokenizer or model is None, disabling local model fallback")
                    self.use_local_model_fallback = False
                else:
                    logger.info("Local model loaded for fallback")
            except Exception as e:
                logger.error(f"Failed to load local model: {e}")
                self.use_local_model_fallback = False
        
        # Load dataset examples
        self.dataset_loader = DatasetLoader(config.DATASET_PATH)
        logger.info(f"Loaded {len(self.dataset_loader.examples)} examples from dataset")
        
        # Initialize MLflow tracker
        self.mlflow_tracker = MLflowTracker(config)
    
    def _create_openai_client(self):
        """Create a fresh OpenAI client for each request."""
        return openai.OpenAI(api_key=self.config.OPENAI_API_KEY)
    
    def generate_eli5_response(self, subject: str, max_length: Optional[int] = None) -> str:
        """
        Generate an ELI5 explanation for the given subject with MLflow tracking.
        
        Args:
            subject: The topic to explain
            max_length: Optional maximum length of the response
            
        Returns:
            A simplified explanation
        """
        start_time = time.time()
        model_used = "unknown"
        success = False
        explanation = ""
        
        try:
            # Format the prompt
            prompt = self.config.ELI5_PROMPT_TEMPLATE.format(subject=subject)
            
            # Use provided max_length if available, otherwise use default
            response_max_length = max_length if max_length is not None else self.config.MAX_RESPONSE_LENGTH
            
            # Try OpenAI first if API key is available
            if self.has_openai_key:
                try:
                    explanation = self._generate_with_openai(prompt, max_length)
                    model_used = "openai_" + self.config.OPENAI_MODEL
                    success = True
                except Exception as e:
                    logger.error(f"OpenAI generation failed: {e}")
                    if not self.use_local_model_fallback:
                        explanation = f"Sorry, I couldn't explain '{subject}' right now. Try again later! #ELI5"
                        model_used = "openai_failed"
            
            # Fall back to local model if OpenAI fails or is not available
            if not success and self.use_local_model_fallback:
                try:
                    explanation = self._generate_with_local_model(prompt, max_length)
                    model_used = "local_model"
                    success = True
                except Exception as e:
                    logger.error(f"Local model generation failed: {e}")
                    explanation = f"Sorry, I couldn't explain '{subject}' right now. Try again later! #ELI5"
                    model_used = "local_failed"
            
            # If both failed
            if not success:
                explanation = f"Sorry, I couldn't explain '{subject}' right now. Try again later! #ELI5"
                model_used = "all_failed"
            
        finally:
            # Always log to MLflow
            response_time = time.time() - start_time
            self.mlflow_tracker.log_eli5_generation(
                subject=subject,
                explanation=explanation,
                model_used=model_used,
                response_time=response_time,
                success=success
            )
        
        return explanation
    
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
        """Generate response using the loaded dataset examples."""
        # Extract the subject from the prompt
        try:
            subject = prompt.split("Explain the following like I'm 5 years old.")[1].split("End your response")[0].strip()
            subject = subject.replace("Keep it under 260 characters and use a sarcastic, slightly condescending tone:", "").strip()
            subject = subject.replace("Keep it under 260 characters:", "").strip()
        except Exception as e:
            logger.error(f"Error extracting subject from prompt: {e}")
            subject = prompt  # Fallback to using the entire prompt
        
        logger.info(f"Extracted subject for local model: '{subject}'")
        
        # First, try to find an exact match in the dataset
        subject_lower = subject.lower()
        for example in self.dataset_loader.examples:
            if example['term'].lower() == subject_lower:
                logger.info(f"Found exact match for '{subject}' in dataset")
                return self._format_response(example['explanation'], max_length)
        
        # If no exact match, try partial matches
        for example in self.dataset_loader.examples:
            if subject_lower in example['term'].lower() or example['term'].lower() in subject_lower:
                logger.info(f"Found partial match for '{subject}' with '{example['term']}' in dataset")
                return self._format_response(example['explanation'], max_length)
        
        # If no match found in dataset, use a random example as a template and create a similar response
        if self.dataset_loader.examples:
            random_example = random.choice(self.dataset_loader.examples)
            logger.info(f"No match found for '{subject}', using template style from '{random_example['term']}'")
            
            # Create a response in the same sarcastic style as the dataset
            sarcastic_responses = [
                f"Oh, {subject}? Just that incredibly important concept that everyone except you seems to understand. It's fundamental knowledge that shapes how we see the world, but don't worry—ignorance is bliss, right? #ELI5",
                f"Seriously? You don't know about {subject}? It's only one of the most basic things people learn about, but I guess you were too busy scrolling through social media to pay attention in school. #ELI5",
                f"{subject} is something that actually matters in the real world, unlike most of your daily activities. It's the kind of knowledge that separates informed people from... well, you. But sure, I'll break it down. #ELI5",
                f"Wow, asking about {subject}? That's like asking what water is—it's so fundamental that most people just know it. But hey, everyone starts somewhere, even if that somewhere is embarrassingly late. #ELI5",
                f"{subject}? Oh, just that thing that people with actual curiosity about the world already understand. It's fascinating stuff, though I doubt you'll retain much of this explanation anyway. #ELI5"
            ]
            
            return self._format_response(random.choice(sarcastic_responses), max_length)
        
        # Final fallback if no dataset is available
        return f"Sorry, I couldn't explain '{subject}' right now. Try again later! #ELI5"
    
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
        "description": "API for generating 'Explain Like I'm 5' explanations that mimic the style of provided examples",
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
        # Log the request
        logger.info(f"Received explanation request for subject: {request.subject}")
        
        # Validate input
        if not request.subject.strip():
            logger.warning("Empty subject received")
            raise HTTPException(status_code=400, detail="Subject cannot be empty")
        
        # Generate explanation
        logger.info("Generating explanation...")
        explanation = llm_client.generate_eli5_response(request.subject, request.max_length)
        logger.info(f"Generated explanation: {explanation}")
        
        # Log the interaction to the dataset
        try:
            dataset_logger.log_interaction(request.subject, explanation)
        except Exception as dataset_error:
            logger.warning(f"Failed to log to dataset, but continuing: {dataset_error}")
        
        # Return response
        logger.info("Returning successful response")
        return {
            "subject": request.subject,
            "explanation": explanation
        }
    except Exception as e:
        logger.error(f"Error generating explanation: {e}", exc_info=True)
        # Return a more generic error message to the client
        raise HTTPException(status_code=500, detail="An internal server error occurred while generating the explanation")

@app.get("/health")
async def health():
    """Health check endpoint with MLflow status."""
    # Check if OpenAI API key is available
    openai_status = "available" if llm_client.has_openai_key else "unavailable"
    
    # Check if local model is available
    local_model_status = "available" if llm_client.use_local_model_fallback else "unavailable"
    
    # Check if dataset is loaded
    dataset_status = "loaded" if len(llm_client.dataset_loader.examples) > 0 else "not loaded"
    
    # Check MLflow connection
    mlflow_status = "unknown"
    try:
        mlflow.get_experiment_by_name(config.MLFLOW_EXPERIMENT_NAME)
        mlflow_status = "connected"
    except Exception:
        mlflow_status = "disconnected"
    
    return {
        "status": "healthy",
        "openai_api": openai_status,
        "local_model": local_model_status,
        "dataset": dataset_status,
        "examples_count": len(llm_client.dataset_loader.examples),
        "mlflow": mlflow_status,
        "mlflow_experiment": config.MLFLOW_EXPERIMENT_NAME
    }

# Lambda handler function
def lambda_handler(event, context):
    """
    AWS Lambda handler function for the ELI5 API.
    
    Args:
        event: AWS Lambda event object
        context: AWS Lambda context object
        
    Returns:
        Dict with statusCode and body
    """
    try:
        import json
        import traceback
        
        logger.info("Lambda function invoked")
        logger.info(f"Event type: {type(event)}")
        logger.info(f"Event: {event}")
        
        # Check if OpenAI API key is available
        if not config.OPENAI_API_KEY:
            logger.warning("OpenAI API key not found in environment variables")
            # Set a default key for testing - this is just a placeholder and won't work
            # but it allows the code to proceed for debugging
            os.environ['OPENAI_API_KEY'] = 'sk-placeholder-for-debugging'
            config.OPENAI_API_KEY = os.environ['OPENAI_API_KEY']
            logger.info("Set placeholder OpenAI API key for debugging")
        
        # Extract the subject from the event
        subject = None
        max_length = None
        
        # Check if the event is from API Gateway
        if 'body' in event:
            logger.info("Found 'body' in event, parsing as API Gateway request")
            try:
                # Parse the body as JSON
                body_str = event.get('body', '{}')
                logger.info(f"Request body: {body_str}")
                
                body = json.loads(body_str)
                subject = body.get('subject')
                max_length = body.get('max_length')
                logger.info(f"Extracted subject: {subject}, max_length: {max_length}")
            except Exception as json_error:
                logger.error(f"Error parsing JSON body: {json_error}")
                logger.error(f"Body content: {event.get('body')}")
        
        # Check if the subject is in query parameters
        if not subject and 'queryStringParameters' in event and event['queryStringParameters']:
            logger.info("Subject not found in body, checking query parameters")
            subject = event['queryStringParameters'].get('subject')
            max_length_str = event['queryStringParameters'].get('max_length')
            max_length = int(max_length_str) if max_length_str and max_length_str.isdigit() else None
            logger.info(f"Extracted subject from query params: {subject}, max_length: {max_length}")
        
        # Check if the subject is directly in the event
        if not subject and 'subject' in event:
            logger.info("Subject not found in body or query params, checking event directly")
            subject = event.get('subject')
            max_length = event.get('max_length')
            logger.info(f"Extracted subject from event: {subject}, max_length: {max_length}")
        
        # If no subject found, return an error
        if not subject:
            logger.warning("No subject found in request")
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
                },
                'body': json.dumps({
                    'error': 'No subject provided'
                })
            }
        
        # Generate the explanation
        logger.info(f"Generating explanation for subject: {subject}")
        explanation = llm_client.generate_eli5_response(subject, max_length)
        logger.info(f"Generated explanation: {explanation}")
        
        # Log the interaction to the dataset
        try:
            dataset_logger.log_interaction(subject, explanation)
        except Exception as dataset_error:
            logger.warning(f"Failed to log to dataset, but continuing: {dataset_error}")
        
        # Return the response
        logger.info("Returning successful response")
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
            },
            'body': json.dumps({
                'subject': subject,
                'explanation': explanation
            })
        }
    except Exception as e:
        logger.error(f"Error in lambda_handler: {e}")
        logger.error(traceback.format_exc())
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
            },
            'body': json.dumps({
                'error': 'An internal server error occurred while processing your request',
                'debug_info': str(e) if os.environ.get('DEBUG', 'false').lower() == 'true' else None
            })
        }

# Run the application
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
