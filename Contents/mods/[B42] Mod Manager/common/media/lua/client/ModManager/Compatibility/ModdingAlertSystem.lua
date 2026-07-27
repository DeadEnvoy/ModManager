---@diagnostic disable: inject-field
require "ISUI/ISRichTextPanel"
require "ModManager/OptionScreens/ModSelector/ModInfoPanelSupportParam"
require "ModManager/OptionScreens/ModSelector/ModSelectorModel"

-- The welcome message is hidden to get straight to the update list, so the Ko-fi
-- link for Chuckleberry Finn is injected here to keep the support option visible.

local original_setModInfo = ModInfoPanel.SupportParam.setModInfo
function ModInfoPanel.SupportParam:setModInfo(modInfo)
    original_setModInfo(self, modInfo)
    if modInfo and modInfo:getId() == "ChuckleberryFinnAlertSystem" and #self.supportLinks == 0 then
        local link = {
            name = "Ko-fi",
            url = "https://steamcommunity.com/linkfilter/?u=https://ko-fi.com/chuckleberryfinn"
        }
        self.supportLinks = { link }
        self.displayLinks = { link }
    end
end

local original_reloadMods = ModSelector.Model.reloadMods
function ModSelector.Model:reloadMods()
    original_reloadMods(self)
    local modData = self.mods and self.mods["ChuckleberryFinnAlertSystem"]
    if modData and not modData.hasSupportLinks then
        modData.hasSupportLinks = true
        modData.supportLinks = {
            {
                name = "Ko-fi",
                url = "https://steamcommunity.com/linkfilter/?u=https://ko-fi.com/chuckleberryfinn"
            }
        }
    end
end

local ok1, alertSystem = pcall(require, "chuckleberryFinnModdingAlertSystem")
local ok2, changelog_handler = pcall(require, "chuckleberryFinnModding_modChangelog")
local ModListData = require("ModManager/Utils/ModListData")
local Changelog = require("ModManager/Utils/WorkshopSubmit")

