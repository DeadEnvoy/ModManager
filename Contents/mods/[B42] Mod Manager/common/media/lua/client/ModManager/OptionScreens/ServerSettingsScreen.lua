require "ISUI/ISPanelJoypad";
require "OptionScreens/ServerSettingsScreen";

local UI_BORDER_SPACING = 10;
local VSCROLL_BAR_OFFSET = 16;
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small);
local FONT_LINE_HGT_SMALL = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight();
local BUTTON_HGT = FONT_HGT_SMALL + 6;

local ModListData = require("ModManager/Utils/ModListData");

local function resolveWorkshopID(modID, modInfo)
    local workshopID = modInfo and modInfo:getWorkshopID() or nil;
    if not workshopID or workshopID == "" then
        local cachedData = ModListData:getModWorkshopInfo(modID);
        if cachedData and cachedData.workshopID then
            workshopID = tostring(cachedData.workshopID);
        end
    end
    return workshopID
end

local function positionVScroll(listbox, listW, listHeight)
    if listbox.vscroll then
        listbox.vscroll:setAnchorRight(false);
        listbox.vscroll:setAnchorBottom(false);
        listbox.vscroll:setX(listW - VSCROLL_BAR_OFFSET);
        listbox.vscroll:setHeight(listHeight);
    end
end

local function getMapLotsFromMod(mapFolder, modID)
    local reader = getModFileReader(modID, "media/maps/" .. mapFolder .. "/map.info", false);
    if not reader then return nil end

    local lots = nil;
    local line = reader:readLine();
    while line do
        local lotValue = line:match("^lots%s*=%s*(.+)$");
        if lotValue then
            lots = {};
            for lot in string.gmatch(lotValue, "([^;]+)") do
                lot = lot:match("^%s*(.-)%s*$");
                if lot ~= "" then
                    table.insert(lots, lot);
                end
            end
            break;
        end
        line = reader:readLine();
    end
    reader:close();

    return lots
end

local function getMapLots(mapFolder, modsString)
    local lots = getMapInfo(mapFolder);
    if lots and lots.lots then return lots.lots end

    if modsString then
        local modIDs = string.split(modsString, ";");
        for _, modID in ipairs(modIDs) do
            if modID ~= "" then
                local result = getMapLotsFromMod(mapFolder, modID);
                if result then return result end
            end
        end
    end

    local modDirectories = getModDirectoryTable();
    for _, dirName in ipairs(modDirectories) do
        local modInfo = getModInfo(dirName);
        if modInfo then
            local result = getMapLotsFromMod(mapFolder, modInfo:getId());
            if result then return result end
        end
    end

    return nil
end

local function ensureLotsForMap(mapsPanel, mapFolder, insertBeforeIndex, modsString, addedMaps)
    local lots = getMapLots(mapFolder, modsString);
    if not lots then return insertBeforeIndex end

    for _, lotFolder in ipairs(lots) do
        local inList = mapsPanel:findMapInList(lotFolder);
        if lotFolder ~= mapFolder and not inList then
            insertBeforeIndex = ensureLotsForMap(mapsPanel, lotFolder, insertBeforeIndex, modsString, addedMaps);
            mapsPanel:addMapToList(lotFolder, insertBeforeIndex);
            insertBeforeIndex = insertBeforeIndex + 1;
            mapsPanel.listbox.selected = insertBeforeIndex - 1;
            mapsPanel.listbox:ensureVisible(mapsPanel.listbox.selected);
            if addedMaps then
                table.insert(addedMaps, lotFolder);
            else
                mapsPanel.pageEdit:notify("addedMap", lotFolder);
            end
        end
    end

    return insertBeforeIndex
end

local function updateServerSettingsMods(settings, modIDList)
    local addModIDs = {};
    local addWorkshopIDs = {};

    for _, modID in ipairs(modIDList) do
        local modInfo = getModInfoByID(modID);
        if modInfo then
            DefaultServerSettings:insertUnique(addModIDs, modID);

            local workshopID = resolveWorkshopID(modID, modInfo);
            if workshopID and workshopID ~= "" then
                DefaultServerSettings:insertUnique(addWorkshopIDs, workshopID);
            end
        end
    end

    local oldModString = settings:getServerOptions():getOptionByName("Mods"):getValue();
    local oldModIDs = string.split(oldModString, ";");

    DefaultServerSettings:setServerOptionValue(settings, "Mods", addModIDs);
    DefaultServerSettings:setServerOptionValue(settings, "WorkshopItems", addWorkshopIDs);

    local oldSet = {};
    for _, id in ipairs(oldModIDs) do
        if id ~= "" then
            oldSet[id] = true;
        end
    end

    local newSet = {};
    for _, id in ipairs(addModIDs) do
        newSet[id] = true;
    end

    local addedMods = {};
    for _, id in ipairs(addModIDs) do
        if not oldSet[id] then
            table.insert(addedMods, id);
        end
    end

    local removedMods = {};
    for _, id in ipairs(oldModIDs) do
        if id ~= "" and not newSet[id] then
            table.insert(removedMods, id);
        end
    end

    return addedMods, removedMods
end

local function applyModsDiff(pageEdit, settings, addedMods, removedMods)
    local modsString = settings:getServerOptions():getOptionByName("Mods"):getValue();

    for _, panel in ipairs(pageEdit.customui) do
        if panel.notify then
            if #removedMods > 0 then
                panel:notify("removedMods", removedMods, modsString);
            end
            if #addedMods > 0 then
                panel:notify("addedMods", addedMods, modsString);
            end
        end
    end

    for _, panel in ipairs(pageEdit.customui) do
        if panel.settingsFromUI then
            panel:settingsFromUI();
        end
    end
end

