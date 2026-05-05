local defaultGameplayCoordinates = {
    JudgeX = 0,
    JudgeY = -80,
    ComboX = 30,
    ComboY = -93,
    ErrorBarX = SCREEN_CENTER_X,
    ErrorBarY = SCREEN_CENTER_Y + 200,
    TargetTrackerX = SCREEN_CENTER_X + 26,
    TargetTrackerY = SCREEN_CENTER_Y + 30,
    MiniProgressBarX = SCREEN_CENTER_X + 44,
    MiniProgressBarY = SCREEN_CENTER_Y + 34,
    FullProgressBarX = SCREEN_CENTER_X,
    FullProgressBarY = 15,
    JudgeCounterX = SCREEN_CENTER_X -200,
    JudgeCounterY = SCREEN_CENTER_Y,
    DisplayPercentX = SCREEN_CENTER_X - 170,
    DisplayPercentY = SCREEN_CENTER_Y - 60,
    DisplayMeanX = SCREEN_CENTER_X - 170,
    DisplayMeanY = SCREEN_CENTER_Y - 75,
    NPSDisplayX = 5,
    NPSDisplayY = SCREEN_BOTTOM - 175,
    NPSGraphX = 0,
    NPSGraphY = SCREEN_BOTTOM - 163,
    NotefieldX = 3,
    NotefieldY = -6,
    ProgressBarPos = 1,
    LeaderboardX = 0,
    LeaderboardY = SCREEN_HEIGHT / 10,
    ReplayButtonsX = SCREEN_WIDTH - 45,
    ReplayButtonsY = SCREEN_HEIGHT / 2 - 100,
    LifeP1X = 178,
    LifeP1Y = 10,
    LifeP1Rotation = 0,
    PracticeCDGraphX = 10,
    PracticeCDGraphY = 85,
    BPMTextX = SCREEN_CENTER_X,
    BPMTextY = SCREEN_BOTTOM - 20,
    MusicRateX = SCREEN_CENTER_X,
    MusicRateY = SCREEN_BOTTOM - 10
}

local defaultGameplaySizes = {
    JudgeZoom = 1.0,
    ComboZoom = 0.6,
    ErrorBarWidth = 240,
    ErrorBarHeight = 10,
    TargetTrackerZoom = 0.4,
    FullProgressBarWidth = 1.0,
    FullProgressBarHeight = 1.0,
    DisplayPercentZoom = 1,
    DisplayMeanZoom = 1,
    NPSDisplayZoom = 0.4,
    NPSGraphWidth = 1.0,
    NPSGraphHeight = 1.0,
    NotefieldWidth = 1.1,
    NotefieldHeight = 1.0,
    NotefieldSpacing = 0.0,
    LeaderboardWidth = 1.0,
    LeaderboardHeight = 1.0,
    LeaderboardSpacing = 0.0,
    ReplayButtonsZoom = 1.0,
    ReplayButtonsSpacing = 0.0,
    LifeP1Width = 1.0,
    LifeP1Height = 1.0,
    PracticeCDGraphWidth = 0.8,
    PracticeCDGraphHeight = 1,
    MusicRateZoom = 1.0,
    BPMTextZoom = 1.0
}

