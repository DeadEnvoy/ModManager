Functions = {};

-- Registry: weak keys (owner tables), values are tables keyed by method name.
--   registry[tbl][key] = { orig = <function>, pre = {...}, post = {...} }
local registry = setmetatable({}, { __mode = "k" });

-- Get or create the hook entry for (tbl, key). Captures the original function
-- the first time and installs the dispatcher into tbl[key].
local function getEntry(tbl, key)
    local perTable = registry[tbl];
    if not perTable then
        perTable = {};
        registry[tbl] = perTable;
    end
    local entry = perTable[key];
    if entry then return entry; end

    local orig = tbl[key];
    entry = { orig = orig, pre = {}, post = {} };
    perTable[key] = entry;

    -- Dispatcher: runs pre-hooks, then original, then post-hooks. Pre/post hooks
    -- are isolated with pcall so a broken hook cannot prevent the original from
    -- running. The engine still dumps the full Lua stack (including the offending
    -- mod and file) via KahluaThread.flushErrorMessage on pcall failure, so no
    -- manual logging is needed. The original is called without pcall: an error
    -- there should surface exactly as it would without hooks. Hooks are observers
    -- only — their return values are ignored and the original always runs.
    tbl[key] = function(...)
        local results;

        -- Pre-hooks: run before the original; return values ignored.
        if #entry.pre > 0 then
            ---@diagnostic disable-next-line: deprecated
            local snapshot = { unpack(entry.pre) };
            for i = 1, #snapshot do
                pcall(snapshot[i], ...);
            end
        end

        if type(entry.orig) == "function" then
            results = { entry.orig(...) };
        end

        -- Post-hooks: receive the same args as the original; return values ignored.
        if #entry.post > 0 then
            ---@diagnostic disable-next-line: deprecated
            local snapshot = { unpack(entry.post) };
            for i = 1, #snapshot do
                pcall(snapshot[i], ...);
            end
        end

        ---@diagnostic disable-next-line: deprecated
        return unpack(results or {});
    end

    return entry;
end

-- Restore the original function and drop the entry when no hooks remain.
local function maybeCleanup(tbl, key, entry)
    if #entry.pre > 0 or #entry.post > 0 then return; end
    tbl[key] = entry.orig;
    local perTable = registry[tbl];
    if perTable then
        perTable[key] = nil;
        if next(perTable) == nil then
            registry[tbl] = nil;
        end
    end
end

-- Remove a single callback from a list (first match by reference).
local function removeCallback(list, func)
    for i = 1, #list do
        if list[i] == func then
            table.remove(list, i);
            return true;
        end
    end
    return false;
end

Functions.PreHook = {};

-- Functions.PreHook.Add(tbl, key, func)
--   Run `func` before `tbl[key]`, with the same arguments. Return value ignored;
--   the original always runs after the hook. Hooks are observers only.
function Functions.PreHook.Add(tbl, key, func)
    if type(func) ~= "function" then return; end
    local entry = getEntry(tbl, key);
    entry.pre[#entry.pre + 1] = func;
end

-- Functions.PreHook.Remove(tbl, key, func)
function Functions.PreHook.Remove(tbl, key, func)
    local perTable = registry[tbl];
    if not perTable then return; end
    local entry = perTable[key];
    if not entry then return; end
    removeCallback(entry.pre, func);
    maybeCleanup(tbl, key, entry);
end

Functions.PostHook = {};

-- Functions.PostHook.Add(tbl, key, func)
--   Run `func` after `tbl[key]`, with the same arguments. Return value ignored.
function Functions.PostHook.Add(tbl, key, func)
    if type(func) ~= "function" then return; end
    local entry = getEntry(tbl, key);
    entry.post[#entry.post + 1] = func;
end

-- Functions.PostHook.Remove(tbl, key, func)
function Functions.PostHook.Remove(tbl, key, func)
    local perTable = registry[tbl];
    if not perTable then return; end
    local entry = perTable[key];
    if not entry then return; end
    removeCallback(entry.post, func);
    maybeCleanup(tbl, key, entry);
end