require "OptionScreens/ModSelector/ModSelectorModel"

local ModListData = require("ModManager/Utils/ModListData")

ModSelector.Model.CATEGORIES = {
    "Animals",
    "Animations",
    "Armor",
    "Audio",
    "Balance",
    "Building",
    "Crafting",
    "Clothing",
    "Climate",
    "Equipment",
    "Farming",
    "Food",
    "Framework",
    "Immersion",
    "Interface",
    "Items",
    "Lighting",
    "Localization",
    "Literature",
    "Map",
    "Misc",
    "Models",
    "Modpack",
    "Multiplayer",
    "Overhaul",
    "Performance",
    "QoL",
    "Quests",
    "Realistic",
    "Roleplay",
    "Scenario",
    "Silly/Fun",
    "Skills",
    "Textures",
    "Traits",
    "Utility",
    "Vehicles",
    "Voices",
    "Weapons",
    "Zombies",
}

local CATEGORY_LOOKUP = {}
for _, name in ipairs(ModSelector.Model.CATEGORIES) do
    CATEGORY_LOOKUP[string.lower(name)] = name;
end
CATEGORY_LOOKUP["vehicle"] = "Vehicles";
CATEGORY_LOOKUP["utilities"] = "Utility";

local SUPPORT_SERVICES = {
    { key = "tribute", name = "Tribute", urlPrefix = "https://web.tribute.tg/" },
    { key = "ko-fi", name = "Ko-fi", urlPrefix = "https://ko-fi.com/" },
    { key = "buy-me-a-coffee", name = "Buy Me a Coffee", urlPrefix = "https://buymeacoffee.com/" },
    { key = "donationalerts", name = "DonationAlerts", urlPrefix = "https://www.donationalerts.com/" },
    { key = "patreon", name = "Patreon", urlPrefix = "https://www.patreon.com/" },
    { key = "boosty", name = "Boosty", urlPrefix = "https://boosty.to/" }
}

