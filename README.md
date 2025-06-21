# ELI5 Twitter Bot – MLOps Powered Keyword Explainer

## Project Overview

The **ELI5 Twitter Bot** is an AI-powered Twitter bot designed to make complex topics simple. Whenever the bot's Twitter handle is tagged in a tweet alongside a subject, it automatically replies with a child-friendly ("Explain Like I'm 5") description of that subject.

The bot is developed using MLOps principles, ensuring it is robust, reproducible, cloud-deployable, and easy to scale and maintain. **All operational aspects—model deployment, data management, CI/CD, configuration—are automated and version-controlled.**

---

## How It Works

### Twitter Bot

1. **Listening:** The bot monitors Twitter for mentions (tweets where its handle is tagged).
2. **Trigger:** When a tweet contains a subject to explain, it triggers the pipeline.
3. **Processing:** The bot extracts the subject, uses a large language model (OpenAI API or local Hugging Face model) to generate an ELI5 explanation.
4. **Replying:** The bot automatically replies to the tweet with a simple, easy-to-understand explanation.
5. **Logging/Tracking:** All interactions, predictions, and model behavior are logged for traceability and possible future improvement.

### API Service

1. **Endpoint:** The API exposes an `/explain` endpoint that accepts POST requests with a subject to explain.
2. **Processing:** The API uses the same language model and dataset as the Twitter bot to generate ELI5 explanations.
3. **Response:** The API returns a JSON response with the subject and explanation.
4. **Health Check:** The API includes a `/health` endpoint to monitor the service status.

---

## Project Architecture & Technologies

| Component           | Technology/Tool         | Purpose                                     |
|---------------------|-------------------------|---------------------------------------------|
| Cloud Provider      | AWS Free Tier           | Hosting models, services, and storage       |
| IaC                 | Terraform               | Version-controlled cloud resource setup     |
| Data Versioning     | DVC                     | Track and share datasets & model artifacts  |
| Source Control      | GitHub                  | Codebase control, CI/CD                     |
| Containerization    | Docker                  | Portable, reproducible execution            |
| Model Management    | MLflow, Hugging Face    | Model tracking, utilizing pre-trained LLMs  |
| Service API         | FastAPI                 | Hosts the model's explanation API           |
| Twitter Connector   | Tweepy (Python)         | Listen and write to Twitter using API       |
| Configuration Mgmt  | YAML                    | Store configurable values and secrets       |
| CI/CD (optional)    | GitHub Actions          | Build/test/deploy automation                |

---

## Recent Code Improvements

The codebase has been significantly refactored to follow MLOps best practices:

1. **Object-Oriented Design**: Restructured the code into classes with clear responsibilities:
   - `Config`: Centralized configuration management
   - `TwitterClient`: Handles Twitter API interactions
   - `LLMClient`: Manages language model interactions (OpenAI and local model)
   - `LastSeenIdManager`: Manages tweet ID persistence
   - `TweetProcessor`: Processes tweets and extracts subjects
   - `RateLimitHandler`: Handles Twitter API rate limiting
   - `ELI5Bot`: Main orchestration class

2. **Model Fallback Mechanism**: Added ability to fall back to a local Hugging Face model when OpenAI API fails or is unavailable.

3. **Improved Error Handling**: Comprehensive error handling with proper logging.

4. **Logging**: Added structured logging to track bot operations and troubleshoot issues.

5. **Type Hints**: Added type annotations for better code quality and IDE support.

6. **Configuration Management**: YAML configuration files and environment variables with defaults for all configurable parameters.

7. **Rate Limit Handling**: Improved handling of Twitter API rate limits with intelligent backoff.

---

## Setup Instructions

### Prerequisites

- Python 3.8+
- Twitter Developer Account with API credentials
- OpenAI API key (optional if using local model)

### Configuration

#### Environment Variables

Create a `.env` file in the project root with the following variables:

```
# Twitter API credentials
TWITTER_API_KEY=your_api_key
TWITTER_API_SECRET=your_api_secret
TWITTER_ACCESS_TOKEN=your_access_token
TWITTER_ACCESS_TOKEN_SECRET=your_access_token_secret
TWITTER_BEARER_TOKEN=your_bearer_token
TWITTER_ACCOUNT_HANDLE=your_bot_handle_without_@
TWITTER_USER_ID=your_twitter_user_id

# OpenAI configuration (optional if using local model)
OPENAI_API_KEY=your_openai_api_key
```

#### YAML Configuration

The bot uses YAML configuration files for non-sensitive settings. The default configuration file is located at `config/config.yml`:

```yaml
# ELI5 Twitter Bot Configuration

# Environment settings
environment: dev  # Options: dev, prod

# Twitter API settings
twitter:
  poll_interval: 960  # 16 minutes by default
  max_tweet_length: 280

# OpenAI settings
openai:
  model: gpt-3.5-turbo
  temperature: 0.8
  max_tokens: 500
  use_local_model_fallback: true

# Dataset settings
dataset:
  eli5_dataset_path: data/eli5_dataset.csv
  examples_dataset_path: data/dataset.csv
  num_examples: 3  # Number of examples to use for few-shot learning

# Prompt settings
prompts:
  eli5_prompt_template: |
    # Template for generating ELI5 explanations
    # {subject} will be replaced with the actual subject
  
  system_prompt: |
    # System prompt for the OpenAI API

# Logging settings
logging:
  log_file: eli5bot.log
  level: INFO  # Options: DEBUG, INFO, WARNING, ERROR, CRITICAL
  format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

# File paths
paths:
  last_seen_file: last_seen_id.txt
```

You can modify these settings to customize the bot's behavior without changing the code.

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/eli5-twitter-bot.git
   cd eli5-twitter-bot
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Run the bot or API:
   ```bash
   # Run the Twitter bot
   python src/main.py
   
   # Run the API server
   uvicorn src.app:app --host 0.0.0.0 --port 8000
   
   # Or run both using Docker Compose
   docker-compose up -d
   ```

4. Access the API documentation:
   ```
   http://localhost:8000/docs
   ```

---

## MLOps Roadmap

Current MLOps implementations:

1. **Containerization**: ✅ Application packaged in Docker for consistent deployment.
2. **Infrastructure as Code**: ✅ Cloud resources defined with Terraform.
3. **Data Versioning**: ✅ Datasets tracked with DVC and stored in S3.
4. **Configuration Management**: ✅ YAML configuration files for externalizing parameters.
5. **Model Deployment**: ✅ FastAPI service for serving model predictions.

Future MLOps improvements planned for this project:

1. **CI/CD Pipeline**: Implement automated testing and deployment with GitHub Actions.
2. **Monitoring**: Add Prometheus/Grafana for real-time monitoring.
3. **Model Versioning**: Track model versions and performance with MLflow.
4. **A/B Testing**: Implement framework for testing different prompt strategies.
5. **Automated Retraining**: Set up pipeline for fine-tuning models based on feedback.

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.
