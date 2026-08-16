if isServer() then return; end

local SteamWorkshopQuery = {};
local ModListData = require("ModManager/Utils/ModListData");

LuaEventManager.AddEvent("OnWorkshopUpdate");

local modMap, hasQueried = {}, false;

function SteamWorkshopQuery.OnSteamQueryCompleted(status, info)
    if not ipairs then return; end
    ModListData.isQuerying = false;
    if status == "Completed" then
        ModListData:updateWorkshopData(info, modMap);
        ModListData:save();
    end
    modMap = {};
    triggerEvent("OnWorkshopUpdate");
end

function SteamWorkshopQuery.query()
    if not getSteamModeActive() then return; end

    if hasQueried then
        triggerEvent("OnWorkshopUpdate");
        return;
    end
    hasQueried = true;

    modMap = {};
    local workshopIDs = java.util.ArrayList.new();
    local addedIDs = {};

    local directories = getModDirectoryTable();
    for _, directory in ipairs(directories) do
        local modInfo = getModInfo(directory);
        if modInfo then
            local workshopID = modInfo:getWorkshopID();

            if workshopID and workshopID ~= "" then
                if not modMap[workshopID] then
                    modMap[workshopID] = {};
                end
                table.insert(modMap[workshopID], modInfo);

                if not addedIDs[workshopID] then
                    workshopIDs:add(workshopID);
                    addedIDs[workshopID] = true;
                end
            end
        end
    end

    if not workshopIDs:isEmpty() then
        ModListData.isQuerying = true;
        querySteamWorkshopItemDetails(workshopIDs, SteamWorkshopQuery.OnSteamQueryCompleted, nil);
    else
        triggerEvent("OnWorkshopUpdate");
    end
end

Events.OnMainMenuEnter.Add(SteamWorkshopQuery.query);