local function onModsPanelButtonChoose(self)
    local pageEdit = self.pageEdit;
    local settings = pageEdit.settings;

    ServerSettingsScreen.instance:setVisible(false);

    local serverModString = settings:getServerOptions():getOptionByName("Mods"):getValue();
    local initialModIDs = string.split(serverModString, ";");

    local initialData = {};
    for i = 1, #initialModIDs do
        local id = initialModIDs[i];
        if id ~= "" then
            local item = {};
            item.modID = id;
            item.modInfo = getModInfoByID(id);
            table.insert(initialData, item);
        end
    end

    local finalFunc = function(finalData)
        if not finalData then
            ServerSettingsScreen.instance:setVisible(true, JoypadState.getMainMenuJoypad());
            return
        end

        local newModIDList = {};
        for _, item in ipairs(finalData) do
            if item.modInfo then
                table.insert(newModIDList, item.modInfo:getId());
            elseif item.getId then
                table.insert(newModIDList, item:getId());
            elseif type(item) == "string" then
                table.insert(newModIDList, item);
            end
        end

        for _, panel in ipairs(pageEdit.customui) do
            if panel.settingsFromUI then
                panel:settingsFromUI();
            end
        end

        local addedMods, removedMods = updateServerSettingsMods(settings, newModIDList);

        for _, panel in ipairs(pageEdit.customui) do
            panel:setSettings(settings);
        end

        applyModsDiff(pageEdit, settings, addedMods, removedMods);

        ServerSettingsScreen.instance:setVisible(true, JoypadState.getMainMenuJoypad());
    end

    ModSelector.instance:setServerSettingsMods(initialData, finalFunc);
    ModSelector.instance:setVisible(true, self.joyfocus);
    ModSelector.instance:reloadMods();
    ModSelector.showNagPanel();
    ModSelector.instance.returnToUI = ServerSettingsScreen.instance;
end

local function layoutModsPanel(self)
    local label = nil;
    for _, child in pairs(self:getChildren()) do
        if child.Type == "ISLabel" then
            label = child;
            break
        end
    end

    if not label or not self.listbox or not self.button then
        return
    end

    local buttonWid = self.button:getWidth();
    local buttonX = self.width - UI_BORDER_SPACING - buttonWid;
    local buttonY = UI_BORDER_SPACING;

    self.button:setX(buttonX);
    self.button:setY(buttonY);

    label:setX(UI_BORDER_SPACING);
    label:setY(UI_BORDER_SPACING + (self.button:getHeight() - label.height) / 2);

    local listY = UI_BORDER_SPACING + self.button:getHeight() + UI_BORDER_SPACING;
    local listW = self.width - UI_BORDER_SPACING * 2;
    local listH = self.height - listY - UI_BORDER_SPACING;

    if listH < 100 then
        listH = 100;
    end

    self.listbox:setX(UI_BORDER_SPACING);
    self.listbox:setY(listY);
    self.listbox:setWidth(listW);
    self.listbox:setHeight(listH);

    positionVScroll(self.listbox, listW, listH);

    self.button:setVisible(true);
end

local function layoutMapsPanel(self)
    if self.buttonRemove then
        self.buttonRemove:setVisible(false);
    end

    local titleLabel = nil;
    local bottomLabels = {};
    for _, child in pairs(self:getChildren()) do
        if child.Type == "ISLabel" then
            if child:getY() < 50 then
                titleLabel = child;
            else
                table.insert(bottomLabels, child);
            end
        end
    end

    if not titleLabel or not self.listbox or not self.comboBox then
        return
    end

    if not self.buttonMoveUp or not self.buttonMoveDown then
        return
    end

    table.sort(bottomLabels, function(a, b) return a:getY() < b:getY() end);

    local labelCombo = bottomLabels[1];

    local buttonWid = self.buttonMoveUp:getWidth();
    self.buttonMoveDown:setX(self.width - UI_BORDER_SPACING - buttonWid);
    self.buttonMoveDown:setY(UI_BORDER_SPACING);

    self.buttonMoveUp:setX(self.buttonMoveDown:getX() - UI_BORDER_SPACING - buttonWid);
    self.buttonMoveUp:setY(UI_BORDER_SPACING);

    local buttonHeight = self.buttonMoveUp:getHeight();
    titleLabel:setX(UI_BORDER_SPACING);
    titleLabel:setY(UI_BORDER_SPACING + (buttonHeight - titleLabel:getHeight()) / 2);

    local listStartY = UI_BORDER_SPACING + buttonHeight + UI_BORDER_SPACING;

    local comboHeight = self.comboBox:getHeight();

    local row1_Y = self.height - UI_BORDER_SPACING - comboHeight;
    local listBottomY = row1_Y - UI_BORDER_SPACING;

    local labelWidth = 0;
    if labelCombo and labelCombo:getWidth() > labelWidth then
        labelWidth = labelCombo:getWidth();
    end

    local inputX = UI_BORDER_SPACING;
    if labelWidth > 0 then
        inputX = inputX + labelWidth + UI_BORDER_SPACING;
    end
    local inputWidth = self.width - inputX - UI_BORDER_SPACING;

    if labelCombo then
        labelCombo:setX(UI_BORDER_SPACING);
        labelCombo:setY(row1_Y + (comboHeight - labelCombo:getHeight()) / 2);
        labelCombo:setVisible(true);
    end

    self.comboBox:setX(inputX);
    self.comboBox:setY(row1_Y);
    self.comboBox:setWidth(inputWidth);

    if self.entry then
        self.entry:setVisible(false);
    end
    for i = 2, #bottomLabels do
        bottomLabels[i]:setVisible(false);
    end

    local listHeight = listBottomY - listStartY;
    if listHeight < 100 then
        listHeight = 100;
    end

    local listW = self.width - UI_BORDER_SPACING * 2;
    self.listbox:setX(UI_BORDER_SPACING);
    self.listbox:setY(listStartY);
    self.listbox:setWidth(listW);
    self.listbox:setHeight(listHeight);

    positionVScroll(self.listbox, listW, listHeight);
end

local function isVanillaMap(mapFolder)
    local modDirectories = getModDirectoryTable();
    for _, dirName in ipairs(modDirectories) do
        local modInfo = getModInfo(dirName);
        if modInfo then
            local mapFolders = getMapFoldersForMod(modInfo:getId());
            if mapFolders then
                for i = 1, mapFolders:size() do
                    if mapFolders:get(i - 1) == mapFolder then return false end
                end
            end
        end
    end
    return true
end

local function getVanillaMapFolders()
    local result = {};
    local sortedResult = {};
    local mapGroups = MapGroups.new();
    mapGroups:createGroups(ActiveMods.getById("serversettings"), true, false);
    local mapFolders = mapGroups:getAllMapsInOrder();
    for i = 1, mapFolders:size() do
        local mapFolder = mapFolders:get(i - 1);
        if mapFolder ~= "challengemaps" and isVanillaMap(mapFolder) then
            local info = getMapInfo(mapFolder);
            if info and not (info.only_for_game_mode and info.only_for_game_mode ~= "Multiplayer") then
                if MapsOrder then
                    local sorted = false;
                    for orderIndex, orderedMap in ipairs(MapsOrder) do
                        if orderedMap == mapFolder then
                            table.insert(sortedResult, orderIndex, mapFolder);
                            sorted = true;
                            break;
                        end
                    end
                    if not sorted then
                        table.insert(result, mapFolder);
                    end
                else
                    table.insert(result, mapFolder);
                end
            end
        end
    end
    for _, mapFolder in ipairs(result) do
        table.insert(sortedResult, mapFolder);
    end
    return sortedResult
