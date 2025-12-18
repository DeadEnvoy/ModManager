require "ISUI/ISPanelJoypad"
require "OptionScreens/ModSelector/ModInfoPanel"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6
local UI_BORDER_SPACING = 10

ModInfoPanel.Param = ISPanelJoypad:derive("ModInfoPanelParam")

function ModInfoPanel.Param:render()
    self:drawRectBorder(0, 0, self.borderX, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawText(self.name, self.borderX - UI_BORDER_SPACING - self.labelWidth, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)

    if self.modInfo == nil then return end

    if self.type == "Status" then
        if self.parent.parent.model:isModActive(self.modInfo:getId()) then
            self:drawText(getText("UI_mods_ModEnabled"), self.borderX+UI_BORDER_SPACING, 2, 0.0, 0.9, 0.0, 0.9, UIFont.Small)
        else
            self:drawText(getText("UI_mods_ModDisabled"), self.borderX+UI_BORDER_SPACING, 2, 0.9, 0.0, 0.0, 0.9, UIFont.Small)
        end
    elseif self.type == "Version" then
        local versionText = self.modInfo:getModVersion() or ""
        local finalText = ""
        local r, g, b = 0.9, 0.9, 0.9
        
        local model = self.parent.parent.model
        local finishedTime, now = model.queryFinishedTime or 0, getTimestampMs()
        local isInDelay = (now - finishedTime < 1000)
        
        local isQuerying = (model.isQueryingWorkshop or isInDelay) and self.workshopID ~= ""
        
        if isQuerying then
            finalText = versionText
        else
            local statusText = ""
            if self.workshopState == "NeedsUpdate" then
                statusText = getText("UI_modselector_status_needsUpdate")
                r, g, b = 0.2, 0.6, 1.0
            elseif self.workshopState == "Installed" then
                statusText = getText("UI_modselector_status_installed")
            end

            if statusText ~= "" then
                if versionText ~= "" then
                    local formattedStatus = statusText:gsub("!", ""):lower()
                    finalText = versionText .. " (" .. formattedStatus .. ")"
                else
                    finalText = statusText
                end
            else
                finalText = versionText
            end
        end

        local textX = self.borderX + UI_BORDER_SPACING
        self:drawText(finalText, textX, 2, r, g, b, 0.9, UIFont.Small)

        if isQuerying then
            local time = getTimestampMs()
            local activeDotIndex = math.floor(time / 300) % 3 + 1
            
            local textLen = 0
            if finalText ~= "" then
                textLen = getTextManager():MeasureStringX(UIFont.Small, finalText) + 4
            end
            
            local dotX = textX + textLen
            local dotWidth = getTextManager():MeasureStringX(UIFont.Small, ".") + 1

            for i = 1, 3 do
                local dr, dg, db = 0.4, 0.4, 0.4
                if i == activeDotIndex then
                    dr, dg, db = 0.9, 0.9, 0.9
                end
                
                self:drawText(".", dotX, 2, dr, dg, db, 0.9, UIFont.Small)
                dotX = dotX + dotWidth
            end
        end

        if self.isUpdateRequired and not isQuerying then
            local textLen = getTextManager():MeasureStringX(UIFont.Small, finalText)
            local lineY = 1 + FONT_HGT_SMALL
            
            local isMouseOverText = self:isMouseOver() and self:getMouseX() > textX and self:getMouseX() < textX + textLen and self:getMouseY() > 2 and self:getMouseY() < 2 + FONT_HGT_SMALL + 1
            if not isMouseOverText then
                self:drawRectBorder(textX, lineY, textLen, 1, 0.9, r, g, b)
            elseif self.pressed then
                activateSteamOverlayToWorkshopItem(self.workshopID)
            end
        end

    elseif self.type == "Author" then
        self:drawText(self.modInfo:getAuthor(), self.borderX+UI_BORDER_SPACING, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)
    elseif self.type == "ModID" then
        self:drawText(self.modInfo:getId(), self.borderX+UI_BORDER_SPACING, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)
    elseif self.type == "WorkshopID" then
        self:drawText(self.workshopID, self.borderX+UI_BORDER_SPACING, 2, 0.2, 0.6, 1.0, 0.9, UIFont.Small)
        if self.workshopID ~= "" and not (self:isMouseOver() and self:getMouseX() > self.borderX+UI_BORDER_SPACING and self:getMouseX() < self.borderX+UI_BORDER_SPACING + self.workshopIDLen
                and self:getMouseY() > 2 and self:getMouseY() < 2 + FONT_HGT_SMALL + 1) then
            self:drawRectBorder(self.borderX+UI_BORDER_SPACING, 1+FONT_HGT_SMALL, self.workshopIDLen, 1, 0.9, 0.2, 0.6, 1.0)
        elseif self.workshopID ~= "" and self.pressed then
            activateSteamOverlayToWorkshopItem(self.workshopID)
        end
    elseif self.type == "ZomboidVersion" then
        if self.modInfo:isAvailableSelf() then
            self:drawText(self.zomboidVersion, self.borderX+UI_BORDER_SPACING, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)
        else
            self:drawText("AVAILABLE ONLY IN DEBUG (mod must be updated to " .. getBreakModGameVersion():toString() .. "+ version)", self.borderX+UI_BORDER_SPACING, 2, 0.9, 0.0, 0.0, 0.9, UIFont.Small)
        end
    end
    self.pressed = false
end

function ModInfoPanel.Param:openUrl(button, url)
    if button.internal == "YES" then
        openUrl(url)
    end
end

function ModInfoPanel.Param:onMouseDown(x, y)
    self.pressed = true
end

function ModInfoPanel.Param:setModInfo(modInfo)
    self.modInfo = modInfo

    self.zomboidVersion = (self.modInfo:getVersionMin() and self.modInfo:getVersionMin():toString() or "**") .. " - " .. (self.modInfo:getVersionMax() and self.modInfo:getVersionMax():toString() or "**")
    
    local model = self.parent.parent.model
    local modId = modInfo:getId()
    local modData = model.mods[modId]

    if modData then
        self.workshopID = modData.workshopIDStr or ""
        self.workshopState = modData.workshopState or ""
        self.isUpdateRequired = (self.workshopState == "NeedsUpdate")
    else
        self.workshopID = ""
        self.workshopState = ""
        self.isUpdateRequired = false
    end

    self.workshopIDLen = getTextManager():MeasureStringX(UIFont.Small, self.workshopID)
end

function ModInfoPanel.Param:new(x, y, width, type)
    local o = ISPanelJoypad:new(x, y, width, BUTTON_HGT)
    setmetatable(o, self)
    self.__index = self
    o.type = type
    o.name = getText(type)
    o.labelWidth = getTextManager():MeasureStringX(UIFont.Small, o.name)
    o.tickTexture = getTexture("media/ui/inventoryPanes/Tickbox_Tick.png")
    o.zomboidVersion = ""
    o.workshopID = ""
    o.workshopIDLen = 0
    o.borderX = width / 4.0
    return o
end