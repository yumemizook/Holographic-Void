--- Holographic Void: Custom Colors Storage System
-- @module 05_CustomColors
-- Persistent storage for user-defined custom colors per element category.
-- Loaded after colorConfig if available, or uses create_setting fallback.

local defaultCustomColors = {
	accent = {
		Accent = "#5ABAFF",
	},

	grades = {
		AAAAA = "#FFFFFF",
		AAAA  = "#80C0CF",
		AAA   = "#CFD198",
		AA    = "#A0CFAB",
		A     = "#CF9898",
		B     = "#98B8CF",
		C     = "#B898CF",
		D     = "#CF98B8",
		F     = "#606060",
		None  = "#454545",
		-- Mid-tier grades
		["AAAA:"] = "#85C5D2",
		["AAAA."] = "#8ACAD6",
		["AAA:"]  = "#D4D59D",
		["AAA."]  = "#D9D9A2",
		["AA:"]   = "#A5D4B0",
		["AA."]   = "#AAD9B5",
		["A:"]    = "#D49D9D",
		["A."]    = "#D9A2A2",
	},
	
	judgment = {
		Ridiculous = "#FFD7FF",
		W1   = "#f1ffff",
		W2   = "#FFFFB7",
		W3   = "#A0E0A0",
		W4   = "#A0C8E0",
		W5   = "#C8A0E0",
		Miss = "#E0A0A0",
		Held = "#8fbb84ff",
		LetGo = "#E0A0A0",
	},
	
	difficulty = {
		Beginner  = "#98B8CF",
		Easy      = "#A0CFAB",
		Medium    = "#CFD198",
		Hard      = "#CF9898",
		Challenge = "#B898CF",
		Edit      = "#8C8C8C",
	},
	
	clearType = {
		RFC     = "#FFD7FF",
		RF      = "#E8C8F8",
		SDM     = "#D8C0F0",
		MFC     = "#E0F8FF",
		WF      = "#E0E0E0",
		SDP     = "#CFD198",
		PFC     = "#CFD198",
		BF      = "#B898CF",
		SDG     = "#A0CFAB",
		FC      = "#A0CFAB",
		MF      = "#CF9898",
		SDCB    = "#80C0CF",
		Clear   = "#5ABAFF",
		Failed  = "#CF9898",
		Invalid = "#454545",
		NoPlay  = "#252525",
		None    = "#252525",
		SoftInvalid = "#A68060",
	},
	
	goalTracker = {
		Positive = "#A0CFAB",
		Negative = "#CF9898",
	},

	lifeBar = {
		L1 = "#A0CFAB",
		L2 = "#A0CFAB",
		L3 = "#5ABAFF",
		L4 = "#5ABAFF",
		L5 = "#CFD198",
		L6 = "#E0B080",
		L7 = "#CF9898",
		Danger = "#FF4444",
	},

	radar = {
		Power = "#E0B080",
		Chaos = "#B898CF",
		Hell = "#CF9898",
		Mach = "#80C0CF",
		Freeze = "#CFD198",
		Earth = "#A0CFAB",
	},
}

-- Use create_setting if available, otherwise fall back to simple table storage
local customColorConfig = nil
local usingFallbackStorage = false

if create_setting then
	customColorConfig = create_setting("HVCustomColors", "Holographic Void_customColors.lua", defaultCustomColors, -1)
else
	-- Fallback: manual file-based storage
	usingFallbackStorage = true
end

local customColorData = nil

