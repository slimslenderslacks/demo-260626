
# pr-bot

```bash
# create a sandbox to review a PR
# add one skill, and access to api.github.com
mkdir ./tmp
export SKILL_PR="git+https://github.com/slimslenderslacks/demo-260626.git#dir=skills/pr-bot-skill"
sbx create --name pr-bot --kit $SKILL_PR_BOT claude .
sbx policy allow network "**.anthropic.com,api.github.com"

sbx run --name pr-bot
```

# notion-report-bot

```bash
# create a sandbox to review a PR
# add one skill, no github, and the notion mcp
sbx mcp add notion --url https://mcp.notion.com/mcp
sbx mcp auth notion
export SKILL_NOTION_REPORT="git+https://github.com/slimslenderslacks/demo-260626.git#dir=skills/change-report-bot-skill"
sbx create --name notion-report-bot --kit $SKILL_NOTION_REPORT --static-mcp notion claude .
sbx policy allow network "**.anthropic.com"

sbx run --name notion-report-bot
```

# sbx cloud

```bash
export SKILL_PR="git+https://github.com/slimslenderslacks/demo-260626.git#dir=skills/pr-bot-skill"
sbx create --cloud --name pr-bot --kit $SKILL_PR_BOT claude .

sbx ls --cloud
```