if (ok1 and ok2) and (alertSystem and changelog_handler) then
    local original_fetchMod = changelog_handler.fetchMod
    function changelog_handler.fetchMod(modID, latest)
        local mdReader = changelog_handler.resolveFile(modID, "ChangeLog.md")
        if mdReader then
            local lines = {}
            local line = mdReader:readLine()
            while line do
                table.insert(lines, line)
                line = mdReader:readLine()
            end
            mdReader:close()

            local completeText = table.concat(lines, "\n")
            local config = completeText:match("<!%-%- ALERT_CONFIG\n(.-)\n%-%->")
            if config then
                changelog_handler.parseModAlertConfig(modID, config)
            end

            local changelogs, _, isLegacy = Changelog.fetchChangelog(modID)
            if not changelogs or #changelogs == 0 then return end
            local alerts = {}
            for _, entry in ipairs(changelogs) do
                table.insert(alerts, { title = entry.title, contents = entry.contents, isMd = true, isLegacy = isLegacy })
            end
            return alerts
        end
        return original_fetchMod(modID, latest)
    end

    local function formatDate(seconds)
        if not seconds or seconds == 0 then return "" end

        local millis = seconds * 1000.0
        local nowMillis = getTimestampMs()

        local sdfComponents = SimpleDateFormat.new("d M yyyy H m")
        local dateStr = sdfComponents:format(millis)

        local values = {}
        for v in string.gmatch(dateStr, "%S+") do table.insert(values, tonumber(v)) end
        local day, month, year, hour, min = values[1], values[2], values[3], values[4], values[5]

        local sdfCompare = SimpleDateFormat.new("yyyyMMdd")
        local dateKey = sdfCompare:format(millis)
        local nowKey = sdfCompare:format(nowMillis)
        local yesterdayKey = sdfCompare:format(nowMillis - 86400000.0)

        local timeFormat
        if dateKey == nowKey then
            timeFormat = getText("UI_modinfopanel_TimeFormat_Today")
        elseif dateKey == yesterdayKey then
            timeFormat = getText("UI_modinfopanel_TimeFormat_Yesterday")
        elseif year == tonumber(os.date("%Y")) then
            timeFormat = getText("UI_modinfopanel_TimeFormat_ThisYear")
        else
            timeFormat = getText("UI_modinfopanel_TimeFormat_OtherYears")
        end

        local monthStr = getText("UI_modinfopanel_Month_Short_" .. month)

        local h12 = hour
        local ampm = ""
        if h12 >= 12 then
            ampm = getText("UI_modinfopanel_PM")
            if h12 > 12 then h12 = h12 - 12 end
        else
            ampm = getText("UI_modinfopanel_AM")
            if h12 == 0 then h12 = 12 end
        end

        local res = timeFormat
        res = res:gsub("{day}", day)
        res = res:gsub("{month}", monthStr)
        res = res:gsub("{year}", year)
        res = res:gsub("{hour24}", string.format("%02d", hour))
        res = res:gsub("{hour12}", h12)
        res = res:gsub("{min}", string.format("%02d", min))
        res = res:gsub("{ampm}", ampm)

        return res
    end

    local function drawAlertChrome(self, layout, subHeader, alertTitle, modAuthor)
        if layout.alertIcon then
            self:drawTextureScaled(layout.alertIcon, 4 + (alertSystem.padding / 3), layout.headerY, 32, 32, 1, 1, 1, 1)
        end

        local maxSubheaderX = math.min(((alertSystem.padding * 1.5) + layout.headerW), (self.width - layout.subHeaderW))
        if subHeader then
            self:drawText(subHeader, maxSubheaderX, layout.headerY + (alertSystem.padding / 5), 1, 1, 1, 0.7, UIFont.NewSmall)
        end

        self:drawText(layout.header, layout.headerX, layout.headerY, 1, 1, 1, 0.96, UIFont.NewMedium)

        local titleY = layout.headerY + layout.headerH + (alertSystem.padding / 7)
        if alertTitle then
            self:drawText(alertTitle, layout.headerX, titleY, 1, 1, 1, 0.85, UIFont.NewSmall)
        end

        if modAuthor then
            local authorX = self.alertContentPanel:getX() + self.alertContentPanel:getWidth() - (alertSystem.padding / 4)
            self:drawTextRight(modAuthor, authorX, titleY, 1, 1, 1, 0.85, UIFont.NewSmall)
        end

        return titleY
    end

    function alertSystem:markCurrentAlertAsSeen()
        if self.alertSelected > 0 and self.alertsLoaded and self.alertsLoaded[self.alertSelected] then
            local modID = self.alertsLoaded[self.alertSelected]; local alertData = self.latestAlerts[modID]
            if alertData and not alertData.alreadyStored then
                alertData.alreadyStored = true; self.alertsOld = self.alertsOld + 1
                if ModListData.data.alerts and ModListData.data.alerts[modID] then
                    ModListData.data.alerts[modID].seen = true
                    ModListData:save()
                end
            end
        end
    end

    local original_onMouseDown = alertSystem.onMouseDown
    function alertSystem:onMouseDown(x, y)
        if y <= 32 then
            local click = 0
            if (x >= self.alertLeftX + 8 and x <= self.alertLeftX + 24) then click = -1 end
            if (x >= self.alertRightX + 8 and x <= self.alertRightX + 24) then click = 1 end
            if click ~= 0 then
                self:markCurrentAlertAsSeen()
            end
        end
        return original_onMouseDown(self, x, y)
    end

    local original_onMouseWheel = alertSystem.onMouseWheel
    function alertSystem:onMouseWheel(del)
        local x, y = self:getMouseX(), self:getMouseY()
        if x >= self.alertLeftX and x <= self.alertLeftX + self.alertBarSpan and y >= 10 and y <= 10 + 12 then
            self:markCurrentAlertAsSeen()
        end
        return original_onMouseWheel(self, del)
    end

    local original_onClickCollapse = alertSystem.onClickCollapse
    function alertSystem:onClickCollapse(...)
        original_onClickCollapse(self, ...); if self.collapsed then
            self:markCurrentAlertAsSeen()
        end
    end

    function alertSystem:processUpdates()
        local twoWeeksAgo = os.time() - 14 * 24 * 60 * 60
        local existingAlerts = ModListData:getAlertsData() or {}
        local newAlerts = {}
        local workshopMods = ModListData.data.workshop and ModListData.data.workshop.mods or {}

        for modID, wsData in pairs(workshopMods) do
            local ts = wsData.lastUpdate
            if ts and ts >= twoWeeksAgo then
                local modInfo = getModInfoByID(modID)
                if modInfo then
                    local alerts = changelog_handler.fetchMod(modID)
                    if alerts and #alerts > 0 then
                        local currentEntry = existingAlerts[modID]
                        if currentEntry then
                            if currentEntry.lastUpdate ~= ts then
                                newAlerts[modID] = { workshopID = wsData.workshopID, lastUpdate = ts, seen = false }
                            else
                                newAlerts[modID] = currentEntry
                            end
                        else
                            newAlerts[modID] = { workshopID = wsData.workshopID, lastUpdate = ts, seen = false }
                        end
                    end
                end
            end
        end

        ModListData.data.alerts = newAlerts; ModListData:save()

        local sortedItems = {}
        for modID, data in pairs(newAlerts) do
            table.insert(sortedItems, { modID = modID, ts = data.lastUpdate })
        end
        table.sort(sortedItems, function(a, b) return a.ts > b.ts end)

        self.alertsLoaded = {}
        self.latestAlerts = {}
        alertSystem.alertsLayout = {}
        self.alertsOld = 0

        for _, item in ipairs(sortedItems) do
            local modID = item.modID
            local modInfo = getModInfoByID(modID)

            if modInfo then
                local alerts = changelog_handler.fetchMod(modID)
                local modName = modInfo:getName()
                local modIcon = modInfo:getIcon() and getTexture(modInfo:getIcon())
                local modAuthor = modInfo:getAuthor()
                local seen = newAlerts[modID].seen

                self.latestAlerts[modID] = {
                    modName = modName,
                    alerts = alerts,
                    icon = modIcon,
                    modAuthor = modAuthor,
                    alreadyStored = seen,
                    ts = item.ts,
                    isLegacy = alerts and alerts[1] and alerts[1].isLegacy or false
                }
                table.insert(self.alertsLoaded, modID)
                if seen then
                    self.alertsOld = self.alertsOld + 1
                end
            end
        end

        if #self.alertsLoaded > 0 then
            self.alertSelected = 1
            if self["linkButton1"] then
                self:updateButtons()
            end
        end
    end

    local original_initialise = alertSystem.initialise
    function alertSystem:initialise()
        original_initialise(self)

        self.alertContentPanel:removeFromUIManager()
        self:removeChild(self.alertContentPanel)

        local panel = ISRichTextPanel:new(self.padding, self.padding * 3.5, self.width - self.padding * 2, self.height - self.padding * 5.3)
        panel:initialise()
        panel:instantiate()
        panel:setAnchorRight(true)
        panel:setAnchorBottom(false)
        panel.defaultFont = UIFont.NewSmall
        panel.autosetheight = false
        panel.clip = true
        panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
        panel.borderColor = { r = 1, g = 1, b = 1, a = 0.4 }
        panel.marginLeft = alertSystem.padding / 3
        panel.marginTop = alertSystem.padding / 3
        panel.marginBottom = alertSystem.padding / 3
        panel:addScrollBars()
        panel.marginRight = panel.vscroll and panel.vscroll:getWidth() or 0
        self.alertContentPanel = panel
        self:addChild(panel)

        self.alertsLoaded = {}
        self.latestAlerts = self.latestAlerts or {}
        self.alertSelected = 0
        self.alertsOld = 0

        self.latestAlerts[""] = nil
        for i = #self.alertsLoaded, 1, -1 do
            if self.alertsLoaded[i] == "" then
                table.remove(self.alertsLoaded, i)
                break
            end
        end

        alertSystem.alertsLoaded = nil
        alertSystem.alertsOld = nil
        alertSystem.alertsLayout = {}

        if getSteamModeActive() then
            if not ModListData.data.workshop then
                ModListData:load()
            end

            self:processUpdates()

            Events.OnWorkshopUpdate.Add(function()
                if MainScreen.instance and MainScreen.instance.alertSystem then
                    MainScreen.instance.alertSystem:processUpdates()
                end
            end)
        end
    end

    function alertSystem:prerender()
        ISPanelJoypad.prerender(self)

        local collapseWidth = not self.collapsed and self.width or self.collapse.width + 10
        self:drawRect(0, 0, collapseWidth, self.height, 0.8, 0, 0, 0)
        self:drawRectBorder(0, 0, collapseWidth, self.height, 0.8, 1, 1, 1)

        if not self.collapsed and self.alertSelected > 0 and self.alertsLoaded and #self.alertsLoaded > 0 then
            local alertModID = self.alertsLoaded[self.alertSelected]
            local alertModData = self.latestAlerts[alertModID]
            if not alertModData then return end

            local modName = alertModData.modName
            local isMd = alertModData.alerts and alertModData.alerts[1] and alertModData.alerts[1].isMd
            local isLegacy = alertModData.isLegacy
            local latestAlert = alertModData.alerts[(isMd and not isLegacy) and 1 or #alertModData.alerts]
            local alertTitle = latestAlert.title ~= "" and latestAlert.title
            local alertContents = (isMd and not isLegacy) and Changelog.markdownToPlaintext(latestAlert.contents or "") or latestAlert.contents
            local alertIcon = alertModData.icon
            local header = modName

            local subHeader = ""
            if alertModData.ts then
                subHeader = " (" .. formatDate(alertModData.ts) .. ")"
            elseif alertModID ~= "" then
                subHeader = " (" .. alertModID .. ")"
            end

            local modAuthor = alertModData.modAuthor
            local layout = self:determineLayout(alertModID, header, subHeader, alertTitle, alertContents, alertIcon)

            local titleY = drawAlertChrome(self, layout, subHeader, alertTitle, modAuthor)

            self.alertContentPanel:setY((titleY + layout.titleH + (alertSystem.padding / 7)))
            local panelH = self.height - (alertSystem.padding * 1.8) - self.alertContentPanel:getY()
            self.alertContentPanel:setHeight(panelH)
            if self.alertContentPanel.vscroll then
                self.alertContentPanel.vscroll:setHeight(panelH)
            end

            if self.lastAlertModID ~= alertModID then
                self.lastAlertModID = alertModID
                self.alertContentPanel:setScrollHeight(0)
                self.alertContentPanel:setYScroll(0)
                self.alertContentPanel:setText(" <TEXT> <RGB:0.8,0.8,0.8> " .. alertContents)
                self.alertContentPanel:paginate()
            end
        elseif not self.collapsed then
            local bottomPad = alertSystem.padding * 1.8
            local expandedY = bottomPad
            local expandedH = self.height - bottomPad * 2
            self.alertContentPanel:setY(expandedY)
            self.alertContentPanel:setHeight(expandedH)

            local noUpdatesText = getText("UI_alertSystem_noUpdates")
            local font = UIFont.NewSmall
            local textW = getTextManager():MeasureStringX(font, noUpdatesText)
            local textH = getTextManager():MeasureStringY(font, noUpdatesText)
            local panelX = self.alertContentPanel:getX()
            local panelW = self.alertContentPanel:getWidth()
            local textX = panelX + (panelW - textW) / 2
            local textY = expandedY + (expandedH - textH) / 2
            self:drawText(noUpdatesText, textX, textY, 1, 1, 1, 0.5, font)

            if self.lastAlertModID ~= nil then
                self.lastAlertModID = nil
                self.alertContentPanel:setScrollHeight(0)
                self.alertContentPanel:setYScroll(0)
                self.alertContentPanel:setText("")
            end
        end
    end

    function alertSystem:render()
        alertSystem.alertsLoaded = self.alertsLoaded or {}
        alertSystem.alertsOld = self.alertsOld or 0

        ISPanelJoypad.render(self)

        if not self.collapsed then
            if alertSystem.spiffoTexture then
                local textureYOffset = self.height - (alertSystem.spiffoTexture:getHeight())
                self:drawTexture(alertSystem.spiffoTexture, self.width - (alertSystem.padding * 1.7), textureYOffset, 1, 1, 1, 1)
            end

            if #alertSystem.alertsLoaded > 0 then
                local label = tostring(self.alertSelected) .. "/" .. tostring(#alertSystem.alertsLoaded)
                self:drawText(label, 40, 7, 1, 1, 1, 0.7, UIFont.AutoNormSmall)

                self:drawTexture(alertSystem.alertLeft, self.alertLeftX, 0, 0.7, 1, 1, 1)
                self:drawTexture(alertSystem.alertRight, self.alertRightX, 0, 0.7, 1, 1, 1)

                local alertBarX = self.alertLeftX + 32
                local rectWidth = self.alertBarSpan - 32
                self:drawRectBorder(alertBarX, 10, rectWidth, 12, 0.7, 1, 1, 1)

                local selectedAlertWidth = math.max(2, rectWidth / #alertSystem.alertsLoaded)
                self:drawRect(alertBarX + (selectedAlertWidth * (self.alertSelected - 1)), 10, selectedAlertWidth, 12, 0.8, 1, 1, 1)
            end
        end

        if #alertSystem.alertsLoaded > 0 then
            local alertImage = (#alertSystem.alertsLoaded - alertSystem.alertsOld) > 0 and alertSystem.alertTextureFull or alertSystem.alertTextureEmpty
            self:drawTexture(alertImage, 0, 0, 1, 1, 1, 1)
        end
    end

    local original_display = alertSystem.display
    function alertSystem.display(visible)
        original_display(visible)

        local instance = MainScreen.instance and MainScreen.instance.alertSystem
        if instance and not instance.collapsed then
            instance:markCurrentAlertAsSeen()
        end
    end
end