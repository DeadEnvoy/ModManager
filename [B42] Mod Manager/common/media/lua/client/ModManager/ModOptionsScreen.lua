require "ISUI/ISPanelJoypad"
require "ISUI/ISButton"
require "ISUI/ISControllerTestPanel"
require "ISUI/ISVolumeControl"
require "ISUI/ISDuplicateKeybindDialog"
require "ISUI/ISSetKeybindDialog"
require "OptionScreens/MainOptions"
require "PZAPI/ModOptions"

function PZAPI.ModOptions.Options:addImage(imagePath, secondParam)
    local option = { type = "image", path = imagePath, fit = false, minWidth = nil }
    if type(secondParam) == "boolean" then
        option.fit = secondParam
    elseif type(secondParam) == "number" then
        option.fit = false
        option.minWidth = secondParam
    end
    table.insert(self.data, option)
    return option
end

function MainOptions:addModOptionsPanel() end

-- ==============================================================================
-- CONSTANTS AND CONFIGURATION
-- ==============================================================================

local ModOptionsConstants = {
    FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small),
    FONT_HGT_TITLE = getTextManager():getFontFromEnum(UIFont.Title):getLineHeight(),
    FONT_HGT_MEDIUM = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight(),
    UI_BORDER_SPACING = 10,
    JOYPAD_TEX_SIZE = 32,
    
    BUTTON_HGT = nil, -- Calculated below
    ENTRY_HGT = nil,  -- Calculated below
    CONTROL_WIDTH = 150 + ((getCore():getOptionFontSizeReal() - 1) * 50),
    
    SORT_BY_NAME = 1,
    SORT_BY_DATE = 2,
    
    DEFAULT_COLOR = { r = 1, g = 1, b = 1, a = 1 },
    SEARCH_HIGHLIGHT_COLOR = { r = 0, g = 0.9, b = 0 },
    NORMAL_TEXT_COLOR = { r = 0.9, g = 0.9, b = 0.9 }
}

ModOptionsConstants.BUTTON_HGT = ModOptionsConstants.FONT_HGT_SMALL + 6
ModOptionsConstants.ENTRY_HGT = ModOptionsConstants.FONT_HGT_MEDIUM + 6

-- ==============================================================================
-- UTILITY FUNCTIONS MODULE
-- ==============================================================================

local ModOptionsUtils = {}

function ModOptionsUtils.safeGetText(key, fallback)
    if not key then return fallback or "" end
    local success, result = pcall(getText, key)
    return success and result or (fallback or key)
end

function ModOptionsUtils.safeGetKeyName(keyCode)
    if not keyCode or keyCode <= 0 then
        return "None"
    end
    
    local success, result = pcall(getKeyName, keyCode)
    if success and result then
        return result
    end
    return "Invalid Key (" .. tostring(keyCode) .. ")"
end

function ModOptionsUtils.safeToNumber(value, defaultValue)
    if not value then return defaultValue or 0 end
    local num = tonumber(value)
    return num or (defaultValue or 0)
end

function ModOptionsUtils.safeTrim(str)
    if not str then return "" end
    return string.gsub(str, "^%s*(.-)%s*$", "%1")
end

function ModOptionsUtils.deepCopy(original)
    if type(original) ~= 'table' then return original end
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = ModOptionsUtils.deepCopy(value)
    end
    return copy
end

function ModOptionsUtils.validateOption(option)
    if not option or type(option) ~= 'table' then
        return false, "Option must be a table"
    end
    
    if not option.type then
        return false, "Option must have a type"
    end
    
    if not option.name and option.type ~= "separator" and option.type ~= "image" then
        return false, "Option must have a name (except separators and images)"
    end
    
    return true, nil
end

-- ==============================================================================
-- KEYBIND DIALOG ENHANCEMENTS
-- ==============================================================================

local KeybindDialogManager = {}

function KeybindDialogManager.enhanceDialogs() 
    local originalOnKeep = ISDuplicateKeybindDialog.onKeep
    local originalOnClear = ISDuplicateKeybindDialog.onClear
    local originalNew = ISDuplicateKeybindDialog.new
    local originalInitialise = ISDuplicateKeybindDialog.initialise
    
    function ISDuplicateKeybindDialog:onKeep(...)
        originalOnKeep(self, ...)
        if self.onKeepCallback then
            self:onKeepCallback()
        end
        self:destroy()
    end
    
    function ISDuplicateKeybindDialog:onClear(...)
        originalOnClear(self, ...)
        if self.onKeepCallback then
            self:onKeepCallback()
        end
        self:destroy()
    end
    
    function ISDuplicateKeybindDialog:new(key, keybindName, keybind2Name, shift, ctrl, alt, onKeepCallback)
        local o = originalNew(self, key, keybindName, keybind2Name, shift, ctrl, alt)
        o.onKeepCallback = onKeepCallback
        return o
    end
    
    function ISDuplicateKeybindDialog:initialise(...)
        originalInitialise(self, ...)
        if ModOptionsScreen.instance and self.label and ModOptionsScreen.instance:getModKeybind(self.keybind2Name) then
            local text = ModOptionsUtils.safeGetText("UI_optionscreen_keyAlreadyBinded", "Key {0} is already bound to {1}")
            text = string.format(text, ModOptionsUtils.safeGetKeyName(self.key), 
                ModOptionsUtils.safeGetText(self.keybind2Name))
            self.label:setText(text:gsub("\\n", "\n"):gsub("\\\"", "\""))
        end
    end
end

function KeybindDialogManager.enhanceSetKeybindDialog()
    local originalOnClear = ISSetKeybindDialog.onClear
    local originalOnDefault = ISSetKeybindDialog.onDefault
    
    function ISSetKeybindDialog:onClear(...)
        if self.isModBind and ModOptionsScreen.instance then
            ModOptionsScreen.instance:setModKeybind(self.keybindName, 0)
            self:destroy()
            return
        end
        return originalOnClear(self, ...)
    end
    
    function ISSetKeybindDialog:onDefault(...)
        if self.isModBind and ModOptionsScreen.instance then
            local keyBinded = ModOptionsScreen.instance:getModKeybind(self.keybindName)
            if keyBinded and keyBinded.defaultkey then
                ModOptionsScreen.instance:setModKeybind(self.keybindName, keyBinded.defaultkey)
            else
                ModOptionsScreen.instance:setModKeybind(self.keybindName, 0)
            end
            self:destroy()
            return
        end
        return originalOnDefault(self, ...)
    end
end

KeybindDialogManager.enhanceDialogs()
KeybindDialogManager.enhanceSetKeybindDialog()

-- ==============================================================================
-- HORIZONTAL LINE UI COMPONENT
-- ==============================================================================

local HorizontalLine = ISPanel:derive("HorizontalLine")

