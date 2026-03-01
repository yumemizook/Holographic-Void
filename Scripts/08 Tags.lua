--- Holographic Void: Tags Persistence
-- Matches Til Death/Rebirth Tag Manager (Saves to tags.lua)
-- This allows tags to be shared across themes in the same Etterna install.

local defaultConfig = {
	playerTags = {}
}

-- create_setting is a fallback utility that handles per-profile or global settings.
-- We use match_depth = 0 to allow the table to expand freely.
TAGMAN = create_setting("tags", "tags.lua", defaultConfig, 0)
TAGMAN:load()

Trace("Holographic Void: TAGMAN initialized (Source: tags.lua)")
