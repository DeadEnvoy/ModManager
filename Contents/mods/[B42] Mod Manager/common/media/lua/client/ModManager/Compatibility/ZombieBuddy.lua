local hasZB = pcall(require, "ZombieBuddy_Options");

if hasZB and ZombieBuddy then
    if ZombieBuddy.setAutoFixModOrder then
        local original_setAutoFixModOrder = ZombieBuddy.setAutoFixModOrder;
        ZombieBuddy.setAutoFixModOrder = function(value)
            original_setAutoFixModOrder(false);
        end
    end

    local MLOS_sorting = require("OptionScreens/ModSelector/MLOS_sorting");
    local rules = MLOS_sorting:readSortingRules();

    local function addRule(modId, ruleKey, targetId, isLoadFirst)
        local modRules = rules[modId] or {};
        if isLoadFirst then
            modRules.loadFirst = "on";
        end

        if ruleKey and targetId then
            modRules[ruleKey] = modRules[ruleKey] or {};
            for _, id in ipairs(modRules[ruleKey]) do
                if id == targetId then
                    rules[modId] = modRules;
                    return;
                end
            end
            table.insert(modRules[ruleKey], targetId);
        end

        rules[modId] = modRules;
    end

    addRule("ZombieBuddy", "loadBefore", "ModLoadOrderSorter_b42", true);
    addRule("zdk", "loadAfter", "ZombieBuddy", true);
    addRule("zdk", "loadBefore", "ModLoadOrderSorter_b42");
    addRule("ZModUnbork", "loadAfter", "zdk", true);
    addRule("ZModUnbork", "loadBefore", "ModLoadOrderSorter_b42");
end