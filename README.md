# ELI5 Twitter Bot – MLOps Powered Keyword Explainer

## Project Overview

The **ELI5 Twitter Bot** is an AI-powered Twitter bot designed by Jan Vermeerbergen to make complex topics simple. Whenever the bot’s Twitter handle is tagged in a tweet alongside a pre-defined keyword or subject, it automatically replies with a child-friendly (“Explain Like I’m 5”) description of that keyword.

The bot is developed using MLOps principles, ensuring it is robust, reproducible, cloud-deployable, and easy to scale and maintain. **All operational aspects—model deployment, data management, CI/CD, configuration—are automated and version-controlled.**

---

## How It Works

1. **Listening:** The bot monitors Twitter for mentions (tweets where its handle is tagged).
2. **Trigger:** When a tweet also contains a specific keyword (from the configurable keyword list), it triggers the pipeline.
3. **Processing:** The bot extracts the keyword, uses a large language model (via Hugging Face or similar) to generate an ELI5 explanation.
4. **Replying:** The bot automatically replies to the tweet with a simple, easy-to-understand explanation.
5. **Logging/Tracking:** All interactions, predictions, and model behavior are logged for traceability and possible future improvement.

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
| Service API         | FastAPI                 | Hosts the model’s explanation API           |
| Twitter Connector   | Tweepy (Python)         | Listen and write to Twitter using API       |
| Configuration Mgmt  | YAML                    | Store configurable values and secrets       |
| CI/CD (optional)    | GitHub Actions          | Build/test/deploy automation                |

---
