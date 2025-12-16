require "ISUI/ISPanelJoypad"
require "OptionScreens/ModSelector/ModInfoPanel"
require "OptionScreens/ModSelector/ModInfoPanelInteractionParam"
local changelog_handler = require "chuckleberryFinnModding_modChangelog"

local UI_BORDER_SPACING = 10

ModInfoPanel.Changelog = ModInfoPanel.InteractionParam:derive("ModInfoPanelChangelog")

function ModInfoPanel.Changelog:new(x, y, width, height)
    local o = ModInfoPanel.InteractionParam.new(self, x, y, width, "Changelog")
    o.name = "Changelog"
    o.labelWidth = getTextManager():MeasureStringX(UIFont.Small, o.name)
    o.modDict = {}
    return o
end

function ModInfoPanel.Changelog:createChildren()
    self.richText = ISRichTextPanel:new(self.borderX + UI_BORDER_SPACING, 3, self.width - self.borderX - 12, self.height - 6)
    self.richText:initialise()
    self.richText:instantiate()
    self.richText:setAnchorRight(true)
    self.richText:setAnchorBottom(true)
    self.richText.defaultFont = UIFont.Small
    self.richText.autosetheight = false
    self.richText.clip = true
    self.richText:noBackground()
    self.richText.marginLeft = 0
    self.richText.marginTop = 0
    self.richText.marginRight = 0
    self.richText.marginBottom = 0
    self.richText:addScrollBars()
    self:addChild(self.richText)
end

function ModInfoPanel.Changelog:render()
    ModInfoPanel.InteractionParam.render(self)
end

function ModInfoPanel.Changelog:onMouseWheel(del)
    return self.richText:onMouseWheel(del)
end

function ModInfoPanel.Changelog:setModInfo(modInfo)
    local modID = modInfo:getId()
    local alerts = changelog_handler.fetchMod(modID)

    local text_parts = {}
    table.insert(text_parts, " <TEXT> ")

    if alerts and #alerts > 0 then
        for i = #alerts, 1, -1 do
            local alert = alerts[i]
            local title = alert.title or ""
            local contents = alert.contents or ""

            table.insert(text_parts, " <RGB:0.8,0.8,0.8> " .. title .. " <LINE> ")
            table.insert(text_parts, " <RGB:0.8,0.8,0.8> " .. luautils.trim(contents))
            table.insert(text_parts, " <LINE> <LINE> ")
        end
    end

    self.richText:setText(table.concat(text_parts, ""))
    self.richText:paginate()
    self.richText:setYScroll(0)
end