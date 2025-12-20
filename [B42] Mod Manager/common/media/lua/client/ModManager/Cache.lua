local ModManagerCache = {
    data = {}, isQuerying = false
}

local function trim(s)
    if not s then return "" end
    return s:match'^%s*(.-)%s*$'
end

function ModManagerCache:load()
    self.data = {
        version = 1,
        mods = {},
        hidden = {},
        alerts = {},
        workshop = {
            usage = {
                time = 0,
                requests = 0,
            },
            mods = {}
        }
    }

    local file = getFileReader("modManager.ini", true)
    if not file then return self.data end

    local line, path = file:readLine(), {}
    local currentAlertModId = nil

    while line ~= nil do
        line = trim(line)

        if line:match("^%s*%}%s*,?%s*$") then
            if path[#path] == currentAlertModId then
                currentAlertModId = nil
            end
            table.remove(path)
        else
            local sectionName = line:match("^%s*([%w_]+)%s*=%s*%{")
            if sectionName then
                table.insert(path, sectionName)
            else
                local modIdMatch = line:match('^%s*"([^"]+)":%s*%{')
                if modIdMatch then
                    table.insert(path, modIdMatch)
                    if path[1] == 'alerts' then
                        currentAlertModId = modIdMatch
                        self.data.alerts[currentAlertModId] = {}
                    end
                else
                    if #path > 0 then
                        local key, value = line:match('^%s*([%w_]+)%s*=%s*"?([^",]+)"?')
                        
                        if key and value then
                            if path[1] == 'workshop' and path[2] == 'usage' then
                                local targetTable = self.data.workshop.usage
                                local numValue = tonumber(value)
                                targetTable[key] = numValue or value
                            elseif path[1] == 'workshop' and path[2] == 'mods' and path[3] then
                                local modId = path[3]
                                if not self.data.workshop.mods[modId] then
                                    self.data.workshop.mods[modId] = {}
                                end
                                local targetTable = self.data.workshop.mods[modId]
                                local numValue = tonumber(value)
                                targetTable[key] = numValue or value
                            elseif path[1] == 'alerts' and currentAlertModId then
                                local targetTable = self.data.alerts[currentAlertModId]
                                if key == 'seen' then
                                    targetTable[key] = (value == "true")
                                else
                                    local numValue = tonumber(value)
                                    targetTable[key] = numValue or value
                                end
                            end
                        elseif path[1] == 'mods' then
                             local modId = line:match('^"([^"]+)"')
                             if modId then table.insert(self.data.mods, modId) end
                        elseif path[1] == 'hidden' then
                            local modId = line:match('^"([^"]+)"')
                            if modId then self.data.hidden[modId] = true end
                        end
                    end
                end
            end
        end
        line = file:readLine()
    end
    file:close()
    return self.data
end

function ModManagerCache:save()
    local file = getFileWriter("modManager.ini", true, false)
    if not file then return end

    file:write("version = " .. tostring(self.data.version or 1) .. ",\r\n")
    
    file:write("mods = {\r\n")
    for _, modID in ipairs(self.data.mods or {}) do
        file:write('    "' .. modID .. '",\r\n')
    end
    file:write("},\r\n")

    file:write("hidden = {\r\n")
    for modID, _ in pairs(self.data.hidden or {}) do
        file:write('    "' .. modID .. '",\r\n')
    end
    file:write("},\r\n")

    file:write("alerts = {\r\n")
    for modID, data in pairs(self.data.alerts or {}) do
        file:write('    "' .. modID .. '": {\r\n')
        file:write('        workshopID = ' .. string.format("%.0f", data.workshopID or 0) .. ',\r\n')
        file:write('        lastUpdate = ' .. string.format("%.0f", data.lastUpdate or 0) .. ',\r\n')
        file:write('        seen = ' .. tostring(data.seen or false) .. ',\r\n')
        file:write('    },\r\n')
    end
    file:write("},\r\n")

    file:write("workshop = {\r\n")
    file:write("    usage = {\r\n")
    local usage = self.data.workshop and self.data.workshop.usage or { time = 0, requests = 0 }
    file:write("        time = " .. string.format("%.0f", usage.time or 0) .. ",\r\n")
    file:write("        requests = " .. string.format("%.0f", usage.requests or 0) .. ",\r\n")
    file:write("    },\r\n")

    file:write("    mods = {\r\n")
    local wsMods = self.data.workshop and self.data.workshop.mods or {}
    for modID, data in pairs(wsMods) do
        file:write('        "' .. modID .. '": {\r\n')
        file:write('            workshopID = ' .. string.format("%.0f", data.workshopID or 0) .. ',\r\n')
        file:write('            lastUpdate = ' .. string.format("%.0f", data.lastUpdate or 0) .. ',\r\n')
        file:write('            state = "' .. tostring(data.state or "") .. '",\r\n')
        file:write('        },\r\n')
    end
    file:write("    }\r\n")
    file:write("}\r\n")

    file:close()
end

function ModManagerCache:getWorkshopData()
    return self.data and self.data.workshop
end

function ModManagerCache:getAlertsData()
    return self.data and self.data.alerts
end

function ModManagerCache:getModWorkshopInfo(modID)
    if self.data and self.data.workshop and self.data.workshop.mods and self.data.workshop.mods[modID] then
        return self.data.workshop.mods[modID]
    end
    return nil
end

function ModManagerCache:updateWorkshopData(steamInfo, modMap)
    if not self.data.workshop then
        self.data.workshop = { usage = { time = 0, requests = 0 }, mods = {} }
    end
    if not self.data.workshop.mods then
        self.data.workshop.mods = {}
    end

    for i = 0, steamInfo:size() - 1 do
        local details = steamInfo:get(i)
        local wid = details:getIDString()
        local mods = modMap and modMap[wid]

        if mods then
            for _, modInfo in ipairs(mods) do
                local modID = modInfo:getId()
                self.data.workshop.mods[modID] = {
                    workshopID = tonumber(wid),
                    lastUpdate = details:getTimeUpdated(),
                    state = details:getState(),
                }
            end
        end
    end
end

function ModManagerCache:updateUsageStats(numRequests)
    if not self.data.workshop then self:load() end
    if not self.data.workshop.usage then
        self.data.workshop.usage = { time = 0, requests = 0 }
    end
    
    local now = os.time()
    if now - (self.data.workshop.usage.time or 0) > 3600 then
        self.data.workshop.usage.requests = 0
    end
    
    self.data.workshop.usage.time = now
    self.data.workshop.usage.requests = (self.data.workshop.usage.requests or 0) + numRequests
end

return ModManagerCache