end

local function findSpawnRegionInList(panel, mapFolder)
    for i, item in ipairs(panel.listbox.items) do
        if item.item.name == mapFolder then
            return i
        end
    end
    return nil;
end

local function fillSpawnRegionsComboBox(panel, modsString)
    panel.spawnComboBox.options = {};
    local mapsPanel = nil;
    if panel.pageEdit then
        for _, p in ipairs(panel.pageEdit.customui) do
            if p.Type == "ServerSettingsScreenMapsPanel" then
                mapsPanel = p;
                break
            end
        end
    end
    local muldraughInMaps = mapsPanel and mapsPanel:findMapInList("Muldraugh, KY") ~= nil;
    if muldraughInMaps then
        for _, mapFolder in ipairs(getVanillaMapFolders()) do
            if not findSpawnRegionInList(panel, mapFolder) then
                panel.spawnComboBox:addOption(mapFolder);
            end
        end
    end
    local modIDs = string.split(modsString, ";");
    for _, modID in ipairs(modIDs) do
        if modID ~= "" then
            local mapFolders = getMapFoldersForMod(modID);
            if mapFolders then
                for i = 1, mapFolders:size() do
                    local mapFolder = mapFolders:get(i - 1);
                    if not isVanillaMap(mapFolder) and spawnpointsExistsForMod(modID, mapFolder) and not findSpawnRegionInList(panel, mapFolder) then
                        local lots = getMapLots(mapFolder, modsString);
                        local lotsSatisfied = true;
                        if lots and mapsPanel then
                            for _, lot in ipairs(lots) do
                                if not mapsPanel:findMapInList(lot) then
                                    lotsSatisfied = false;
                                    break
                                end
                            end
                        end
                        if lotsSatisfied then
                            panel.spawnComboBox:addOption(mapFolder);
                        end
                    end
                end
            end
        end
    end
    if #panel.spawnComboBox.options == 0 then
        panel.spawnComboBox:addOption("");
        panel.spawnComboBox:setEnabled(false);
    else
        panel.spawnComboBox:setEnabled(true);
    end
    panel.spawnComboBox.selected = 1;
end

local function layoutSpawnRegionsPanel(self)
    if self.buttonAdd then self.buttonAdd:setVisible(false); end
    if self.buttonRemove then self.buttonRemove:setVisible(false); end
    if self.nameFilePanel then self.nameFilePanel:setVisible(false); end

    if not self.listbox or not self.spawnComboBox then return end
    if not self.buttonMoveUp or not self.buttonMoveDown then return end

    if self.entry then
        self.entry:setAnchorTop(false);
        self.entry:setAnchorBottom(false);
    end

    local bottomLabels = {};
    for _, child in pairs(self:getChildren()) do
        if child.Type == "ISLabel" and child ~= self.listTitleLabel and child ~= self.spawnTitleLabel and child ~= self.entryTitleLabel then
            table.insert(bottomLabels, child);
        end
    end
    table.sort(bottomLabels, function(a, b) return a:getY() < b:getY() end);

    local buttonWid = self.buttonMoveUp:getWidth();
    self.buttonMoveDown:setX(self.width - UI_BORDER_SPACING - buttonWid);
    self.buttonMoveDown:setY(UI_BORDER_SPACING);

    self.buttonMoveUp:setX(self.buttonMoveDown:getX() - UI_BORDER_SPACING - buttonWid);
    self.buttonMoveUp:setY(UI_BORDER_SPACING);

    if self.buttonEdit then
        self.buttonEdit:setAnchorLeft(false);
        self.buttonEdit:setAnchorRight(false);
        self.buttonEdit:setAnchorTop(false);
        self.buttonEdit:setAnchorBottom(false);
        self.buttonEdit:setVisible(false);
    end

    if self.listTitleLabel then
        local buttonHeight = self.buttonMoveUp:getHeight();
        self.listTitleLabel:setX(UI_BORDER_SPACING);
        self.listTitleLabel:setY(UI_BORDER_SPACING + (buttonHeight - self.listTitleLabel:getHeight()) / 2);
    end

    local listStartY = UI_BORDER_SPACING + self.buttonMoveUp:getHeight() + UI_BORDER_SPACING;

    local comboHeight = self.spawnComboBox:getHeight();
    local entryHeight = self.entry and self.entry:getHeight() or 0;

    local row2_Y = self.height - UI_BORDER_SPACING - entryHeight;
    local row1_Y = row2_Y - UI_BORDER_SPACING - comboHeight;
    local listBottomY = row1_Y - UI_BORDER_SPACING;

    local labelCombo = bottomLabels[1];
    if labelCombo then
        labelCombo:setAnchorTop(false);
        labelCombo:setAnchorBottom(false);
        labelCombo:setVisible(false);
    end

    if self.spawnTitleLabel then
        self.spawnTitleLabel:setAnchorTop(false);
        self.spawnTitleLabel:setAnchorBottom(false);
        self.spawnTitleLabel:setX(UI_BORDER_SPACING);
        self.spawnTitleLabel:setY(row1_Y + (comboHeight - self.spawnTitleLabel:getHeight()) / 2);
    end

    local labelWidth = 0;
    if self.spawnTitleLabel and self.spawnTitleLabel:getWidth() > labelWidth then
        labelWidth = self.spawnTitleLabel:getWidth();
    end
    if self.entryTitleLabel and self.entryTitleLabel:getWidth() > labelWidth then
        labelWidth = self.entryTitleLabel:getWidth();
    end

    local inputX = UI_BORDER_SPACING;
    if labelWidth > 0 then
        inputX = inputX + labelWidth + UI_BORDER_SPACING;
    end
    local inputWidth = self.width - inputX - UI_BORDER_SPACING;

    self.spawnComboBox:setX(inputX);
    self.spawnComboBox:setY(row1_Y);
    self.spawnComboBox:setWidth(inputWidth);

    local labelEntry = self.entryTitleLabel;
    if self.entry then
        local entryLabelX = UI_BORDER_SPACING;
        if labelEntry then
            labelEntry:setAnchorTop(false);
            labelEntry:setAnchorBottom(false);
            labelEntry:setX(entryLabelX);
            labelEntry:setY(row2_Y + (entryHeight - labelEntry:getHeight()) / 2);
            labelEntry:setVisible(true);

            if labelEntry:getWidth() > 0 then
                self.entry:setX(entryLabelX + labelEntry:getWidth() + UI_BORDER_SPACING);
            else
                self.entry:setX(entryLabelX);
            end
        else
            self.entry:setX(entryLabelX);
        end
        self.entry:setY(row2_Y);
        self.entry:setWidth(self.width - self.entry:getX() - UI_BORDER_SPACING);
    end

    for i = 1, #bottomLabels do
        bottomLabels[i]:setAnchorTop(false);
        bottomLabels[i]:setAnchorBottom(false);
        bottomLabels[i]:setVisible(false);
    end

    local listHeight = listBottomY - listStartY;
    if listHeight < 100 then listHeight = 100; end

    self.listbox:setAnchorRight(false);
    self.listbox:setAnchorBottom(false);
    local listW = self.width - UI_BORDER_SPACING * 2;
    self.listbox:setX(UI_BORDER_SPACING);
    self.listbox:setY(listStartY);
    self.listbox:setWidth(listW);
    self.listbox:setHeight(listHeight);

    positionVScroll(self.listbox, listW, listHeight);