function HorizontalLine:render()
    self:drawRect(0, 0, self.width, 1, 1.0, 0.5, 0.5, 0.5)
end

function HorizontalLine:new(x, y, width)
    return ISPanel.new(self, x, y, width, 2)
end

-- ==============================================================================
-- MOD MANAGER OPTION CLASS
-- ==============================================================================

local ModManagerOption = ISBaseObject:derive("ModManagerOption")

function ModManagerOption:new(name, control)
    if not name or not control then
        error("ModManagerOption requires both name and control parameters")
    end
    
    local o = ISBaseObject.new(self)
    o.name = name
    o.control = control
    
    o:setupControlHandlers()
    
    return o
end

function ModManagerOption:setupControlHandlers()
    if not self.control then return end
    
    if self.control.isCombobox then
        self.control.onChange = self.onChangeComboBox
        self.control.target = self
    end
    
    if self.control.isTickBox then
        self.control.changeOptionMethod = self.onChangeTickBox
        self.control.changeOptionTarget = self
    end
    
    if self.control.Type == "ISTextEntryBox" then
        self.control.onTextChange = function()
            if self.gameOptions then
                self.gameOptions:onChange(self)
            end
            if self.onChange then
                self:onChange(self.control:getInternalText())
            end
        end
    end
    
    if self.control.Type == "ISSliderPanel" then
        self.control.target = self
        self.control.onValueChange = function(control, val)
            if control.gameOptions then
                control.gameOptions:onChange(control)
            end
            if control.onChange then
                control:onChange(val)
            end
        end
    end
end

function ModManagerOption:onChangeComboBox(box)
    if self.gameOptions then
        self.gameOptions:onChange(self)
    end
    if self.onChange then
        self:onChange(box)
    end
end

function ModManagerOption:onChangeTickBox(index, selected)
    if self.gameOptions then
        self.gameOptions:onChange(self)
    end
    if self.onChange then
        self:onChange(index, selected)
    end
end

-- ==============================================================================
-- MOD MANAGER OPTIONS COLLECTION CLASS
-- ==============================================================================

local ModManagerOptions = ISBaseObject:derive("ModManagerOptions")

function ModManagerOptions:new()
    local o = ISBaseObject.new(self)
    o.options = {}
    o.changed = false
    return o
end

function ModManagerOptions:add(option)
    if not option then
        error("Cannot add nil option to ModManagerOptions")
    end
    
    option.gameOptions = self
    table.insert(self.options, option)
end

function ModManagerOptions:get(optionName)
    if not optionName then return nil end
    
    for _, option in ipairs(self.options) do
        if option.name == optionName then
            return option
        end
    end
    return nil
end

function ModManagerOptions:apply()
    for _, option in ipairs(self.options) do
        if option.apply then
            local success, error = pcall(option.apply, option)
            if not success then
                print("Error applying option " .. tostring(option.name) .. ": " .. tostring(error))
            end
        end
    end
    self.changed = false
end

function ModManagerOptions:toUI()
    for _, option in ipairs(self.options) do
        if option.toUI then
            local success, error = pcall(option.toUI, option)
            if not success then
                print("Error updating UI for option " .. tostring(option.name) .. ": " .. tostring(error))
            end
        end
    end
    self.changed = false
end

function ModManagerOptions:onChange(option)
    self.changed = true
end

-- ==============================================================================
-- CUSTOM LISTBOX FOR MOD OPTIONS
-- ==============================================================================

local ModOptionsScreenListBox = ISScrollingListBox:derive("ModOptionsScreenListBox")

function ModOptionsScreenListBox:doDrawItem(y, item, alt)
    local constants = ModOptionsConstants
    
    self:drawRectBorder(0, y, self:getWidth(), self.itemheight - 1, 0.5, 
        self.borderColor.r, self.borderColor.g, self.borderColor.b)
    
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15)
    elseif self.mouseoverselected == item.index and not self:isMouseOverScrollBar() then
        self:drawRect(1, y + 1, self:getWidth() - 2, self.itemheight - 4, 0.95, 0.05, 0.05, 0.05)
    end
    
    local dx = constants.UI_BORDER_SPACING
    local dy = (self.itemheight - getTextManager():getFontFromEnum(self.font):getLineHeight()) / 2
    
    local r, g, b = constants.NORMAL_TEXT_COLOR.r, constants.NORMAL_TEXT_COLOR.g, constants.NORMAL_TEXT_COLOR.b
    if item.searchFound then
        r, g, b = constants.SEARCH_HIGHLIGHT_COLOR.r, constants.SEARCH_HIGHLIGHT_COLOR.g, constants.SEARCH_HIGHLIGHT_COLOR.b
    end
    
    self:drawText(item.text, dx, y + dy, r, g, b, 0.9, self.font)
    return y + self.itemheight
end

-- ==============================================================================
-- CUSTOM PANEL FOR MOD OPTIONS
-- ==============================================================================

local ModOptionsScreenPanel = ISPanelJoypad:derive("ModOptionsScreenPanel")

function ModOptionsScreenPanel:prerender()
    self:doRightJoystickScrolling(20, 20)
    ISPanelJoypad.prerender(self)
    
    if self.labels then
        for settingName, label in pairs(self.labels) do
            if label and label.searchFound then
                label:setColor(0, 1, 0)
            elseif label then
                label:setColor(1, 1, 1)
            end
        end
    end
    
    self:setStencilRect(1, 1, self.width - 2, self.height - 2)
end

function ModOptionsScreenPanel:render()
    self:drawRectBorderStatic(0, 0, self.width, self.height, 
        self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    ISPanelJoypad.render(self)
    self:clearStencilRect()
end

function ModOptionsScreenPanel:onMouseWheel(del)
    if self:getScrollHeight() > 0 then
        self:setYScroll(self:getYScroll() - (del * 40))
        return true
    end
    return false
end

-- ==============================================================================
-- MAIN MOD OPTIONS SCREEN CLASS
-- ==============================================================================

ModOptionsScreen = ISPanelJoypad:derive("ModOptionsScreen")

function ModOptionsScreen:new(x, y, width, height)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.2 }
    o.gameOptions = ModManagerOptions:new()
    o.modsByDateAdded = {}
    o.controls = {}
    return o
end

function ModOptionsScreen:initialise()
    ISPanelJoypad.initialise(self)
    ModOptionsScreen.instance = self
    
    self:loadModsByDateAdded()
    self:createChildren()
    
    self.originalKeyPressHandler = MainOptions.keyPressHandler
    MainOptions.keyPressHandler = function(...) self:keyPressHandler(...) end
end

