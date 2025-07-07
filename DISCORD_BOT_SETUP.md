# Discord Bot Setup Guide

This guide explains how to set up the Discord bot that listens for mentions of @eliprofessor and adds them to the mentions.csv file.

## Prerequisites

- Python 3.8 or higher
- A Discord account
- Permission to create a Discord bot and add it to a server

## Step 1: Create a Discord Bot

1. Go to the [Discord Developer Portal](https://discord.com/developers/applications)
2. Click "New Application" and give your application a name (e.g., "ELI5Professor")
3. Navigate to the "Bot" tab and click "Add Bot"
4. Under the "TOKEN" section, click "Copy" to copy your bot token
   - Keep this token secure! It provides full access to your bot.
5. Under "Privileged Gateway Intents", enable:
   - Server Members Intent (required for the bot to access all channels in a server)
6. Save your changes

## Step 2: Invite the Bot to Your Server

1. In the Developer Portal, go to the "OAuth2" tab, then "URL Generator"
2. Under "Scopes", select "bot"
3. Under "Bot Permissions", select:
   - Read Messages/View Channels
   - Send Messages
   - Read Message History
4. Copy the generated URL and open it in your browser
5. Select the server you want to add the bot to and authorize it

## Step 3: Get Your Discord Server and Channel IDs

1. Open Discord
2. Go to User Settings > Advanced and enable "Developer Mode"
3. Right-click on the server (guild) where your channel is located
4. Select "Copy ID" to get the server ID
5. Right-click on the channel where you want the bot to listen for mentions
6. Select "Copy ID" to get the channel ID

## Step 4: Configure Environment Variables

1. Create a `.env` file in the root directory of the project (you can copy from `.env.example`)
2. Add the following variables:
   ```
   DISCORD_BOT_TOKEN=your_discord_bot_token_here
   DISCORD_SERVER_ID=your_discord_server_id_here
   DISCORD_CHANNEL_ID=your_discord_channel_id_here
   ```
   Replace the placeholders with your actual bot token and channel ID

## Step 5: Install Dependencies

```bash
pip install -r requirements.txt
```

## Step 6: Run the Discord Bot

```bash
python src/get_discord_mentions.py
```

The bot will now listen for mentions of @eliprofessor in the specified Discord channel and add them to the mentions.csv file.

## How It Works

1. The bot connects to Discord and listens for messages in the specified channel
2. When the bot is directly mentioned (using @botname), it records:
   - The message ID (stored as tweet_id in the CSV)
   - The author's name
   - A placeholder for the message content
3. This information is added to the mentions.csv file with a timestamp
4. The post_replies.py script can then process these mentions and post replies to Discord

## Troubleshooting

- If the bot doesn't respond to mentions, check that:
  - The bot is running
  - The bot has the correct permissions
  - You're mentioning @eliprofessor in the correct channel
  - The DISCORD_CHANNEL_ID in your .env file is correct
- If you see errors about missing environment variables, check your .env file
- If you see connection errors, check your internet connection and Discord's status