local defaultConfig = {
    ScreenFilter = 1,
    JudgeType = 1,
    AvgScoreType = 0,
    GhostScoreType = 1,
    DisplayPercent = true,
    DisplayMean = false,
    TargetTracker = true,
    TargetGoal = 93,
    TargetTrackerMode = 0, -- 0: set percent, 1: pb, 2: pb (replay)
    JudgeCounter = true,
    ErrorBar = 1,
    leaderboardEnabled = false,
    PlayerInfo = true,
    FullProgressBar = true,
    MiniProgressBar = false,
    LaneCover = 0, -- soon to be changed to: 0=off, 1=sudden, 2=hidden
    LaneCoverHeight = 10,
    NPSDisplay = true,
    NPSGraph = false,
    CBHighlight = false,
    OneShotMirror = false,
    JudgmentText = true,
    ComboText = true,
    ReceptorSize = 100,
    ErrorBarCount = 30,
    BackgroundType = 1,
    UserName = "Player",
    PasswordToken = "",
    CustomizeGameplay = false,
    CustomEvaluationWindowTimings = false,
    PracticeMode = false,
    GameplayXYCoordinates = {
        ["3K"] = DeepCopy(defaultGameplayCoordinates),
        ["4K"] = DeepCopy(defaultGameplayCoordinates),
        ["5K"] = DeepCopy(defaultGameplayCoordinates),
        ["6K"] = DeepCopy(defaultGameplayCoordinates),
        ["7K"] = DeepCopy(defaultGameplayCoordinates),
        ["8K"] = DeepCopy(defaultGameplayCoordinates),
        ["9K"] = DeepCopy(defaultGameplayCoordinates),
        ["10K"] = DeepCopy(defaultGameplayCoordinates),
        ["12K"] = DeepCopy(defaultGameplayCoordinates),
        ["16K"] = DeepCopy(defaultGameplayCoordinates)
    },
    GameplaySizes = {
        ["3K"] = DeepCopy(defaultGameplaySizes),
        ["4K"] = DeepCopy(defaultGameplaySizes),
        ["5K"] = DeepCopy(defaultGameplaySizes),
        ["6K"] = DeepCopy(defaultGameplaySizes),
        ["7K"] = DeepCopy(defaultGameplaySizes),
        ["8K"] = DeepCopy(defaultGameplaySizes),
        ["9K"] = DeepCopy(defaultGameplaySizes),
        ["10K"] = DeepCopy(defaultGameplaySizes),
        ["12K"] = DeepCopy(defaultGameplaySizes),
        ["16K"] = DeepCopy(defaultGameplaySizes)
    }
}

function getDefaultGameplaySize(obj)
    return defaultGameplaySizes[obj]
end

function getDefaultGameplayCoordinate(obj)
    return defaultGameplayCoordinates[obj]
end

-- create the playerConfig global
playerConfig = create_setting("playerConfig", "playerConfig.lua", defaultConfig, -1)

local tmp2 = playerConfig.load
playerConfig.load = function(self, slot)
    local tmp = force_table_elements_to_match_type
    force_table_elements_to_match_type = function()
    end

    local x = create_setting("playerConfig", "playerConfig.lua", {}, -1)
    x = x:load(slot)
    local coords = x.GameplayXYCoordinates
    local sizes = x.GameplaySizes
    if sizes and not sizes["4K"] then
        for _, k in ipairs({"3K","4K","5K","6K","7K","8K","9K","10K","12K","16K"}) do
            defaultConfig.GameplaySizes[k] = sizes
        end
    end
    if coords and not coords["4K"] then
        for _, k in ipairs({"3K","4K","5K","6K","7K","8K","9K","10K","12K","16K"}) do
            defaultConfig.GameplayXYCoordinates[k] = coords
        end
    end
    force_table_elements_to_match_type = tmp
    return tmp2(self, slot)
end

playerConfig:load()
-- Force an initial save to create the file if it doesn't exist
playerConfig:save()

function LoadProfileCustom(profile, dir)
    local players = GAMESTATE:GetEnabledPlayers()
    for _, v in pairs(players) do
        if PROFILEMAN:GetProfile(v):GetGUID() == profile:GetGUID() then
            playerConfig:load(pn_to_profile_slot(v))
        end
    end
end

function SaveProfileCustom(profile, dir)
    local players = GAMESTATE:GetEnabledPlayers()
    for _, v in pairs(players) do
        if PROFILEMAN:GetProfile(v):GetGUID() == profile:GetGUID() then
            playerConfig:set_dirty(pn_to_profile_slot(v))
            playerConfig:save(pn_to_profile_slot(v))
        end
    end
end