-- Initialize the custom color data
local function initCustomColors()
	if customColorData then return end
	
	if customColorConfig and customColorConfig.get_data then
		customColorData = customColorConfig:get_data()
	else
		-- Manual load from file
		local path = "Save/Holographic Void_settings/HVCustomColors.lua"
		local file = RageFileUtil.CreateRageFile()
		if file:Open(path, 1) then -- READ
			local content = file:Read()
			file:Close()
			if content and content ~= "" then
				local chunk = loadstring(content)
				if chunk then
					local success, data = pcall(chunk)
					if success and type(data) == "table" then
						customColorData = data
					end
				end
			end
		end
		file:destroy()
	end
	
	-- Initialize with defaults if nil or empty
	if not customColorData then
		customColorData = {}
		for cat, elements in pairs(defaultCustomColors) do
			customColorData[cat] = {}
			for elem, color in pairs(elements) do
				customColorData[cat][elem] = color
			end
		end
	end
	
	-- Ensure all categories exist (merge with defaults)
	for cat, elements in pairs(defaultCustomColors) do
		if not customColorData[cat] then customColorData[cat] = {} end
		for elem, color in pairs(elements) do
			if customColorData[cat][elem] == nil then
				customColorData[cat][elem] = color
			end
		end
	end

	if type(customColorData.__syncToAccent) ~= "table" then
		customColorData.__syncToAccent = {}
	end
end

local function normalizeHex(hex)
	if type(hex) ~= "string" then return nil end
	if hex == "" then return nil end
	if hex:sub(1, 1) ~= "#" then hex = "#" .. hex end
	if not hex:match("^#[0-9A-Fa-f]+$") then return nil end
	return hex
end

-- Save custom colors to file
local function saveCustomColors()
	if customColorConfig and customColorConfig.set_dirty then
		customColorConfig:set_dirty()
		customColorConfig:save()
	else
		-- Manual save
		local path = "Save/Holographic Void_settings/HVCustomColors.lua"
		local file = RageFileUtil.CreateRageFile()
		if file:Open(path, 2) then -- WRITE
			local function tableToString(tbl, indent)
				indent = indent or 0
				local indentStr = string.rep("\t", indent)
				local result = "{\n"
				for k, v in pairs(tbl) do
					if type(v) == "table" then
						result = result .. indentStr .. "\t[" .. string.format("%q", k) .. "] = " .. tableToString(v, indent + 1) .. ",\n"
					elseif type(v) == "string" then
						result = result .. indentStr .. "\t[" .. string.format("%q", k) .. "] = " .. string.format("%q", v) .. ",\n"
					else
						result = result .. indentStr .. "\t[" .. string.format("%q", k) .. "] = " .. tostring(v) .. ",\n"
					end
				end
				result = result .. indentStr .. "}"
				return result
			end
			
			file:Write("return " .. tableToString(customColorData))
			file:Close()
		end
		file:destroy()
	end
end

-- Public API
HVCustomColors = {}

--- Get a custom color hex string for a category and element
function HVCustomColors.GetColor(category, element)
	initCustomColors()
	if not customColorData or not customColorData[category] then
		return defaultCustomColors[category] and defaultCustomColors[category][element] or "#FFFFFF"
	end
	return customColorData[category][element] or defaultCustomColors[category][element] or "#FFFFFF"
end

--- Set a custom color hex string for a category and element
function HVCustomColors.SetColor(category, element, hex)
	initCustomColors()
	if not customColorData[category] then customColorData[category] = {} end
	customColorData[category][element] = hex
	saveCustomColors()
	MESSAGEMAN:Broadcast("CustomColorChanged", { Category = category, Element = element, Color = hex })
end

--- Get all elements for a category
function HVCustomColors.GetElements(category)
	initCustomColors()
	local ordered = {
		grades = {
			"AAAAA", "AAAA:", "AAAA.", "AAAA",
			"AAA:", "AAA.", "AAA",
			"AA:", "AA.", "AA",
			"A:", "A.", "A",
			"B", "C", "D", "F", "None",
		},
		judgment = { "Ridiculous", "W1", "W2", "W3", "W4", "W5", "Miss", "Held", "LetGo" },
		difficulty = { "Beginner", "Easy", "Medium", "Hard", "Challenge", "Edit" },
		clearType = {
			"RFC", "RF", "SDM", "MFC", "WF", "SDP", "PFC", "BF", "SDG", "FC", "MF", "SDCB",
			"Clear", "Failed", "NoPlay", "Invalid", "None", "SoftInvalid",
		},
	}

	local categoryDefaults = defaultCustomColors[category]
	if not categoryDefaults then return {} end

	local elements = {}
	local used = {}

	if ordered[category] then
		for _, elem in ipairs(ordered[category]) do
			if categoryDefaults[elem] ~= nil then
				table.insert(elements, elem)
				used[elem] = true
			end
		end
	end

	local extras = {}
	for elem, _ in pairs(categoryDefaults) do
		if not used[elem] then
			table.insert(extras, elem)
		end
	end
	table.sort(extras)
	for _, elem in ipairs(extras) do
		table.insert(elements, elem)
	end

	return elements
