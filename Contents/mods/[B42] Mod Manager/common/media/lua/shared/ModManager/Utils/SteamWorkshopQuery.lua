if isServer() then return; end

local SteamWorkshopQuery = {};
local ModListData = require("ModManager/Utils/ModListData");

LuaEventManager.AddEvent("OnWorkshopUpdate");

function SteamWorkshopQuery.OnSteamQueryCompleted(status, info)
    ModListData.isQuerying = false;
    if status == "Completed" then
        ModListData:updateWorkshopData(info, SteamWorkshopQuery.modMap);
        ModListData:updateUsageStats(SteamWorkshopQuery.queriedCount or 0);
        ModListData:save(); triggerEvent("OnWorkshopUpdate");
    end
end

function SteamWorkshopQuery.query()
    if not getSteamModeActive() then return; end

    SteamWorkshopQuery.modMap = {};
    local workshopIDs = java.util.ArrayList.new();
    local addedIDs = {};

    local directories = getModDirectoryTable();
    for _, directory in ipairs(directories) do
        local modInfo = getModInfo(directory);
        if modInfo then
            local workshopID = modInfo:getWorkshopID();

            if workshopID and workshopID ~= "" then
                if not SteamWorkshopQuery.modMap[workshopID] then
                    SteamWorkshopQuery.modMap[workshopID] = {};
                end
                table.insert(SteamWorkshopQuery.modMap[workshopID], modInfo);

                if not addedIDs[workshopID] then
                    workshopIDs:add(workshopID);
                    addedIDs[workshopID] = true;
                end
            end
        end
    end

    if not workshopIDs:isEmpty() then
        local modListData = ModListData:load();
        local now = os.time();
        local usage = modListData.workshop and modListData.workshop.usage or { time = 0, requests = 0 };

        if now - (usage.time or 0) > 3600 then
            usage.requests = 0;
        end

        if (usage.requests or 0) + workshopIDs:size() >= 3600 then
            triggerEvent("OnWorkshopUpdate");
            return;
        end

        ModListData.isQuerying = true;
        SteamWorkshopQuery.queriedCount = workshopIDs:size();
        querySteamWorkshopItemDetails(workshopIDs, SteamWorkshopQuery.OnSteamQueryCompleted, nil);
    else
        triggerEvent("OnWorkshopUpdate");
    end
end

Events.OnMainMenuEnter.Add(SteamWorkshopQuery.query);