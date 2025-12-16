require "ISUI/ISPanelJoypad"
require "OptionScreens/ModSelector/ModInfoPanel"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6

function ModInfoPanel:createChildren()
    self.titlePanel = ModInfoPanel.Title:new(0, 0, self.width)
    self.titlePanel:initialise()
    self.titlePanel:instantiate()
    self:addChild(self.titlePanel)

    self.descPanel = ModInfoPanel.Desc:new(0, self.titlePanel:getBottom() - 1, self.width)
    self.descPanel:initialise()
    self.descPanel:instantiate()
    self:addChild(self.descPanel)

    self.thumbnailPanel = ModInfoPanel.Thumbnail:new(0, self.descPanel:getBottom() - 1, self.width)
    self.thumbnailPanel:initialise()
    self.thumbnailPanel:instantiate()
    self.thumbnailPanel:setAnchorRight(true)
    self:addChild(self.thumbnailPanel)

    local prevPanel = self.thumbnailPanel
    for _, param in ipairs(self.modInfoParams) do
        self[param] = ModInfoPanel.Param:new(0, prevPanel:getBottom() - 1, self.width, param)
        self[param]:initialise()
        self[param]:instantiate()
        self:addChild(self[param])
        prevPanel = self[param]
    end

    self.dependenciesPanel = ModInfoPanel.InteractionParam:new(0, prevPanel:getBottom()-1, self.width, "Dependencies")
    self.dependenciesPanel:initialise()
    self.dependenciesPanel:instantiate()
    self:addChild(self.dependenciesPanel)

    self.incompatiblePanel = ModInfoPanel.InteractionParam:new(0, self.dependenciesPanel:getBottom()-1, self.width, "IncompatibleWith")
    self.incompatiblePanel:initialise()
    self.incompatiblePanel:instantiate()
    self:addChild(self.incompatiblePanel)

    self:removeChild(self.incompatiblePanel)
    self.incompatiblePanel = nil

    self.incompatiblePanel = ModInfoPanel.IncompatibleParam:new(0, self.dependenciesPanel:getBottom()-1, self.width, "IncompatibleWith")
    self.incompatiblePanel:initialise()
    self.incompatiblePanel:instantiate()
    self:addChild(self.incompatiblePanel)

    self.changelogPanel = ModInfoPanel.Changelog:new(0, self.incompatiblePanel:getBottom() - 1, self.width, self:getHeight() - self.incompatiblePanel:getBottom() + 1)
    self.changelogPanel:initialise()
    self.changelogPanel:instantiate()
    self:addChild(self.changelogPanel)
end

function ModInfoPanel:updateView(modInfo)
    self.modInfo = modInfo

    self.titlePanel:setModInfo(modInfo)
    self.descPanel:setModInfo(modInfo)
    self.thumbnailPanel:setModInfo(modInfo)

    for _, param in ipairs(self.modInfoParams) do
        self[param]:setModInfo(modInfo)
    end

    self.dependenciesPanel:setModInfo(modInfo)
    self.incompatiblePanel:setModInfo(modInfo)
    self.incompatiblePanel:setY(self.dependenciesPanel:getBottom()-1)
    self.incompatiblePanel:setHeight(self:getHeight() - self.incompatiblePanel:getY())
    self:setVisible(true)

    self.incompatiblePanel:setHeight(BUTTON_HGT)
    self.changelogPanel:setY(self.incompatiblePanel:getBottom() - 1)
    self.changelogPanel:setHeight(self:getHeight() - self.changelogPanel:getY())
    self.changelogPanel:setModInfo(modInfo)
end

function ModInfoPanel:recalcSize()
    ISPanelJoypad.recalcSize(self)
    for _, child in pairs(self:getChildren()) do
        child:setWidth(self.width)
        child:recalcSize()
    end
    self.incompatiblePanel:setHeight(self:getHeight() - self.incompatiblePanel:getY())

    if self.changelogPanel then
        self.changelogPanel:setHeight(self:getHeight() - self.changelogPanel:getY())
    end
end