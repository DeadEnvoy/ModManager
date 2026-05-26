require "ISUI/ISPanelJoypad"
require "ModManager/OptionScreens/ModSelector/ModInfoPanel"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6
local UI_BORDER_SPACING = 10

ModInfoPanel.SupportParam = ISPanelJoypad:derive("ModInfoPanelSupportParam")

function ModInfoPanel.SupportParam:render()
    self:drawRectBorder(0, 0, self.borderX, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawText(self.name, self.borderX - UI_BORDER_SPACING - self.labelWidth, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)

    if self.modInfo == nil then return end

    local currentX = self.borderX + UI_BORDER_SPACING
    local mouseX = self:getMouseX()
    local mouseY = self:getMouseY()
    local isMouseOver = self:isMouseOver()

    for i, link in ipairs(self.displayLinks) do
        local textWidth = getTextManager():MeasureStringX(UIFont.Small, link.name)
        local isHovered = isMouseOver and mouseX >= currentX and mouseX < currentX + textWidth and mouseY >= 2 and mouseY < 2 + FONT_HGT_SMALL + 1

        self:drawText(link.name, currentX, 2, 0.2, 0.6, 1.0, 0.9, UIFont.Small)

        if not isHovered then
            self:drawRectBorder(currentX, 2 + FONT_HGT_SMALL, textWidth, 1, 0.9, 0.2, 0.6, 1.0)
        else
            if self.pressed then
                openUrl(link.url)
            end
        end

        currentX = currentX + textWidth
        if i < #self.displayLinks then
            self:drawText(", ", currentX, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)
            currentX = currentX + getTextManager():MeasureStringX(UIFont.Small, ", ")
        end
    end
    self.pressed = false
end

function ModInfoPanel.SupportParam:onMouseDown()
    self.pressed = true
end

function ModInfoPanel.SupportParam:hasLinks()
    return #self.supportLinks > 0
end

function ModInfoPanel.SupportParam:setModInfo(modInfo)
    if not modInfo then return end

    self.modInfo = modInfo

    local modData = self.parent.parent.model.mods[modInfo:getId()]
    self.supportLinks = modData.supportLinks
    self.displayLinks = self.supportLinks

    local fullText = ""
    for i, link in ipairs(self.displayLinks) do
        if i > 1 then
            fullText = fullText .. ", "
        end
        fullText = fullText .. link.name
    end

    local availableWidth = self.width - self.borderX - UI_BORDER_SPACING * 2
    if getTextManager():MeasureStringX(UIFont.Small, fullText) > availableWidth then
        local truncatedLinks = {}
        local currentWidth = 0
        local spaceWidth = getTextManager():MeasureStringX(UIFont.Small, ", ")
        local dotWidth = getTextManager():MeasureStringX(UIFont.Small, " ...")

        for _, link in ipairs(self.supportLinks) do
            local textWidth = getTextManager():MeasureStringX(UIFont.Small, link.name)
            if currentWidth + textWidth + (spaceWidth * #truncatedLinks) > availableWidth then
                local name = link.name
                local remainingWidth = availableWidth - currentWidth - (spaceWidth * #truncatedLinks) - dotWidth
                while name ~= "" and getTextManager():MeasureStringX(UIFont.Small, name) > remainingWidth do
                    name = string.sub(name, 1, #name - 1)
                end
                if name ~= "" then
                    table.insert(truncatedLinks, { name = name .. " ...", url = link.url })
                end
                break
            end
            table.insert(truncatedLinks, link)
            currentWidth = currentWidth + textWidth
        end
        self.displayLinks = truncatedLinks
    end
end

function ModInfoPanel.SupportParam:new(x, y, width)
    local o = ISPanelJoypad:new(x, y, width, BUTTON_HGT)
    setmetatable(o, self)
    self.__index = self
    o.name = getText("UI_modinfopanel_Support")
    o.labelWidth = getTextManager():MeasureStringX(UIFont.Small, o.name)
    o.supportLinks = {}
    o.displayLinks = {}
    o.borderX = width / 4.0
    o.pressed = false
    return o
end