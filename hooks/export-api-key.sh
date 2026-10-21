#!/bin/sh
# Hand the API key from the plugin's user config to the shell commands the
# skills run. Claude Code does not put a sensitive value into skill text, so
# this hook exports it as GAFFA_API_KEY through CLAUDE_ENV_FILE, which the
# Bash tool sources before every command. Nothing is written when the key was
# not entered, so an environment variable set the usual way still applies.
if [ -n "$CLAUDE_PLUGIN_OPTION_GAFFA_API_KEY" ] && [ -n "$CLAUDE_ENV_FILE" ]; then
  printf 'export GAFFA_API_KEY=%s\n' "'$(printf '%s' "$CLAUDE_PLUGIN_OPTION_GAFFA_API_KEY" | sed "s/'/'\\\\''/g")'" >> "$CLAUDE_ENV_FILE"
fi