local function getSupportLinks(modID)
    local reader = getModFileReader(modID, "mod.info", false)
    if not reader then return {} end

    local values = {}
    local line = reader:readLine()
    while line do
        local key, value = line:match("^%s*([%w%-]+)%s*=%s*(.-)%s*$")
        if key and value and value ~= "" then
            values[key] = value
        end
        line = reader:readLine()
    end
    reader:close()

    local links = {}
    for _, service in ipairs(SUPPORT_SERVICES) do
        local url = values[service.key]
        if url and string.sub(url, 1, #service.urlPrefix) == service.urlPrefix then
            table.insert(links, { name = service.name, url = "https://steamcommunity.com/linkfilter/?u=" .. url })
        end
    end

    return links
end

local original_new = ModSelector.Model.new
function ModSelector.Model:new(view)
    local o = original_new(self, view)
    o.currentSort = 'name'
    o.hidden = {}
    o.incompatibles = {}
    o.requirements = {}
    o:trackMods()
    return o
end

function ModSelector.Model:sortMods()
    local sortFunc
    if self.currentSort == 'name' then
        ---@diagnostic disable-next-line: undefined-field
        sortFunc = function(a, b) return not string.sort(a.name, b.name) end
    elseif self.currentSort == 'date_added' then
        sortFunc = function(a, b) return a.indexAdded > b.indexAdded end
    elseif self.currentSort == 'date_updated' then
        sortFunc = function(a, b)
            local tA = a.timeUpdated or 0
            local tB = b.timeUpdated or 0
            if tA ~= tB then
                return tA > tB
            end
            ---@diagnostic disable-next-line: undefined-field
            return not string.sort(a.name, b.name)
        end
    else
        ---@diagnostic disable-next-line: undefined-field
        sortFunc = function(a, b) return not string.sort(a.name, b.name) end
    end

    table.sort(self.sortedMods, function(a, b)
        if a.favorite and not b.favorite then return true end
        if not a.favorite and b.favorite then return false end
        return sortFunc(a, b)
    end)
end

function ModSelector.Model:setSort(sortType)
    self.currentSort = sortType
    self:refreshMods()
end

function ModSelector.Model:isHidden(id)
    local modData = ModListData.data.mods[id]
    return modData and modData.hidden == true
end

function ModSelector.Model:setHidden(id, isHidden)
    local mods = ModListData.data.mods
    if not mods[id] then mods[id] = {} end
    mods[id].hidden = isHidden
    ModListData:save()
    self:refreshMods()
end

function ModSelector.Model:getCategory(id)
    if self:isCategoryLocked(id) then
        return self.mods[id].category
    end
    local modData = ModListData.data.mods[id]
    return modData and modData.category or ""
end

function ModSelector.Model:setCategory(id, category)
    if self:isCategoryLocked(id) then
        return
    end
    local mods = ModListData.data.mods
    if not mods[id] then mods[id] = {} end
    mods[id].category = category
    ModListData:save()
    self:refreshMods()
end

function ModSelector.Model:isCategoryLocked(modId)
    local category = getModInfoByID(modId):getCategory()
    return (category ~= "" and CATEGORY_LOOKUP[string.lower(category)]) and self.mods[modId].category or false
end

function ModSelector.Model:isFavorite(id)
    return self.favs[id] == true
end

function ModSelector.Model:setFavorite(id, isFavorite)
    self.favs[id] = isFavorite and true or nil
    self:saveModDataToFile()
    self:refreshMods()
end

function ModSelector.Model:reloadMods()
    self:loadModDataFromFile()
    self:trackMods()

    local modListData = ModListData.data

    self.modsByDateAdded = {}
    if modListData.mods then
        local sorted = {}
        for modID, data in pairs(modListData.mods) do
            table.insert(sorted, { id = modID, index = data.index })
        end
        table.sort(sorted, function(a, b) return (a.index or 0) < (b.index or 0) end)
        for _, item in ipairs(sorted) do
            table.insert(self.modsByDateAdded, item.id)
        end
    end

    ---@diagnostic disable-next-line: undefined-field
    table.wipe(self.mods)
    ---@diagnostic disable-next-line: undefined-field
    table.wipe(self.sortedMods)

    self.incompatibles = {}
    self.requirements = {}

    for _, directory in ipairs(getModDirectoryTable()) do
        local modInfoFromDir = getModInfo(directory)
        if modInfoFromDir then
            local modId = modInfoFromDir:getId()
            local modInfo = getModInfoByID(modId)
            if modInfo and not self.mods[modId] then
                local data = {}
                data.modId = modId
                data.modInfo = modInfo
                data.name = modInfo:getName()
                data.icon = modInfo:getIcon()
                data.author = modInfo:getAuthor() or ""
                local rawCategory = modInfo:getCategory()
                if rawCategory ~= "" then
                    local primary = rawCategory:match("^%s*([^,]-)%s*[,]") or rawCategory:match("^%s*(.-)%s*$")
                    data.category = CATEGORY_LOOKUP[string.lower(primary)] or ""
                else
                    data.category = ""
                end
                data.defaultActive = self:isModActive(modId)
                data.defaultFav = self.favs[modId]
                data.indexAdded = self:indexByDateAdded(modId)
                data.supportLinks = getSupportLinks(modId)
                data.hasSupportLinks = #data.supportLinks > 0

                local workshopID = modInfoFromDir:getWorkshopID()
                data.workshopIDStr = (workshopID and workshopID ~= "") and tostring(workshopID) or ""

                local cachedData = ModListData:getModWorkshopInfo(modId)
                if data.workshopIDStr == "" and cachedData and cachedData.workshopID then
                    data.workshopIDStr = tostring(cachedData.workshopID)
                end

                data.timeUpdated = (cachedData and cachedData.lastUpdate) or 0
                data.workshopState = (cachedData and cachedData.state) or ""

                data.source = modInfo:getSource()

                self.mods[modId] = data
                table.insert(self.sortedMods, data)
            end
        end
    end

    self.ModsEnabled = getCore():getOptionModsEnabled()

    self:buildDependencyGraph()

    self:refreshMods()
end

function ModSelector.Model:buildDependencyGraph()
    local function addIncompatibles(id, data)
        self.incompatibles[id] = self.incompatibles[id] or {}
        if data == nil then return end
        for i = 0, data:size() - 1 do
            local id2 = data:get(i)
            self.incompatibles[id][id2] = true

            self.incompatibles[id2] = self.incompatibles[id2] or {}
            self.incompatibles[id2][id] = true
        end
    end

    local function addRequire(id, data)
        self.requirements[id] = self.requirements[id] or { dependsOn = {}, neededFor = {} }
        if data == nil then return end
        for i = 0, data:size() - 1 do
            local id2 = data:get(i)
            self.requirements[id2] = self.requirements[id2] or { dependsOn = {}, neededFor = {} }

            self.requirements[id].dependsOn[id2] = true
            self.requirements[id2].neededFor[id] = true
        end
    end

    for modId, modData in pairs(self.mods) do
        self.incompatibles[modId] = self.incompatibles[modId] or {}
        self.requirements[modId] = self.requirements[modId] or { dependsOn = {}, neededFor = {} }

        addIncompatibles(modId, modData.modInfo:getIncompatible())
        addRequire(modId, modData.modInfo:getRequire())
    end
end

function ModSelector.Model:refreshMods()
    for modId, modData in pairs(self.mods) do
        modData.isAvailable = modData.modInfo:isAvailable()
        modData.isActive = self:isModActive(modId)
        modData.favorite = self:isFavorite(modId)
        modData.isHidden = self:isHidden(modId)
        modData.category = self:getCategory(modId)
    end

    for modId, modData in pairs(self.mods) do
        modData.incompatibleWith = self.incompatibles[modId]
        modData.isIncompatible = false

        if self.incompatibles[modId] then
            for id, _ in pairs(self.incompatibles[modId]) do
                if self.mods[id] and self.mods[id].isActive then
                    modData.isIncompatible = true
                    break
                end
            end
        end

        modData.requireMods = self.requirements[modId].dependsOn
    end

    self:sortMods()

    self.view:updateView()
end

function ModSelector.Model:filterMods(category, searchWord, favoriteMode, onlyEnabled, onlyDisabled, showHidden)
    ---@diagnostic disable-next-line: undefined-field
    table.wipe(self.currentMods)

    for _, modData in ipairs(self.sortedMods) do
        local show = true
        if category ~= "" and modData.category ~= category then
            show = false
        end

        if not showHidden and modData.isHidden and searchWord == "" then
            show = false
        end

        if searchWord ~= "" then
            local isMatch = false
            if string.find(string.lower(modData.name), searchWord, 1, true) then
                isMatch = true
            elseif string.find(string.lower(modData.modId), searchWord, 1, true) then
                isMatch = true
            elseif string.find(modData.workshopIDStr, searchWord, 1, true) then
                isMatch = true
            elseif string.find(string.lower(modData.author), searchWord, 1, true) then
                isMatch = true
            end

            if not isMatch then
                show = false
            end
        end

        if favoriteMode and not modData.favorite then
            show = false
        end

        if onlyEnabled and not onlyDisabled then
            if not modData.isActive then
                show = false
            end
        elseif not onlyEnabled and onlyDisabled then
            if modData.isActive then
                show = false
            end
        end

        if show then
            table.insert(self.currentMods, modData)
        end
    end
end

function ModSelector.Model:indexByDateAdded(modID)
    for index, v in ipairs(self.modsByDateAdded) do
        if v == modID then
            return index
        end
    end
    return -1
end

function ModSelector.Model:trackMods()
    local modListData = ModListData:load()

    local storedModsList = {}
    if modListData.mods then
        local sorted = {}
        for modID, data in pairs(modListData.mods) do
            table.insert(sorted, { id = modID, index = data.index, hidden = data.hidden, category = data.category })
        end
        table.sort(sorted, function(a, b) return (a.index or 0) < (b.index or 0) end)
        for _, item in ipairs(sorted) do
            table.insert(storedModsList, { id = item.id, hidden = item.hidden, category = item.category })
        end
    end

    local loadedMods = {}
    local directories = getModDirectoryTable()
    for _, directory in ipairs(directories) do
        local modInfo = getModInfo(directory)
        if modInfo then
            local modID = modInfo:getId()
            table.insert(loadedMods, modID)
        end
    end

    local oldModsSet, newModsSet = {}, {}
    for _, mod in ipairs(storedModsList) do
        oldModsSet[mod.id] = true
    end
    for _, modID in ipairs(loadedMods) do
        newModsSet[modID] = true
    end

    local addMods, delModsSet = {}, {}
    for modID, _ in pairs(oldModsSet) do
        if not newModsSet[modID] then
            delModsSet[modID] = true
        end
    end
    for modID, _ in pairs(newModsSet) do
        if not oldModsSet[modID] then
            table.insert(addMods, modID)
        end
    end

    local newCacheMods = {}
    local currentIndex = 1

    for _, mod in ipairs(storedModsList) do
        if not delModsSet[mod.id] then
            newCacheMods[mod.id] = { hidden = mod.hidden, category = mod.category, index = currentIndex }
            currentIndex = currentIndex + 1
        end
    end
    for _, modID in ipairs(addMods) do
        newCacheMods[modID] = { hidden = false, index = currentIndex }
        currentIndex = currentIndex + 1
    end

    ModListData.data.mods = newCacheMods
    ModListData:save()

    self.modsByDateAdded = {}
    local sorted = {}
    for modID, data in pairs(newCacheMods) do
        table.insert(sorted, { id = modID, index = data.index })
    end
    table.sort(sorted, function(a, b) return (a.index or 0) < (b.index or 0) end)
    for _, item in ipairs(sorted) do
        table.insert(self.modsByDateAdded, item.id)
    end
end

function ModSelector.Model:loadModDataFromFile()
    ---@diagnostic disable-next-line: undefined-field
    table.wipe(self.presets)
    ---@diagnostic disable-next-line: undefined-field
    table.wipe(self.favs)

    local file = getFileReader("pz_modlist_settings.cfg", true)
    local line = file:readLine()
    local count = 0
    while line ~= nil do
        if luautils.stringStarts(line, "!fav!") and count == 0 then
            local sepIndex = string.find(line, ":")
            local modsString = ""
            if sepIndex ~= nil then
                modsString = string.sub(line, sepIndex + 1)
            end
            for i, val in ipairs(luautils.split(modsString, ";")) do
                local modId = val:match("^\\?(.+)") or val
                if modId ~= "" then self.favs[modId] = true end
            end
        else
            local sepIndex = string.find(line, ":")
            local presetName = ""
            local modsString = ""
            if sepIndex ~= nil then
                presetName = string.sub(line, 0, sepIndex - 1)
                modsString = string.sub(line, sepIndex + 1)
            end
            if presetName ~= "" then
                self.presets[presetName] = {}
                for i, val in ipairs(luautils.split(modsString, ";")) do
                    local modId = val:match("^\\?(.+)") or val
                    if modId ~= "" then
                        table.insert(self.presets[presetName], modId)
                    end
                end
            end
        end
        count = count + 1
        line = file:readLine()
    end
    file:close()
end

function ModSelector.Model:saveModDataToFile()
    local file = getFileWriter("pz_modlist_settings.cfg", true, false)
    local modsStrTable = {}
    for modId, modData in pairs(self.mods) do
        if modData.favorite then
            table.insert(modsStrTable, modId)
            table.insert(modsStrTable, ";")
        end
    end
    file:write("!fav!:" .. table.concat(modsStrTable) .. "\n")
    for name, data in pairs(self.presets) do
        modsStrTable = {}
        for _, id in ipairs(data) do
            table.insert(modsStrTable, id)
            table.insert(modsStrTable, ";")
        end
        file:write(name .. ":" .. table.concat(modsStrTable) .. "\n")
    end
    file:close()
end

function ModSelector.Model:getPresetShareText(name)
    local data = self.presets[name]
    local modsStrTable = {}
    for _, id in ipairs(data) do
        table.insert(modsStrTable, id)
        table.insert(modsStrTable, ";")
    end
    return name .. ":" .. table.concat(modsStrTable) .. "\n"
end

function ModSelector.Model:addSharedPreset(button)
    if button.internal == "OK" then
        local line = button.parent.entry:getText()
        local sepIndex = string.find(line, ":")
        local presetName = ""
        local modsString = ""
        if sepIndex ~= nil then
            presetName = string.sub(line, 0, sepIndex - 1)
            modsString = string.sub(line, sepIndex + 1)
        end
        if presetName ~= "" then
            self.presets[presetName] = {}
            for i, val in ipairs(luautils.split(modsString, ";")) do
                table.insert(self.presets[presetName], val)
            end
            self:saveModDataToFile()
        end
    end
end

function ModSelector.Model:getDependentModsToDisable(modInfo, dependents, visited)
    dependents = dependents or {}
    visited = visited or {}
    local modId = modInfo:getId()
    if visited[modId] then return dependents end
    visited[modId] = true

    if self.requirements[modId] and self.requirements[modId].neededFor then
        for dependentId, _ in pairs(self.requirements[modId].neededFor) do
            if self.mods[dependentId] and self:isModActive(dependentId) then
                table.insert(dependents, self.mods[dependentId].modInfo)
                self:getDependentModsToDisable(self.mods[dependentId].modInfo, dependents, visited)
            end
        end
    end
    return dependents
end

function ModSelector.Model:onConfirmDisable(modInfo)
    self:forceActivateMods(modInfo, false, true)
end

function ModSelector.Model:forceActivateMods(modInfo, activate, bypassConfirm, suppressRefresh)
    local modId = modInfo:getId()
    local isModActive = self:isModActive(modId)

    if isModActive == activate then return end

    if activate then
        if self:isHidden(modId) then
            self:setHidden(modId, false)
        end

        if modInfo:isAvailable() and not self.mods[modId].isIncompatible then
            self:setModActive(modId, true)
            self.mods[modId].isActive = true

            if self:isModActive(modId) and modInfo:getRequire() then
                local requiredMods = modInfo:getRequire()
                for i = 0, requiredMods:size() - 1 do
                    local reqId = requiredMods:get(i)
                    if self.mods[reqId] then
                        self:forceActivateMods(self.mods[reqId].modInfo, true, true, true)
                    end
                end
            end
        end
    else
        if not bypassConfirm then
            local dependents = self:getDependentModsToDisable(modInfo)
            if #dependents > 0 then
                local dependentData = {}
                for _, depInfo in ipairs(dependents) do
                    table.insert(dependentData, { name = depInfo:getName(), id = depInfo:getWorkshopID(), modId = depInfo:getId() })
                end
                local screenW = getCore():getScreenWidth()
                local screenH = getCore():getScreenHeight()
                local w = math.max(600, screenW * 0.35)
                local h = math.max(400, screenH * 0.4)
                local dialog = ModSelector.DisableConfirmWindow:new((screenW - w) / 2, (screenH - h) / 2, w, h, dependentData, self, modInfo)
                dialog:initialise()
                ModSelector.instance.disableConfirmWindow = dialog
                dialog:addToUIManager()
                dialog:setCapture(true)
                dialog:bringToTop()
                return
            end
        end

        self:setModActive(modId, false)
        self.mods[modId].isActive = false
        if not self:isModActive(modId) then
            for id, _ in pairs(self.requirements[modId].neededFor) do
                self:forceActivateMods(self.mods[id].modInfo, false, true, true)
            end
        end
    end

    if not suppressRefresh then
        self:refreshMods()
    end
end

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

ModSelector.DisableConfirmPanel = ISPanelJoypad:derive("DisableConfirmPanel")
local DisableConfirmPanel = ModSelector.DisableConfirmPanel

function DisableConfirmPanel:new(x, y, width, height, data)
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.data = data
    o.borderColor.a = 0
    return o
end

function DisableConfirmPanel:createChildren()
    local y = 0
    local buttonHeight = FONT_HGT_MEDIUM + 6
    local spacing = 5
    self.buttons = {}
    for _, v in ipairs(self.data) do
        local button = ISButton:new(25, y, self.width - 50, buttonHeight, v.name, self,
            DisableConfirmPanel.onOptionMouseDown)
        button.modData = v
        button:initialise()
        button:instantiate()
        button:setFont(UIFont.Medium)
        self:addChild(button)
        table.insert(self.buttons, button)
        y = y + buttonHeight + spacing
    end
    self:setScrollHeight(math.max(0, y - spacing))
end

function DisableConfirmPanel:onResize()
    if self.buttons then
        for _, button in ipairs(self.buttons) do
            button:setWidth(self.width - 50)
        end
    end
end

function DisableConfirmPanel:onMouseWheel(del)
    if self:getScrollHeight() > self:getHeight() then
        self:setYScroll(self:getYScroll() - (del * 20))
        return true
    end
    return false
end

function DisableConfirmPanel:onOptionMouseDown(button)
    local modId = button.modData and button.modData.modId
    if modId then
        self.parent:closeAndSelect(modId)
    end
end

function DisableConfirmPanel:prerender()
    ISPanelJoypad.prerender(self)
    self:setStencilRect(0, 0, self.width, self.height)
end

function DisableConfirmPanel:render()
    ISPanelJoypad.render(self)
    self:clearStencilRect()
    self:repaintStencilRect(0, 0, self.width, self.height)
end

ModSelector.DisableConfirmWindow = ISPanelJoypad:derive("DisableConfirmWindow")
local DisableConfirmWindow = ModSelector.DisableConfirmWindow

function DisableConfirmWindow:new(x, y, width, height, data, model, modToDisable)
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.data = data
    o.model = model
    o.modToDisable = modToDisable
    o.backgroundColor.a = 0.9
    return o
end

function DisableConfirmWindow:prerender()
    ISPanelJoypad.prerender(self)
    local titleY = 5
    local subtitleY = math.max(35, titleY + FONT_HGT_LARGE + 5)
    self:drawTextCentre(getText("UI_modselector_disableWarningTitle"), self.width / 2, titleY, 1, 1, 1, 1, UIFont.Large)
    self:drawTextCentre(getText("UI_modselector_disableWarningText"), self.width / 2, subtitleY, 0.8, 0.8, 0.8, 1, UIFont.Small)
end

function DisableConfirmWindow:createChildren()
    local titleY = 5
    local subtitleY = math.max(35, titleY + FONT_HGT_LARGE + 5)
    local panelTop = subtitleY + FONT_HGT_SMALL + 5
    self.panel = DisableConfirmPanel:new(10, panelTop, self.width - 20, self.height - panelTop - 50, self.data)
    self.panel:initialise()
    self.panel:instantiate()
    self.panel:setAnchorRight(true)
    self.panel:setAnchorBottom(true)
    self.panel:addScrollBars()
    self.panel:setScrollChildren(true)
    self.panel.vscroll.doSetStencil = false
    self:addChild(self.panel)

    self.btnDisable = ISButton:new(self.width / 2 - 150 - 5, self.height - 40, 150, 30, getText("UI_btn_accept"), self, DisableConfirmWindow.onOptionMouseDown)
    self.btnDisable.internal = "DISABLE"
    self.btnDisable:initialise()
    self.btnDisable:instantiate()
    self:addChild(self.btnDisable)

    self.btnCancel = ISButton:new(self.width / 2 + 5, self.height - 40, 150, 30, getText("UI_btn_cancel"), self, DisableConfirmWindow.onOptionMouseDown)
    self.btnCancel.internal = "CANCEL"
    self.btnCancel:initialise()
    self.btnCancel:instantiate()
    self:addChild(self.btnCancel)

    self.onResolutionChangeEvent = function(_, _, neww, newh)
        if self:isReallyVisible() then
            self:onResolutionChange(neww, newh)
        end
    end
    Events.OnResolutionChange.Add(self.onResolutionChangeEvent)
end

function DisableConfirmWindow:onResolutionChange(neww, newh)
    local width = math.max(600, neww * 0.35)
    local height = math.max(400, newh * 0.4)
    local titleY = 5
    local subtitleY = math.max(35, titleY + FONT_HGT_LARGE + 5)
    local panelTop = subtitleY + FONT_HGT_SMALL + 5

    self:setX((neww - width) / 2)
    self:setY((newh - height) / 2)
    self:setWidth(width)
    self:setHeight(height)

    self.panel:setX(10)
    self.panel:setY(panelTop)
    self.panel:setWidth(self.width - 20)
    self.panel:setHeight(self.height - panelTop - 50)
    self.panel:onResize()

    self.btnDisable:setX(self.width / 2 - 150 - 5)
    self.btnDisable:setY(self.height - 40)

    self.btnCancel:setX(self.width / 2 + 5)
    self.btnCancel:setY(self.height - 40)
end

function DisableConfirmWindow:onClose()
    if self.onResolutionChangeEvent then
        Events.OnResolutionChange.Remove(self.onResolutionChangeEvent)
        self.onResolutionChangeEvent = nil
    end
    self:setVisible(false)
    self:removeFromUIManager()
    if ModSelector.instance then
        ModSelector.instance.disableConfirmWindow = nil
    end
end

function DisableConfirmWindow:onOptionMouseDown(button)
    self:onClose()
    if button.internal == "DISABLE" then
        self.model:onConfirmDisable(self.modToDisable)
    end
end

function DisableConfirmWindow:closeAndSelect(modId)
    self:onClose()

    local modSelector = ModSelector.instance
    modSelector:setVisible(true)

    local modList = modSelector.modListPanel.modList
    local targetIndex = -1
    for i, item in ipairs(modList.items) do
        if item.item.modId == modId then
            targetIndex = i
            break
        end
    end

    if targetIndex ~= -1 then
        modList.selected = targetIndex
        modList:ensureVisible(targetIndex)
        if modList.onmousedown then
            modList.onmousedown(modList.target, modList.items[targetIndex].item)
        end
    end
end

function ModSelector.Model:acceptChanges()
    self:saveModDataToFile()

    local activeMods = self:getActiveMods()

    activeMods:checkMissingMods()
    activeMods:checkMissingMaps()

    if self.loadGameFolder then
        local saveFolder = self.loadGameFolder
        self.loadGameFolder = nil
        manipulateSavefile(saveFolder, "WriteModsDotTxt")

        local defaultMods = ActiveMods.getById("default")
        local currentMods = ActiveMods.getById("currentGame")
        currentMods:copyFrom(defaultMods)

        LoadGameScreen.instance:onSavefileModsChanged(saveFolder)
        LoadGameScreen.instance:setVisible(true, self.joyfocus)
        return
    end

    if self.isNewGame then
        NewGameScreen.instance:setVisible(true, self.joyfocus)
    elseif self.isServerSettingsMods then
        local result = {}
        local mods = activeMods:getMods()
        for i = 0, mods:size() - 1 do
            local id = mods:get(i)
            local info = self.mods[id].modInfo
            table.insert(result, { modID = id, modInfo = info })
        end
        self.serverSettingsFinishFunc(result)
        self.isServerSettingsMods = false
        return
    else
        saveModsFile()

        local defaultMods = ActiveMods.getById("default")
        local currentMods = ActiveMods.getById("currentGame")
        currentMods:copyFrom(defaultMods)

        MainScreen.instance.bottomPanel:setVisible(true)
    end

    local reset = self.ModsEnabled ~= getCore():getOptionModsEnabled()
    if ActiveMods.requiresResetLua(activeMods) then
        reset = true
    end
    if reset then
        local activeModList = activeMods:getMods()
        local currentIds = {}
        local currentCount = 0
        for i = 0, activeModList:size() - 1 do
            currentIds[activeModList:get(i)] = true
            currentCount = currentCount + 1
        end

        local isDuplicate = false

        for _, data in pairs(self.presets) do
            if #data == currentCount then
                local match = true
                for _, id in ipairs(data) do
                    if not currentIds[id] then
                        match = false
                        break
                    end
                end
                if match then
                    isDuplicate = true
                    break
                end
            end
        end

        local HISTORY_LIMIT = 30
        local historyLines = {}
        local file = getFileReader("ModManager/HistoryData.cfg", false)

        if file then
            local line = file:readLine()
            while line ~= nil do
                if not isDuplicate then
                    local sepIndex = string.find(line, ":")
                    if sepIndex then
                        local modsStr = string.sub(line, sepIndex + 1)
                        local historyIds = {}
                        local historyCount = 0
                        for modId in string.gmatch(modsStr, "([^;]+)") do
                            historyIds[modId] = true
                            historyCount = historyCount + 1
                        end

                        if historyCount == currentCount then
                            local match = true
                            for id, _ in pairs(currentIds) do
                                if not historyIds[id] then
                                    match = false
                                    break
                                end
                            end
                            if match then isDuplicate = true end
                        end
                    end
                end
                table.insert(historyLines, line)
                line = file:readLine()
            end
            file:close()
        end

        if not isDuplicate then
            table.sort(historyLines, function(a, b) return a > b end)

            while #historyLines >= HISTORY_LIMIT do
                table.remove(historyLines)
            end

            local sdf = SimpleDateFormat.new("yyyy-MM-dd_HH-mm-ss", Locale.ENGLISH)
            local dateStr = sdf:format(getTimestampMs())
            local modsStrTable = {}
            for i = 0, activeModList:size() - 1 do
                table.insert(modsStrTable, activeModList:get(i))
                table.insert(modsStrTable, ";")
            end
            local newLine = dateStr .. ":" .. table.concat(modsStrTable)

            table.insert(historyLines, 1, newLine)

            local writer = getFileWriter("ModManager/HistoryData.cfg", true, false)
            if writer then
                for _, str in ipairs(historyLines) do
                    writer:write(str .. "\r\n")
                end
                writer:close()
            end
        end

        if self.isNewGame then
            getCore():ResetLua("currentGame", "NewGameMods")
        else
            MainScreen.instance.bottomPanel:setVisible(false)
            getCore():ResetLua("default", "modsChanged")
        end
    end
end