function ModOptionsScreen:loadModsByDateAdded()
    self.modsByDateAdded = {}
    
    local success, file = pcall(getFileReader, "modManager.ini", true)
    if not success or not file then
        print("Warning: Could not load modManager.ini")
        return
    end
    
    local line = file:readLine()
    local inModsSection = false
    
    while line ~= nil do
        line = ModOptionsUtils.safeTrim(line)
        
        if line == "mods = {" then
            inModsSection = true
        elseif inModsSection and (line == "}" or line == "},") then
            inModsSection = false
        elseif inModsSection and line ~= "" then
            local modID = ModOptionsUtils.safeTrim(string.gsub(line, '[",]', ''))
            if modID ~= "" then
                table.insert(self.modsByDateAdded, modID)
            end
        end
        
        line = file:readLine()
    end
    
    file:close()
end

function ModOptionsScreen:getModIndex(modID)
    if not modID then return -1 end
    
    for i, id in ipairs(self.modsByDateAdded) do
        if id == "\\" .. modID then
            return i
        end
    end
    return -1
end

function ModOptionsScreen:onSortChanged()
    local wasChanged = self.gameOptions and self.gameOptions.changed or false
    
    local selectedModID = nil
    if self.listbox.selected > 0 and self.listbox.items[self.listbox.selected] then
        selectedModID = self.listbox.items[self.listbox.selected].item.page.modOptionsID
    end
    
    if self.gameOptions then
        for _, option in ipairs(self.gameOptions.options) do
            if option.apply then
                local success, error = pcall(option.apply, option)
                if not success then
                    print("Error applying option during sort: " .. tostring(error))
                end
            end
        end
    end
    
    self:sortAndRefillListbox()
    
    if selectedModID then
        for i, item in ipairs(self.listbox.items) do
            if item.item.page.modOptionsID == selectedModID then
                self.listbox.selected = i
                self:onMouseDownListbox(item.item)
                break
            end
        end
    end
    
    if wasChanged then
        self.gameOptions.changed = true
    end
end

function ModOptionsScreen:sortAndRefillListbox()
    if not self.listbox then return end
    
    self.listbox:clear()
    self.gameOptions = ModManagerOptions:new()
    
    if not PZAPI or not PZAPI.ModOptions or not PZAPI.ModOptions.Data then
        print("Warning: PZAPI.ModOptions.Data not available")
        return
    end
    
    local sortedModOptions = {}
    for _, options in ipairs(PZAPI.ModOptions.Data) do
        if options and options.modOptionsID then
            table.insert(sortedModOptions, options)
        end
    end
    
    if self.sortCombo and self.sortCombo.selected == ModOptionsConstants.SORT_BY_DATE then
        table.sort(sortedModOptions, function(a, b)
            return self:getModIndex(a.modOptionsID) > self:getModIndex(b.modOptionsID)
        end)
    else
        table.sort(sortedModOptions, function(a, b)
            local nameA = ModOptionsUtils.safeGetText(a.name, a.name or "")
            local nameB = ModOptionsUtils.safeGetText(b.name, b.name or "")
            return nameA < nameB
        end)
    end
    
    for _, options in ipairs(sortedModOptions) do
        local success, panel = pcall(self.createPanel, self, options)
        if success and panel then
            local item = {}
            item.page = options
            item.panel = panel
            local displayName = ModOptionsUtils.safeGetText(options.name, options.modOptionsID or "Unknown")
            self.listbox:addItem(displayName, item)
        else
            print("Error creating panel for mod: " .. tostring(options.modOptionsID))
        end
    end
    
    if #self.listbox.items > 0 then
        self:onMouseDownListbox(self.listbox.items[1].item)
        self.listbox.selected = 1
    end
    
    self.gameOptions:toUI()
    self:doSearch()
end

function ModOptionsScreen:createChildren()
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.load then
        local success, error = pcall(PZAPI.ModOptions.load, PZAPI.ModOptions)
        if not success then
            print("Error loading PZAPI ModOptions: " .. tostring(error))
            return
        end
    else
        print("Warning: PZAPI.ModOptions not available")
        return
    end
    
    local constants = ModOptionsConstants
    
    local btnPadding = constants.JOYPAD_TEX_SIZE + constants.UI_BORDER_SPACING * 2
    local btnWidthBack = btnPadding + getTextManager():MeasureStringX(UIFont.Small, 
        ModOptionsUtils.safeGetText("UI_btn_back", "Back"))
    local btnWidthAccept = btnPadding + getTextManager():MeasureStringX(UIFont.Small, 
        ModOptionsUtils.safeGetText("UI_btn_accept", "Accept"))
    local btnWidthApply = btnPadding + getTextManager():MeasureStringX(UIFont.Small, 
        ModOptionsUtils.safeGetText("UI_btn_apply", "Apply"))
    
    local totalBtnWidth = btnWidthBack + btnWidthAccept + btnWidthApply + constants.UI_BORDER_SPACING * 2
    local startX = (self.width - totalBtnWidth) / 2
    
    self:createButtons(startX, btnWidthBack, btnWidthAccept, btnWidthApply)
    
    local listboxWidth = self:calculateListboxWidth()
    
    self:createSortAndSearchControls(listboxWidth)
    
    self:createMainListbox(listboxWidth)
    
    self:sortAndRefillListbox()
    self.gameOptions:toUI()
end

function ModOptionsScreen:createButtons(startX, btnWidthBack, btnWidthAccept, btnWidthApply)
    local constants = ModOptionsConstants
    
    self.backButton = ISButton:new(startX, self.height - constants.UI_BORDER_SPACING - constants.BUTTON_HGT - 1, 
        btnWidthBack, constants.BUTTON_HGT, ModOptionsUtils.safeGetText("UI_btn_back", "Back"), self, self.onOptionMouseDown)
    self.backButton.internal = "BACK"
    self.backButton:initialise()
    self.backButton:instantiate()
    self.backButton:setAnchorLeft(false)
    self.backButton:setAnchorRight(false)
    self.backButton:setAnchorTop(false)
    self.backButton:setAnchorBottom(true)
    self.backButton:enableCancelColor()
    self:addChild(self.backButton)
    
    self.acceptButton = ISButton:new(self.backButton:getRight() + constants.UI_BORDER_SPACING, self.backButton.y, 
        btnWidthAccept, constants.BUTTON_HGT, ModOptionsUtils.safeGetText("UI_btn_accept", "Accept"), self, self.onOptionMouseDown)
    self.acceptButton.internal = "ACCEPT"
    self.acceptButton:initialise()
    self.acceptButton:instantiate()
    self.acceptButton:setAnchorLeft(false)
    self.acceptButton:setAnchorRight(false)
    self.acceptButton:setAnchorTop(false)
    self.acceptButton:setAnchorBottom(true)
    self.acceptButton:enableAcceptColor()
    self:addChild(self.acceptButton)
    
    self.applyButton = ISButton:new(self.acceptButton:getRight() + constants.UI_BORDER_SPACING, self.backButton.y, 
        btnWidthApply, constants.BUTTON_HGT, ModOptionsUtils.safeGetText("UI_btn_apply", "Apply"), self, self.onOptionMouseDown)
    self.applyButton.internal = "APPLY"
    self.applyButton:initialise()
    self.applyButton:instantiate()
    self.applyButton:setAnchorLeft(false)
    self.applyButton:setAnchorRight(false)
    self.applyButton:setAnchorTop(false)
    self.applyButton:setAnchorBottom(true)
    self:addChild(self.applyButton)
