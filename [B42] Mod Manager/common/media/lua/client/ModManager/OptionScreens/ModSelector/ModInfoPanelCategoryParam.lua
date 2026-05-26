require "ISUI/ISPanelJoypad"
require "ModManager/OptionScreens/ModSelector/ModInfoPanel"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local BUTTON_HGT = FONT_HGT_SMALL + 6
local UI_BORDER_SPACING = 10
local SCROLL_BAR_WIDTH = 17

local function getCategorySelectLayout(searchHeight)
    local panelPad = UI_BORDER_SPACING * 2.2
    local titleBottom = 5 + FONT_HGT_LARGE
    local searchY = titleBottom + UI_BORDER_SPACING
    local panelTop = searchY + searchHeight + 5
    return panelPad, searchY, panelTop
end

ModInfoPanel.CategoryParam = ISPanelJoypad:derive("ModInfoPanelCategoryParam")

function ModInfoPanel.CategoryParam:onMouseDown(x, y)
    self.pressed = true
end

function ModInfoPanel.CategoryParam:setModInfo(modInfo)
    self.modInfo = modInfo
    if not modInfo then
        self.categoryText = ""
        self.categoryTextWidth = 0
        self.isChangeLink = true
        self.isLocked = false
        return
    end

    local model = self.parent.parent.model
    local modId = modInfo:getId()

    local category = model:getCategory(modId)
    if model:isCategoryLocked(modId) then
        self.categoryText = getText("UI_modinfopanel_Category_" .. category)
        self.isChangeLink = false
        self.isLocked = true
    else
        if category and category ~= "" then
            self.categoryText = getText("UI_modinfopanel_Category_" .. category)
            self.isChangeLink = false
        else
            self.categoryText = getText("UI_modinfopanel_SetCategory")
            self.isChangeLink = true
        end
        self.isLocked = false
    end

    self.categoryTextWidth = getTextManager():MeasureStringX(UIFont.Small, self.categoryText)
end

