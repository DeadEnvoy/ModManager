if isServer() then return; end

local defaultData = {
    version = 2,
    mods = {},
    alerts = {},
}

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = deepCopy(v)
    end
    return copy
end

local ModListData = {
    data = deepCopy(defaultData),
    isQuerying = false
}

-- loadstring/loadstream were removed in build 42.20.4 for security reasons,
-- so the saved file (a Lua table literal) is parsed with a hand-written parser.
local Parser = {}

function Parser.new(content)
    return setmetatable({ content = content, pos = 1 }, { __index = Parser })
end

function Parser:skipWhitespace()
    while self.pos <= #self.content do
        local c = self.content:sub(self.pos, self.pos)
        if c == " " or c == "\t" or c == "\r" or c == "\n" or c == "," then
            self.pos = self.pos + 1
        elseif c == "-" and self.content:sub(self.pos + 1, self.pos + 1) == "-" then
            local newline = self.content:find("[\r\n]", self.pos + 2)
            self.pos = newline and (newline + 1) or (#self.content + 1)
        else
            break
        end
    end
end

function Parser:peek()
    self:skipWhitespace()
    return self.content:sub(self.pos, self.pos)
end

function Parser:expect(c)
    if self:peek() ~= c then
        error("expected '" .. c .. "' at position " .. self.pos)
    end
    self.pos = self.pos + 1
end

function Parser:parseString()
    self:expect('"')
    local result = {}
    while self.pos <= #self.content do
        local c = self.content:sub(self.pos, self.pos)
        self.pos = self.pos + 1
        if c == '"' then
            return table.concat(result)
        elseif c == "\\" then
            local esc = self.content:sub(self.pos, self.pos)
            self.pos = self.pos + 1
            if esc == "n" then
                result[#result + 1] = "\n"
            elseif esc == "t" then
                result[#result + 1] = "\t"
            elseif esc == "r" then
                result[#result + 1] = "\r"
            elseif esc == "a" then
                result[#result + 1] = "\a"
            elseif esc == "b" then
                result[#result + 1] = "\b"
            elseif esc == "f" then
                result[#result + 1] = "\f"
            elseif esc == "v" then
                result[#result + 1] = "\v"
            elseif esc == '"' then
                result[#result + 1] = '"'
            elseif esc == "\\" then
                result[#result + 1] = "\\"
            elseif esc:match("%d") then
                local digits = esc
                while #digits < 3 and self.content:sub(self.pos, self.pos):match("%d") do
                    digits = digits .. self.content:sub(self.pos, self.pos)
                    self.pos = self.pos + 1
                end
                result[#result + 1] = string.char(tonumber(digits) or 0)
            elseif esc == "z" then
                while self.pos <= #self.content and self.content:sub(self.pos, self.pos):match("%s") do
                    self.pos = self.pos + 1
                end
            else
                result[#result + 1] = esc
            end
        else
            result[#result + 1] = c
        end
    end
    error("unterminated string")
end

function Parser:parseValue()
    local c = self:peek()
    if c == "{" then
        return self:parseTable()
    elseif c == '"' then
        return self:parseString()
    else
        local word = self.content:match("^[%+%-]?%d+%.?%d*[eE]?[+-]?%d*", self.pos)
        if word and word ~= "" and word ~= "-" and word ~= "+" then
            self.pos = self.pos + #word
            return tonumber(word)
        end
        word = self.content:match("^[a-zA-Z_][%w_]*", self.pos)
        if not word then
            error("unexpected character at position " .. self.pos)
        end
        self.pos = self.pos + #word
        if word == "true" then return true end
        if word == "false" then return false end
        if word == "nil" then return nil end
        error("unknown identifier '" .. word .. "'")
    end
end

function Parser:parseTable()
    self:expect("{")
    local result = {}
    while self.pos <= #self.content do
        local c = self:peek()
        if c == "}" then
            self.pos = self.pos + 1
            return result
        end
        local key
        if c == "[" then
            self.pos = self.pos + 1
            key = self:parseValue()
            self:expect("]")
            self:expect("=")
        else
            local word = self.content:match("^[a-zA-Z_][%w_]*", self.pos)
            if not word then
                error("expected key at position " .. self.pos)
            end
            self.pos = self.pos + #word
            key = word
            self:expect("=")
        end
        ---@diagnostic disable-next-line: need-check-nil
        result[key] = self:parseValue()
    end
    error("unterminated table")
end

local function tryParseContent(content)
    local startPos = content:find("return")
    if not startPos then return nil end

    local parser = Parser.new(content:sub(startPos + 6))
    local success, res = pcall(function()
        return parser:parseValue()
    end)
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

function ModListData:load()
    self.data = deepCopy(defaultData)

    local hasMainFile = false

    local mainContent = readFileContent("ModManager/ModListData.ini")
    if mainContent then
        local res = tryParseContent(mainContent)
        if res and type(res) == "table" then
            hasMainFile = true
            self.data = res
        else
            local tmpContent = readFileContent("ModManager/ModListData.tmp.ini")
            if tmpContent then
                local tmpRes = tryParseContent(tmpContent)
                if tmpRes and type(tmpRes) == "table" then
                    hasMainFile = true
                    self.data = tmpRes
                end
            end
        end
    else
        local tmpContent = readFileContent("ModManager/ModListData.tmp.ini")
        if tmpContent then
            local tmpRes = tryParseContent(tmpContent)
            if tmpRes and type(tmpRes) == "table" then
                hasMainFile = true
                self.data = tmpRes
            end
        end
    end

    if not hasMainFile then
        local legacyContent = readFileContent("ModManager/ModListData.lua") or
        readFileContent("ModManager/ModListData.tmp")
        if legacyContent then
            local legacyRes = tryParseContent(legacyContent)
            if legacyRes and type(legacyRes) == "table" then
                self.data = legacyRes
            end
        end
    end

    self.data.version = self.data.version or 1
    self.data.mods = self.data.mods or {}
    self.data.alerts = self.data.alerts or {}

    if self.data.version < 2 then
        self:migrateToV2()
        self:save()
    end

    return self.data
end

function ModListData:migrateToV2()
    for _, modData in pairs(self.data.mods) do
        if modData.category == "" then
            modData.category = nil
        end
    end

    if self.data.workshop and self.data.workshop.mods then
        for modID, wsData in pairs(self.data.workshop.mods) do
            if wsData.lastUpdate and wsData.lastUpdate ~= 0 and self.data.mods[modID] then
                self.data.mods[modID].workshop = {
                    workshopID = wsData.workshopID,
                    lastUpdate = wsData.lastUpdate,
                    state = wsData.state,
                }
            end
        end
        self.data.workshop.mods = nil
    end

    self.data.version = 2
end

local function quoteStr(s)
    return string.format("%q", tostring(s or ""))
end

function ModListData:save()
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
        table.insert(content, "            index = " .. tostring(item.data.index) .. ",\r\n")
        table.insert(content,
            "            category = " .. (item.data.category == nil and "nil" or quoteStr(item.data.category)) .. ",\r\n")
        if item.data.workshop then
            local ws = item.data.workshop
            table.insert(content, "            workshop = {\r\n")
            table.insert(content, "                workshopID = " .. string.format("%.0f", ws.workshopID or 0) .. ",\r\n")
            table.insert(content, "                lastUpdate = " .. string.format("%.0f", ws.lastUpdate or 0) .. ",\r\n")
            table.insert(content, "                state = " .. quoteStr(ws.state) .. ",\r\n")
            table.insert(content, "            },\r\n")
        end
        table.insert(content, "            hidden = " .. tostring(item.data.hidden) .. ",\r\n")
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

    table.insert(content, "}\r\n")

    local finalContent = table.concat(content)

    local currentMain = readFileContent("ModManager/ModListData.ini")
    if currentMain then
        local tmpWriter = getFileWriter("ModManager/ModListData.tmp.ini", true, false)
        if tmpWriter then
            tmpWriter:write(currentMain)
            tmpWriter:close()
        end
    end

    local mainWriter = getFileWriter("ModManager/ModListData.ini", true, false)
    if not mainWriter then
        return false
    end
    mainWriter:write(finalContent)
    mainWriter:close()

    return true
end

function ModListData:getAlertsData()
    return self.data and self.data.alerts
end

function ModListData:getModWorkshopInfo(modID)
    local modData = self.data.mods[modID]
    return modData and modData.workshop
end

function ModListData:updateWorkshopData(steamInfo, modMap)
    for i = 0, steamInfo:size() - 1 do
        local details = steamInfo:get(i)
        local lastUpdate = details:getTimeUpdated()
        if lastUpdate ~= 0 then
            local wid = details:getIDString()
            local mods = modMap and modMap[wid]

            if mods then
                for _, modInfo in ipairs(mods) do
                    local modID = modInfo:getId()
                    if self.data.mods[modID] then
                        self.data.mods[modID].workshop = {
                            workshopID = tonumber(wid),
                            lastUpdate = lastUpdate,
                            state = details:getState(),
                        }
                    end
                end
            end
        end
    end
end

ModListData:load()

return ModListData