end

function ModOptionsScreen:calculateListboxWidth()
    local listboxWidth = 200
    
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.Data then
        for _, options in ipairs(PZAPI.ModOptions.Data) do
            if options and options.name then
                local displayName = ModOptionsUtils.safeGetText(options.name, "")
                local nameWidth = getTextManager():MeasureStringX(UIFont.Large, displayName)
                listboxWidth = math.max(nameWidth, listboxWidth)
            end
        end
    end
    
    return math.min(listboxWidth + ModOptionsConstants.UI_BORDER_SPACING * 2, 300)
end

function ModOptionsScreen:createSortAndSearchControls(listboxWidth)
    local constants = ModOptionsConstants
    local searchEntryY = constants.UI_BORDER_SPACING * 2 + constants.FONT_HGT_TITLE + 1
    
    self.sortCombo = ISComboBox:new(constants.UI_BORDER_SPACING + 1, searchEntryY, listboxWidth, constants.ENTRY_HGT, 
        self, self.onSortChanged)
    self.sortCombo:initialise()
    self.sortCombo:addOptionWithData(ModOptionsUtils.safeGetText("UI_modlistpanel_sortBy_name", "Name"), "name")
    self.sortCombo:addOptionWithData(ModOptionsUtils.safeGetText("UI_modlistpanel_sortBy_date", "Date Added"), "date_added")
    self.sortCombo.selected = constants.SORT_BY_NAME
    self:addChild(self.sortCombo)
    
    local searchX = self.sortCombo:getRight() + constants.UI_BORDER_SPACING
    self.searchEntry = ISTextEntryBox:new("", searchX, searchEntryY, 
        self.width - searchX - constants.UI_BORDER_SPACING - 1, constants.ENTRY_HGT)
    self.searchEntry.font = UIFont.Medium
    self.searchEntry.onTextChange = function() self:doSearch() end
    self.searchEntry:initialise()
    self.searchEntry:instantiate()
    
    if SandboxOptionsScreen and SandboxOptionsScreen.searchPrerender then
        self.searchEntry.prerender = SandboxOptionsScreen.searchPrerender
    end
    
    self:addChild(self.searchEntry)
end

function ModOptionsScreen:createMainListbox(listboxWidth)
    local constants = ModOptionsConstants
    local listY = self.searchEntry:getBottom() + constants.UI_BORDER_SPACING
    local listHeight = self.height - listY - constants.UI_BORDER_SPACING * 2 - constants.BUTTON_HGT - 1
    
    self.listbox = ModOptionsScreenListBox:new(constants.UI_BORDER_SPACING + 1, listY, listboxWidth, listHeight)
    self.listbox:initialise()
    self.listbox:setAnchorLeft(true)
    self.listbox:setAnchorRight(false)
    self.listbox:setAnchorTop(true)
    self.listbox:setAnchorBottom(true)
    self.listbox:setFont("Medium", 4)
    self.listbox.drawBorder = true
    self.listbox:setOnMouseDownFunction(self, self.onMouseDownListbox)
    self:addChild(self.listbox)
end

function ModOptionsScreen:doSearch()
    if not self.searchEntry or not self.listbox then return end
    
    local searchWord = string.lower(self.searchEntry:getInternalText() or "")
    local firstMatchIndex = -1
    
    for i, item in ipairs(self.listbox.items) do
        item.searchFound = false
        
        if item.item.panel and item.item.panel.labels then
            local panelHasMatch = false
            
            if searchWord ~= "" then
                local modName = ModOptionsUtils.safeGetText(item.item.page.name, "")
                if string.find(string.lower(modName), searchWord, 1, true) then
                    panelHasMatch = true
                end
            end
            
            for settingName, label in pairs(item.item.panel.labels) do
                if label then
                    label.searchFound = false
                    
                    if searchWord ~= "" then
                        local labelName = label:getName() or ""
                        if string.find(string.lower(labelName), searchWord, 1, true) then
                            label.searchFound = true
                            panelHasMatch = true
                        end
                        
                        local modName = ModOptionsUtils.safeGetText(item.item.page.name, "")
                        if string.find(string.lower(modName), searchWord, 1, true) then
                            label.searchFound = true
                        end
                    end
                end
            end
            
            if panelHasMatch then
                item.searchFound = true
                if firstMatchIndex == -1 then
                    firstMatchIndex = i
                end
            end
        end
    end
    
    if firstMatchIndex ~= -1 and self.listbox.selected ~= firstMatchIndex then
        self.listbox.selected = firstMatchIndex
        self:onMouseDownListbox(self.listbox.items[firstMatchIndex].item)
    end
end

function ModOptionsScreen:createPanel(page)
    if not page or not page.data then
        error("Invalid page data provided to createPanel")
    end
    
    local constants = ModOptionsConstants
    local panel = ModOptionsScreenPanel:new(
        self.listbox:getRight() + constants.UI_BORDER_SPACING,
        self.listbox:getY(),
        self.width - self.listbox:getRight() - constants.UI_BORDER_SPACING * 2 - 1,
        self.listbox:getHeight()
    )
    
    panel._instance = self
    panel:initialise()
    panel:instantiate()
    panel:setAnchorRight(true)
    panel:setAnchorBottom(true)
    
    local addControlsTo = panel
    addControlsTo:setScrollChildren(true)
    addControlsTo:addScrollBars()
    addControlsTo.vscroll.doSetStencil = false
    
    local labels = {}
    local controls = {}
    
    for _, option in ipairs(page.data) do
        local isValid, errorMsg = ModOptionsUtils.validateOption(option)
        if isValid then
            local label, control = self:createOptionControls(option, page)
            
            if label and control then
                self:configureControlTooltips(label, control, option)
                table.insert(labels, label)
                table.insert(controls, control)
            end
        else
            print("Warning: Invalid option in " .. tostring(page.modOptionsID) .. ": " .. errorMsg)
        end
    end
    
    self:layoutControlsOnPanel(panel, addControlsTo, page, labels, controls)
    
    return panel
end

