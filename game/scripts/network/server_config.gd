extends Node

## Configuration for the multiplayer backend. The matchmaker URL is read first
## from an environment variable, then from a project setting, then falls back to
## the production worker. Override at runtime by exporting CLOWNS_MM_URL before
## launching the game (handy for the dev environment or a local wrangler).

const DEFAULT_MATCHMAKER := "https://cm-matchmaker.workers.dev"
const ENV_VAR := "CLOWNS_MM_URL"
const SETTING_KEY := "application/config/matchmaker_url"

static func matchmaker_url() -> String:
	var from_env := OS.get_environment(ENV_VAR)
	if not from_env.is_empty():
		return from_env
	if ProjectSettings.has_setting(SETTING_KEY):
		var v: String = ProjectSettings.get_setting(SETTING_KEY)
		if not v.is_empty():
			return v
	return DEFAULT_MATCHMAKER

static func protocol_version() -> int:
	return 1