end

local original_create = ServerSettingsScreen.create;
function ServerSettingsScreen:create(...)
    original_create(self, ...);

    if self.pageEdit and self.pageEdit.listbox then
        local workshopIndex = nil;
        for i, item in ipairs(self.pageEdit.listbox.items) do
            if item.item.page and item.item.page.name == getText("UI_ServerSettingGroup_SteamWorkshop") then
                workshopIndex = i;
                break
            end
        end

        if workshopIndex then
            local panelToRemove = self.pageEdit.listbox.items[workshopIndex].item.panel;
            if panelToRemove then
                for i, panel in ipairs(self.pageEdit.customui) do
                    if panel == panelToRemove then
                        table.remove(self.pageEdit.customui, i);
                        break
                    end
                end
            end
            self.pageEdit.listbox:removeItemByIndex(workshopIndex);
        end
    end

    if self.pageEdit and self.pageEdit.customui then
        for _, panel in ipairs(self.pageEdit.customui) do
            if panel.Type == "ServerSettingsScreenModsPanel" then
                local original_createChildren = panel.createChildren;
                local original_prerender = panel.prerender;

                function panel:createChildren()
                    original_createChildren(self);
                    layoutModsPanel(self);
                end

                function panel:prerender()
                    if self.button and not self.button:isVisible() then
                        self.button:setVisible(true);
                    end
                    original_prerender(self);
                end

                function panel:onResolutionChange()
                    layoutModsPanel(self);
                end

                if not panel.button then
                    local buttonWid = UI_BORDER_SPACING * 2 + getTextManager():MeasureStringX(UIFont.Medium, getText("UI_NewGame_ChooseMods"));
                    panel.button = ISButton:new(0, 0, buttonWid, BUTTON_HGT, getText("UI_NewGame_ChooseMods"), panel, onModsPanelButtonChoose);
                    panel.button:initialise();
                    panel.button.borderColor = {r=1, g=1, b=1, a=0.2};
                    panel.button:setFont(UIFont.Medium);
                    panel:addChild(panel.button);
                    panel:addJoypadColumn({ panel.button });
                    layoutModsPanel(panel);
                end
                panel.button:setOnClick(onModsPanelButtonChoose, panel);

                local warningTexture = getTexture("media/ui/ModManager/Icons/Warning_" .. FONT_HGT_SMALL ..".png");
                panel.listbox.mouseOverButtonIndex = nil;
                panel.listbox.modsPanel = panel;

                function panel.listbox:doDrawItem(y, item, _)
                    self:drawRectBorder(0, y, self:getWidth(), self.itemheight - 1, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b);

                    if self.selected == item.index then
                        self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15);
                    elseif self.mouseoverselected == item.index and not self:isMouseOverScrollBar() then
                        self:drawRect(1, y + 1, self:getWidth() - 2, item.height - 4, 0.95, 0.05, 0.05, 0.05);
                    end

                    local smallFontHgt = FONT_LINE_HGT_SMALL;

                    local modID = "";
                    local workshopID = nil;

                    if item.item.modInfo then
                        modID = item.item.modInfo:getId();
                        workshopID = resolveWorkshopID(modID, item.item.modInfo);
                    end

                    local isUnknown = not item.item.modInfo;

                    local textX = 8;
                    item.warningIconRect = nil;
                    if not isUnknown and (not workshopID or workshopID == "") then
                        if warningTexture then
                            local iconY = y + (self.itemheight - FONT_HGT_SMALL) / 2;
                            self:drawTextureScaledAspect(warningTexture, textX, iconY, FONT_HGT_SMALL, FONT_HGT_SMALL, 1);
                            item.warningIconRect = {x = textX, y = iconY, w = FONT_HGT_SMALL, h = FONT_HGT_SMALL};
                            textX = textX + FONT_HGT_SMALL + 6;
                        end
                    end

                    local dy = (self.itemheight - getTextManager():getFontFromEnum(self.font):getLineHeight()) / 2;
                    if isUnknown then
                        self:drawText(item.text, textX, y + dy, 0.9, 0.0, 0.0, 0.9, self.font);
                    else
                        self:drawText(item.text, textX, y + dy, 0.9, 0.9, 0.9, 0.9, self.font);
                    end

                    local x = textX + getTextManager():MeasureStringX(self.font, item.text) + 8;
                    dy = (self.itemheight - smallFontHgt) / 2;

                    if modID and modID ~= "" then
                        self:drawText("[" .. modID .. "]", x, y + dy, 0.6, 0.6, 0.6, 0.9, UIFont.Small);
                        x = x + getTextManager():MeasureStringX(UIFont.Small, "[" .. modID .. "]") + 4;
                    else
                        self:drawText("[" .. getText("UI_modselector_UnknownMod") .. "]", x, y + dy, 0.6, 0.6, 0.6, 0.9, UIFont.Small);
                        x = x + getTextManager():MeasureStringX(UIFont.Small, "[" .. getText("UI_modselector_UnknownMod") .. "]") + 4;
                    end

                    if workshopID and workshopID ~= "" then
                        self:drawText("[" .. workshopID .. "]", x, y + dy, 0.6, 0.6, 0.6, 0.9, UIFont.Small);
                    end

                    if self.mouseoverselected == item.index and not self:isMouseOverScrollBar() then
                        local textRemove = getText("UI_btn_remove");
                        local textRemoveWid = getTextManager():MeasureStringX(UIFont.Small, textRemove);
                        local btnWid = 8 + textRemoveWid + 8;
                        local btnHgt = smallFontHgt + 4;
                        local scrollBarWid = self:isVScrollBarVisible() and 13 or 0;
                        local btnX = self.width - 4 - scrollBarWid - btnWid;
                        local btnY = y + (item.height - btnHgt) / 2;
                        local isMouseOverButton = (self:getMouseX() > btnX - 8);
                        if isMouseOverButton then
                            self:drawRect(btnX, btnY, btnWid, btnHgt, 1, 0.85, 0, 0);
                            self.mouseOverButtonIndex = item.index;
                        else
                            self:drawRect(btnX, btnY, btnWid, btnHgt, 1, 0.50, 0.50, 0.50);
                        end
                        self:drawTextCentre(textRemove, btnX + btnWid / 2, y + (item.height - smallFontHgt) / 2, 0, 0, 0, 1, UIFont.Small);
                    end

                    return y + item.height
                end

                function panel.listbox:prerender()
                    self.mouseOverButtonIndex = nil;
                    ISScrollingListBox.prerender(self);

                    local shouldShow = false;
                    if self.mouseoverselected and self.mouseoverselected > 0 then
                        local item = self.items[self.mouseoverselected];
                        if item and item.warningIconRect then
                            local mx = self:getMouseX();
                            local my = self:getMouseY();
                            local r = item.warningIconRect;
                            if mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h then
                                shouldShow = true;
                                local tooltipText = getText("UI_modselector_LocalMod_tooltip");
                                if not self.warningToolTip then
                                    self.warningToolTip = ISToolTip:new();
                                    self.warningToolTip:initialise();
                                    self.warningToolTip:setVisible(true);
                                    self.warningToolTip:setDescription(tooltipText);
                                    self.warningToolTip:addToUIManager();
                                else
                                    self.warningToolTip:setDescription(tooltipText);
                                end
                                self.warningToolTip:setX(self:getAbsoluteX() + mx + 10);
                                self.warningToolTip:setY(self:getAbsoluteY() + my);
                            end
                        end
                    end

                    if not shouldShow and self.warningToolTip then
                        self.warningToolTip:removeFromUIManager();
                        self.warningToolTip = nil;
                    end
                end

                function panel.listbox:onMouseDown(x, y)
                    if self.mouseOverButtonIndex then
                        local item = self.items[self.mouseOverButtonIndex];
                        if item and self.modsPanel then
                            self:removeItemByIndex(self.mouseOverButtonIndex);
                            self.currentItem = nil;

                            local modIDList = {};
                            for _, listItem in ipairs(self.items) do
                                table.insert(modIDList, listItem.item.modID);
                            end

                            local settings = self.modsPanel.pageEdit.settings;
                            local addedMods, removedMods = updateServerSettingsMods(settings, modIDList);
                            applyModsDiff(self.modsPanel.pageEdit, settings, addedMods, removedMods);
                        end
                    else
                        ISScrollingListBox.onMouseDown(self, x, y);
                    end
                end
            elseif panel.Type == "ServerSettingsScreenMapsPanel" then
                local original_createChildren = panel.createChildren;
                local original_setSettings = panel.setSettings;

                function panel:createChildren()
                    original_createChildren(self);
                    layoutMapsPanel(self);
                    if self.buttonRemove then
                        self.multiColumnUI[2] = { self.buttonMoveUp, self.buttonMoveDown };
                    end
                end

                function panel:onResolutionChange()
                    layoutMapsPanel(self);
                end

                function panel:setSettings(settings)
                    original_setSettings(self, settings);
                    local modsString = settings:getServerOptions():getOptionByName("Mods"):getValue();
                    self:fillComboBox(modsString);
                end

                function panel:canMoveUp()
                    if self.listbox.selected <= 1 then return false end
                    local mapFolder = self.listbox.items[self.listbox.selected].item.mapFolder;
                    local modsString = self.settings:getServerOptions():getOptionByName("Mods"):getValue();
                    local prevFolder = self.listbox.items[self.listbox.selected - 1].item.mapFolder;
                    local lots = getMapLots(prevFolder, modsString);
                    if lots then
                        for _, lot in ipairs(lots) do
                            if lot == mapFolder then return false end
                        end
                    end
                    return true
                end

                function panel:canMoveDown()
                    if self.listbox.selected >= #self.listbox.items then return false end
                    local mapFolder = self.listbox.items[self.listbox.selected].item.mapFolder;
                    local modsString = self.settings:getServerOptions():getOptionByName("Mods"):getValue();
                    local nextFolder = self.listbox.items[self.listbox.selected + 1].item.mapFolder;
                    local lots = getMapLots(mapFolder, modsString);
                    if lots then
                        for _, lot in ipairs(lots) do
                            if lot == nextFolder then return false end
                        end
                    end
                    return true
                end

                function panel:onButtonMoveUp()
                    if not self:canMoveUp() then return end
                    local index = self.listbox.selected;
                    local item = self.listbox.items[index].item;
                    self.listbox:removeItemByIndex(index);
                    self.listbox:insertItem(index - 1, item.mapFolder, item);
                    self.listbox.selected = index - 1;
                    self.listbox:ensureVisible(self.listbox.selected);
                end

                function panel:onButtonMoveDown()
                    if not self:canMoveDown() then return end
                    local index = self.listbox.selected;
                    local item = self.listbox.items[index].item;
                    self.listbox:removeItemByIndex(index);
                    self.listbox:insertItem(index + 1, item.mapFolder, item);
                    self.listbox.selected = index + 1;
                    self.listbox:ensureVisible(self.listbox.selected);
                end

                function panel:prerender()
                    ISPanelJoypad.prerender(self);
                    self.buttonMoveUp:setEnable(self:canMoveUp());
                    self.buttonMoveDown:setEnable(self:canMoveDown());
                end

                function panel:fillComboBox(modsString)
                    self.comboBox.options = {};
                    if not self:findMapInList("Muldraugh, KY") then
                        self.comboBox:addOption("Muldraugh, KY");
                    end
                    local modIDs = string.split(modsString, ";");
                    for _, modID in ipairs(modIDs) do
                        local modInfo = nil;
                        if modID ~= "" then
                            modInfo = getModInfoByID(modID);
                        end
                        if modInfo then
                            local mapFolders = getMapFoldersForMod(modID);
                            if mapFolders then
                                for i = 1, mapFolders:size() do
                                    local mapFolder = mapFolders:get(i - 1);
                                    if not self:findMapInList(mapFolder) then
                                        self.comboBox:addOption(mapFolder);
                                    end
                                end
                            end
                        end
                    end
                    if #self.comboBox.options == 0 then
                        self.comboBox:addOption("");
                        self.comboBox:setEnabled(false);
                    else
                        self.comboBox:setEnabled(true);
                    end
                    self.comboBox.selected = 1;
                end

                function panel:onAddInstalledMap()
                    local mapFolder = self.comboBox.options[self.comboBox.selected];
                    if self:findMapInList(mapFolder) then return end
                    self:addMapToList(mapFolder, 1);
                    local modsString = self.pageEdit and self.pageEdit.settings and self.pageEdit.settings:getServerOptions():getOptionByName("Mods"):getValue() or nil;
                    ensureLotsForMap(self, mapFolder, 2, modsString);
                    self.listbox.selected = 1;
                    self.listbox:ensureVisible(1);
                    self.pageEdit:notify("addedMap", mapFolder);
                    self:fillComboBox(modsString);
                end

                function panel:addMapsForMods(modIDs, modsString, addedMaps)
                    for _, modID in ipairs(modIDs) do
                        local mapFolders = getMapFoldersForMod(modID);
                        if mapFolders then
                            local insertAt = 1;
                            for i = 1, mapFolders:size() do
                                local mapFolder = mapFolders:get(i - 1);
                                if not self:findMapInList(mapFolder) then
                                    self:addMapToList(mapFolder, insertAt);
                                    insertAt = insertAt + 1;
                                    insertAt = ensureLotsForMap(self, mapFolder, insertAt, modsString, addedMaps);
                                    self.listbox.selected = 1;
                                    self.listbox:ensureVisible(self.listbox.selected);
                                    table.insert(addedMaps, mapFolder);
                                end
                            end
                        end
                    end
                end

                function panel:removeMapsForMods(modIDs, removedMaps)
                    for _, modID in ipairs(modIDs) do
                        local mapFolders = getMapFoldersForMod(modID);
                        if mapFolders then
                            for i = 1, mapFolders:size() do
                                local mapFolder = mapFolders:get(i - 1);
                                local index = self:findMapInList(mapFolder);
                                while index do
                                    self.listbox:removeItemByIndex(index);
                                    index = self:findMapInList(mapFolder);
                                end
                                table.insert(removedMaps, mapFolder);
                            end
                        end
                    end
                end

                function panel:removeDependentMaps(modsString, removedMaps)
                    local changed = true;
                    while changed do
                        changed = false;
                        for i = #self.listbox.items, 1, -1 do
                            local mapFolder = self.listbox.items[i].item.mapFolder;
                            local lots = getMapLots(mapFolder, modsString);
                            if lots then
                                for _, lot in ipairs(lots) do
                                    if not self:findMapInList(lot) then
                                        self.listbox:removeItemByIndex(i);
                                        table.insert(removedMaps, mapFolder);
                                        changed = true;
                                        break
                                    end
                                end
                            end
                        end
                    end
                end

                if panel.comboBox then
                    panel.comboBox.target = panel;
                    panel.comboBox.onChange = panel.onAddInstalledMap;
                end
                panel.buttonMoveUp:setOnClick(panel.onButtonMoveUp, panel);
                panel.buttonMoveDown:setOnClick(panel.onButtonMoveDown, panel);


                function panel:notify(message, arg1, arg2)
                    if message == "addedMod" then
                        local addedMaps = {};
                        self:addMapsForMods({ arg1 }, arg2, addedMaps);
                        for _, mapFolder in ipairs(addedMaps) do
                            self.pageEdit:notify("addedMap", mapFolder);
                        end
                        self:fillComboBox(arg2);
                    elseif message == "addedMods" then
                        local addedMaps = {};
                        self:addMapsForMods(arg1, arg2, addedMaps);
                        if #addedMaps > 0 then
                            self.pageEdit:notify("addedMaps", addedMaps);
                        end
                        self:fillComboBox(arg2);
                    elseif message == "removedMod" then
                        local removedMaps = {};
                        self:removeMapsForMods({ arg1 }, removedMaps);
                        for _, mapFolder in ipairs(removedMaps) do
                            self.pageEdit:notify("removedMap", mapFolder);
                        end
                        self:fillComboBox(arg2);
                    elseif message == "removedMods" then
                        local removedMaps = {};
                        self:removeMapsForMods(arg1, removedMaps);
                        if #removedMaps > 0 then
                            self.pageEdit:notify("removedMaps", removedMaps);
                        end
                        self:fillComboBox(arg2);
                    elseif message == "removedMap" then
                        local modsString = self.pageEdit and self.pageEdit.settings and self.pageEdit.settings:getServerOptions():getOptionByName("Mods"):getValue() or nil;
                        local removedMaps = {};
                        self:removeDependentMaps(modsString, removedMaps);
                        for _, mapFolder in ipairs(removedMaps) do
                            self.pageEdit:notify("removedMap", mapFolder);
                        end
                        self:fillComboBox(modsString);
                    elseif message == "removedMaps" then
                        local modsString = self.pageEdit and self.pageEdit.settings and self.pageEdit.settings:getServerOptions():getOptionByName("Mods"):getValue() or nil;
                        local removedMaps = {};
                        self:removeDependentMaps(modsString, removedMaps);
                        if #removedMaps > 0 then
                            self.pageEdit:notify("removedMaps", removedMaps);
                        end
                        self:fillComboBox(modsString);
                    end
                end

            elseif panel.Type == "SpawnRegionsPanel" then
                local buttonWid = UI_BORDER_SPACING * 2 + math.max(
                    getTextManager():MeasureStringX(UIFont.Medium, getText("UI_ServerSettings_ButtonMoveUp")),
                    getTextManager():MeasureStringX(UIFont.Medium, getText("UI_ServerSettings_ButtonMoveDown"))
                );

                local button = ISButton:new(0, 0, buttonWid, BUTTON_HGT, getText("UI_ServerSettings_ButtonMoveUp"), panel, nil);
                button:initialise();
                button.borderColor = {r=1, g=1, b=1, a=0.2};
                button:setFont(UIFont.Medium);
                panel:addChild(button);
                panel.buttonMoveUp = button;

                button = ISButton:new(0, 0, buttonWid, BUTTON_HGT, getText("UI_ServerSettings_ButtonMoveDown"), panel, nil);
                button:initialise();
                button.borderColor = {r=1, g=1, b=1, a=0.2};
                button:setFont(UIFont.Medium);
                panel:addChild(button);
                panel.buttonMoveDown = button;

                local fontHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight();

                local listTitleLabel = ISLabel:new(UI_BORDER_SPACING, 0, fontHgt, getText("UI_ServerSettings_SpawnRegions"), 1, 1, 1, 1, UIFont.Medium, true);
                panel:addChild(listTitleLabel);
                panel.listTitleLabel = listTitleLabel;

                local comboTitleLabel = ISLabel:new(UI_BORDER_SPACING, 0, fontHgt, getText("UI_ServerSettings_AddSpawnRegion"), 1, 1, 1, 1, UIFont.Medium, true);
                panel:addChild(comboTitleLabel);
                panel.spawnTitleLabel = comboTitleLabel;

                local entryTitleLabel = ISLabel:new(UI_BORDER_SPACING, 0, fontHgt, getText("UI_ServerOption_SpawnPoint"), 1, 1, 1, 1, UIFont.Medium, true);
                panel:addChild(entryTitleLabel);
                panel.entryTitleLabel = entryTitleLabel;

                local comboBox = ISComboBox:new(UI_BORDER_SPACING, 0, 100, fontHgt + 4, panel, nil);
                panel:addChild(comboBox);
                panel.spawnComboBox = comboBox;

                layoutSpawnRegionsPanel(panel);

                if panel.buttonAdd then panel.buttonAdd:setVisible(false); end
                if panel.buttonRemove then panel.buttonRemove:setVisible(false); end
                if panel.listbox.entryName then panel.listbox.entryName:setVisible(false); end
                if panel.listbox.entryFile then panel.listbox.entryFile:setVisible(false); end
                if panel.nameFilePanel then panel.nameFilePanel:setVisible(false); end

                panel.multiColumnUI[2] = { panel.buttonMoveUp, panel.buttonMoveDown };

                function panel:onResolutionChange()
                    layoutSpawnRegionsPanel(self);
                end

                function panel:onButtonMoveUp()
                    if self.listbox.selected > 1 then
                        local index = self.listbox.selected;
                        local item = self.listbox.items[index].item;
                        self.listbox:removeItemByIndex(index);
                        local newItem = { name = item.name, file = item.file };
                        self.listbox:insertItem(index - 1, item.name, newItem);
                        self.listbox.selected = index - 1;
                        self.listbox:ensureVisible(index - 1);
                    end
                end

                function panel:onButtonMoveDown()
                    if self.listbox.selected < #self.listbox.items then
                        local index = self.listbox.selected;
                        local item = self.listbox.items[index].item;
                        self.listbox:removeItemByIndex(index);
                        local newItem = { name = item.name, file = item.file };
                        self.listbox:insertItem(index + 1, item.name, newItem);
                        self.listbox.selected = index + 1;
                        self.listbox:ensureVisible(index + 1);
                    end
                end

                function panel:onAddInstalledSpawnRegion()
                    local mapFolder = self.spawnComboBox.options[self.spawnComboBox.selected];
                    if findSpawnRegionInList(self, mapFolder) then return end
                    self:addToList(mapFolder, "media/maps/" .. mapFolder .. "/spawnpoints.lua");
                    self.listbox.selected = #self.listbox.items;
                    self.listbox:ensureVisible(self.listbox.selected);
                    local modsString = self.settings:getServerOptions():getOptionByName("Mods"):getValue();
                    fillSpawnRegionsComboBox(self, modsString);
                end

                panel.buttonMoveUp.onclick = panel.onButtonMoveUp;
                panel.buttonMoveDown.onclick = panel.onButtonMoveDown;
                panel.spawnComboBox.target = panel;
                panel.spawnComboBox.onChange = panel.onAddInstalledSpawnRegion;

                function panel:prerender()
                    ISPanelJoypad.prerender(self);
                    self.buttonMoveUp:setEnable(self.listbox.selected > 1);
                    self.buttonMoveDown:setEnable(self.listbox.selected < #self.listbox.items);
                end

                function panel:setSettings(settings)
                    self.settings = settings;
                    self.listbox.currentItem = nil;
                    self.listbox:clear();
                    for i = 1, settings:getNumSpawnRegions() do
                        local name = settings:getSpawnRegionName(i - 1);
                        local file = settings:getSpawnRegionFile(i - 1);
                        if isVanillaMap(name) then
                            local info = getMapInfo(name);
                            if info and not (info.only_for_game_mode and info.only_for_game_mode ~= "Multiplayer") then
                                self:addToList(name, file);
                            end
                        else
                            self:addToList(name, file);
                        end
                    end
                    self.entry:setText(settings:getServerOptions():getOptionByName("SpawnPoint"):getValue());
                    local modsString = settings:getServerOptions():getOptionByName("Mods"):getValue();
                    fillSpawnRegionsComboBox(self, modsString);
                end

                function panel:settingsFromUI()
                    self.settings:clearSpawnRegions();
                    for i = 1, #self.listbox.items do
                        local item = self.listbox.items[i].item;
                        self.settings:addSpawnRegion(item.name, item.file);
                    end
                    self.settings:getServerOptions():getOptionByName("SpawnPoint"):setValue(self.entry:getText());
                end

                function panel:addSpawnRegionsForMaps(mapFolders)
                    for _, mapFolder in ipairs(mapFolders) do
                        if mapFolder == "Muldraugh, KY" then
                            for _, vanillaFolder in ipairs(getVanillaMapFolders()) do
                                if not findSpawnRegionInList(self, vanillaFolder) then
                                    self:addToList(vanillaFolder, "media/maps/" .. vanillaFolder .. "/spawnpoints.lua");
                                end
                            end
                        elseif not isVanillaMap(mapFolder) then
                            if not findSpawnRegionInList(self, mapFolder) then
                                self:addToList(mapFolder, "media/maps/" .. mapFolder .. "/spawnpoints.lua");
                            end
                        end
                    end
                end

                function panel:removeSpawnRegionsForMaps(mapFolders)
                    for _, mapFolder in ipairs(mapFolders) do
                        if mapFolder == "Muldraugh, KY" then
                            for i = #self.listbox.items, 1, -1 do
                                if isVanillaMap(self.listbox.items[i].item.name) then
                                    self.listbox.currentItem = nil;
                                    self.listbox:removeItemByIndex(i);
                                end
                            end
                        elseif not isVanillaMap(mapFolder) then
                            local index = findSpawnRegionInList(self, mapFolder);
                            if index then
                                self.listbox.currentItem = nil;
                                self.listbox:removeItemByIndex(index);
                            end
                        end
                    end
                end

                function panel:notify(message, arg1, arg2)
                    if message == "addedMap" then
                        self:addSpawnRegionsForMaps({ arg1 });
                        local modsString = self.settings:getServerOptions():getOptionByName("Mods"):getValue();
                        fillSpawnRegionsComboBox(self, modsString);
                    elseif message == "addedMaps" then
                        self:addSpawnRegionsForMaps(arg1);
                        local modsString = self.settings:getServerOptions():getOptionByName("Mods"):getValue();
                        fillSpawnRegionsComboBox(self, modsString);
                    elseif message == "removedMap" then
                        self:removeSpawnRegionsForMaps({ arg1 });
                        local modsString = self.settings:getServerOptions():getOptionByName("Mods"):getValue();
                        fillSpawnRegionsComboBox(self, modsString);
                    elseif message == "removedMaps" then
                        self:removeSpawnRegionsForMaps(arg1);
                        local modsString = self.settings:getServerOptions():getOptionByName("Mods"):getValue();
                        fillSpawnRegionsComboBox(self, modsString);
                    elseif message == "addedMod" then
                        fillSpawnRegionsComboBox(self, arg2);
                    elseif message == "addedMods" then
                        fillSpawnRegionsComboBox(self, arg2);
                    elseif message == "removedMod" then
                        fillSpawnRegionsComboBox(self, arg2);
                    elseif message == "removedMods" then
                        fillSpawnRegionsComboBox(self, arg2);
                    end
                end

                panel.listbox:setFont("Medium", 4);

                function panel.listbox:doDrawItem(y, item, _)
                    self:drawRectBorder(0, y, self:getWidth(), self.itemheight - 1, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b);

                    if self.selected == item.index then
                        self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15);
                    elseif self.mouseoverselected == item.index and not self:isMouseOverScrollBar() then
                        self:drawRect(1, y + 1, self:getWidth() - 2, item.height - 4, 0.95, 0.05, 0.05, 0.05);
                    end

                    local dy = (self.itemheight - getTextManager():getFontFromEnum(self.font):getLineHeight()) / 2;
                    self:drawText(item.item.name, 8, y + dy, 0.9, 0.9, 0.9, 0.9, self.font);

                    if self.mouseoverselected == item.index and not self:isMouseOverScrollBar() then
                        local smallFontHgt = FONT_LINE_HGT_SMALL;
                        local textRemove = getText("UI_btn_remove");
                        local textRemoveWid = getTextManager():MeasureStringX(UIFont.Small, textRemove);
                        local btnWid = 8 + textRemoveWid + 8;
                        local btnHgt = smallFontHgt + 4;
                        local scrollBarWid = self:isVScrollBarVisible() and 13 or 0;
                        local btnX = self.width - 4 - scrollBarWid - btnWid;
                        local btnY = y + (item.height - btnHgt) / 2;
                        local isMouseOverButton = (self:getMouseX() > btnX - 8);
                        if isMouseOverButton then
                            self:drawRect(btnX, btnY, btnWid, btnHgt, 1, 0.85, 0, 0);
                            self.mouseOverButtonIndex = item.index;
                        else
                            self:drawRect(btnX, btnY, btnWid, btnHgt, 1, 0.50, 0.50, 0.50);
                        end
                        self:drawTextCentre(textRemove, btnX + btnWid / 2, y + (item.height - smallFontHgt) / 2, 0, 0, 0, 1, UIFont.Small);
                    end

                    return y + item.height
                end

                panel.listbox.mouseOverButtonIndex = nil;
                panel.listbox.spawnPanel = panel;

                function panel.listbox:prerender()
                    self.mouseOverButtonIndex = nil;
                    ISScrollingListBox.prerender(self);
                end

                function panel.listbox:onMouseDown(x, y)
                    if self.mouseOverButtonIndex then
                        self:removeItemByIndex(self.mouseOverButtonIndex);
                        self.currentItem = nil;
                        if self.spawnPanel then
                            local modsString = self.spawnPanel.settings:getServerOptions():getOptionByName("Mods"):getValue();
                            fillSpawnRegionsComboBox(self.spawnPanel, modsString);
                        end
                    else
                        ISScrollingListBox.onMouseDown(self, x, y);
                    end
                end
            end
        end
    end