function ModOptionsScreen:createOptionControls(option, page)
    local constants = ModOptionsConstants
    local label, control
    
    if option.type == "title" or option.type == "separator" or 
       option.type == "description" or option.type == "button" or option.type == "image" then
        return nil, nil
    end
    
    if option.type == "tickbox" then
        label, control = self:createTickboxControl(option, page)
    elseif option.type == "multipletickbox" then
        label, control = self:createMultipleTickboxControl(option, page)
    elseif option.type == "combobox" then
        label, control = self:createComboboxControl(option, page)
    elseif option.type == "slider" then
        label, control = self:createSliderControl(option, page)
    elseif option.type == "colorpicker" then
        label, control = self:createColorPickerControl(option, page)
    elseif option.type == "textentry" then
        label, control = self:createTextEntryControl(option, page)
    elseif option.type == "keybind" then
        label, control = self:createKeybindControl(option, page)
    else
        print("Warning: Unknown option type: " .. tostring(option.type))
        return nil, nil
    end
    
    return label, control
end

function ModOptionsScreen:createTickboxControl(option, page)
    local constants = ModOptionsConstants
    local label = ISLabel:new(0, 0, constants.ENTRY_HGT, 
        ModOptionsUtils.safeGetText(option.name), 1, 1, 1, 1, UIFont.Medium)
    local control = ISTickBox:new(0, 0, constants.ENTRY_HGT, constants.ENTRY_HGT, "")
    control:addOption("")
    option.element = control
    
    local gameOption = ModManagerOption:new(page.modOptionsID .. "." .. option.id, control)
    gameOption.toUI = function(self) 
        if option.value ~= nil then
            self.control:setSelected(1, option.value) 
        end
    end
    gameOption.apply = function(self) 
        option.value = self.control:isSelected(1) 
    end
    gameOption.onChange = function(self, index, selected) 
        if option.onChange then 
            local success, error = pcall(option.onChange, option, selected)
            if not success then
                print("Error in onChange callback for " .. tostring(option.name) .. ": " .. tostring(error))
            end
        end 
    end
    
    self.gameOptions:add(gameOption)
    return label, control
end

function ModOptionsScreen:createMultipleTickboxControl(option, page)
    local constants = ModOptionsConstants
    local label = ISLabel:new(0, 0, constants.ENTRY_HGT, 
        ModOptionsUtils.safeGetText(option.name), 1, 1, 1, 1, UIFont.Medium)
    local control = ISTickBox:new(0, 0, constants.BUTTON_HGT, constants.BUTTON_HGT, "")
    
    if option.values then
        for _, value in ipairs(option.values) do
            control:addOption(ModOptionsUtils.safeGetText(value.name), value.name)
        end
    end
    
    option.element = control
    
    local gameOption = ModManagerOption:new(page.modOptionsID .. "." .. option.id, control)
    gameOption.toUI = function(self) 
        if option.values then
            for i = 1, #self.control.options do
                if option.values[i] and option.values[i].value ~= nil then
                    self.control:setSelected(i, option.values[i].value)
                end
            end
        end
    end
    gameOption.apply = function(self) 
        if option.values then
            for i = 1, #self.control.options do
                if option.values[i] then
                    option.values[i].value = self.control:isSelected(i)
                end
            end
        end
    end
    gameOption.onChange = function(self, index, selected) 
        if option.onChange then 
            local success, error = pcall(option.onChange, option, index, selected)
            if not success then
                print("Error in onChange callback for " .. tostring(option.name) .. ": " .. tostring(error))
            end
        end 
    end
    
    self.gameOptions:add(gameOption)
    return label, control
end

function ModOptionsScreen:createComboboxControl(option, page)
    local constants = ModOptionsConstants
    local label = ISLabel:new(0, 0, constants.ENTRY_HGT, 
        ModOptionsUtils.safeGetText(option.name), 1, 1, 1, 1, UIFont.Medium)
    local control = ISComboBox:new(0, 0, constants.CONTROL_WIDTH, constants.ENTRY_HGT, self, nil)
    
    if option.values then
        for _, v in ipairs(option.values) do
            control:addOption(ModOptionsUtils.safeGetText(v))
        end
    end
    
    option.element = control
    
    local gameOption = ModManagerOption:new(page.modOptionsID .. "." .. option.id, control)
    gameOption.toUI = function(self) 
        if option.selected then
            self.control.selected = option.selected 
        end
    end
    gameOption.apply = function(self) 
        option.selected = self.control.selected 
    end
    gameOption.onChange = function(self, box) 
        if option.onChange then 
            local success, error = pcall(option.onChange, option, box.selected)
            if not success then
                print("Error in onChange callback for " .. tostring(option.name) .. ": " .. tostring(error))
            end
        end 
    end
    
    self.gameOptions:add(gameOption)
    return label, control
end

function ModOptionsScreen:createSliderControl(option, page)
    local constants = ModOptionsConstants
    local label = ISLabel:new(0, 0, constants.ENTRY_HGT, 
        ModOptionsUtils.safeGetText(option.name), 1, 1, 1, 1, UIFont.Medium)
    
    local container = ISPanel:new(0, 0, constants.CONTROL_WIDTH * 2, constants.ENTRY_HGT)
    container:noBackground()
    
    local valueLabel = ISLabel:new(60, 0, constants.ENTRY_HGT, 
        tostring(option.value or 0), 1, 1, 1, 1, UIFont.Small, false)
    valueLabel:initialise()
    container:addChild(valueLabel)
    
    local control = ISSliderPanel:new(70, 0, constants.CONTROL_WIDTH * 2 - 70, constants.ENTRY_HGT)
    control:setValues(
        option.min or 0, 
        option.max or 100, 
        option.step or 1, 
        (option.step or 1) * 10
    )
    container:addChild(control)
    
    control.label = valueLabel
    control.container = container
    option.element = control
    
    local gameOption = ModManagerOption:new(page.modOptionsID .. "." .. option.id, control)
    gameOption.toUI = function(self) 
        local value = option.value or option.min or 0
        self.control.label:setName(tostring(value))
        self.control:setCurrentValue(value, true) 
    end
    gameOption.apply = function(self) 
        option.value = self.control:getCurrentValue() 
    end
    gameOption.onChange = function(self, value) 
        self.control.label:setName(tostring(value))
        if option.onChange then 
            local success, error = pcall(option.onChange, option, value)
            if not success then
                print("Error in onChange callback for " .. tostring(option.name) .. ": " .. tostring(error))
            end
        end 
    end
    
    self.gameOptions:add(gameOption)
    return label, control
end

