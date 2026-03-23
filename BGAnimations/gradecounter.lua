-- pls don't look at this mess
-- big thank you to LegendaryHawk for helping to improve this mess <3

local t = Def.ActorFrame {}

local fontColor = color("#FFFFFF") -- getMainColor("positive")
local fontZoom = 0.45

local xPos = 100
local xGap = 5

local yPos = 37.5
local yGap = 11.5

-- In-memory storage for grade counts
if GRADECOUNTERSTORAGE == nil then
    GRADECOUNTERSTORAGE = {
        AAAAA = 0,
        AAAA = 0,
        AAA = 0,
        AA = 0,
        A = 0,
        session_AAAAA = 0,
        session_AAAA = 0,
        session_AAA = 0,
        session_AA = 0,
        session_A = 0,
        session_UnderA = 0,
        initialized = false,
        lastProfileName = ""
    }
end

-- the visual display logic has been moved to the sidebar in ScreenSelectMusic overlay.
-- this file now handles the in-memory storage and initialization of grade counts.

-- code for parsing the xml
-- really dirty but haven't had any problems with it
local function Trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function ParseXML(xml)
    local grades = {}
    local pattern = "<Score.-<Grade>(.-)</Grade>.-</Score>"

    for grade in xml:gmatch(pattern) do
        local trimmedGrade = Trim(grade)
        if trimmedGrade ~= "" then
            grades[#grades + 1] = trimmedGrade
        end
    end

    return grades
end

local function CountGrade(tiers, grades)
    local count = 0
    for _, grade in ipairs(grades) do
        for _, tier in ipairs(tiers) do
            if grade == tier then
                count = count + 1
                break
            end
        end
    end
    return count
end

function GRADECOUNTERSTORAGE:increment(grade)
    if grade == "AAAAA" then self.AAAAA = self.AAAAA + 1 end
    if grade == "AAAA" then self.AAAA = self.AAAA + 1 end
    if grade == "AAA" then self.AAA = self.AAA + 1 end
    if grade == "AA" then self.AA = self.AA + 1 end
    if grade == "A" then self.A = self.A + 1 end
end

-- increments session-specific grade count
function GRADECOUNTERSTORAGE:incrementSession(grade)
    if not grade then return end
    local tier = ToEnumShortString(grade)
    if tier == "Tier01" then
        self.session_AAAAA = self.session_AAAAA + 1
    elseif tier == "Tier02" or tier == "Tier03" or tier == "Tier04" then
        self.session_AAAA = self.session_AAAA + 1
    elseif tier == "Tier05" or tier == "Tier06" or tier == "Tier07" then
        self.session_AAA = self.session_AAA + 1
    elseif tier == "Tier08" or tier == "Tier09" or tier == "Tier10" then
        self.session_AA = self.session_AA + 1
    elseif tier == "Tier11" or tier == "Tier12" or tier == "Tier13" then
        self.session_A = self.session_A + 1
    elseif tier == "Failed" or tier == "Tier14" or tier == "Tier15" or tier == "Tier16" or tier == "Tier17" then
        self.session_UnderA = self.session_UnderA + 1
    end
end

-- parse the xml and initialize the grade counts
-- make sure we re-check, if we switch profiles in game
function GRADECOUNTERSTORAGE:init()
    local profile            = GetPlayerOrMachineProfile(PLAYER_1)
    local currentProfileName = profile:GetDisplayName()

    if not self.initialized or self.lastProfileName ~= currentProfileName then
        local xmlData = File.Read(PROFILEMAN:GetProfileDir(1) .. "Etterna.xml")
        local grades = {}
        if xmlData then
            grades = ParseXML(xmlData)
        end
		
        self.AAAAA = CountGrade({"Tier01"}, grades)
        self.AAAA = CountGrade({"Tier02", "Tier03", "Tier04"}, grades)
        self.AAA = CountGrade({"Tier05", "Tier06", "Tier07"}, grades)
        self.AA = CountGrade({"Tier08", "Tier09", "Tier10"}, grades)
        self.A = CountGrade({"Tier11", "Tier12", "Tier13"}, grades)

        self.lastProfileName = currentProfileName
        self.initialized = true
    end
end

-- Initialize the storage
GRADECOUNTERSTORAGE:init()

return t
