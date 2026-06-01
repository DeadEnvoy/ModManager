require "ISUI/ISPanelJoypad"
require "ISUI/ISRichTextPanel"
require "ModManager/OptionScreens/ModSelector/ModInfoPanel"
require "ModManager/OptionScreens/ModSelector/ModInfoPanelInteractionParam"

local UI_BORDER_SPACING = 10
local Changelog = require("ModManager/Utils/WorkshopSubmit")

ModInfoPanel.ChangelogParam = ModInfoPanel.InteractionParam:derive("ModInfoPanelChangelogParam")

function ModInfoPanel.ChangelogParam:createChildren()
    self.richText = ISRichTextPanel:new(self.borderX + UI_BORDER_SPACING, 3, self.width - self.borderX - UI_BORDER_SPACING - 2, self.height - 6)
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
    self:addChild(self.richText)
    self.richText:addScrollBars()
    self.richText.marginRight = self.richText.vscroll and self.richText.vscroll:getWidth() or 0
end

function ModInfoPanel.ChangelogParam:onMouseWheel(del)
    return self.richText:onMouseWheel(del)
end

function ModInfoPanel.ChangelogParam:recalcSize()
    ISPanelJoypad.recalcSize(self)
    if self.richText then
        self.richText:setWidth(self.width - self.borderX - UI_BORDER_SPACING - 2)
        self.richText:setHeight(self.height - 6)
    end
end

function ModInfoPanel.ChangelogParam:setModInfo(modInfo)
    local modID = modInfo:getId()
    local changelogs, isMd, isLegacy = Changelog.fetchChangelog(modID)

    if not changelogs or #changelogs == 0 then
        self.richText:setText("")
        self.richText:paginate()
        self.richText:setYScroll(0)
        return
    end

    local text_parts = {}
    table.insert(text_parts, " <TEXT> ")

    local start, stop, step
    if isMd and not isLegacy then
        start, stop, step = 1, #changelogs, 1
    else
        start, stop, step = #changelogs, 1, -1
    end

    local isLatest = true
    for i = start, stop, step do
        local entry = changelogs[i]
        if type(entry.title) == "string" then
            local title = entry.title
            local contents = (isMd and not isLegacy) and Changelog.markdownToPlaintext(entry.contents or "") or luautils.trim(entry.contents or "")
            if isLatest then
                table.insert(text_parts, " <RGB:0.8,0.8,0.8> " .. title .. " <LINE> ")
                table.insert(text_parts, " <RGB:0.8,0.8,0.8> " .. contents)
                isLatest = false
            else
                table.insert(text_parts, " <RGB:0.4,0.4,0.4> " .. title .. " <LINE> ")
                table.insert(text_parts, " <RGB:0.4,0.4,0.4> " .. contents)
            end
            table.insert(text_parts, " <LINE> <LINE> ")
        end
    end

    self.richText:setText(table.concat(text_parts, ""))
    self.richText:paginate()
    self.richText:setYScroll(0)
end

function ModInfoPanel.ChangelogParam:new(x, y, width, height)
    local o = ModInfoPanel.InteractionParam.new(self, x, y, width, "Changelog")
    o:setHeight(height)
    o.name = getText("UI_modinfopanel_Changelog")
    o.labelWidth = getTextManager():MeasureStringX(UIFont.Small, o.name)
    o.modDict = {}
    return o
end