function ModOptionsScreen:createColorPickerControl(option, page)
    local constants = ModOptionsConstants
    local label = ISLabel:new(0, 0, constants.ENTRY_HGT, 
        ModOptionsUtils.safeGetText(option.name), 1, 1, 1, 1, UIFont.Medium)
    
    if not option.modOptionsID then
        option.modOptionsID = page.modOptionsID
    end
    
    local control = self:createColorButton(option)
    option.element = control
    
    local gameOptionKey = tostring(page.modOptionsID) .. "." .. tostring(option.id)
    local gameOption = ModManagerOption:new(gameOptionKey, control)
    gameOption.toUI = function(self) 
        if option.color then 
            self.control.backgroundColor = option.color 
        end 
    end
    gameOption.apply = function(self) 
        if self.control.backgroundColor then 
            option.color = self.control.backgroundColor 
        end 
    end
    gameOption.onChange = function(self, color) 
        if option.onChange then 
            local success, error = pcall(option.onChange, option, color)
            if not success then
                print("Error in onChange callback for " .. tostring(option.name) .. ": " .. tostring(error))
            end
        end 
    end
    
    self.gameOptions:add(gameOption)
    return label, control
end

function ModOptionsScreen:createTextEntryControl(option, page)
    local constants = ModOptionsConstants
    local label = ISLabel:new(0, 0, constants.ENTRY_HGT, 
        ModOptionsUtils.safeGetText(option.name), 1, 1, 1, 1, UIFont.Medium)
    local control = ISTextEntryBox:new(option.value or "", 0, 0, 
        constants.CONTROL_WIDTH * 2, constants.ENTRY_HGT)
    control.font = UIFont.Medium
    option.element = control
    
    local gameOption = ModManagerOption:new(page.modOptionsID .. "." .. option.id, control)
    gameOption.toUI = function(self) 
        self.control:setText(option.value or "") 
    end
    gameOption.apply = function(self) 
        option.value = self.control:getInternalText() 
    end
    gameOption.onChange = function(self, text) 
        if option.onChange then 
            local success, error = pcall(option.onChange, option, text)
            if not success then
                print("Error in onChange callback for " .. tostring(option.name) .. ": " .. tostring(error))
            end
        end 
    end
    
    self.gameOptions:add(gameOption)
    return label, control
end

function ModOptionsScreen:createKeybindControl(option, page)
    local constants = ModOptionsConstants
    
    if option.key ~= nil then
        option.value = tostring(option.key)
    elseif option.value == nil and option.defaultkey ~= nil then
        option.value = tostring(option.defaultkey)
        option.key = option.defaultkey
    end
    
    local label = ISLabel:new(0, 0, constants.ENTRY_HGT, 
        ModOptionsUtils.safeGetText(option.name), 1, 1, 1, 1, UIFont.Medium)
    
    local keyValue = ModOptionsUtils.safeToNumber(option.value, 0)
    local keyName = ModOptionsUtils.safeGetKeyName(keyValue)
    
    local control = ISButton:new(0, 0, constants.CONTROL_WIDTH, constants.ENTRY_HGT, 
        keyName, self, MainOptions.onKeyBindingBtnPress)
    control.internal = option.name
    control.isModBind = true
    control.keyCode = keyValue
    option.element = control
    
    local gameOption = ModManagerOption:new(page.modOptionsID .. "." .. option.id, control)
    gameOption.toUI = function(self) 
        local keyNum = ModOptionsUtils.safeToNumber(option.key or option.value, 0)
        local keyName = ModOptionsUtils.safeGetKeyName(keyNum)
        self.control:setTitle(keyName)
        self.control.keyCode = keyNum
        option.value = tostring(keyNum)
    end
    gameOption.apply = function(self) 
        option.value = tostring(self.control.keyCode or 0)
        option.key = self.control.keyCode or 0
    end
    
    self.gameOptions:add(gameOption)
    return label, control
end

function ModOptionsScreen:configureControlTooltips(label, control, option)
    if option.tooltip then
        local tooltipText = ModOptionsUtils.safeGetText(option.tooltip)
        if tooltipText and ModOptionsUtils.safeTrim(tooltipText) ~= "" then
            control.tooltip = tooltipText
            label.tooltip = tooltipText
        end
    end
end

function ModOptionsScreen:addImageToPanel(addControlsTo, option, currentY, panelWidth, labelWidth, maxControlWidth)
    local constants = ModOptionsConstants
    local texture = getTexture(option.path)
    if not texture then
        print("Warning: Could not load image for mod options: " .. tostring(option.path))
        return currentY
    end

    local scrollbarWidth = addControlsTo.vscroll and addControlsTo.vscroll:getWidth() or 17
    local fullContentWidth = panelWidth - scrollbarWidth

    local imgWidth = texture:getWidthOrig()
    local imgHeight = texture:getHeightOrig()
    
    local finalWidth, finalHeight

    if option.fit then
        finalWidth = fullContentWidth - constants.UI_BORDER_SPACING * 2
        finalHeight = (imgHeight / imgWidth) * finalWidth
    else
        if option.minWidth then
            finalWidth = math.min(option.minWidth, fullContentWidth - constants.UI_BORDER_SPACING * 2)
            finalHeight = (imgHeight / imgWidth) * finalWidth
        else
            local controlsAreaWidth = labelWidth + maxControlWidth + constants.UI_BORDER_SPACING
            finalWidth = imgWidth
            finalHeight = imgHeight
            if finalWidth > controlsAreaWidth then
                finalWidth = controlsAreaWidth
                finalHeight = (imgHeight / imgWidth) * finalWidth
            end
        end
    end

    local imageX = (fullContentWidth - finalWidth) / 2

    local image = ISImage:new(imageX, currentY, finalWidth, finalHeight, texture)
    image.autoScale = true
    image:initialise()
    addControlsTo:addChild(image)

    return currentY + finalHeight + constants.UI_BORDER_SPACING
end

function ModOptionsScreen:layoutControlsOnPanel(panel, addControlsTo, page, labels, controls)
    local constants = ModOptionsConstants
    
    local labelWidth = 0
    for _, label in ipairs(labels) do
        if label then
            labelWidth = math.max(labelWidth, label:getWidth())
        end
    end
    
    local maxControlWidth = 0
    for _, control in ipairs(controls) do
        if control then
            local width = control:getWidth()
            if control.Type == 'ISSliderPanel' and control.container then
                width = control.container:getWidth()
            end
            maxControlWidth = math.max(maxControlWidth, width)
        end
    end
    
    local xOffset = (panel.width - (labelWidth + maxControlWidth + constants.UI_BORDER_SPACING * 2)) / 2
    local currentY = 11
    local optionIndex = 0
    
    for i = 1, #page.data do
        local option = page.data[i]
        
        if option.type == "title" then
            currentY = self:addTitleToPanel(addControlsTo, option, currentY, panel.width)
        elseif option.type == "separator" then
            currentY = self:addSeparatorToPanel(addControlsTo, currentY, panel.width)
        elseif option.type == "description" then
            currentY = self:addDescriptionToPanel(addControlsTo, option, currentY, xOffset, panel.width)
        elseif option.type == "button" then
            currentY = self:addButtonToPanel(addControlsTo, option, currentY, xOffset, labelWidth)
        elseif option.type == "image" then
            currentY = self:addImageToPanel(addControlsTo, option, currentY, panel.width, labelWidth, maxControlWidth)
        else
            optionIndex = optionIndex + 1
            local label = labels[optionIndex]
            local control = controls[optionIndex]
            
            if label and control then
                currentY = self:addControlPairToPanel(addControlsTo, label, control, currentY, xOffset, labelWidth)
            end
        end
    end
    
    addControlsTo:setScrollHeight(currentY)
    
    panel.labels = {}
    panel.controls = {}
    optionIndex = 0
    
    for i = 1, #page.data do
        local option = page.data[i]
        if option.type ~= "title" and option.type ~= "separator" and 
           option.type ~= "description" and option.type ~= "button" and option.type ~= "image" then
            optionIndex = optionIndex + 1
            if labels[optionIndex] and controls[optionIndex] then
                panel.labels[option.id] = labels[optionIndex]
                panel.controls[option.id] = controls[optionIndex]
            end
        end
    end
