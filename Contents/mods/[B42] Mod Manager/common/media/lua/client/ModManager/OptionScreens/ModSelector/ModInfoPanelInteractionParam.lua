require "ISUI/ISPanelJoypad"
require "ModManager/OptionScreens/ModSelector/ModInfoPanel"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6
local UI_BORDER_SPACING = 10

ModInfoPanel.InteractionParam = ISPanelJoypad:derive("ModInfoPanelInteractionParam")

function ModInfoPanel.InteractionParam:initialise()
    ISPanelJoypad.initialise(self)
    self.tooltipUI = ISToolTip:new()
    self.tooltipUI:initialise()
    self.tooltipUI:setOwner(self)
end

function ModInfoPanel.InteractionParam:update()
    ISPanelJoypad.update(self)
    if self:isMouseOver() and self.tooltip and self.tooltip ~= "" then
        if not self.tooltipUI:getIsVisible() then
            self.tooltipUI:addToUIManager()
            self.tooltipUI:setVisible(true)
        end
        self.tooltipUI.description = self.tooltip
    elseif self.tooltipUI and self.tooltipUI:getIsVisible() then
        self.tooltipUI:setVisible(false)
        self.tooltipUI:removeFromUIManager()
    end
end

function ModInfoPanel.InteractionParam:render()
    self:drawRectBorder(0, 0, self.borderX, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawText(self.name, self.borderX - UI_BORDER_SPACING - self.labelWidth, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)

    if self.modInfo == nil then return end

    local currentX = self.borderX + self.padX
    local mouseX = self:getMouseX()
    local mouseY = self:getMouseY()
    local isMouseOver = self:isMouseOver()

    for i, val in ipairs(self.modDict) do
        local textWidth = getTextManager():MeasureStringX(UIFont.Small, val.id)
        local isHovered = isMouseOver and mouseX >= currentX and mouseX < currentX + textWidth and mouseY >= 2 and mouseY < 2 + FONT_HGT_SMALL + 1

        self:drawText(val.id, currentX, 2, val.color.r, val.color.g, val.color.b, 0.9, UIFont.Small)

        if not isHovered then
            self:drawRectBorder(currentX, 2 + FONT_HGT_SMALL, textWidth, 1, 0.9, val.color.r, val.color.g, val.color.b)
        else
            if self.pressed then
                if val.available then
                    self.parent.parent:selectModByInfo(val.modInfo)
                else
                    local modData = self.parent.parent.model.mods[val.id]
                    local workshopID = modData and modData.workshopIDStr
                    if workshopID and workshopID ~= "" then
                        activateSteamOverlayToWorkshopItem(workshopID)
                    end
                end
            end
        end

        currentX = currentX + textWidth
        if i < #self.modDict then
            self:drawText(", ", currentX, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)
            currentX = currentX + getTextManager():MeasureStringX(UIFont.Small, ", ")
        end
    end
    self.pressed = false
end

function ModInfoPanel.InteractionParam:onMouseDown(x, y)
    self.pressed = true
end

function ModInfoPanel.InteractionParam:setModInfo(modInfo)
    self.modInfo = modInfo
    local model = self.parent.parent.model
    local modData = model.mods[modInfo:getId()]

    self.modDict = {}
    self.tooltip = nil

    if self.type == "Dependencies" and self.modInfo:getRequire() ~= nil then
        for id, _ in pairs(modData.requireMods) do
            local color = { r = 0.9, g = 0.0, b = 0.0 }
            local available = false
            local modInfo2
            if model.mods[id] then
                available = true
                modInfo2 = model.mods[id].modInfo
                if model.mods[id].isActive then
                    color = { r = 0.0, g = 0.9, b = 0.0 }
                else
                    color = { r = 0.9, g = 0.9, b = 0.9 }
                end
            end
            table.insert(self.modDict, { id = id, color = color, available = available, modInfo = modInfo2 })
        end
    end
    if self.type == "IncompatibleWith" and self.modInfo:getIncompatible() ~= nil then
        for id, _ in pairs(model.incompatibles[modInfo:getId()]) do
            local color = { r = 0.9, g = 0.0, b = 0.0 }
            local available = false
            local modInfo2
            if model.mods[id] then
                available = true
                modInfo2 = model.mods[id].modInfo
                if model.mods[id].isActive then
                    color = { r = 0.9, g = 0.0, b = 0.0 }
                else
                    color = { r = 0.9, g = 0.9, b = 0.9 }
                end
            end
            table.insert(self.modDict, { id = id, color = color, available = available, modInfo = modInfo2 })
        end
    end

    if #self.modDict == 0 then
        self:setHeight(BUTTON_HGT)
        return
    end

    local fullText_tooltip = ""
    local fullText_display = ""
    local availableWidth = self.width - self.borderX - UI_BORDER_SPACING * 2
    local spaceWidth = getTextManager():MeasureStringX(UIFont.Small, ", ")

    for i, part in ipairs(self.modDict) do
        if i > 1 then
            fullText_tooltip = fullText_tooltip .. ", "
            fullText_display = fullText_display .. ", "
        end
        fullText_tooltip = fullText_tooltip .. part.id
        fullText_display = fullText_display .. part.id
    end

    if getTextManager():MeasureStringX(UIFont.Small, fullText_display) > availableWidth then
        self.tooltip = fullText_tooltip
        local truncatedParts = {}
        local currentWidth = 0
        for _, part in ipairs(self.modDict) do
            local partWidth = getTextManager():MeasureStringX(UIFont.Small, part.id)
            if currentWidth + partWidth + (spaceWidth * #truncatedParts) > availableWidth then
                local remainingWidth = availableWidth - currentWidth - (spaceWidth * #truncatedParts) - getTextManager():MeasureStringX(UIFont.Small, " ...")
                while #part.id > 0 and getTextManager():MeasureStringX(UIFont.Small, part.id) > remainingWidth do
                    part.id = string.sub(part.id, 1, #part.id - 1)
                end
                part.id = part.id .. " ..."
                table.insert(truncatedParts, part)
                break
            end
            table.insert(truncatedParts, part)
            currentWidth = currentWidth + partWidth
        end
        self.modDict = truncatedParts
    end

    self:setHeight(BUTTON_HGT)
end

function ModInfoPanel.InteractionParam:new(x, y, width, type)
    local o = ISPanelJoypad:new(x, y, width, BUTTON_HGT)
    setmetatable(o, self)
    self.__index = self
    o.type = type
    o.name = getText("UI_modinfopanel_" .. type)
    o.labelWidth = getTextManager():MeasureStringX(UIFont.Small, o.name)
    o.padX = UI_BORDER_SPACING
    o.padY = UI_BORDER_SPACING
    o.modDict = {}
    o.borderX = width / 4.0
    return o
end