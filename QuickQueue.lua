local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CONFIRM_LOOT_ROLL")

local IsEnabled = true
local timerQueue, timerHello, timerMark = 0, 0, 0
local sayHelloPending, markTankPending = false, false

-- --- BOUTON MINIMAP (SANS IMAGE EXTERNE) ---
local MinimapBtn = CreateFrame("Button", "QuickQueueMinimapBtn", Minimap)
MinimapBtn:SetSize(32, 32)
MinimapBtn:SetFrameLevel(10)
MinimapBtn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 10, -10)

-- On crée un fond de couleur au lieu d'une icône
local bg = MinimapBtn:CreateTexture(nil, "ARTWORK")
bg:SetSize(20, 20)
bg:SetTexture("Interface\\Buttons\\WHITE8X8") -- Texture blanche de base de WoW
bg:SetPoint("CENTER")

-- On ajoute un texte par-dessus (QQ pour QuickQueue)
local text = MinimapBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
text:SetPoint("CENTER", 0, 0)
text:SetText("QQ")

-- Bordure standard
local border = MinimapBtn:CreateTexture(nil, "OVERLAY")
border:SetSize(54, 54)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetPoint("TOPLEFT", 0, 0)

local function UpdateVisual()
    if IsEnabled then
        bg:SetVertexColor(0, 0.8, 0, 1) -- VERT quand ON
        text:SetTextColor(1, 1, 1)     -- Texte Blanc
    else
        bg:SetVertexColor(0.8, 0, 0, 1) -- ROUGE quand OFF
        text:SetTextColor(1, 1, 1)     -- Texte Blanc
    end
end

-- Déplacement (Drag)
MinimapBtn:RegisterForDrag("LeftButton")
MinimapBtn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function(self)
        local xpos, ypos = GetCursorPosition()
        local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
        local scale = Minimap:GetEffectiveScale()
        local x = xmin - (xpos/scale) + 70
        local y = (ypos/scale) - ymin - 70
        local angle = math.atan2(y, x)
        self:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * math.cos(angle)), (80 * math.sin(angle)) - 52)
    end)
end)
MinimapBtn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

MinimapBtn:SetScript("OnClick", function()
    IsEnabled = not IsEnabled
    UpdateVisual()
    print("|cFF00FF00[QuickQueue]|r : " .. (IsEnabled and "ON" or "OFF"))
end)

-- --- LOGIQUE ---
StaticPopupDialogs["QUICK_QUEUE_PROMPT"] = {
    text = "Voulez-vous vous inscrire en Donjon Aléatoire ?",
    button1 = "Oui", button2 = "Non",
    OnAccept = function() if LFDQueueFrameFindGroupButton then LFDQueueFrameFindGroupButton:Click() end end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

frame:SetScript("OnUpdate", function(self, elapsed)
    if not IsEnabled then return end
    if self.shouldShowPrompt then
        timerQueue = timerQueue + elapsed
        if timerQueue >= 5 then
            if GetLFGMode() ~= "queued" then StaticPopup_Show("QUICK_QUEUE_PROMPT") end
            self.shouldShowPrompt = false
        end
    end
    if sayHelloPending then
        timerHello = timerHello + elapsed
        if timerHello >= 10 then
            if IsInInstance() then SendChatMessage("Hello everyone, have a good run!", "PARTY") end
            sayHelloPending = false
        end
    end
    if markTankPending then
        timerMark = timerMark + elapsed
        if timerMark >= 12 then
            if IsInInstance() and (IsPartyLeader() or IsRaidOfficer()) then
                for i = 1, 4 do
                    local unit = "party"..i
                    if UnitGroupRolesAssigned(unit) == "TANK" then SetRaidTarget(unit, 1) break end
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
    elseif event == "CONFIRM_LOOT_ROLL" and IsEnabled then
        if arg2 == 2 then ConfirmLootRoll(arg1, arg2) StaticPopup_Hide("CONFIRM_LOOT_ROLL") end
    end
end)

UpdateVisual()