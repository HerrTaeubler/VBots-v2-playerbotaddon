-- Create Date : 2020/5/12 10:00:00 by coolzoom https://github.com/coolzoom/vmangos-pbotaddon/tree/master
-- Remaster Date : 2025/2/23 15:31:24 by HerrTaeubler https://github.com/HerrTaeubler/vmangos-pbotaddon
-- Constants moved to top and grouped logically
local ADDON_NAME = "VBots"

-- Command constants
-- PartyBot commands
CMD_PARTYBOT_CLONE = ".partybot clone"
CMD_PARTYBOT_REMOVE = ".partybot remove"
CMD_PARTYBOT_ADD = ".partybot add "
CMD_PARTYBOT_SETROLE = ".partybot setrole "
CMD_PARTYBOT_GEAR = ".character premade gear "
CMD_PARTYBOT_SPEC = ".character premade spec "

-- BattleBot commands
CMD_BATTLEGROUND_GO = ".go "
CMD_BATTLEBOT_ADD = ".battlebot add "

-- BG sizes and level requirements
local BG_INFO = {
    warsong = {
        size = 10,
        minLevel = 10,
        maxLevel = 60
    },
    arathi = {
        size = 15,
        minLevel = 20,
        maxLevel = 60
    },
    alterac = {
        size = 40,
        minLevel = 51,
        maxLevel = 60
    }
}

-- Track if temporary bots should be used
local useTempBots = false

-- Command queue system
local CommandQueue = {
    commands = {},
    timer = 0,
    processing = false
}

-- Local variables for minimap button
local MinimapButton = {
    shown = true,
    position = 268,
    radius = 78,
    cos = math.cos,
    sin = math.sin,
    deg = math.deg,
    atan2 = math.atan2
}


local playerFaction = nil  -- Initialize as nil
local manualFactionOverride = nil -- For manual override

-- Get faction with improved detection for GM mode
function GetPlayerFaction()
    -- If manual override is set, use that
    if manualFactionOverride then
        return manualFactionOverride
    end
    
    -- Try to determine faction from race first (more reliable in GM mode)
    local _, race = UnitRace("player")
    if race then
        if race == "Human" or race == "Dwarf" or race == "NightElf" or race == "Gnome" then
            return "alliance"
        elseif race == "Orc" or race == "Troll" or race == "Tauren" or race == "Undead" or race == "Scourge" then
            return "horde"
        end
    end
    
    -- If race detection failed, try faction group
    if not playerFaction then
        local faction = UnitFactionGroup("player")
        if faction then
            playerFaction = string.lower(faction)
        else
            -- Default fallback if all detection methods fail
            DEFAULT_CHAT_FRAME:AddMessage("Faction detection failed. Using Alliance as default. Use /vbots faction alliance|horde to set manually.")
            playerFaction = "alliance"
        end
    end
    
    return playerFaction
end

-- Function to manually set faction
function SetPlayerFaction(faction)
    if faction == "alliance" or faction == "horde" then
        manualFactionOverride = faction
        DEFAULT_CHAT_FRAME:AddMessage("Faction manually set to: " .. faction)
        -- Update UI elements that depend on faction
        InitializeFactionClassButton()
    else
        DEFAULT_CHAT_FRAME:AddMessage("Invalid faction. Use 'alliance' or 'horde'.")
    end
end

-- Slash command to set faction manually
SLASH_VBOTS1 = "/vbots"
SlashCmdList["VBOTS"] = function(msg)
    local command, arg = string.match(msg, "^(%S+)%s*(.*)$")
    
    if command == "faction" then
        if arg == "alliance" or arg == "horde" then
            SetPlayerFaction(arg)
        else
            DEFAULT_CHAT_FRAME:AddMessage("Usage: /vbots faction alliance|horde")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("VBots commands:")
        DEFAULT_CHAT_FRAME:AddMessage("/vbots faction alliance|horde - Manually set your faction")
    end
end

-- Minimap button position calculation optimization
function MinimapButton:UpdatePosition()
    local radian = self.position * (math.pi/180)
    vbotsButtonFrame:SetPoint(
        "TOPLEFT",
        "Minimap",
        "TOPLEFT",
        54 - (self.radius * self.cos(radian)),
        (self.radius * self.sin(radian)) - 55
    )
    self:Init()
end

function MinimapButton:CalculatePosition(xpos, ypos)
    local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
    xpos = xmin - xpos/UIParent:GetScale() + 70
    ypos = ypos/UIParent:GetScale() - ymin - 70
    
    local angle = self.deg(self.atan2(ypos, xpos))
    if angle < 0 then
        angle = angle + 360
    end
    
    self.position = angle
    self:UpdatePosition()