end

function ModOptionsScreen:addTitleToPanel(addControlsTo, option, currentY, panelWidth)
    local constants = ModOptionsConstants
    local title = ISLabel:new(0, currentY + constants.UI_BORDER_SPACING, 
        constants.FONT_HGT_MEDIUM + 6, ModOptionsUtils.safeGetText(option.name), 
        1, 1, 1, 1, UIFont.Large)
    title:initialise()
    addControlsTo:addChild(title)
    title:setX((panelWidth - title:getWidth()) / 2)
    return currentY + title:getHeight() + constants.UI_BORDER_SPACING * 2
end

function ModOptionsScreen:addSeparatorToPanel(addControlsTo, currentY, panelWidth)
    local constants = ModOptionsConstants
    local hLine = HorizontalLine:new(constants.UI_BORDER_SPACING, currentY, 
        panelWidth - constants.UI_BORDER_SPACING * 2 - 13)
    addControlsTo:addChild(hLine)
    return currentY + hLine:getHeight() + constants.UI_BORDER_SPACING
end

function ModOptionsScreen:addDescriptionToPanel(addControlsTo, option, currentY, xOffset, panelWidth)
    local constants = ModOptionsConstants
    local richText = ISRichTextPanel:new(xOffset, currentY, panelWidth - xOffset * 2, 100)
    richText.background = false
    richText.autosetheight = true
    richText.marginLeft = 0
    richText:initialise()
    addControlsTo:addChild(richText)
    richText:setText("<RGB:0.8,0.8,0.8>" .. (option.text or ""))
    richText:paginate()
    richText.onMouseWheel = function(self, del) return false end
    return currentY + richText:getHeight() + constants.UI_BORDER_SPACING
end

function ModOptionsScreen:addButtonToPanel(addControlsTo, option, currentY, xOffset, labelWidth)
    local constants = ModOptionsConstants
    local button = ISButton:new(0, currentY, constants.CONTROL_WIDTH, constants.ENTRY_HGT, 
        ModOptionsUtils.safeGetText(option.name))
    button:initialise()
    addControlsTo:addChild(button)
    button:setX(xOffset + labelWidth + constants.UI_BORDER_SPACING)
    
    if option.onclick and option.args then
        button:setOnClick(option.onclick, option.args[1], option.args[2], option.args[3], option.args[4])
    end
    
    if option.tooltip then
        local tooltipText = ModOptionsUtils.safeGetText(option.tooltip)
        if tooltipText and ModOptionsUtils.safeTrim(tooltipText) ~= "" then
            button:setTooltip(tooltipText)
        end
    end
    
    return currentY + button:getHeight() + constants.UI_BORDER_SPACING
end

function ModOptionsScreen:addControlPairToPanel(addControlsTo, label, control, currentY, xOffset, labelWidth)
    local constants = ModOptionsConstants
    
    addControlsTo:addChild(label)
    label:setX(xOffset)
    label:setY(currentY)
    
    if control.Type == 'ISSliderPanel' and control.container then
        addControlsTo:addChild(control.container)
        control.container:setX(xOffset + labelWidth + constants.UI_BORDER_SPACING)
        control.container:setY(currentY)
    else
        addControlsTo:addChild(control)
        control:setX(xOffset + labelWidth + constants.UI_BORDER_SPACING)
        control:setY(currentY)
    end
    
    return currentY + math.max(label:getHeight(), control:getHeight()) + constants.UI_BORDER_SPACING
end

-- ==============================================================================
-- KEYBIND MANAGEMENT METHODS
-- ==============================================================================

function ModOptionsScreen:getModKeybind(keybindName)
    if not keybindName or not PZAPI or not PZAPI.ModOptions or not PZAPI.ModOptions.Data then
        return nil
    end
    
    for _, options in ipairs(PZAPI.ModOptions.Data) do
        if options and options.data then
            for _, option in ipairs(options.data) do
                if option.type == "keybind" and option.name == keybindName then
                    return option
                end
            end
        end
    end
    return nil
end

function ModOptionsScreen:setModKeybind(keybindName, key)
    local keyBinded = self:getModKeybind(keybindName)
    if not keyBinded then return end
    
    keyBinded.value = tostring(key)
    keyBinded.key = key
    
    if keyBinded.element then
        keyBinded.element.keyCode = key
    end
    
    self:updateKeybindButton(keybindName)
    self.gameOptions.changed = true
    
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then
        local success, error = pcall(PZAPI.ModOptions.save, PZAPI.ModOptions)
        if not success then
            print("Error saving mod options: " .. tostring(error))
        end
    end
    
    if MainOptions.setKeybindDialog then
        MainOptions.setKeybindDialog:destroy()
        MainOptions.setKeybindDialog = nil
    end
end

function ModOptionsScreen:showKeybindConflictDialog(key, keybindName, conflictingKeybindName)
    if MainOptions.setKeybindDialog then
        MainOptions.setKeybindDialog:destroy()
        MainOptions.setKeybindDialog = nil
    end
    
    local modal = ISDuplicateKeybindDialog:new(key, keybindName, conflictingKeybindName, 
        false, false, false, function()
            self:setModKeybind(keybindName, key)
        end)
    modal:initialise()
    modal:addToUIManager()
    modal:setAlwaysOnTop(true)
end

