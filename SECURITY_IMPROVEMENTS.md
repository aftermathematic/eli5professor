# Security Improvements - Discord Bot Token Management

## Issue Identified
GitHub detected a publicly leaked Discord bot token in the repository:
- **Token**: `MTM4NjQ2Njk4MzI3NjU3Njg3MA.GRsps_.YnIaVZp24DGg6Kmb-Z6nQaC2ajg8fwVDQxPhXM`
- **Location**: `bot-update-config.json`
- **Risk**: Unauthorized access to Discord bot functionality

## Security Improvements Implemented

### 1. Moved Secrets to AWS Secrets Manager
- **Secret Name**: `eli5-discord-bot/discord-credentials-dev`
- **Stored Credentials**:
  - `DISCORD_BOT_TOKEN`
  - `DISCORD_CHANNEL_ID`
  - `DISCORD_SERVER_ID`
  - `TARGET_USER_ID`

### 2. Updated Configuration Files
- **File**: `bot-update-config.json`
- **Change**: Removed all hardcoded sensitive tokens
- **Result**: Configuration now only contains non-sensitive environment variables

### 3. Enhanced .gitignore
Added comprehensive Terraform exclusions:
```
# Terraform
*.tfstate
*.tfstate.*
*.tfvars
!*.tfvars.template
.terraform/
.terraform.lock.hcl
```

### 4. Removed Sensitive Files from Git
- Removed `terraform.tfstate` from Git tracking
- This file contained the Discord bot token in the Terraform state

## Infrastructure Configuration

### App Runner Service Configuration
The Discord bot service is already configured in Terraform to use AWS Secrets Manager:

```hcl
environment_variables = {
  DISCORD_BOT_TOKEN    = "${aws_secretsmanager_secret.discord_credentials.name}:DISCORD_BOT_TOKEN"
  DISCORD_CHANNEL_ID   = "${aws_secretsmanager_secret.discord_credentials.name}:DISCORD_CHANNEL_ID"
  DISCORD_SERVER_ID    = "${aws_secretsmanager_secret.discord_credentials.name}:DISCORD_SERVER_ID"
  TARGET_USER_ID       = "${aws_secretsmanager_secret.discord_credentials.name}:TARGET_USER_ID"
  # ... other variables
}
```

## Next Steps Required

### 1. Rotate the Discord Bot Token
**IMPORTANT**: The exposed token should be rotated in Discord:
1. Go to Discord Developer Portal
2. Navigate to your application
3. Go to "Bot" section
4. Click "Reset Token"
5. Update the new token in AWS Secrets Manager

### 2. Update AWS Secrets Manager
After rotating the token, update the secret:
```bash
aws secretsmanager update-secret \
  --secret-id "eli5-discord-bot/discord-credentials-dev" \
  --secret-string '{"DISCORD_BOT_TOKEN":"NEW_TOKEN_HERE","DISCORD_CHANNEL_ID":"1386452379733594145","DISCORD_SERVER_ID":"1386452379733594142","TARGET_USER_ID":"1386466983276576870"}' \
  --region eu-west-3
```

### 3. Redeploy Discord Bot Service
After updating the secret, trigger a new deployment:
```bash
aws apprunner start-deployment \
  --service-arn "arn:aws:apprunner:eu-west-3:335561736978:service/eli5-discord-bot-discord-bot-dev/a5592aca377042f5805c7595bd63a2a8"
```

## Security Best Practices Implemented

1. **Secrets Management**: All sensitive credentials now stored in AWS Secrets Manager
2. **Infrastructure as Code**: Terraform configuration uses secret references, not hardcoded values
3. **Git Security**: Sensitive files excluded from version control
4. **Least Privilege**: App Runner services have specific IAM roles for secret access

## Verification

The security improvements have been successfully implemented:
- ✅ Discord bot token removed from configuration files
- ✅ Secrets stored securely in AWS Secrets Manager
- ✅ Terraform state files excluded from Git
- ✅ Infrastructure configured to use secret references
- ✅ Changes committed and pushed to GitHub

**Status**: Security vulnerability mitigated. Token rotation required to complete remediation.
