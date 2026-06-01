require "OptionScreens/WorkshopSubmitScreen";

local WorkshopSubmit = {};

local function convertInline(text)
    text = string.gsub(text, "%*%*%*(.-)%*%*%*", "[b][i]%1[/i][/b]");
    text = string.gsub(text, "%*%*(.-)%*%*", "[b]%1[/b]");
    text = string.gsub(text, "__(.-)__", "[b]%1[/b]");
    text = string.gsub(text, "%*(.-)%*", "[i]%1[/i]");
    text = string.gsub(text, "_(.-)_", "[i]%1[/i]");
    text = string.gsub(text, "~~(.-)~~", "[strike]%1[/strike]");
    text = string.gsub(text, "`(.-)`", "[code]%1[/code]");
    text = string.gsub(text, "%[(.-)%]%((.-)%)", "[url=%2]%1[/url]");
    return text
end

local function splitLines(str)
    local lines = {}
    local start = 1
    while true do
        local pos = string.find(str, "\n", start, true);
        if not pos then
            table.insert(lines, string.sub(str, start));
            break
        end
        table.insert(lines, string.sub(str, start, pos - 1));
        start = pos + 1;
    end
    return lines
end

local function markdownToSteam(version, content)
    local result = "[h1][b]" .. version .. "[/b][/h1]\n";
    local lines = splitLines(content);
    local listStack = {};
    local inCode = false;

    local function closeList()
        local top = listStack[#listStack];
        if not top then return end
        if top == "ul" then
            result = result .. "[/list]\n";
        elseif top == "ol" then
            result = result .. "[/olist]\n";
        end
        table.remove(listStack);
    end

    local function closeAllLists()
        while #listStack > 0 do
            closeList();
        end
    end

    local function openList(ltype)
        if ltype == "ul" then
            result = result .. "[list]\n";
        else
            result = result .. "[olist]\n";
        end
        table.insert(listStack, ltype);
    end

    local function topList()
        return listStack[#listStack]
    end

    local function getIndent(raw)
        local indent = 0;
        local i = 1;
        while i <= #raw do
            local ch = string.sub(raw, i, i);
            if ch == " " then
                indent = indent + 1;
            elseif ch == "\t" then
                indent = math.floor((indent + 4) / 4) * 4;
            else
                break
            end
            i = i + 1;
        end
        return math.floor(indent / 4)
    end

    for i = 1, #lines do
        local raw = lines[i];
        local line = string.trim(raw);

        if string.match(line, "^```") then
            if inCode then
                result = result .. "[/code]\n";
                inCode = false;
            else
                closeAllLists();
                result = result .. "[code]\n";
                inCode = true;
            end

        elseif inCode then
            result = result .. raw .. "\n";

        elseif line ~= "" then
            local h3 = string.match(line, "^###%s+(.+)$");
            local h2 = string.match(line, "^##%s+(.+)$");
            local h1 = string.match(line, "^#%s+(.+)$");
            local isHR = string.match(line, "^%-%-%-+$") or string.match(line, "^%*%*%*+$") or string.match(line, "^___+$");
            local quote = string.match(line, "^>%s*(.*)$");
            local ulItem = string.match(line, "^[-*+]%s+(.+)$");
            local olItem = string.match(line, "^%d+%.%s+(.+)$");

            if h3 then
                closeAllLists();
                result = result .. "[h3]" .. convertInline(h3) .. "[/h3]\n";
            elseif h2 then
                closeAllLists();
                result = result .. "[h2]" .. convertInline(h2) .. "[/h2]\n";
            elseif h1 then
                closeAllLists();
                result = result .. "[h1]" .. convertInline(h1) .. "[/h1]\n";
            elseif isHR then
                closeAllLists();
                result = result .. "[hr][/hr]\n";
            elseif quote ~= nil then
                closeAllLists();
                result = result .. "[quote]" .. convertInline(quote) .. "[/quote]\n";
            elseif ulItem then
                local indent = getIndent(raw);
                local wantDepth = indent + 1;
                while #listStack > wantDepth do
                    closeList();
                end
                if topList() ~= "ul" then
                    closeList();
                    openList("ul");
                end
                while #listStack < wantDepth do
                    openList("ul");
                end
                result = result .. "[*]" .. convertInline(ulItem) .. "\n";
            elseif olItem then
                local indent = getIndent(raw);
                local wantDepth = indent + 1;
                while #listStack > wantDepth do
                    closeList();
                end
                if topList() ~= "ol" then
                    closeList();
                    openList("ol");
                end
                while #listStack < wantDepth do
                    openList("ol");
                end
                result = result .. "[*]" .. convertInline(olItem) .. "\n";
            else
                closeAllLists();
                result = result .. convertInline(line) .. "\n";
            end
        else
            closeAllLists();
            result = result .. "\n";
        end
    end

    closeAllLists();
    if inCode then result = result .. "[/code]\n" end
    return string.trim(result)
end

local function stripInline(text)
    text = string.gsub(text, "%*%*%*(.-)%*%*%*", "%1");
    text = string.gsub(text, "%*%*(.-)%*%*", "%1");
    text = string.gsub(text, "__(.-)__", "%1");
    text = string.gsub(text, "%*(.-)%*", "%1");
    text = string.gsub(text, "_(.-)_", "%1");
    text = string.gsub(text, "~~(.-)~~", "%1");
    text = string.gsub(text, "`(.-)`", "%1");
    text = string.gsub(text, "%(%[(#%d+)%]%((.-)%)%)", "(%1)");
    text = string.gsub(text, "%[(.-)%]%((.-)%)", function(label)
        if string.match(label, "^\".-\"$") then
            return label
        end
        return "\"" .. label .. "\""
    end);
    return text
end

function WorkshopSubmit.markdownToPlaintext(content)
    content = string.gsub(content, "<!%-%-[%s%S]-%-%->", "");
    local lines = splitLines(content);
    local result = "";
    local inCode = false;

    for i = 1, #lines do
        local raw = lines[i];
        local line = string.trim(raw);

        if string.match(line, "^```") then
            inCode = not inCode;
        elseif inCode then
            result = result .. raw .. "\n";
        elseif line ~= "" then
            local h3 = string.match(line, "^###%s+(.+)$");
            local h2 = string.match(line, "^##%s+(.+)$");
            local h1 = string.match(line, "^#%s+(.+)$");
            local isHR = string.match(line, "^%-%-%-+$")
                or string.match(line, "^%*%*%*+$")
                or string.match(line, "^___+$");
            local quote = string.match(line, "^>%s*(.*)$");
            local ulIndent, ulText = string.match(raw, "^(%s*)[-*+]%s+(.+)$");
            local olIndent, olText = string.match(raw, "^(%s*)%d+%.%s+(.+)$");

            if h3 then
                result = result .. stripInline(h3) .. "\n";
            elseif h2 then
                result = result .. stripInline(h2) .. "\n";
            elseif h1 then
                result = result .. stripInline(h1) .. "\n";
            elseif isHR then
                result = result .. "---\n";
            elseif quote ~= nil then
                result = result .. stripInline(quote) .. "\n";
            elseif ulIndent and ulText then
                local indentLevel = 0;
                local tabCount = 0;
                for _ in string.gmatch(ulIndent, "\t") do
                    tabCount = tabCount + 1;
                end
                if tabCount > 0 then
                    indentLevel = tabCount;
                else
                    local spaceCount = #ulIndent;
                    indentLevel = math.floor(spaceCount / 4);
                end

                local indentPixels = indentLevel * 20;
                if indentPixels > 0 then
                    result = result .. " <INDENT:" .. indentPixels .. "> ";
                end
                result = result .. "- " .. stripInline(ulText) .. "\n";
                if indentPixels > 0 then
                    result = result .. " <INDENT:0> ";
                end
            elseif olIndent and olText then
                local indentLevel = 0;
                local tabCount = 0;
                for _ in string.gmatch(olIndent, "\t") do
                    tabCount = tabCount + 1;
                end
                if tabCount > 0 then
                    indentLevel = tabCount;
                else
                    local spaceCount = #olIndent;
                    indentLevel = math.floor(spaceCount / 4);
                end

                local indentPixels = indentLevel * 20;
                if indentPixels > 0 then
                    result = result .. " <INDENT:" .. indentPixels .. "> ";
                end
                result = result .. olText .. "\n";
                if indentPixels > 0 then
                    result = result .. " <INDENT:0> ";
                end
            else
                result = result .. stripInline(line) .. "\n";
            end
        else
            result = result .. "\n";
        end
    end

    return string.trim(result)
end

local function detectMdFormat(lines)
    local inHtmlComment = false;
    for i = 1, #lines do
        local trimmed = string.trim(lines[i]);
        if string.match(trimmed, "^<!%-%-") then
            if not string.match(trimmed, "%-%->$") then inHtmlComment = true end
        elseif inHtmlComment and string.match(trimmed, "%-%->$") then
            inHtmlComment = false;
        elseif not inHtmlComment and trimmed ~= "" then
            if string.match(trimmed, "^###%s*.-%s*###") then
                return "legacy"
            end
            return "modern"
        end
    end
    return "modern"
end

local function parseLegacyMd(lines)
    local changelogs = nil;
    local currentTitle = nil;
    local currentContent = nil;
    local inHtmlComment = false;

    for i = 1, #lines do
        local line = lines[i];
        local trimmed = string.trim(line);

        if string.match(trimmed, "^<!%-%-") then
            if not string.match(trimmed, "%-%->$") then inHtmlComment = true end
        elseif inHtmlComment and string.match(trimmed, "%-%->$") then
            inHtmlComment = false;
        elseif string.match(trimmed, "^###%s*(.-)%s*###$") then
            local title = string.match(trimmed, "^###%s*(.-)%s*###$");
            if title ~= "ALERT_CONFIG" then
                if currentTitle then
                    if not changelogs then changelogs = {} end
                    table.insert(changelogs, {title = currentTitle, contents = string.trim(currentContent or "")});
                end
                currentTitle = title;
                currentContent = "";
            end
        elseif trimmed == "#" then
            if currentTitle then
                if not changelogs then changelogs = {} end
                table.insert(changelogs, {title = currentTitle, contents = string.trim(currentContent or "")});
                currentTitle = nil;
                currentContent = nil;
            end
        elseif currentTitle and not inHtmlComment then
            currentContent = (currentContent or "") .. line .. "\n";
        end
    end

    if currentTitle then
        if not changelogs then changelogs = {} end
        table.insert(changelogs, {title = currentTitle, contents = string.trim(currentContent or "")});
    end

    return changelogs
end

local function parseMdVersionHeader(trimmed)
    local header = string.match(trimmed, "^#%s+(.+)$");
    if not header then return nil end

    local v = string.match(header, "^%[(.-)%]");
    if v then return v end

    v = string.match(header, "^(.-)%s+%-%s");
    if v then return string.trim(v) end

    return string.trim(header)
end

local function parseTxtVersionHeader(trimmed)
    if string.match(trimmed, "^%[%s*%-%-+%s*%]$") or trimmed == "#" then
        return true, false
    end
    local v = string.match(trimmed, "^%[%s*(.-)%s*%]$")
        or string.match(trimmed, "^###%s*(.-)%s*###$");
    if v and v ~= "ALERT_CONFIG" then
        return v, false
    end
    return nil, false
end

function WorkshopSubmit.fetchChangelog(modID)
    local reader, isMd = getModFileReader(modID, "ChangeLog.md", false), false;
    if reader then
        isMd = true;
    else
        reader = getModFileReader(modID, "ChangeLog.txt", false);
    end
    if not reader then return nil, false, false end

    local lines = {};
    local line = reader:readLine();
    while line do
        table.insert(lines, line);
        line = reader:readLine();
    end
    reader:close();

    if isMd then
        local fmt = detectMdFormat(lines);
        if fmt == "legacy" then
            return parseLegacyMd(lines), true, true;
        end
    end

    local changelogs = nil;
    local currentTitle = nil;
    local currentContent = nil;
    local inHtmlComment = false;

    for i = 1, #lines do
        line = lines[i];
        local trimmed = string.trim(line);
        local version = nil;
        local isSep = false;

        if string.match(trimmed, "^<!%-%-") then
            if not string.match(trimmed, "%-%->$") then inHtmlComment = true end
        elseif inHtmlComment and string.match(trimmed, "%-%->$") then
            inHtmlComment = false;
        elseif isMd then
            version = parseMdVersionHeader(trimmed);
        else
            version, isSep = parseTxtVersionHeader(trimmed);
        end

        if version then
            if currentTitle then
                if not changelogs then changelogs = {} end
                table.insert(changelogs, {title = currentTitle, contents = currentContent});
            end
            currentTitle = version;
            currentContent = "";
        elseif isSep then
            if currentTitle then
                if not changelogs then changelogs = {} end
                table.insert(changelogs, {title = currentTitle, contents = currentContent});
            end
            currentTitle = nil;
        elseif currentTitle and not inHtmlComment then
            if isMd then
                currentContent = currentContent .. line .. "\n";
            elseif trimmed ~= "" then
                currentContent = currentContent .. trimmed .. "\n";
            end
        end
    end

    if currentTitle then
        if not changelogs then changelogs = {} end
        table.insert(changelogs, {title = currentTitle, contents = currentContent});
    end

    return changelogs, isMd, false
end

function WorkshopSubmit.getLatestChangelog(modID)
    local changelogs, isMd, isLegacy = WorkshopSubmit.fetchChangelog(modID);
    if not changelogs or #changelogs == 0 then return nil end

    local entry = (isMd and not isLegacy) and changelogs[1] or changelogs[#changelogs];
    if not entry or entry.contents == "" then return nil end

    if isMd and not isLegacy then
        return markdownToSteam(entry.title, entry.contents)
    else
        return string.trim(entry.title .. "\n" .. entry.contents)
    end
end

local function updateChangeNotes(workshopItem)
    if not workshopItem then return end

    local modID, desc = nil, workshopItem:getSubmitDescription();

    for line in string.gmatch(desc, "[^\r\n]+") do
        modID = string.match(line, "^Mod ID:%s*(.+)$");
        if modID then break end
    end

    if not modID then return end

    local changeLog = WorkshopSubmit.getLatestChangelog(modID);
    if changeLog then
        workshopItem:setChangeNote(changeLog);
    end
end

local original_create = WorkshopSubmitScreen.create;

function WorkshopSubmitScreen:create()
    original_create(self);
    local original_setWorkshopItem = self.page2.setWorkshopItem;
    function self.page2:setWorkshopItem(item)
        original_setWorkshopItem(self, item);
        updateChangeNotes(self.parent.item);
    end
end

return WorkshopSubmit;