function ModInfoPanel.CategoryParam:render()
    self:drawRectBorder(0, 0, self.borderX, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawText(self.name, self.borderX - UI_BORDER_SPACING - self.labelWidth, 2, 0.9, 0.9, 0.9, 0.9, UIFont.Small)

    if not self.modInfo then
        return
    end

    local textX = self.borderX + UI_BORDER_SPACING
    local mouseX = self:getMouseX()
    local mouseY = self:getMouseY()
    local isMouseOverText = self:isMouseOver() and mouseX >= textX and mouseX < textX + self.categoryTextWidth and mouseY >= 2 and mouseY < 2 + FONT_HGT_SMALL + 1

    local r, g, b = 0.9, 0.9, 0.9
    if self.isChangeLink then
        r, g, b = 0.0, 0.9, 0.0
    end

    self:drawText(self.categoryText, textX, 2, r, g, b, 0.9, UIFont.Small)

    if not isMouseOverText then
        if not self.isLocked then
            self:drawRectBorder(textX, 2 + FONT_HGT_SMALL, self.categoryTextWidth, 1, 0.9, r, g, b)
        end
    else
        if self.pressed then
            self:openCategorySelectWindow()
        end
    end

    self.pressed = false
end

function ModInfoPanel.CategoryParam:openCategorySelectWindow()
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local w = math.max(450, screenW * 0.25)
    local h = math.max(400, screenH * 0.4)
    local model = self.parent.parent.model
    local modId = self.modInfo:getId()
    if model:isCategoryLocked(modId) then return end
    local currentCategory = model:getCategory(modId)
    local dialog = ModInfoPanel.CategorySelectWindow:new(
        (screenW - w) / 2,
        (screenH - h) / 2,
        w, h, self, currentCategory
    )
    dialog:initialise()
    dialog:instantiate()
    ModSelector.instance.categorySelectWindow = dialog
    dialog:addToUIManager()
    dialog:setCapture(true)
    dialog:bringToTop()
end

function ModInfoPanel.CategoryParam:onCategorySelected(categoryValue)
    local model = self.parent.parent.model
    local modId = self.modInfo:getId()
    model:setCategory(modId, categoryValue)
    self:setModInfo(self.modInfo)
end

function ModInfoPanel.CategoryParam:new(x, y, width)
    local o = ISPanelJoypad:new(x, y, width, BUTTON_HGT)
    setmetatable(o, self)
    self.__index = self
    o.name = getText("UI_modinfopanel_Category")
    o.labelWidth = getTextManager():MeasureStringX(UIFont.Small, o.name)
    o.borderX = width / 4.0
    o.categoryText = ""
    o.categoryTextWidth = 0
    o.isChangeLink = true
    o.pressed = false
    o.isLocked = false
    return o
end

ModInfoPanel.CategorySelectPanel = ISPanelJoypad:derive("ModInfoPanelCategorySelectPanel")
local CategorySelectPanel = ModInfoPanel.CategorySelectPanel

function CategorySelectPanel:createChildren()
    local y = 0
    local buttonHeight = FONT_HGT_MEDIUM + 6
    local spacing = 5
    local hasCategory = self.currentCategory and self.currentCategory ~= ""
    local buttonWidth = self.width - SCROLL_BAR_WIDTH
    self.allButtons = {}

    local noneButton = ISButton:new(0, y, buttonWidth, buttonHeight, getText("UI_modinfopanel_Category_None"), self, CategorySelectPanel.onCategorySelected)
    noneButton.categoryValue = nil
    noneButton:initialise()
    noneButton:instantiate()
    noneButton:setFont(UIFont.Medium)
    if not hasCategory then
        noneButton:setEnable(false)
    end
    self:addChild(noneButton)
    table.insert(self.allButtons, noneButton)
    y = y + buttonHeight + spacing

    local sortedCategories = {}
    for _, catName in ipairs(ModSelector.Model.CATEGORIES) do
        local localizedName = getText("UI_modinfopanel_Category_" .. catName)
        table.insert(sortedCategories, {value = catName, label = localizedName})
    end
    table.sort(sortedCategories, function(a, b) return a.label < b.label end)

    for _, cat in ipairs(sortedCategories) do
        local button = ISButton:new(0, y, buttonWidth, buttonHeight, cat.label, self, CategorySelectPanel.onCategorySelected)
        button.categoryValue = cat.value
        button:initialise()
        button:instantiate()
        button:setFont(UIFont.Medium)
        if hasCategory and cat.value == self.currentCategory then
            button:setEnable(false)
        end
        self:addChild(button)
        table.insert(self.allButtons, button)
        y = y + buttonHeight + spacing
    end

    self:setScrollHeight(math.max(0, y - spacing))
end

function CategorySelectPanel:filterCategories()
    local searchText = string.lower(self.searchEntry:getInternalText())
    for _, button in ipairs(self.allButtons) do
        if button.categoryValue == nil then
            button:setVisible(true)
        else
            local buttonText = string.lower(button.title)
            local isVisible = searchText == "" or string.find(buttonText, searchText, 1, true) ~= nil
            button:setVisible(isVisible)
        end
    end
    self:updateLayout(true)
end

function CategorySelectPanel:updateLayout(resetScroll)
    local y = 0
    local buttonHeight = FONT_HGT_MEDIUM + 6
    local spacing = 5
    for _, button in ipairs(self.allButtons) do
        if button:isVisible() then
            button:setY(y)
            button:setWidth(self.width - SCROLL_BAR_WIDTH)
            y = y + buttonHeight + spacing
        end
    end
    self:setScrollHeight(math.max(0, y - spacing))
    if resetScroll then
        self:setYScroll(0)
    end
end

function CategorySelectPanel:onMouseWheel(del)
    if self:getScrollHeight() > self:getHeight() then
        self:setYScroll(self:getYScroll() - (del * 20))
        return true
    end
    return false
end

function CategorySelectPanel:prerender()
    ISPanelJoypad.prerender(self)
    self:setStencilRect(0, 0, self.width, self.height)
end

function CategorySelectPanel:render()
    ISPanelJoypad.render(self)
    self:clearStencilRect()
    self:repaintStencilRect(0, 0, self.width, self.height)
end

function CategorySelectPanel:onCategorySelected(button)
    self.categoryParam:onCategorySelected(button.categoryValue)
    self.parent:onClose()
end

function CategorySelectPanel:new(x, y, width, height, categoryParam, currentCategory, searchEntry)
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.categoryParam = categoryParam
    o.currentCategory = currentCategory
    o.searchEntry = searchEntry
    o.borderColor.a = 0
    return o
end

ModInfoPanel.CategorySelectWindow = ISPanelJoypad:derive("ModInfoPanelCategorySelectWindow")
local CategorySelectWindow = ModInfoPanel.CategorySelectWindow

function CategorySelectWindow:prerender()
    ISPanelJoypad.prerender(self)
    self:drawTextCentre(getText("UI_modinfopanel_SelectCategory"), self.width / 2, 5, 1, 1, 1, 1, UIFont.Large)
end

function CategorySelectWindow:createChildren()
    local searchHeight = FONT_HGT_MEDIUM + 6
    local panelPad, searchY, panelTop = getCategorySelectLayout(searchHeight)
    self.searchEntry = ISTextEntryBox:new("", panelPad, searchY, self.width - panelPad * 2, searchHeight)
    self.searchEntry.font = UIFont.Medium
    self.searchEntry:initialise()
    self.searchEntry:instantiate()
    self.searchEntry:setPlaceholderText(getText("UI_sandbox_searchEntryBoxWord"))
    self.searchEntry:setClearButton(true)
    self:addChild(self.searchEntry)

    self.panel = CategorySelectPanel:new(panelPad, panelTop, self.width - panelPad * 2 + SCROLL_BAR_WIDTH, self.height - panelTop - 50, self.categoryParam, self.currentCategory, self.searchEntry)
    self.panel:initialise()
    self.panel:instantiate()
    self.panel:setAnchorRight(true)
    self.panel:setAnchorBottom(true)
    self.panel:addScrollBars()
    self.panel:setScrollChildren(true)
    self.panel.vscroll.doSetStencil = false
    self:addChild(self.panel)

    self.btnCancel = ISButton:new(self.width / 2 - 75, self.height - 40, 150, 30, getText("UI_btn_cancel"), self, CategorySelectWindow.onOptionMouseDown)
    self.btnCancel.internal = "CANCEL"
    self.btnCancel:initialise()
    self.btnCancel:instantiate()
    self:addChild(self.btnCancel)

    self.searchEntry.onTextChange = function() self.panel:filterCategories() end

    self.onResolutionChangeEvent = function(_, _, neww, newh)
        if self:isReallyVisible() then
            self:onResolutionChange(neww, newh)
        end
    end
    Events.OnResolutionChange.Add(self.onResolutionChangeEvent)
end

function CategorySelectWindow:onResolutionChange(neww, newh)
    local width = math.max(450, neww * 0.25)
    local height = math.max(400, newh * 0.4)
    local panelPad, searchY, panelTop = getCategorySelectLayout(self.searchEntry.height)

    self:setX((neww - width) / 2)
    self:setY((newh - height) / 2)
    self:setWidth(width)
    self:setHeight(height)

    self.searchEntry:setX(panelPad)
    self.searchEntry:setY(searchY)
    self.searchEntry:setWidth(self.width - panelPad * 2)

    self.panel:setX(panelPad)
    self.panel:setY(panelTop)
    self.panel:setWidth(self.width - panelPad * 2 + SCROLL_BAR_WIDTH)
    self.panel:setHeight(self.height - panelTop - 50)
    self.panel:updateLayout(false)

    self.btnCancel:setX(self.width / 2 - 75)
    self.btnCancel:setY(self.height - 40)
end

function CategorySelectWindow:onClose()
    if self.onResolutionChangeEvent then
        Events.OnResolutionChange.Remove(self.onResolutionChangeEvent)
        self.onResolutionChangeEvent = nil
    end
    self:setVisible(false)
    self:removeFromUIManager()
    if ModSelector.instance then
        ModSelector.instance.categorySelectWindow = nil
    end
end

function CategorySelectWindow:onOptionMouseDown()
    self:onClose()
end

function CategorySelectWindow:new(x, y, width, height, categoryParam, currentCategory)
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.categoryParam = categoryParam
    o.currentCategory = currentCategory
    o.backgroundColor.a = 0.9
    return o
end