require "OptionScreens/ModSelector/ModSelectorModel"

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
    return self.hidden[id] == true
end

function ModSelector.Model:setHidden(id, isHidden)
    self.hidden[id] = isHidden and true or nil
    self:saveModManagerFile()
    self:refreshMods()
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
                data.category = modInfo:getCategory()
                data.defaultActive = self:isModActive(modId)
                data.defaultFav = self.favs[modId]
                data.indexAdded = self:indexByDateAdded(modId)
                data.timeUpdated = 0
                if data.icon == "" then data.icon = ModSelector.Model.categories[data.category] end

                data.lowerName = string.lower(data.name)
                data.lowerId = string.lower(data.modId)
                local author = modInfo:getAuthor() or ""
                data.lowerAuthor = string.lower(author)
                
                local workshopID = modInfo:getWorkshopID()
                if not workshopID or workshopID == "" then
                    local path = modInfo:getDir(); if path then
                        workshopID = path:match("content[\\/]108600[\\/](%d+)")
                    end
                end
                data.workshopIDStr = workshopID and tostring(workshopID) or ""

                self.mods[modId] = data
                table.insert(self.sortedMods, data)
            end
        end
    end

    self.ModsEnabled = getCore():getOptionModsEnabled()
    
    self:buildDependencyGraph()

    self:refreshMods()
    
    -- Запускаем проверку обновлений сразу после загрузки списка модов
    self:queryWorkshopItemDetails()
end

function ModSelector.Model:buildDependencyGraph()
    local function addIncompatibles(id, data)
        self.incompatibles[id] = self.incompatibles[id] or {}
        if data == nil then return end
        for i = 0, data:size()-1 do
            local id2 = data:get(i)
            self.incompatibles[id][id2] = true
            
            self.incompatibles[id2] = self.incompatibles[id2] or {}
            self.incompatibles[id2][id] = true
        end
    end

    local function addRequire(id, data)
        self.requirements[id] = self.requirements[id] or { dependsOn = {}, neededFor = {} }
        if data == nil then return end
        for i = 0, data:size()-1 do
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
            if string.find(modData.lowerName, searchWord, 1, true) then
                isMatch = true
            elseif string.find(modData.lowerId, searchWord, 1, true) then
                isMatch = true
            elseif string.find(modData.workshopIDStr, searchWord, 1, true) then
                isMatch = true
            elseif string.find(modData.lowerAuthor, searchWord, 1, true) then
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

function ModSelector.Model:saveModManagerFile()
    local FILE_MODS = "modManager.ini"
    local VERSION_MODS = 1

    local file = getFileWriter(FILE_MODS, true, false)
    file:write("version = " .. tostring(VERSION_MODS) .. ",\r\n")
    file:write("mods = {\r\n")

    for i, modID in ipairs(self.modsByDateAdded) do
        file:write('    "' .. modID .. '",\r\n')
    end

    file:write("},\r\n")

    file:write("hidden = {\r\n")
    for modID, _ in pairs(self.hidden) do
        file:write('    "' .. modID .. '",\r\n')
    end
    file:write("},\r\n")

    file:close()
end

function ModSelector.Model:trackMods()
    local FILE_MODS = "modManager.ini"
    local VERSION_MODS = 1

    local version = 0
    local storedMods = {}
    self.hidden = {}

    local file = getFileReader(FILE_MODS, true)
    if file then
        local line = file:readLine()
        local inModsSection = false
        local inHiddenSection = false

        while line ~= nil do
            line = string.gsub(line, "^%s*(.-)%s*$", "%1")

            if luautils.stringStarts(line, "version") then
                local versionStr = string.match(line, "version%s*=%s*(%d+)")
                if versionStr then
                    -- version = tonumber(versionStr)
                end
            elseif line == "mods = {" then
                inModsSection = true
                inHiddenSection = false
            elseif line == "hidden = {" then
                inHiddenSection = true
                inModsSection = false
            elseif (inModsSection or inHiddenSection) and (line == "}" or line == "},") then
                inModsSection = false
                inHiddenSection = false
            elseif (inModsSection or inHiddenSection) and line ~= "" then
                local modID = string.gsub(line, '[",]', '')
                modID = string.gsub(modID, "^%s*(.-)%s*$", "%1")
                if modID ~= "" then
                    if inModsSection then
                        table.insert(storedMods, modID)
                    elseif inHiddenSection then
                        self.hidden[modID] = true
                    end
                end
            end
            line = file:readLine()
        end
        file:close()
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

    local oldMods, newMods = {}, {}
    for _, modID in ipairs(storedMods or {}) do
        oldMods[modID] = true
    end
    for _, modID in ipairs(loadedMods) do
        newMods[modID] = true
    end

    local addMods, delMods = {}, {}
    for modID, _ in pairs(oldMods) do
        if not newMods[modID] then
            delMods[modID] = true
        end
    end
    for modID, _ in pairs(newMods) do
        if not oldMods[modID] then
            table.insert(addMods, modID)
        end
    end

    for modID, _ in pairs(delMods) do
        if self.hidden[modID] then
            self.hidden[modID] = nil
        end
    end

    local newList = {}
    for _, modID in ipairs(storedMods) do
        if not delMods[modID] then
            table.insert(newList, modID)
        end
    end
    for _, modID in ipairs(addMods) do
        table.insert(newList, modID)
    end

    self.modsByDateAdded = newList

    self:saveModManagerFile()
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
                if val ~= "" then self.favs[val] = true end
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
                    local data = luautils.split(val, "\\")
                    self.presets[presetName][val] = data[1]
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
        for id, wID in pairs(data) do
            table.insert(modsStrTable, id)
            table.insert(modsStrTable, ";")
        end
        file:write(name .. ":" .. table.concat(modsStrTable) .. "\n")
    end
    file:close()
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
        if modInfo:isAvailable() and not self.mods[modId].isIncompatible then
            self:setModActive(modId, true)
            self.mods[modId].isActive = true

            if self:isModActive(modId) and modInfo:getRequire() then
                local requiredMods = modInfo:getRequire()
                for i = 0, requiredMods:size()-1 do
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
                    table.insert(dependentData, {name=depInfo:getName(), id=depInfo:getWorkshopID(), modId=depInfo:getId()})
                end
                local w,h = 600, 400
                local dialog = ModSelector.DisableConfirmWindow:new(getCore():getScreenWidth()/2 - w/2, getCore():getScreenHeight()/2 - h/2, w, h, dependentData, self, modInfo)
                dialog:initialise()
                dialog:addToUIManager()
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

