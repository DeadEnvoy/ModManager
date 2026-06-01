if isServer() then return; end

local ModManagerData = {
    data = {},
    isQuerying = false
}

local defaultData = {
    version = 1,
    mods = {},
    alerts = {},
    workshop = {
        usage = {
            time = 0,
            requests = 0,
        },
        mods = {}
    }
}

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = deepCopy(v)
    end
    return copy
end

local function tryParseContent(content)
    ---@diagnostic disable-next-line: deprecated
    local func = loadstring(content)
    if not func then return nil end
    local env = {}
    ---@diagnostic disable-next-line: deprecated
    setfenv(func, env)
    local success, res = pcall(func)
    if success and type(res) == "table" then
        return res
    end
    return nil
end

local function readFileContent(filename)
    local reader = getFileReader(filename, false)
    if not reader then return nil end

    local content = ""
    local line = reader:readLine()
    while line do
        content = content .. line .. "\n"
        line = reader:readLine()
    end
    reader:close()

    return content ~= "" and content or nil
end

function ModManagerData:load()
    self.data = deepCopy(defaultData)

    local content = readFileContent("ModManager/ModListData.lua")
    if content then
        local res = tryParseContent(content)
        if res then
            self.data = res
            return self.data
        end
    end

    local tmpContent = readFileContent("ModManager/ModListData.tmp")
    if tmpContent then
        local tmpRes = tryParseContent(tmpContent)
        if tmpRes then
            self.data = tmpRes
        end
    end

    return self.data
end

local function quoteStr(s)
    return string.format("%q", tostring(s or ""))
end

function ModManagerData:save()
    local content = {}

    table.insert(content, "return {\r\n")
    table.insert(content, "    version = " .. tostring(self.data.version or 1) .. ",\r\n")

    table.insert(content, "    mods = {\r\n")
    local sortedMods = {}
    for k, v in pairs(self.data.mods or {}) do
        table.insert(sortedMods, { id = k, data = v })
    end
    table.sort(sortedMods, function(a, b) return (a.data.index or 0) < (b.data.index or 0) end)

    for _, item in ipairs(sortedMods) do
        table.insert(content, "        [" .. quoteStr(item.id) .. "] = {\r\n")
        table.insert(content, "            category = " .. quoteStr(item.data.category) .. ",\r\n")
        table.insert(content, "            hidden = " .. tostring(item.data.hidden) .. ",\r\n")
        table.insert(content, "            index = " .. tostring(item.data.index) .. ",\r\n")
        table.insert(content, "        },\r\n")
    end
    table.insert(content, "    },\r\n")

    table.insert(content, "    alerts = {\r\n")
    local alertKeys = {}
    for k in pairs(self.data.alerts or {}) do table.insert(alertKeys, k) end
    table.sort(alertKeys)
    for _, modID in ipairs(alertKeys) do
        local data = self.data.alerts[modID]
        table.insert(content, "        [" .. quoteStr(modID) .. "] = {\r\n")
        table.insert(content, "            workshopID = " .. string.format("%.0f", data.workshopID or 0) .. ",\r\n")
        table.insert(content, "            lastUpdate = " .. string.format("%.0f", data.lastUpdate or 0) .. ",\r\n")
        table.insert(content, "            seen = " .. tostring(data.seen or false) .. ",\r\n")
        table.insert(content, "        },\r\n")
    end
    table.insert(content, "    },\r\n")

    table.insert(content, "    workshop = {\r\n")
    table.insert(content, "        usage = {\r\n")
    local usage = self.data.workshop and self.data.workshop.usage or { time = 0, requests = 0 }
    table.insert(content, "            time = " .. string.format("%.0f", usage.time or 0) .. ",\r\n")
    table.insert(content, "            requests = " .. string.format("%.0f", usage.requests or 0) .. ",\r\n")
    table.insert(content, "        },\r\n")

    table.insert(content, "        mods = {\r\n")
    local wsMods = self.data.workshop and self.data.workshop.mods or {}
    local wsKeys = {}
    for k in pairs(wsMods) do table.insert(wsKeys, k) end
    table.sort(wsKeys)
    for _, modID in ipairs(wsKeys) do
        local data = wsMods[modID]
        table.insert(content, "            [" .. quoteStr(modID) .. "] = {\r\n")
        table.insert(content, "                workshopID = " .. string.format("%.0f", data.workshopID or 0) .. ",\r\n")
        table.insert(content, "                lastUpdate = " .. string.format("%.0f", data.lastUpdate or 0) .. ",\r\n")
        table.insert(content, "                state = " .. quoteStr(data.state) .. ",\r\n")
        table.insert(content, "            },\r\n")
    end
    table.insert(content, "        }\r\n")
    table.insert(content, "    }\r\n")
    table.insert(content, "}\r\n")

    local finalContent = table.concat(content)

    local tmpWriter = getFileWriter("ModManager/ModListData.tmp", true, false)
    if not tmpWriter then
        return false
    end
    tmpWriter:write(finalContent)
    tmpWriter:close()

    local mainWriter = getFileWriter("ModManager/ModListData.lua", true, false)
    if not mainWriter then
        return false
    end
    mainWriter:write(finalContent)
    mainWriter:close()

    return true
end

function ModManagerData:getWorkshopData()
    return self.data and self.data.workshop
end

function ModManagerData:getAlertsData()
    return self.data and self.data.alerts
end

function ModManagerData:getModWorkshopInfo(modID)
    if self.data and self.data.workshop and self.data.workshop.mods and self.data.workshop.mods[modID] then
        return self.data.workshop.mods[modID]
    end
    return nil
end

function ModManagerData:updateWorkshopData(steamInfo, modMap)
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

function ModManagerData:updateUsageStats(numRequests)
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

return ModManagerData