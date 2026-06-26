
# pr-bot

```bash
# create a sandbox to review a PR
# add one skill, and access to api.github.com
sbx settings set kit.allowedSources '["docker.io/","github.com/slimslenderslacks/"]'

export SKILL_PR="git+https://github.com/slimslenderslacks/demo-260626.git#dir=skills/pr-bot-skill"
sbx create --name pr-bot --kit $SKILL_PR claude .
sbx policy allow network "**.anthropic.com,api.github.com"
sbx secret set pr-bot github -t "$(gh auth token)"

sbx run --name pr-bot
```

Enter a prompt like:

> research the PR https://github.com/docker/sandboxes/pull/3491

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

Enter a prompt like:

> make a notion report for summary.md

# sbx cloud

```bash
sbx create --cloud --name pr-bot --kit $SKILL_PR claude .

sbx ls --cloud
```

There's a bug in `sbx --cloud` so you need to find the `ID` of the sandbox you just created because we can not currently exec cloud sandboxes by name.

```
./cloud-fork.sh -s $SANDBOX_ID

# use --kill to kill them all
./cloud-fork.sh -s $SANDBOX_ID --kill
```

# Agentic Platform
