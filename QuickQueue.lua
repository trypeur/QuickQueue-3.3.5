local frame = CreateFrame("Frame", "QuickQueueMainFrame", UIParent)
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CONFIRM_LOOT_ROLL")

-- --- VARIABLES D'ÉTAT ---
local IsEnabled = true
local OptCupi = true
local OptMessage = true
local OptTank = true
local OptPrompt = true
local timerQueue, timerHello, timerMark = 0, 0, 0
local sayHelloPending, markTankPending = false, false

-- --- CRÉATION DU MENU D'OPTIONS ---
local settingsMenu = CreateFrame("Frame", "QuickQueueMenu", UIParent)
settingsMenu:SetSize(220, 180) -- Légèrement plus grand pour les nouvelles options
settingsMenu:SetPoint("CENTER")
settingsMenu:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
settingsMenu:EnableMouse(true)
settingsMenu:SetMovable(true)
settingsMenu:RegisterForDrag("LeftButton")
settingsMenu:SetScript("OnDragStart", settingsMenu.StartMoving)
settingsMenu:SetScript("OnDragStop", settingsMenu.StopMovingOrSizing)
settingsMenu:Hide()

-- Titre
settingsMenu.title = settingsMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
settingsMenu.title:SetPoint("TOP", 0, -15)
settingsMenu.title:SetText("Options QuickQueue")

-- BOUTON FERMER (CROIX)
local closeBtn = CreateFrame("Button", nil, settingsMenu, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -5, -5)
closeBtn:SetScript("OnClick", function() settingsMenu:Hide() end)

-- Fonction pour créer les cases à cocher
local function CreateCheckButton(name, parent, yOffset, label, varName)
    local cb = CreateFrame("CheckButton", name, parent, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 20, yOffset)
    _G[name .. "Text"]:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    _G[name .. "Text"]:SetText(label)
    cb:SetChecked(true)
    cb:SetScript("OnClick", function(self)
        if varName == "OptCupi" then OptCupi = self:GetChecked() end
        if varName == "OptMessage" then OptMessage = self:GetChecked() end
        if varName == "OptTank" then OptTank = self:GetChecked() end
        if varName == "OptPrompt" then OptPrompt = self:GetChecked() end
    end)
    return cb
end

-- Liste des options
local cbCupi = CreateCheckButton("QQ_CB_Cupi", settingsMenu, -40, "Auto Cupi (Loot)", "OptCupi")
local cbMsg = CreateCheckButton("QQ_CB_Msg", settingsMenu, -65, "Message Bonjour", "OptMessage")
local cbTank = CreateCheckButton("QQ_CB_Tank", settingsMenu, -90, "Marquage Tank", "OptTank")
local cbPrompt = CreateCheckButton("QQ_CB_Prompt", settingsMenu, -115, "Prompt Queue", "OptPrompt")

-- --- BOUTON MINIMAP ---
local MinimapBtn = CreateFrame("Button", "QuickQueueMinimapBtn", Minimap)
MinimapBtn:SetSize(32, 32)
MinimapBtn:SetFrameLevel(10)
MinimapBtn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 10, -10)

local bg = MinimapBtn:CreateTexture(nil, "ARTWORK")
bg:SetSize(22, 22)
bg:SetTexture("Interface\\Buttons\\WHITE8X8")
bg:SetPoint("CENTER")

local text = MinimapBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
text:SetPoint("CENTER", 0, 0)
text:SetText("QQ")

local border = MinimapBtn:CreateTexture(nil, "OVERLAY")
border:SetSize(54, 54)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetPoint("TOPLEFT", 0, 0)

local function UpdateVisual()
    if IsEnabled then
        bg:SetVertexColor(0, 0.8, 0, 1) -- Vert
    else
        bg:SetVertexColor(0.8, 0, 0, 1) -- Rouge
    end
end

MinimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
MinimapBtn:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        if settingsMenu:IsShown() then settingsMenu:Hide() else settingsMenu:Show() end
    else
        IsEnabled = not IsEnabled
        UpdateVisual()
        print("|cFF00FF00[QuickQueue]|r : " .. (IsEnabled and "Addon activé" or "Addon désactivé (Toutes options OFF)"))
    end
end)

-- Drag Minimap
MinimapBtn:RegisterForDrag("LeftButton")
MinimapBtn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local xpos, ypos = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
        local x = xmin - (xpos/scale) + 70
        local y = (ypos/scale) - ymin - 70
        local angle = math.atan2(y, x)
        self:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * math.cos(angle)), (80 * math.sin(angle)) - 52)
    end)
end)
MinimapBtn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

-- --- LOGIQUE ---
StaticPopupDialogs["QUICK_QUEUE_PROMPT"] = {
    text = "Voulez-vous vous inscrire en Donjon Aléatoire ?",
    button1 = "Oui", button2 = "Non",
    OnAccept = function() if LFDQueueFrameFindGroupButton then LFDQueueFrameFindGroupButton:Click() end end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

frame:SetScript("OnUpdate", function(self, elapsed)
    -- Si l'addon est OFF (Rouge), on ne fait RIEN
    if not IsEnabled then return end
    
    -- Prompt Queue
    if self.shouldShowPrompt and OptPrompt then
        timerQueue = timerQueue + elapsed
        if timerQueue >= 5 then
            if GetLFGMode() ~= "queued" then StaticPopup_Show("QUICK_QUEUE_PROMPT") end
            self.shouldShowPrompt = false
        end
    end

    -- Bonjour
    if sayHelloPending and OptMessage then
        timerHello = timerHello + elapsed
        if timerHello >= 8 then
            if IsInInstance() then SendChatMessage("Hello everyone, have a good run!", "PARTY") end
            sayHelloPending = false
        end
    end

    -- Tank
    if markTankPending and OptTank then
        timerMark = timerMark + elapsed
        if timerMark >= 10 then
            if IsInInstance() then
                local units = {"player", "party1", "party2", "party3", "party4"}
                for _, unit in ipairs(units) do
                    if UnitExists(unit) and UnitGroupRolesAssigned(unit) == "TANK" then
                        SetRaidTarget(unit, 1)
                        break
                    end
                end
            end
            markTankPending = false
        end
    end
end)

frame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "PLAYER_ENTERING_WORLD" then
        local _, type = GetInstanceInfo()
        if type == "party" then
            sayHelloPending, markTankPending, timerHello, timerMark = true, true, 0, 0
            self.shouldShowPrompt = false
        else
            self.shouldShowPrompt, timerQueue = true, 0
        end
    elseif event == "CONFIRM_LOOT_ROLL" and IsEnabled and OptCupi then
        if arg2 == 2 then 
            ConfirmLootRoll(arg1, arg2) 
            StaticPopup_Hide("CONFIRM_LOOT_ROLL") 
        end
    end
end)

UpdateVisual()