function ModSelector.Model:queryWorkshopItemDetails()
    local workshopIDs = getSteamWorkshopItemIDs()

    if not workshopIDs or workshopIDs:isEmpty() then
        return
    end

    querySteamWorkshopItemDetails(workshopIDs, self.onItemQueryFinished, self)
end

function ModSelector.Model:onItemQueryFinished(status, info)
    if status == "Completed" then
        local detailsMap = {}
        for i = 1, info:size() do
            local details = info:get(i - 1)
            detailsMap[details:getIDString()] = details
        end

        if self.mods then
            for modId, modData in pairs(self.mods) do
                if modData.workshopIDStr and modData.workshopIDStr ~= "" then
                    local details = detailsMap[modData.workshopIDStr]
                    if details then
                        modData.timeUpdated = details:getTimeUpdated() or 0
                    end
                end
            end
        end
        
        if self.currentSort == 'date_updated' then
            self:refreshMods()
        end
    end
end

local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

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
    local y = 10
    for _, v in ipairs(self.data) do
        local button = ISButton:new(25, y, 550, FONT_HGT_MEDIUM + 6, v.name, self, DisableConfirmPanel.onOptionMouseDown)
        button.modData = v
        button:initialise()
        button:instantiate()
        button:setFont(UIFont.Medium)
        self:addChild(button)
        y = y + FONT_HGT_MEDIUM + 6 + 5
    end
    self:setScrollHeight(y)
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
    self:drawTextCentre(getText("UI_modselector_disableWarningTitle"), self.width / 2, 5, 1, 1, 1, 1, UIFont.Title)
    self:drawTextCentre(getText("UI_modselector_disableWarningText"), self.width / 2, 35, 0.8, 0.8, 0.8, 1, UIFont.Small)
end

function DisableConfirmWindow:createChildren()
    local panel = DisableConfirmPanel:new(0, 60, self.width, self.height - 110, self.data)
    panel:initialise()
    panel:instantiate()
    panel:setAnchorRight(true)
    panel:setAnchorBottom(true)
    panel:addScrollBars()
    panel:setScrollChildren(true)
    panel.vscroll.doSetStencil = false
    self:addChild(panel)

    local btnDisable = ISButton:new(self.width/2 - 150 - 5, self.height - 40, 150, 30, getText("UI_btn_accept"), self, DisableConfirmWindow.onOptionMouseDown)
    btnDisable.internal = "DISABLE"
    btnDisable:initialise()
    btnDisable:instantiate()
    self:addChild(btnDisable)

    local btnCancel = ISButton:new(self.width/2 + 5, self.height - 40, 150, 30, getText("UI_btn_cancel"), self, DisableConfirmWindow.onOptionMouseDown)
    btnCancel.internal = "CANCEL"
    btnCancel:initialise()
    btnCancel:instantiate()
    self:addChild(btnCancel)
end

function DisableConfirmWindow:onOptionMouseDown(button)
    self:setVisible(false)
    self:removeFromUIManager()
    if button.internal == "DISABLE" then
        self.model:onConfirmDisable(self.modToDisable)
    end
end

function DisableConfirmWindow:closeAndSelect(modId)
    self:setVisible(false)
    self:removeFromUIManager()

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