require "ISUI/ISToolTip"
require "ModManager/OptionScreens/ModSelector/ModInfoPanelParam"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local UI_BORDER_SPACING = 10

ModInfoPanel.IncompatibleParam = ModInfoPanel.Param:derive("ModInfoPanelIncompatibleParam")

function ModInfoPanel.IncompatibleParam:initialise()
    ModInfoPanel.Param.initialise(self)
    self.tooltipUI = ISToolTip:new()
    self.tooltipUI:initialise()
    self.tooltipUI:setOwner(self)
end

function ModInfoPanel.IncompatibleParam:onMouseUp(x, y)
    return false
end

function ModInfoPanel.IncompatibleParam:onMouseDown(x, y)
    self.pressed = true
end

function ModInfoPanel.IncompatibleParam:update()
    ModInfoPanel.Param.update(self)
    if self:isMouseOver() and self:isReallyVisible() and self.tooltip and self.tooltip ~= "" then
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

function ModInfoPanel.IncompatibleParam:setModInfo(modInfo)
    self.modInfo = modInfo
    self.displayParts = {}
    self.tooltip = nil

    local model = self.parent.parent.model
    local currentModData = model.mods[modInfo:getId()]
    if not currentModData then return end

    local incompatibleIDs = {}
    if self.modInfo:getIncompatible() ~= nil then
        for id, _ in pairs(model.incompatibles[modInfo:getId()]) do
            table.insert(incompatibleIDs, id)
        end
    end

    if #incompatibleIDs == 0 then return end

    local fullText_tooltip = {}
    local fullText_display = ""
    local availableWidth = self.width - self.borderX - UI_BORDER_SPACING * 2
    local spaceWidth = getTextManager():MeasureStringX(UIFont.Small, ", ")

    for i, incompatibleID in ipairs(incompatibleIDs) do
        local partText = incompatibleID
        local incompatibleModData = model.mods[incompatibleID]
        local color = { r = 0.9, g = 0.9, b = 0.9 }
        local available = false
        local modInfo2

        if currentModData.isActive then
            if incompatibleModData and not incompatibleModData.isActive then
                color = { r = 0.9, g = 0.45, b = 0.0 }
            end
        elseif currentModData.isIncompatible then
            if incompatibleModData and incompatibleModData.isActive then
                color = { r = 0.9, g = 0.45, b = 0.0 }
            end
        end

        if incompatibleModData then
            available = true
            modInfo2 = incompatibleModData.modInfo
        end

        table.insert(fullText_tooltip, string.format(" <RGB:%.3f,%.3f,%.3f> %s ", color.r, color.g, color.b, partText))
        if i > 1 then
            fullText_display = fullText_display .. ", "
        end
        fullText_display = fullText_display .. partText

        table.insert(self.displayParts, { text = partText, color = color, available = available, modInfo = modInfo2, id = incompatibleID })
    end

    if getTextManager():MeasureStringX(UIFont.Small, fullText_display) > availableWidth then
        self.tooltip = table.concat(fullText_tooltip, "<LINE>")
        local truncatedParts = {}
        local currentWidth = 0
        for _, part in ipairs(self.displayParts) do
            local partWidth = getTextManager():MeasureStringX(UIFont.Small, part.text)
            if currentWidth + partWidth + (spaceWidth * #truncatedParts) > availableWidth then
                local remainingWidth = availableWidth - currentWidth - (spaceWidth * #truncatedParts) - getTextManager():MeasureStringX(UIFont.Small, " ...")
                while #part.text > 0 and getTextManager():MeasureStringX(UIFont.Small, part.text) > remainingWidth do
                    part.text = string.sub(part.text, 1, #part.text - 1)
                end
                part.text = part.text .. " ..."
                table.insert(truncatedParts, part)
                break
            end
            table.insert(truncatedParts, part)
            currentWidth = currentWidth + partWidth
        end
        self.displayParts = truncatedParts
    end
end

function ModInfoPanel.IncompatibleParam:render()
    self:drawRectBorder(0, 0, self.borderX, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawText(self.name, self.borderX - UI_BORDER_SPACING - self.labelWidth, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)

    if self.modInfo == nil then return end

    local currentX = self.borderX + UI_BORDER_SPACING
    local mouseX = self:getMouseX()
    local mouseY = self:getMouseY()
    local isMouseOver = self:isMouseOver()

    for i, part in ipairs(self.displayParts) do
        local textWidth = getTextManager():MeasureStringX(UIFont.Small, part.text)
        local isHovered = isMouseOver and mouseX >= currentX and mouseX < currentX + textWidth and mouseY >= 2 and mouseY < 2 + FONT_HGT_SMALL + 1

        self:drawText(part.text, currentX, 2, part.color.r, part.color.g, part.color.b, 0.9, UIFont.Small)

        if part.available then
            if not isHovered then
                self:drawRectBorder(currentX, 2 + FONT_HGT_SMALL, textWidth, 1, 0.9, part.color.r, part.color.g, part.color.b)
            else
                if self.pressed then
                    self.parent.parent:selectModByInfo(part.modInfo)
                end
            end
        end

        currentX = currentX + textWidth
        if i < #self.displayParts then
            self:drawText(", ", currentX, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)
            currentX = currentX + getTextManager():MeasureStringX(UIFont.Small, ", ")
        end
    end
    self.pressed = false
end

function ModInfoPanel.IncompatibleParam:new(x, y, width, type)
    local o = ModInfoPanel.Param.new(self, x, y, width, type)
    o.displayParts = {}
    return o
end