end

--- Get all categories
function HVCustomColors.GetCategories()
	return { "grades", "judgment", "difficulty", "clearType", "goalTracker", "lifeBar", "radar" }
end

--- Get display name for category
function HVCustomColors.GetCategoryDisplayName(category)
	local names = {
		grades = "Grades",
		judgment = "Judgments",
		difficulty = "Difficulty",
		clearType = "Clear Types",
		goalTracker = "Goal Tracker",
		lifeBar = "Life Bar",
		radar = "Radar",
	}
	return names[category] or category
end

--- Check if an element is configured to sync with Accent.
function HVCustomColors.IsSyncToAccentEnabled(category, element)
	initCustomColors()
	if type(customColorData.__syncToAccent) ~= "table" then return false end
	return customColorData.__syncToAccent[category]
		and customColorData.__syncToAccent[category][element] == true
end

--- Enable or disable sync-to-accent for a specific element.
function HVCustomColors.SetSyncToAccentEnabled(category, element, enabled)
	initCustomColors()
	if type(customColorData.__syncToAccent) ~= "table" then
		customColorData.__syncToAccent = {}
	end
	if type(customColorData.__syncToAccent[category]) ~= "table" then
		customColorData.__syncToAccent[category] = {}
	end
	customColorData.__syncToAccent[category][element] = enabled and true or false
	saveCustomColors()
	MESSAGEMAN:Broadcast("CustomColorSyncChanged", {
		Category = category,
		Element = element,
		Enabled = enabled and true or false,
	})
end

--- Push current accent color to all synced elements immediately.
function HVCustomColors.SyncAccentLinkedColors(accentHex)
	initCustomColors()
	if type(customColorData.__syncToAccent) ~= "table" then return end

	local normalized = normalizeHex(accentHex)
	if not normalized then return end

	local changed = false
	for category, elements in pairs(customColorData.__syncToAccent) do
		if type(elements) == "table" then
			if not customColorData[category] then customColorData[category] = {} end
			for element, enabled in pairs(elements) do
				if enabled == true and customColorData[category][element] ~= normalized then
					customColorData[category][element] = normalized
					changed = true
					MESSAGEMAN:Broadcast("CustomColorChanged", {
						Category = category,
						Element = element,
						Color = normalized,
					})
				end
			end
		end
	end

	if changed then
		saveCustomColors()
	end
end

--- Check if custom colors differ from defaults for any element in a category
function HVCustomColors.HasCustomColors(category)
	initCustomColors()
	if not defaultCustomColors[category] then return false end
	for elem, defaultColor in pairs(defaultCustomColors[category]) do
		local currentColor = customColorData[category] and customColorData[category][elem] or defaultColor
		if currentColor:lower() ~= defaultColor:lower() then
			return true
		end
	end
	return false
end

--- Reset all colors in a category to defaults
function HVCustomColors.ResetCategoryToDefaults(category)
	initCustomColors()
	if not defaultCustomColors[category] then return end
	if not customColorData[category] then customColorData[category] = {} end
	for elem, color in pairs(defaultCustomColors[category]) do
		customColorData[category][elem] = color
	end
	saveCustomColors()
	MESSAGEMAN:Broadcast("CustomColorReset", { Category = category })
end

--- Reset all custom colors to defaults
function HVCustomColors.ResetAllToDefaults()
	initCustomColors()
	for cat, elements in pairs(defaultCustomColors) do
		customColorData[cat] = {}
		for elem, color in pairs(elements) do
			customColorData[cat][elem] = color
		end
	end
	saveCustomColors()
	MESSAGEMAN:Broadcast("CustomColorReset", { Category = "all" })
end

-- Initialize on load
initCustomColors()

Trace("Holographic Void: 05 CustomColors.lua loaded.")
