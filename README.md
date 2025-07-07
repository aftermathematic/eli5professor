# ELI5 Discord Bot – MLOps Powered Keyword Explainer

## Project Overview

The **ELI5 Discord Bot** is an AI-powered Discord bot designed to make complex topics simple. Whenever the bot is mentioned in a Discord channel alongside the `#eli5` hashtag and a subject, it automatically replies with a child-friendly ("Explain Like I'm 5") description of that subject.

The bot is developed using MLOps principles, ensuring it is robust, reproducible, cloud-deployable, and easy to scale and maintain. **All operational aspects—model deployment, data management, CI/CD, configuration—are automated and version-controlled.**

---

## How It Works

### Discord Bot Workflow

1. **Listening:** The bot monitors Discord channels for mentions that include the `#eli5` hashtag.
2. **Queue Processing:** Mentions are saved to a CSV queue for asynchronous processing.
3. **Processing:** The bot extracts the subject, uses a large language model (OpenAI API or local Hugging Face model) to generate an ELI5 explanation.
4. **Replying:** The bot posts the explanation back to the Discord channel via webhook.
5. **Logging/Tracking:** All interactions, predictions, and model behavior are logged with MLflow for traceability and improvement.

### API Service

1. **Endpoint:** The API exposes an `/explain` endpoint that accepts POST requests with a subject to explain.
2. **Processing:** The API uses the same language model and dataset as the Discord bot to generate ELI5 explanations.
3. **Response:** The API returns a JSON response with the subject and explanation.
4. **Health Check:** The API includes a `/health` endpoint to monitor service status including MLflow connectivity.

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
| Discord Connector   | discord.py              | Listen and respond to Discord messages      |
| Configuration Mgmt  | YAML                    | Store configurable values and secrets       |
| CI/CD               | GitHub Actions          | Build/test/deploy automation                |

---

## Discord Bot Components

The Discord bot consists of three main components:

### 1. Mention Listener (`get_discord_mentions.py`)
- Listens for Discord mentions that include `#eli5` hashtag
- Extracts keywords after mentions
- Saves mentions to `mentions.csv` queue for processing
- Runs continuously with real-time message monitoring

### 2. Queue Processor (`post_replies.py`)
- Reads oldest mentions from CSV queue
- Calls the `/explain` API for ELI5 generation
- Posts responses to Discord via webhook
- Removes processed mentions from queue
- Runs continuously with 30-second intervals

### 3. ELI5 API Service (`app.py`)
- FastAPI service with `/explain` endpoint
- OpenAI + local model fallback
- Dataset-driven sarcastic responses
- **MLflow experiment tracking** for all generations
- Proper formatting with #ELI5 hashtag

---

## MLflow Integration

The bot now includes comprehensive MLflow tracking for MLOps compliance:

### Tracked Metrics
- **Parameters**: Subject, model used, max response length
- **Metrics**: Response time, response length, success rate, hashtag presence
- **Artifacts**: Generated responses saved as text files
- **Tags**: Request type, model type for filtering experiments

### MLflow Configuration
```yaml
mlflow:
  tracking_uri: "file:./mlruns"
  experiment_name: "eli5-discord-bot"
```

### Viewing Experiments
```bash
# Start MLflow UI
mlflow ui --backend-store-uri ./mlruns

# Access at http://localhost:5000
```

---

## Setup Instructions

### Prerequisites

- Python 3.10+
- Discord Bot Token and Channel/Server IDs
- OpenAI API key (optional if using local model)
- Discord Webhook URL for posting responses

### Configuration

#### Environment Variables

Create a `.env` file in the project root with the following variables:

```
# Discord Bot Configuration
DISCORD_BOT_TOKEN=your_discord_bot_token
DISCORD_CHANNEL_ID=your_channel_id
DISCORD_SERVER_ID=your_server_id
TARGET_USER_ID=your_bot_user_id

# OpenAI Configuration (optional if using local model)
OPENAI_API_KEY=your_openai_api_key
OPENAI_MODEL=gpt-3.5-turbo

# MLflow Configuration (optional)
MLFLOW_TRACKING_URI=file:./mlruns
MLFLOW_EXPERIMENT_NAME=eli5-discord-bot
```

#### YAML Configuration

The bot uses YAML configuration files for non-sensitive settings. The configuration file is located at `config/config.yml`:

```yaml
# ELI5 Discord Bot Configuration

# Logging configuration
logging:
  level: "INFO"
  format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
  log_file: "eli5bot.log"

# OpenAI configuration
openai:
  model: "gpt-3.5-turbo"
  max_tokens: 500
  temperature: 0.8
  use_local_model_fallback: true

# Dataset configuration
dataset:
  examples_dataset_path: "data/dataset.csv"
  eli5_dataset_path: "data/eli5_dataset.csv"
  num_examples: 3

# API configuration
api:
  max_response_length: 280

# MLflow configuration
mlflow:
  tracking_uri: "file:./mlruns"
  experiment_name: "eli5-discord-bot"
```

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/eli5professor.git
   cd eli5professor
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Run the components:
   ```bash
   # Run the Discord mention listener
   python src/get_discord_mentions.py
   
   # Run the API server (in separate terminal)
   uvicorn src.app:app --host 0.0.0.0 --port 8000
   
   # Run the queue processor (in separate terminal)
   python src/post_replies.py
   
   # Or run using Docker
   docker-compose up -d
   ```

4. Access the API documentation:
   ```
   http://localhost:8000/docs
   ```

5. View MLflow experiments:
   ```bash
   mlflow ui --backend-store-uri ./mlruns
   # Access at http://localhost:5000
   ```

---

## Usage

### Discord Usage
1. Mention the bot in a Discord channel with `#eli5` hashtag
2. Include the topic you want explained
3. Example: `@eliprofessor explain quantum physics #eli5`
4. The bot will respond with a simple explanation

### API Usage
```bash
# Test the API
curl -X POST "http://localhost:8000/explain" \
     -H "Content-Type: application/json" \
     -d '{"subject": "quantum physics", "max_length": 200}'
```

---

## MLOps Implementation Status

### ✅ Completed MLOps Components

1. **Containerization**: Application packaged in Docker for consistent deployment
2. **Infrastructure as Code**: Cloud resources defined with Terraform
3. **Data Versioning**: Datasets tracked with DVC and stored in cloud storage
4. **Configuration Management**: YAML configuration files for externalizing parameters
5. **Model Deployment**: FastAPI service for serving model predictions
6. **CI/CD Pipeline**: Automated testing and deployment with GitHub Actions
7. **Experiment Tracking**: MLflow integration for tracking model performance
8. **Monitoring**: Health checks and comprehensive logging

### 🎯 Project Completion: 95%

The Discord bot is **production-ready** with all major MLOps components implemented:
- ✅ Async queue-based processing architecture
- ✅ Scalable webhook-based responses
- ✅ Robust error handling and fallbacks
- ✅ MLflow experiment tracking
- ✅ Production-ready infrastructure
- ✅ Automated CI/CD pipeline

---

## Testing

### Test MLflow Integration
```bash
python test_mlflow.py
```

### Test API Health
```bash
curl http://localhost:8000/health
```

### Test Discord Bot Components
1. Start all three components (listener, API, processor)
2. Send a test message in Discord: `@yourbotname test subject #eli5`
3. Check logs and MLflow UI for tracking data

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.
