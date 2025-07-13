# Secret Management Guide

## Problem Fixed
GitHub's push protection was blocking commits because secrets (Discord Bot Token and OpenAI API Key) were hardcoded in the repository.

## Solution Implemented

### 1. Template-Based Configuration
- Created `discord.tfvars.template` with placeholder values
- Updated `.gitignore` to exclude `*.tfvars` files (except templates)
- Removed problematic commit from git history

### 2. Proper Secret Handling
- Real secrets should ONLY be stored in local `discord.tfvars` file
- This file is now gitignored and will not be committed
- Use the template to create your local configuration

## How to Use

### Initial Setup
1. Copy the template:
   ```bash
   cp discord.tfvars.template discord.tfvars
   ```

2. Edit `discord.tfvars` with your real secrets:
   ```
   discord_bot_token    = "YOUR_ACTUAL_DISCORD_BOT_TOKEN"
   discord_channel_id   = "1386452379733594145"
   discord_server_id    = "1386452379733594142"
   target_user_id       = "1386466983276576870"
   openai_api_key       = "YOUR_ACTUAL_OPENAI_API_KEY"
   ```

3. The file `discord.tfvars` will be ignored by git and won't be committed

### Using Terraform
Deploy using your local discord.tfvars file:
```bash
terraform plan -var-file=dev.tfvars -var-file=discord.tfvars
terraform apply -var-file=dev.tfvars -var-file=discord.tfvars
```

## Security Best Practices
- ✅ Never commit real secrets to git
- ✅ Use template files for configuration structure
- ✅ Keep sensitive files in .gitignore
- ✅ Use environment variables in production
- ✅ Rotate secrets regularly

## Files Modified
- `infra/.gitignore` - Added *.tfvars exclusion
- `infra/discord.tfvars.template` - Created template with placeholders
- Removed commit with hardcoded secrets from git history
