--- Holographic Void: Tags Persistence
-- Matches Til Death/Rebirth Tag Manager (Saves to tags.lua)
-- This allows tags to be shared across themes in the same Etterna install.

local defaultConfig = {
	playerTags = {}
}

-- Use a local setting object for each possible profile slot
local TAGS_P1 = create_setting("tags_p1", "tags.lua", defaultConfig, 0)
local TAGS_P2 = create_setting("tags_p2", "tags.lua", defaultConfig, 0)

TAGMAN = {
	get_data = function(self)
		local slot = pn_to_profile_slot(GAMESTATE:GetMasterPlayerNumber())
		if slot == "ProfileSlot_Player1" then
			return TAGS_P1:get_data(slot)
		elseif slot == "ProfileSlot_Player2" then
			return TAGS_P2:get_data(slot)
		end
		-- Fallback to P1 load if no master player or something weird
		return TAGS_P1:get_data("ProfileSlot_Player1")
	end,
	set_dirty = function(self)
		local slot = pn_to_profile_slot(GAMESTATE:GetMasterPlayerNumber())
		if slot == "ProfileSlot_Player1" then
			TAGS_P1:set_dirty(slot)
		elseif slot == "ProfileSlot_Player2" then
			TAGS_P2:set_dirty(slot)
		end
	end,
	save = function(self)
		local slot = pn_to_profile_slot(GAMESTATE:GetMasterPlayerNumber())
		if slot == "ProfileSlot_Player1" then
			TAGS_P1:save(slot)
		elseif slot == "ProfileSlot_Player2" then
			TAGS_P2:save(slot)
		end
	end,
	load = function(self)
		TAGS_P1:load("ProfileSlot_Player1")
		TAGS_P2:load("ProfileSlot_Player2")
	end
}

-- Initial load
TAGMAN:load()

Trace("Holographic Void: TAGMAN initialized (Per-Profile)")