end

function MinimapButton:Init()
    if self.shown then
        vbotsFrame:Show()
    else
        vbotsFrame:Hide()
    end
end

function MinimapButton:Toggle()
    self.shown = not self.shown
    self:Init()
end

-- PartyBot functions
function SubPartyBotClone(self)
    SendChatMessage(CMD_PARTYBOT_CLONE)
end

function SubPartyBotRemove(self)
    SendChatMessage(CMD_PARTYBOT_REMOVE)
end

function SubPartyBotSetRole(self, arg)
    SendChatMessage(CMD_PARTYBOT_SETROLE .. arg)
end

function SubPartyBotAdd(self, arg)
    SendChatMessage(CMD_PARTYBOT_ADD .. arg)
    DEFAULT_CHAT_FRAME:AddMessage("bot added. please search available gear and spec set.")
end

-- BattleGround function
function SubBattleGo(self, arg)
    SendChatMessage(CMD_BATTLEGROUND_GO .. arg)
end

-- Utility functions
function SubSendGuildMessage(self, arg)
    SendChatMessage(arg, "GUILD", GetDefaultLanguage("player"));
end

function CloseFrame()
    vbotsFrame:Hide()
    MinimapButton.shown = false
end

-- Near the top with other local variables
local VBOTS_NUM_TABS = 4

-- Modify the tab switching function
function vbotsFrame_ShowTab(tabID)
    -- Hide all content frames
    for i=1, VBOTS_NUM_TABS do
        local content = getglobal(vbotsFrame:GetName().."Tab"..i.."Content")
        if content then
            content:Hide()
        end
    end
    
    -- Show selected content frame
    local selectedContent = getglobal(vbotsFrame:GetName().."Tab"..tabID.."Content")
    if selectedContent then
        selectedContent:Show()
    end
end

-- Modify the OpenFrame function
function OpenFrame()
    DEFAULT_CHAT_FRAME:AddMessage("Loading " .. ADDON_NAME)
    vbotsFrame:Show()
    MinimapButton.shown = true
end

-- Handle tab initialization
function vbotsFrame_OnLoad()
    -- Set up number of tabs
    this.numTabs = VBOTS_NUM_TABS
    
    -- Initialize first tab as selected
    this.selectedTab = 1
    PanelTemplates_SetNumTabs(this, VBOTS_NUM_TABS)
    PanelTemplates_SetTab(this, 1)
    
    -- Show first content, hide others
    vbotsFrame_ShowTab(1)
    
    -- Register events
    this:RegisterEvent("VARIABLES_LOADED")
    DEFAULT_CHAT_FRAME:RegisterEvent('CHAT_MSG_SYSTEM')
end

-- Minimap button functions
function vbotsButtonFrame_OnClick()
    vbotsButtonFrame_Toggle()
end

function vbotsButtonFrame_Init()
    MinimapButton:Init()
end

function vbotsButtonFrame_Toggle()
    MinimapButton:Toggle()
end

function vbotsButtonFrame_UpdatePosition()
    MinimapButton:UpdatePosition()
end

function vbotsButtonFrame_BeingDragged()
    local x, y = GetCursorPosition()
    MinimapButton:CalculatePosition(x, y)
end

function vbotsButtonFrame_OnEnter()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("vmangos bot command, \n click to open/close, \n right mouse to drag me")
    GameTooltip:Show()
end

-- Store templates
local templates = {}

-- Faction button handling
function InitializeFactionClassButton()
    local button = getglobal("PartyBotAddFactionClass")
    if button then
        local faction = GetPlayerFaction()
        if faction == "alliance" then
            button:SetText("Add Paladin")
        else
            button:SetText("Add Shaman")
        end
        DEFAULT_CHAT_FRAME:AddMessage("Faction detected as: " .. faction)
    end
end

-- Register events and set up event handler
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_SYSTEM")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function()
    local event = event
    local message = arg1

    if event == "CHAT_MSG_SYSTEM" and message then
        if string.find(message, "^%d+%s*-%s*") then
            local _, _, id, name = string.find(message, "^(%d+)%s*-%s*([^%(]+)")
            if id and name then
                templates[id] = name
                local dropdown = getglobal("vbotsTemplateDropDown")
                if dropdown then
                    UIDropDownMenu_Initialize(dropdown, TemplateDropDown_Initialize)
                end
            end
        end
        
        if string.find(message, "Listing available premade templates") then
            templates = {}
        end
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
        -- Initialize faction detection
        local faction = GetPlayerFaction()
        DEFAULT_CHAT_FRAME:AddMessage("VBots: Detected faction as " .. faction)
        InitializeFactionClassButton()
    end