function ModOptionsScreen:keyPressHandler(key, shift, ctrl, alt)
    if not MainOptions.setKeybindDialog or key <= 0 then
        if self.originalKeyPressHandler then
            self.originalKeyPressHandler(key, shift, ctrl, alt)
        end
        return
    end
    
    local keybindName = MainOptions.setKeybindDialog.keybindName
    
    if not self:getModKeybind(keybindName) then
        if self.originalKeyPressHandler then
            self.originalKeyPressHandler(key, shift, ctrl, alt)
        end
        return
    end
    
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.Data then
        for _, options in ipairs(PZAPI.ModOptions.Data) do
            if options and options.data then
                for _, option in ipairs(options.data) do
                    if option.type == "keybind" and option.name ~= keybindName and 
                       ModOptionsUtils.safeToNumber(option.value, 0) == key then
                        self:showKeybindConflictDialog(key, keybindName, option.name)
                        return
                    end
                end
            end
        end
    end
    
    if MainOptions.keyText then
        for i, v in ipairs(MainOptions.keyText) do
            if not v.value and v.keyCode == key then
                self:showKeybindConflictDialog(key, keybindName, v.txt:getName())
                return
            end
        end
    end
    
    self:setModKeybind(keybindName, key)
end

function ModOptionsScreen:updateKeybindButton(keybindName)
    local keyBinded = self:getModKeybind(keybindName)
    if not keyBinded or not keyBinded.element then return end
    
    local keyNum = ModOptionsUtils.safeToNumber(keyBinded.value, 0)
    local keyName = ModOptionsUtils.safeGetKeyName(keyNum)
    
    keyBinded.element:setTitle(keyName)
    keyBinded.element.keyCode = keyNum
end

-- ==============================================================================
-- COLOR PICKER METHODS
-- ==============================================================================

function ModOptionsScreen:createColorButton(option)
    local constants = ModOptionsConstants
    local button = ISButton:new(0, 0, constants.ENTRY_HGT * 2, constants.ENTRY_HGT, 
        "", self, self.onModColorPick)
    button.backgroundColor = option.color or ModOptionsUtils.deepCopy(constants.DEFAULT_COLOR)
    button.option = option
    
    button.colorPicker = ISColorPicker:new(0, 0)
    button.colorPicker:initialise()
    button.colorPicker.pickedTarget = self
    button.colorPicker.resetFocusTo = self
    
    local initialColor = option.color or constants.DEFAULT_COLOR
    button.colorPicker:setInitialColor(ColorInfo.new(
        initialColor.r or 1, initialColor.g or 1, initialColor.b or 1, initialColor.a or 1))
    
    return button
end

function ModOptionsScreen:onModColorPick(button)
    if not button or not button.colorPicker then return end
    
    local x = self.x + button.parent.x + (button.parent:getXScroll() or 0) + button.x
    local y = self.y + button.parent.y + (button.parent:getYScroll() or 0) + button.y + button.height + 1
    
    if y + button.colorPicker.height > getCore():getScreenHeight() then
        y = y - button.height - button.colorPicker.height - 2
    end
    
    button.colorPicker:setX(x)
    button.colorPicker:setY(y)
    
    button.colorPicker.pickedFunc = function(target, color, mouseUp, ...)
        self:pickedModColor(target, color, mouseUp)
    end
    button.colorPicker.pickedTarget = button
    
    self:addChild(button.colorPicker)
    button.colorPicker:setVisible(true)
    button.colorPicker:bringToTop()
end

function ModOptionsScreen:pickedModColor(button, color, mouseUp)
    if not button or not button.option or not color then return end
    
    local modOptionsID = button.option.modOptionsID
    local optionId = button.option.id
    
    button.backgroundColor = { r = color.r, g = color.g, b = color.b, a = 1 }
    
    local gameOptionKey = tostring(modOptionsID) .. "." .. tostring(optionId)
    local gameOption = self.gameOptions:get(gameOptionKey)
    
    if gameOption then
        self.gameOptions:onChange(gameOption)
        if gameOption.onChange then
            local success, error = pcall(gameOption.onChange, gameOption, button.backgroundColor)
            if not success then
                print("Error in color picker onChange: " .. tostring(error))
            end
        end
    end
end

-- ==============================================================================
-- UI EVENT HANDLERS
-- ==============================================================================

function ModOptionsScreen:onMouseDownListbox(item)
    if not item or not item.page then return end
    
    if self.currentPanel then
        self:removeChild(self.currentPanel)
        self.currentPanel = nil
    end
    
    if item.panel then
        self:addChild(item.panel)
        self.currentPanel = item.panel
    end
end

function ModOptionsScreen:prerender()
    ISPanelJoypad.prerender(self)
    
    local titleText = ModOptionsUtils.safeGetText("UI_modoptions_title", "Mod Options")
    self:drawTextCentre(titleText, self.width / 2, ModOptionsConstants.UI_BORDER_SPACING + 1, 
        1, 1, 1, 1, UIFont.Title)
    
    if self.applyButton and self.gameOptions then
        self.applyButton:setEnable(self.gameOptions.changed or false)
    end
end

function ModOptionsScreen:onOptionMouseDown(button)
    if not button or not button.internal then return end
    
    if button.internal == "BACK" then
        self:close()
    elseif button.internal == "ACCEPT" then
        self:apply(true)
    elseif button.internal == "APPLY" then
        self:apply(false)
    end
end

function ModOptionsScreen:apply(closeAfter)
    if not self.gameOptions then return end
    
    self.gameOptions:apply()
    
    if PZAPI and PZAPI.ModOptions then
        if PZAPI.ModOptions.save then
            local success, error = pcall(PZAPI.ModOptions.save, PZAPI.ModOptions)
            if not success then
                print("Error saving mod options: " .. tostring(error))
            end
        end
        
        if PZAPI.ModOptions.load then
            local success, error = pcall(PZAPI.ModOptions.load, PZAPI.ModOptions)
            if not success then
                print("Error reloading mod options: " .. tostring(error))
            end
        end
    end
    
    self.gameOptions.changed = false
    
    if closeAfter then
        self:close()
    end
end

function ModOptionsScreen:close()
    if self.originalKeyPressHandler then
        MainOptions.keyPressHandler = self.originalKeyPressHandler
        self.originalKeyPressHandler = nil
    end
    
    self:setVisible(false)
    
    if self.returnToUI then
        if self.returnToUI == MainScreen.instance then
            self.returnToUI.bottomPanel:setVisible(true, self.joyfocus)
        else
            self.returnToUI:setVisible(true, self.joyfocus)
        end
    elseif ModSelector and ModSelector.instance then
        ModSelector.instance:setVisible(true, self.joyfocus)
    end
    
    self:removeFromUIManager()
    ModOptionsScreen.instance = nil
end

-- ==============================================================================
-- EVENT REGISTRATION
-- ==============================================================================

Events.OnGameBoot.Add(function()
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.load then
        local success, error = pcall(PZAPI.ModOptions.load, PZAPI.ModOptions)
        if not success then
            print("Error loading PZAPI ModOptions on game boot: " .. tostring(error))
        end
    else
        print("Warning: PZAPI.ModOptions not available on game boot")
    end
end)