end

---@diagnostic disable: need-check-nil
Events.OnMainMenuEnter.Add(function()
    local pageEdit = ServerSettingsScreen.instance.pageEdit;
    local chooseModsWindow = pageEdit.chooseModsWindow;

    chooseModsWindow.onButtonNext = function(self_)
        self_:setVisible(false);

        local activeMods = ActiveMods.getById("serversettings");
        local modArray = activeMods:getMods();
        modArray:clear();
        local modIDList = {};
        for _, item in ipairs(self_.listbox.items) do
            modArray:add(item.item.modID);
            table.insert(modIDList, item.item.modID);
        end

        local addedMods, removedMods = updateServerSettingsMods(self_.settings, modIDList);

        self_.parent.pageEdit.settings = self_.settings;
        self_.parent.pageEdit:aboutToShow();
        self_.parent.pageEdit:setVisible(true, self_.joyfocus);

        applyModsDiff(self_.parent.pageEdit, self_.settings, addedMods, removedMods);

        local modsPanel = nil;
        for _, panel in ipairs(self_.parent.pageEdit.customui) do
            if panel.Type == "ServerSettingsScreenModsPanel" then
                modsPanel = panel;
                break
            end
        end

        modsPanel.listbox:clear();
        for i = 0, modArray:size() - 1 do
            local item = {};
            item.modID = modArray:get(i);
            item.modInfo = modsPanel.modInfoByID[modArray:get(i)];
            if item.modInfo then
                modsPanel.listbox:addItem(item.modInfo:getName(), item);
            else
                modsPanel.listbox:addItem(item.modID, item);
            end
        end
    end
    chooseModsWindow.buttonAccept:setOnClick(chooseModsWindow.onButtonNext, chooseModsWindow);

    pageEdit.onButtonCancel = function(self_)
        self_:setVisible(false);
        self_.parent.pageStart:setVisible(true, JoypadState.getMainMenuJoypad());
    end
    pageEdit.buttonCancel:setOnClick(pageEdit.onButtonCancel, pageEdit);

    pageEdit.onButtonSave = function(self_)
        self_:settingsFromUI();
        self_.settings:saveFiles();
        self_:setVisible(false);
        self_.parent.initialSelectedSettings = self_.settings:getName();
        self_.parent.pageStart:aboutToShow();
        self_.parent.pageStart:setVisible(true, JoypadState.getMainMenuJoypad());
    end
    pageEdit.buttonAccept:setOnClick(pageEdit.onButtonSave, pageEdit);
end);