end)

-- Dropdown menu initializer
function TemplateDropDown_Initialize()
    local info = {}
    -- Add header
    info.text = "Select Template"
    info.notClickable = 1
    info.isTitle = 1
    UIDropDownMenu_AddButton(info)

    -- Add all stored templates
    for id, name in pairs(templates) do
        info = {}
        info.text = id .. " - " .. name
        info.func = TemplateDropDown_OnClick
        info.value = id
        UIDropDownMenu_AddButton(info)
    end
end

-- Dropdown click handler
function TemplateDropDown_OnClick()
    local id = this.value
    local name = templates[id]
    if id and name then
        SendChatMessage(".character premade gear " .. id)
        local dropdownText = getglobal("vbotsTemplateDropDown".."Text")
        if dropdownText then
            dropdownText:SetText(id .. " - " .. name)
        end
    end
end

-- Function to add a bot command to queue
local function QueueCommand(command)
    table.insert(CommandQueue.commands, command)
    if not CommandQueue.processing then
        CommandQueue.processing = true
        CommandQueue.timer = 0
        CommandQueue.frame:Show()
    end
end

-- Create the command processing frame
CommandQueue.frame = CreateFrame("Frame")
CommandQueue.frame:Hide()
CommandQueue.frame:SetScript("OnUpdate", function()
    if table.getn(CommandQueue.commands) == 0 then
        CommandQueue.processing = false
        CommandQueue.frame:Hide()
        return
    end

    CommandQueue.timer = CommandQueue.timer + arg1
    if CommandQueue.timer >= 0.5 then -- Half second delay between commands
        local command = table.remove(CommandQueue.commands, 1)
        SendChatMessage(command)
        CommandQueue.timer = 0
        
        if table.getn(CommandQueue.commands) == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("All bots have been added!")
        end
    end
end)

-- Function to fill a battleground -- THANK YOU DIGITAL SCRIPTORIUM FOR THE IDEA - https://www.youtube.com/@Digital-Scriptorium
function SubBattleFill(self, bgType)
    local playerFaction = GetPlayerFaction() 
    local playerLevel = UnitLevel("player")
    local bgData = BG_INFO[bgType]
    
    if not bgData then
        DEFAULT_CHAT_FRAME:AddMessage("Invalid battleground type: " .. bgType)
        return
    end
    
    -- Check level requirements
    if playerLevel < bgData.minLevel then
        DEFAULT_CHAT_FRAME:AddMessage("You must be at least level " .. bgData.minLevel .. " to queue for " .. bgType)
        return
    end
    
    -- Clear any existing queue
    CommandQueue.commands = {}
    CommandQueue.timer = 0
    
    DEFAULT_CHAT_FRAME:AddMessage("Using faction: " .. playerFaction .. " for BG fill")
    
    -- Add Alliance bots
    local allianceCount = bgData.size
    if playerFaction == "alliance" then
        allianceCount = bgData.size - 1 -- Leave one spot for the player
    end
    for i = 1, allianceCount do
        local command = CMD_BATTLEBOT_ADD .. bgType .. " alliance " .. playerLevel
        if useTempBots then
            command = command .. " temp"
        end
        QueueCommand(command)
    end
    
    -- Add Horde bots
    local hordeCount = bgData.size
    if playerFaction == "horde" then
        hordeCount = bgData.size - 1 -- Leave one spot for the player
    end
    for i = 1, hordeCount do
        local command = CMD_BATTLEBOT_ADD .. bgType .. " horde " .. playerLevel
        if useTempBots then
            command = command .. " temp"
        end
        QueueCommand(command)
    end
    
    -- Queue the battleground at the end
    QueueCommand(CMD_BATTLEGROUND_GO .. bgType)
    
    -- Show feedback message
    local totalBots = allianceCount + hordeCount
    local botType = useTempBots and "temporary" or "permanent"
    DEFAULT_CHAT_FRAME:AddMessage("Queueing " .. totalBots .. " level " .. playerLevel .. " " .. botType .. " bots for " .. bgType .. " (leaving space for you in " .. playerFaction .. " team)")
end 

-- Function to toggle temporary bots
function ToggleTempBots()
    useTempBots = not useTempBots
    local status = useTempBots and "enabled" or "disabled"
    DEFAULT_CHAT_FRAME:AddMessage("Temporary bots " .. status)
    
    -- Update checkbox visual state
    local checkbox = getglobal("TempBotsCheckbox")
    if checkbox then
        checkbox:SetChecked(useTempBots)
    end
end 
