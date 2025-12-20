local alertSystem = require "chuckleberryFinnModdingAlertSystem"
local changelog_handler = require "chuckleberryFinnModding_modChangelog"

if alertSystem and changelog_handler then
    local original_initialise = alertSystem.initialise

    local function formatDate(seconds)
        if not seconds or seconds == 0 then return "" end

        local timeFormat
        
        local d, now = os.date("*t", seconds), os.date("*t")
        local midnight = os.time({year=now.year, month=now.month, day=now.day, hour=0, min=0, sec=0})
        local isToday, isYesterday = (seconds >= midnight), (seconds >= midnight - 86400 and seconds < midnight)
        
        if isToday then
            timeFormat = getText("UI_modinfopanel_TimeFormat_Today")
        elseif isYesterday then
            timeFormat = getText("UI_modinfopanel_TimeFormat_Yesterday")
        elseif d.year == now.year then
            timeFormat = getText("UI_modinfopanel_TimeFormat_ThisYear")
        else
            timeFormat = getText("UI_modinfopanel_TimeFormat_OtherYears")
        end

        local month = getText("UI_modinfopanel_Month_Short_" .. d.month)

        local h12 = d.hour
        local ampm = ""
        if h12 >= 12 then
            ampm = getText("UI_modinfopanel_PM")
            if h12 > 12 then h12 = h12 - 12 end
        else
            ampm = getText("UI_modinfopanel_AM")
            if h12 == 0 then h12 = 12 end
        end

        local res = timeFormat
        res = res:gsub("{day}", d.day)
        res = res:gsub("{month}", month)
        res = res:gsub("{year}", d.year)
        res = res:gsub("{hour24}", string.format("%02d", d.hour))
        res = res:gsub("{hour12}", h12)
        res = res:gsub("{min}", string.format("%02d", d.min))
        res = res:gsub("{ampm}", ampm)

        return res
    end

    function alertSystem:onSteamQueryCompleted(status, info)
        if status == "Completed" then
            local twoWeeksAgo = os.time() - 14 * 24 * 60 * 60

            local sortedItems = {}

            for i = 0, info:size() - 1 do
                local details = info:get(i)
                local ts = details:getTimeUpdated()

                if ts >= twoWeeksAgo then
                    table.insert(sortedItems, { details = details, ts = ts })
                end
            end

            table.sort(sortedItems, function(a, b) return a.ts > b.ts end)

            self.alertsLoaded = {}
            self.latestAlerts = {}
            self.alertsLayout = {}

            for _, data in ipairs(sortedItems) do
                local wid = data.details:getIDString()
                local mods = self.modMap and self.modMap[wid]

                if mods then
                    for _, modInfo in ipairs(mods) do
                        local modID = modInfo:getId()
                        local alerts = changelog_handler.fetchMod(modID)

                        if alerts and #alerts > 0 then
                            local modName = modInfo:getName()
                            local modIconPath = modInfo:getIcon()
                            local modIcon = nil
                            if modIconPath and modIconPath ~= "" then
                                modIcon = getTexture(modIconPath)
                            end
                            local modAuthor = modInfo:getAuthor()

                            self.latestAlerts[modID] = {
                                modName = modName,
                                alerts = alerts,
                                icon = modIcon,
                                modAuthor = modAuthor,
                                alreadyStored = false,
                                ts = data.ts
                            }
                            table.insert(self.alertsLoaded, modID)
                        end
                    end
                end
            end

            if #self.alertsLoaded > 0 then
                self.alertSelected = 1
                self:updateButtons()
            end
        end
    end

    function alertSystem:initialise()
        original_initialise(self)

        self.latestAlerts = {}
        self.alertsLoaded = {}
        self.alertSelected = 0
        self.alertsOld = 0
        self.alertsLayout = {}

        if getSteamModeActive() then
            self.modMap = {}
            local workshopIDs = java.util.ArrayList.new()
            local addedIDs = {}

            local directories = getModDirectoryTable()
            for _, directory in ipairs(directories) do
                local modInfo = getModInfo(directory)
                if modInfo then
                    local workshopID = modInfo:getWorkshopID()
                    
                    if not workshopID or workshopID == "" then
                        local path = modInfo:getDir()
                        if path then
                            workshopID = path:match("content[\\/]108600[\\/](%d+)")
                        end
                    end

                    if workshopID and workshopID ~= "" then
                        if not self.modMap[workshopID] then
                            self.modMap[workshopID] = {}
                        end
                        table.insert(self.modMap[workshopID], modInfo)

                        if not addedIDs[workshopID] then
                            workshopIDs:add(workshopID)
                            addedIDs[workshopID] = true
                        end
                    end
                end
            end

            if not workshopIDs:isEmpty() then
                querySteamWorkshopItemDetails(workshopIDs, self.onSteamQueryCompleted, self)
            end
        end
    end

    function alertSystem:prerender()
        ISPanelJoypad.prerender(self)

        local collapseWidth = not self.collapsed and self.width or self.collapse.width+10
        self:drawRect(0, 0, collapseWidth, self.height, 0.8, 0, 0, 0)
        self:drawRectBorder(0, 0, collapseWidth, self.height, 0.8, 1, 1, 1)

        if not self.collapsed and self.alertSelected > 0 then
            local alertModID = self.alertsLoaded[self.alertSelected]
            local alertModData = self.latestAlerts[alertModID]
            local modName = alertModData.modName
            local latestAlert = alertModData.alerts[#alertModData.alerts]
            local alertTitle = latestAlert.title ~= "" and latestAlert.title
            local alertContents = latestAlert.contents
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

            if layout.alertIcon then self:drawTextureScaled(layout.alertIcon, 4+(alertSystem.padding/3), layout.headerY, 32, 32, 1, 1, 1, 1) end

            local maxSubheaderX = math.min( ((alertSystem.padding*1.5)+layout.headerW), (self.width-layout.subHeaderW) )
            if subHeader then
                self:drawText(subHeader, maxSubheaderX, layout.headerY + (alertSystem.padding/5), 1, 1, 1, 0.7, UIFont.NewSmall)
            end

            self:drawText(layout.header, layout.headerX, layout.headerY, 1, 1, 1, 0.96, UIFont.NewMedium)

            local titleY = layout.headerY+layout.headerH+(alertSystem.padding/7)
            if alertTitle then
                self:drawText(alertTitle, layout.headerX, titleY, 1, 1, 1, 0.85, UIFont.NewSmall)
            end

            if modAuthor then
                local authorX = self.alertContentPanel:getX()+self.alertContentPanel:getWidth()-(alertSystem.padding/4)
                self:drawTextRight(modAuthor, authorX, titleY, 1, 1, 1, 0.85, UIFont.NewSmall)
            end

            self.alertContentPanel:setY((titleY+layout.titleH+(alertSystem.padding/7)))
            self.alertContentPanel:setHeight(self.alertContentPanel.originalH+(self.alertContentPanel.originalY-self.alertContentPanel:getY()))

            self.alertContentPanel:clampStencilRectToParent(0, 0, self.alertContentPanel:getWidth(), self.alertContentPanel:getHeight())
            self.alertContentPanel:setScrollHeight(layout.contentsH)
            self.alertContentPanel:drawText(layout.contents, self.padding/3, self.padding/3, 1, 1, 1, 0.8, UIFont.NewSmall)
            self.alertContentPanel:clearStencilRect()
        end
    end

    local original_display = alertSystem.display
    function alertSystem.display(visible)
        original_display(visible)
        
        local instance = MainScreen.instance and MainScreen.instance.alertSystem
        
        if instance and not instance.__forcedCollapseInit then
            instance.collapsed = true; if instance.collapse then
                 instance.collapse.tooltip = getText("IGUI_ChuckAlertTooltip_Open")
            end
            instance:collapseApply(); instance.__forcedCollapseInit = true
        end
    end
end