require "ISUI/ISScrollingListBox"
require "OptionScreens/ModSelector/ModListBox"

local ModListBox = ModSelector.ModListBox

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6
local UI_BORDER_SPACING = 10
local GHC = getCore():getGoodHighlitedColor()
local BHC = getCore():getBadHighlitedColor()

function ModListBox:doDrawItem(y, item, alt)
    local isMouseOver = self.mouseoverselected == item.index
    local height = UI_BORDER_SPACING*2 + BUTTON_HGT + 2

    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), height, 0.3, 0.7, 0.35, 0.15)

        if self.parent.joyfocus ~= nil and self.parent.joypadListFocus then
            self:drawTextureScaled(self.joypadStarButtonTex, self:getWidth() - 48 - 40, 8 + y, 24, 24, 1, 1, 1, 1)
        end
    end
    self:drawRectBorder(0, y, self:getWidth(), height, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawRectBorder(height-1, y, 1, height, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    local shift = (height - self.boxSize)/2
    self:drawRectBorder(shift, shift + y, self.boxSize, self.boxSize, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    if isMouseOver and ((self:getMouseX() > shift) and (self:getMouseX() < self.boxSize + shift) and (self:getMouseY() > shift + y) and (self:getMouseY() < shift + y + self.boxSize)) then
        self.mouseOverTickBox = item
    end

    if item.item.isActive then
        local tr, tg, tb = GHC:getR(), GHC:getG(), GHC:getB()
        if item.item.defaultActive == false then
            tr, tg, tb = 0.2, 0.8, 1.0
        end
        self:drawTextureScaled(self.tickTexture, shift + 2, shift + 2 + y, self.boxSize-4, self.boxSize-4, 1, tr, tg, tb)
    else
        if not item.item.isAvailable then
            self:drawTextureScaled(self.cantTexture, shift + 2, shift + 2 + y, self.boxSize-4, self.boxSize-4, 1, BHC:getR(), BHC:getG(), BHC:getB())
        end
    end

    local iconX = height + UI_BORDER_SPACING
    local iconY = y + (height - BUTTON_HGT) / 2
    local iconTexture = Texture.trygetTexture(item.item.icon) or Texture.trygetTexture("Item_Pie.png")
    self:drawTextureScaled(iconTexture, iconX, iconY, BUTTON_HGT, BUTTON_HGT, 1, 1, 1, 1)

    if item.item.hasSupportLinks then
        local supportIconSize = BUTTON_HGT * 0.45
        local supportIconOffset = BUTTON_HGT * 0.12
        local supportIconX = iconX + BUTTON_HGT - supportIconSize + supportIconOffset
        local supportIconY = iconY + BUTTON_HGT - supportIconSize + supportIconOffset
        self:drawTextureScaled(getTexture("media/ui/ModManager/Icons/Support.png"), supportIconX, supportIconY, supportIconSize, supportIconSize, 1, 1, 1, 1)
    end

    local itemPadY = (height - self.fontHgt) / 2

    local starOffset = 0
    if self:isVScrollBarVisible() then
        starOffset = 10
    end
    local starX = self:getWidth() - UI_BORDER_SPACING - BUTTON_HGT - 1 - starOffset
    local starY = y + UI_BORDER_SPACING + 1

    local showStar = item.item.favorite or isMouseOver

    local author = item.item.modInfo:getAuthor()
    local authorText = ""
    local authorWidth = 0

    local authorX = starX - 10
    if not showStar then
        authorX = starX + BUTTON_HGT
    end

    if author and author ~= "" then
        authorText = author
        authorWidth = getTextManager():MeasureStringX(self.font, authorText)
    end

    local nameToDraw = item.item.name
    local nameX = height * 2
    local nameWidth = getTextManager():MeasureStringX(self.font, nameToDraw)
    local textSpacing = getTextManager():MeasureStringX(UIFont.Small, "  ")
    local rightBoundary = starX - textSpacing
    if authorText ~= "" then
        rightBoundary = authorX - authorWidth - textSpacing
    end

    local r,g,b = 0.9, 0.9, 0.9
    if item.item.isAvailable then
        if item.item.isActive then
            r, g, b = GHC:getR(), GHC:getG(), GHC:getB()
            if item.item.defaultActive == false then
                r, g, b = 0.2, 0.8, 1.0
            end
        elseif item.item.isIncompatible then
            r, g, b = 0.9, 0.45, 0.0
            item.tooltip = getText("UI_modselector_incompatibleWith")
            for v, _ in pairs(item.item.incompatibleWith) do
                item.tooltip = item.tooltip .. "\n" .. v
            end
        end
    else
        r, g, b = BHC:getR(), BHC:getG(), BHC:getB()
    end

    if item.item.isHidden then
        r,g,b = 0.6, 0.6, 0.6
    end
    local category = self.model:getCategory(item.item.modId)
    local categoryText = ""
    local categoryWidth = 0
    if category and category ~= "" then
        categoryText = "[" .. getText("UI_modinfopanel_Category_" .. category) .. "]"
        categoryWidth = getTextManager():MeasureStringX(UIFont.Small, categoryText)
    end

    if nameX + nameWidth > rightBoundary then
        local truncBoundary = rightBoundary
        if categoryText ~= "" then
            truncBoundary = truncBoundary - categoryWidth - textSpacing
        end
        while #nameToDraw > 5 and (nameX + getTextManager():MeasureStringX(self.font, nameToDraw .. "...") > truncBoundary) do
            nameToDraw = string.sub(nameToDraw, 1, #nameToDraw - 1)
        end
        nameToDraw = nameToDraw .. "..."
    end

    self:drawText(nameToDraw, height*2, y+itemPadY, r, g, b, 0.9, self.font)

    if categoryText ~= "" then
        local catX = nameX + getTextManager():MeasureStringX(self.font, nameToDraw) + textSpacing
        local catPadY = (height - FONT_HGT_SMALL) / 2
        self:drawText(categoryText, catX, y + catPadY, 0.6, 0.6, 0.6, 0.9, UIFont.Small)
    end

    if authorText ~= "" then
        self:drawTextRight(authorText, authorX, y + itemPadY, 0.7, 0.7, 0.7, 0.9, self.font)
    end

    if showStar then
        if item.item.favorite then
            self:drawTextureScaled(self.starSetTexture, starX, starY, BUTTON_HGT, BUTTON_HGT, 1, 1, 1, 1)
        else
            self:drawTextureScaled(self.starUnsetTexture, starX, starY, BUTTON_HGT, BUTTON_HGT, 1, 1, 1, 1)
        end

        if isMouseOver and (
                (self:getMouseX() > starX) and
                (self:getMouseX() < starX + BUTTON_HGT) and
                (self:getMouseY() > starY) and
                (self:getMouseY() < starY + BUTTON_HGT)) then
            self.mouseOverFavoriteButton = item
        end
    end

    y = y + height
    return y
end