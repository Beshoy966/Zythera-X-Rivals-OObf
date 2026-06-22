--[[
        WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]

-- Continue with the main script below

-- ============================================================
-- [V4] ANTI-CHEAT BYPASS SYSTEM (from 25ms unlocker)
-- Disables anti-cheat scripts + monitors NetworkClient
-- ============================================================
task.spawn(function()
    pcall(function()
        -- 1. Block MiscellaneousController weak table creation
        local _stbl
        _stbl = hookfunction(getrenv().setmetatable, newcclosure(function(tbl, mt)
            if mt and typeof(mt) == "table" and rawget(mt, "__mode") == "kv" then
                local tr = debug.traceback()
                if tr:find("MiscellaneousController") then
                    return _stbl({1,2,3}, {})
                end
            end
            return _stbl(tbl, mt)
        end))
    end)

    -- 2. Disable anti-cheat scripts by name
    pcall(function()
        local function _procAC(o)
            pcall(function()
                if o:IsA("LocalScript") or o:IsA("ModuleScript") then
                    local _s, nm = pcall(function() return o.Name:lower() end)
                    if not _s or not nm then return end
                    local _tags = {"anticheat","ac","detection","ban","kick","security","moderation"}
                    for _i = 1, #_tags do
                        if nm:find(_tags[_i]) then
                            pcall(function() o.Disabled = true end)
                            break
                        end
                    end
                end
            end)
        end
        -- Scan existing descendants
        pcall(function()
            for _, o in ipairs(game:GetDescendants()) do
                _procAC(o)
            end
        end)
        -- Monitor new descendants
        pcall(function() game.DescendantAdded:Connect(_procAC) end)
    end)

    -- 3. Monitor NetworkClient for anti-cheat injections
    pcall(function()
        local _nc = game:GetService("NetworkClient")
        if not _nc then return end
        _nc.ChildAdded:Connect(function(ch)
            pcall(function()
                local _ok, _n = pcall(function() return ch.Name:lower() end)
                if _ok and _n then
                    if _n:find("anticheat") or _n:find("detection") then
                        pcall(function() ch:Destroy() end)
                    end
                end
            end)
        end)
    end)

    -- 4. Hook LocalScript3 ban/kick functions
    pcall(function()
        local _rf = game:GetService("ReplicatedFirst")
        local _tgt = _rf:WaitForChild("LocalScript3", 10)
        local _gc = getgc(false)
        for _i = 1, #_gc do
            local _fn = _gc[_i]
            if type(_fn) ~= "function" then continue end
            local _ok1, _env = pcall(getfenv, _fn)
            if not _ok1 or type(_env) ~= "table" then continue end
            local _ok2, _scr = pcall(function() return rawget(_env, "script") end)
            if not _ok2 or not _scr or typeof(_scr) ~= "Instance" then continue end
            if _scr ~= _tgt then continue end
            local _ok4, _consts = pcall(debug.getconstants, _fn)
            if not _ok4 or type(_consts) ~= "table" then continue end
            for _j = 1, #_consts do
                local _c = _consts[_j]
                if type(_c) == "string" and (_c:find("TakeTheL") or _c:find("ban") or _c:find("kick")) then
                    pcall(function() hookfunction(_fn, function() end) end)
                    break
                end
            end
        end
    end)
end)

-- ============================================================
-- [V4] COSMETIC UNLOCKER (from 25ms unlocker)
-- Unlocks ALL skins/wraps/charms/dances/emotes for free
-- Saves equipped cosmetics to rivals_unlocker_config.json
-- OFF by default — toggle "Skin Changer" in Misc tab to enable
-- ============================================================
local CosmeticUnlocker = {
    Enabled = false,  -- [V5] OFF by default — user controls it via UI
    _active = false,  -- Internal: tracks if the hooks are installed
    _eq = {},         -- equipped cosmetics per weapon
    _favs = {},       -- favorited cosmetics
    _saveLock = false,
}

-- The actual unlocker logic, defined as a function so we can call it on toggle
-- [V6] Improved: retry mechanism + remove _active guard so it can re-trigger
local function _startCosmeticUnlocker()
    pcall(function()
        local _plrs    = game:GetService("Players")
        local _rs      = game:GetService("ReplicatedStorage")
        local _http    = game:GetService("HttpService")
        local _lp      = _plrs.LocalPlayer
        local _pscripts = _lp.PlayerScripts
        local _ctrl    = _pscripts:WaitForChild("Controllers", 30)
        local _mods    = _rs:WaitForChild("Modules", 30)

        if not _ctrl or not _mods then return end

        local _enumLib = require(_mods:WaitForChild("EnumLibrary", 30))
        if _enumLib then pcall(function() _enumLib:WaitForEnumBuilder() end) end

        local _cosLib  = require(_mods:WaitForChild("CosmeticLibrary", 30))
        local _itmLib  = require(_mods:WaitForChild("ItemLibrary", 30))
        local _datCtrl = require(_ctrl:WaitForChild("PlayerDataController", 30))

        if not _cosLib or not _datCtrl then return end

        local _cosTypes = {"Skin","Wrap","Charm","Dance","Emote"}
        local function _isCosType(cosObj)
            if not cosObj then return false end
            for _, t in ipairs(_cosTypes) do
                if cosObj.Type == t then return true end
            end
            return false
        end

        local function _mkCosmetic(nm, ctype, opts)
            local _base = _cosLib.Cosmetics[nm]
            if not _base then return nil end
            local _d = {}
            for k, v in pairs(_base) do _d[k] = v end
            _d.Name = nm
            _d.Type = _d.Type or ctype
            _d.Seed = _d.Seed or math.random(1, 1000000)
            if _enumLib then
                local _s, _eid = pcall(_enumLib.ToEnum, _enumLib, nm)
                if _s and _eid then
                    _d.Enum = _eid
                    _d.ObjectID = _d.ObjectID or _eid
                end
            end
            if opts then
                if opts.inverted ~= nil then _d.Inverted = opts.inverted end
                if opts.favoritesOnly ~= nil then _d.OnlyUseFavorites = opts.favoritesOnly end
            end
            return _d
        end

        local _cfgFile = "rivals_unlocker_config.json"

        local function _stripForSave()
            local _out = {}
            for wn, cos in pairs(CosmeticUnlocker._eq) do
                _out[wn] = {}
                for ct, cd in pairs(cos) do
                    if cd and cd.Name then
                        _out[wn][ct] = {
                            Name = cd.Name,
                            Inverted = cd.Inverted,
                            OnlyUseFavorites = cd.OnlyUseFavorites
                        }
                    end
                end
            end
            return { equipped = _out, favorites = CosmeticUnlocker._favs }
        end

        local function _loadCfg()
            if not isfile or not readfile then return end
            local _ok1, _ex = pcall(isfile, _cfgFile)
            if not _ok1 or not _ex then return end
            local _ok2, _raw = pcall(readfile, _cfgFile)
            if not _ok2 or not _raw or _raw == "" then return end
            local _ok3, _dec = pcall(_http.JSONDecode, _http, _raw)
            if not _ok3 or not _dec then return end
            if _dec.favorites then
                CosmeticUnlocker._favs = _dec.favorites
            end
            if _dec.equipped then
                CosmeticUnlocker._eq = {}
                for wn, cos in pairs(_dec.equipped) do
                    CosmeticUnlocker._eq[wn] = {}
                    for ct, sd in pairs(cos) do
                        if sd and sd.Name and _cosLib.Cosmetics[sd.Name] then
                            local _cloned = _mkCosmetic(sd.Name, ct, {
                                inverted = sd.Inverted,
                                favoritesOnly = sd.OnlyUseFavorites
                            })
                            if _cloned then
                                CosmeticUnlocker._eq[wn][ct] = _cloned
                            end
                        end
                    end
                    if not next(CosmeticUnlocker._eq[wn]) then CosmeticUnlocker._eq[wn] = nil end
                end
            end
        end

        local function _saveCfg()
            if not writefile or CosmeticUnlocker._saveLock then return end
            CosmeticUnlocker._saveLock = true
            task.spawn(function()
                task.wait(1)
                local _payload = _stripForSave()
                local _ok, _enc = pcall(_http.JSONEncode, _http, _payload)
                if _ok then
                    pcall(writefile, _cfgFile, _enc)
                end
                CosmeticUnlocker._saveLock = false
            end)
        end

        _loadCfg()

        -- Override OwnsCosmetic functions — always return true for skin types
        _cosLib.OwnsCosmeticNormally = function(self, inv, nm, wep)
            local c = _cosLib.Cosmetics[nm]
            if c and c.Type == "Skin" then return true end
            return false
        end
        _cosLib.OwnsCosmeticUniversally = function(self, inv, nm, wep)
            local c = _cosLib.Cosmetics[nm]
            if c and c.Type == "Skin" then return true end
            return false
        end
        _cosLib.OwnsCosmeticForWeapon = function(self, inv, nm, wep)
            local c = _cosLib.Cosmetics[nm]
            if c and c.Type == "Skin" then return true end
            return false
        end

        local _origOwns = _cosLib.OwnsCosmetic
        _cosLib.OwnsCosmetic = function(self, inv, nm, wep)
            if nm:find("MISSING_") or nm == "Bubble Gun" then
                return _origOwns(self, inv, nm, wep)
            end
            local c = _cosLib.Cosmetics[nm]
            if c and _isCosType(c) then return true end
            return _origOwns(self, inv, nm, wep)
        end

        -- Override PlayerDataController.Get to fake cosmetic inventory
        local _origGet = _datCtrl.Get
        _datCtrl.Get = function(self, key)
            local _val = _origGet(self, key)
            if key == "CosmeticInventory" then
                local _prx = {}
                if _val then
                    for k, v in pairs(_val) do
                        local c = _cosLib.Cosmetics[k]
                        if c and _isCosType(c) then _prx[k] = v end
                    end
                end
                return setmetatable(_prx, {
                    __index = function(t, k)
                        local c = _cosLib.Cosmetics[k]
                        if c and _isCosType(c) then return true end
                        return nil
                    end
                })
            end
            if key == "FavoritedCosmetics" then
                local _res = _val and table.clone(_val) or {}
                for wep, fv in pairs(CosmeticUnlocker._favs) do
                    _res[wep] = _res[wep] or {}
                    for nm, isFav in pairs(fv) do
                        local c = _cosLib.Cosmetics[nm]
                        if c and _isCosType(c) then
                            _res[wep][nm] = isFav
                        end
                    end
                end
                return _res
            end
            return _val
        end

        -- Override GetWeaponData to apply equipped cosmetics
        local _origGetWep = _datCtrl.GetWeaponData
        _datCtrl.GetWeaponData = function(self, wn)
            local _d = _origGetWep(self, wn)
            if not _d then return nil end
            local _m = {}
            for k, v in pairs(_d) do _m[k] = v end
            _m.Name = wn
            if CosmeticUnlocker._eq[wn] then
                for ct, cd in pairs(CosmeticUnlocker._eq[wn]) do
                    _m[ct] = cd
                end
            end
            return _m
        end

        -- Hook EquipCosmetic + FavoriteCosmetic remotes
        local _fightCtrl
        pcall(function()
            _fightCtrl = require(_ctrl:WaitForChild("FighterController", 10))
        end)

        if hookmetamethod then
            local _remotes   = _rs:FindFirstChild("Remotes")
            local _dataRem   = _remotes and _remotes:FindFirstChild("Data")
            local _equipRem  = _dataRem and _dataRem:FindFirstChild("EquipCosmetic")
            local _favRem    = _dataRem and _dataRem:FindFirstChild("FavoriteCosmetic")
            local _repRem    = _remotes and _remotes:FindFirstChild("Replication")
            local _fightRem  = _repRem and _repRem:FindFirstChild("Fighter")
            local _useItmRem = _fightRem and _fightRem:FindFirstChild("UseItem")

            if _equipRem then
                local _onc
                _onc = hookmetamethod(game, "__namecall", function(self, ...)
                    if getnamecallmethod() ~= "FireServer" then
                        return _onc(self, ...)
                    end
                    local _a = {...}

                    if self == _equipRem then
                        local _wn   = _a[1]
                        local _ct   = _a[2]
                        local _cn   = _a[3]
                        local _opts = _a[4] or {}
                        if _cn and _cn ~= "None" and _cn ~= "" then
                            local _inv = _datCtrl:Get("CosmeticInventory")
                            if _inv and rawget(_inv, _cn) then
                                return _onc(self, ...)
                            end
                        end
                        CosmeticUnlocker._eq[_wn] = CosmeticUnlocker._eq[_wn] or {}
                        if not _cn or _cn == "None" or _cn == "" then
                            CosmeticUnlocker._eq[_wn][_ct] = nil
                            if not next(CosmeticUnlocker._eq[_wn]) then CosmeticUnlocker._eq[_wn] = nil end
                        else
                            local _cloned = _mkCosmetic(_cn, _ct, {
                                inverted = _opts.IsInverted,
                                favoritesOnly = _opts.OnlyUseFavorites
                            })
                            if _cloned then CosmeticUnlocker._eq[_wn][_ct] = _cloned end
                        end
                        task.defer(function()
                            pcall(function() _datCtrl.CurrentData:Replicate("WeaponInventory") end)
                        end)
                        _saveCfg()
                        return
                    end

                    if self == _favRem then
                        local _cos = _cosLib.Cosmetics[_a[2]]
                        if _cos then
                            CosmeticUnlocker._favs[_a[1]] = CosmeticUnlocker._favs[_a[1]] or {}
                            CosmeticUnlocker._favs[_a[1]][_a[2]] = _a[3] or nil
                            task.spawn(function()
                                pcall(function() _datCtrl.CurrentData:Replicate("FavoritedCosmetics") end)
                            end)
                            _saveCfg()
                        end
                        return
                    end

                    return _onc(self, ...)
                end)
            end
        end

        -- Hook ClientItem._CreateViewModel to apply cosmetics to view models
        local _cliItem
        pcall(function()
            _cliItem = require(_lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
        end)

        if _cliItem and _cliItem._CreateViewModel then
            local _origCVM = _cliItem._CreateViewModel
            _cliItem._CreateViewModel = function(self, vmRef)
                local _wn  = self.Name
                local _wp  = self.ClientFighter and self.ClientFighter.Player
                if _wp == _lp and CosmeticUnlocker._eq[_wn] then
                    local _dk = self:ToEnum("Data")
                    if vmRef[_dk] then
                        if CosmeticUnlocker._eq[_wn].Skin then
                            vmRef[_dk][self:ToEnum("Skin")] = CosmeticUnlocker._eq[_wn].Skin
                            vmRef[_dk][self:ToEnum("Name")] = CosmeticUnlocker._eq[_wn].Skin.Name
                        end
                        if CosmeticUnlocker._eq[_wn].Charm then vmRef[_dk][self:ToEnum("Charm")] = CosmeticUnlocker._eq[_wn].Charm end
                        if CosmeticUnlocker._eq[_wn].Wrap  then vmRef[_dk][self:ToEnum("Wrap")]  = CosmeticUnlocker._eq[_wn].Wrap  end
                    elseif vmRef.Data then
                        if CosmeticUnlocker._eq[_wn].Skin  then vmRef.Data.Skin  = CosmeticUnlocker._eq[_wn].Skin; vmRef.Data.Name = CosmeticUnlocker._eq[_wn].Skin.Name end
                        if CosmeticUnlocker._eq[_wn].Charm then vmRef.Data.Charm = CosmeticUnlocker._eq[_wn].Charm end
                        if CosmeticUnlocker._eq[_wn].Wrap  then vmRef.Data.Wrap  = CosmeticUnlocker._eq[_wn].Wrap  end
                    end
                end
                return _origCVM(self, vmRef)
            end
        end

        -- Hook ClientViewModel.new
        local _vmMod = _lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
        if _vmMod then
            local _CVM = require(_vmMod)
            local _origNew = _CVM.new
            _CVM.new = function(repData, cliItm)
                local _wp  = cliItm.ClientFighter and cliItm.ClientFighter.Player
                local _wn  = cliItm.Name
                if _wp == _lp and CosmeticUnlocker._eq[_wn] then
                    local _RC  = require(_rs.Modules.ReplicatedClass)
                    local _dk  = _RC:ToEnum("Data")
                    repData[_dk] = repData[_dk] or {}
                    local _cos = CosmeticUnlocker._eq[_wn]
                    if _cos.Skin  then repData[_dk][_RC:ToEnum("Skin")]  = _cos.Skin  end
                    if _cos.Charm then repData[_dk][_RC:ToEnum("Charm")] = _cos.Charm end
                    if _cos.Wrap  then repData[_dk][_RC:ToEnum("Wrap")]  = _cos.Wrap  end
                end
                return _origNew(repData, cliItm)
            end
        end

        -- Export globally
        getgenv().CosmeticUnlocker = CosmeticUnlocker
        CosmeticUnlocker._active = true  -- mark as active
    end)
end

-- Export the start function globally so the UI toggle can call it
getgenv()._startCosmeticUnlocker = _startCosmeticUnlocker
getgenv().CosmeticUnlocker = CosmeticUnlocker

--// CONFIG
getgenv().whscript = "Zythera-X"
-- [V4] Ported: Anti-cheat bypass + Cosmetic unlocker + Rage Hub features (AutoBhop, CustomFOV, ShowFPS, Server Hop, better prediction, RaycastParams WallCheck)

-- [FIX] Webhook URL removed (was sending user data to external server)
getgenv().webhookexecUrl = ""

--// ANTI-LOGGER / URL BLOCK
-- [FIX] Removed anti-logger hook (was blocking all URL output to hide webhook activity)

--// BLOCK GLOBAL ID CREATION
if rawget(_G, "ID") then
    while true do end
end

setmetatable(_G, {
    __newindex = function(t, i, v)
        if tostring(i) == "ID" then
            while true do end
        end
        rawset(t, i, v)
    end
})

--// EXECUTION INITIALIZATION
-- [FIX] Removed webhook logging (was sending user data to external Discord server)

--// CLONEREF & CLONEFUNCTION — Anti-detection wrappers (safe version)
-- [V7 FIX] Some executors (like Ugc) have cloneref but it returns nil or errors.
-- We wrap it in pcall and fall back to the original instance if anything fails.
local _raw_cloneref = cloneref or clonereference
local function safe_cloneref(instance)
    if not instance then return instance end
    if not _raw_cloneref then return instance end  -- executor doesn't have cloneref
    local ok, result = pcall(_raw_cloneref, instance)
    if ok and result and typeof(result) == "Instance" then
        return result
    end
    return instance  -- fall back to original
end
local cloneref = safe_cloneref

local _raw_clonefn = clonefunction or copyfunction
local function safe_clonefunction(func)
    if not func then return func end
    if not _raw_clonefn then return func end
    local ok, result = pcall(_raw_clonefn, func)
    if ok and result and type(result) == "function" then
        return result
    end
    return func
end
local clonefunction = safe_clonefunction

--// SAFE FILE SYSTEM FUNCTIONS — Fixes executor compatibility
local isfolder, isfile, listfiles = isfolder, isfile, listfiles

if typeof(clonefunction) == "function" then
    local isfolder_copy = clonefunction(isfolder)
    local isfile_copy = clonefunction(isfile)
    local listfiles_copy = clonefunction(listfiles)

    local isfolder_success, isfolder_result = pcall(function()
        return isfolder_copy("test" .. tostring(math.random(1000000, 9999999)))
    end)

    if isfolder_success == false or typeof(isfolder_result) ~= "boolean" then
        isfolder = function(folder)
            local success, data = pcall(isfolder_copy, folder)
            if success then return data else return false end
        end

        isfile = function(file)
            local success, data = pcall(isfile_copy, file)
            if success then return data else return false end
        end

        listfiles = function(folder)
            local success, data = pcall(listfiles_copy, folder)
            if success then return data else return {} end
        end
    end
end

--// SERVICE PROXY — Auto-cloneref service access via setmetatable
-- Access any service as: ServiceProxy.Players, ServiceProxy.Workspace, etc.
-- Each lookup automatically applies cloneref for anti-instance-tracking
local ServiceProxy = setmetatable({}, {
    __index = function(_, serviceName)
        local success, service = pcall(function()
            return game:GetService(serviceName)
        end)
        if success and service then
            return cloneref(service)
        end
        return nil
    end
})

--// CLONED SERVICE REFERENCES — Anti-instance-tracking
local HttpService = cloneref(game:GetService("HttpService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local Workspace = cloneref(game:GetService("Workspace"))
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local StarterGui = cloneref(game:GetService("StarterGui"))
local TweenService = cloneref(game:GetService("TweenService"))

-- [V2] Additional cloneref'd services for anti-detection
local TeleportService = cloneref(game:GetService("TeleportService"))
local Lighting = cloneref(game:GetService("Lighting"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local VirtualInputManager = cloneref(game:GetService("VirtualInputManager"))
local Stats = cloneref(game:GetService("Stats"))

--// ANTI-CHEAT BYPASS — Minimal punishment-channel neutralizer (v3)
-- REVISED after user reported that v2 broke damage replication.
-- v2 hooked too broadly (VerifyClientEntity, Remotes.RemoteEvent, CameraSecurity,
-- defensive getgc sweep) — those are NOT punishment channels, they are gameplay
-- channels. Blocking them prevented the server from confirming hits → no damage.
--
-- v3 strategy: hook ONLY server-driven Ban/Kick punishment remotes.
-- These channels are NEVER used for normal gameplay — they exist purely for
-- moderation. Blocking OnClientEvent on them means: when the server tries to
-- kick/ban us (because it detected cheating), the kick never fires locally.
-- This is 100% safe for gameplay because Ban/Kick events carry no game state.
--
-- Channels we NOW LEAVE ALONE (v2 was wrong to hook these):
--   ✗ VerifyClientEntity  → server confirms our entity before replicating damage.
--                           Hooking this = server rejects our hits = NO DAMAGE.
--   ✗ Remotes.RemoteEvent → fired 3×/5s — that's LOW (a real heartbeat fires
--                           every frame = 60×/s). This is the shot/damage event
--                           channel, NOT AC telemetry. Hooking = NO DAMAGE.
--   ✗ CameraSecurity      → in Rivals this is the camera wall-collision system
--                           (prevents camera clipping through walls), NOT an AC.
--                           Hooking breaks camera + possibly hit detection.
--   ✗ generic getgc sweep → too many false positives; broke legitimate game code.
--
-- Multi-run: 0s / +8s / +25s / +60s to catch late-attached connections.

local ACBypassState = {
    runs = 0,
    remoteHooks = 0,
    hookedRemotes = {},  -- set of remote paths already hooked (avoids double-hook)
    hookedFunctions = {}, -- set of function addresses already hooked
}

-- Helper: hook every Function on a RemoteEvent's OnClientEvent to a no-op.
-- This blinds the channel — when the server fires it (to kick/ban us), our local
-- listener does nothing, so the kick/ban never executes on the client.
local function hookRemoteOnClientEvent(remotePath, remote)
    if not remote or not remote:IsA("RemoteEvent") then return 0 end
    if ACBypassState.hookedRemotes[remotePath] then return 0 end
    if not getconnections or not hookfunction then return 0 end

    local hooked = 0
    local ok, conns = pcall(getconnections, remote.OnClientEvent)
    if not ok or not conns then return 0 end

    for _, conn in ipairs(conns) do
        if conn and conn.Function then
            local fn = conn.Function
            local key = tostring(fn)
            if not ACBypassState.hookedFunctions[key] then
                ACBypassState.hookedFunctions[key] = true
                pcall(function()
                    hookfunction(fn, function(...)
                        return  -- swallow the kick/ban silently
                    end)
                end)
                hooked = hooked + 1
            end
        end
    end
    ACBypassState.hookedRemotes[remotePath] = true
    return hooked
end

-- Helper: neutralize a RemoteFunction's OnClientInvoke callback.
-- For moderation RemoteFunctions (FetchBannedPlayers, PardonRedFlags), the server
-- calls the client to ask for data/confirmation. Returning nil is safe — the
-- server treats nil as "no data" / "don't pardon", which is the default behavior.
local function hookRemoteFunctionInvoke(remotePath, remote)
    if not remote or not remote:IsA("RemoteFunction") then return 0 end
    if ACBypassState.hookedRemotes[remotePath] then return 0 end

    pcall(function()
        remote.OnClientInvoke = function(...)
            return nil
        end
    end)
    ACBypassState.hookedRemotes[remotePath] = true
    return 1
end

local function setupAnticheatBypass()
    pcall(function()
        ACBypassState.runs = ACBypassState.runs + 1
        local RS = game:GetService("ReplicatedStorage")
        local remotes = RS:FindFirstChild("Remotes")
        if not remotes then
            print("[Zythera-X] AC bypass run #" .. ACBypassState.runs .. ": Remotes folder not found yet")
            return
        end

        local totalRemoteHooks = 0

        -- PUNISHMENT REMOTES ONLY — these are the ONLY channels safe to blind.
        -- Ban/Kick events carry no gameplay state; they exist purely to punish.
        -- Hooking OnClientEvent means: when the server fires Ban/Kick at us,
        -- our local listener does nothing → we don't get kicked.
        local punishmentRemotes = {
            -- Moderator folder
            {"Moderator", "Ban"},                    -- RemoteEvent
            {"Moderator", "Kick"},                   -- RemoteEvent
            {"Moderator", "Unban"},                  -- RemoteEvent
            {"Moderator", "UpdateBanData"},          -- RemoteEvent
            {"Moderator", "LockBans"},               -- RemoteEvent
            {"Moderator", "PardonRedFlags"},         -- RemoteFunction
            -- PrivateServer folder
            {"PrivateServer", "BanPlayer"},          -- RemoteEvent
            {"PrivateServer", "KickPlayer"},         -- RemoteEvent
            {"PrivateServer", "UnbanPlayer"},        -- RemoteEvent
            {"PrivateServer", "ReplicateBannedPlayers"}, -- RemoteEvent
            {"PrivateServer", "FetchBannedPlayers"}, -- RemoteFunction
            -- Matchmaking folder
            {"Matchmaking", "KickPlayerFromParty"},  -- RemoteEvent
        }
        for _, path in ipairs(punishmentRemotes) do
            local parent = remotes:FindFirstChild(path[1])
            if parent then
                local remote = parent:FindFirstChild(path[2])
                if remote then
                    local fullPath = "Remotes." .. path[1] .. "." .. path[2]
                    if remote:IsA("RemoteEvent") then
                        totalRemoteHooks = totalRemoteHooks + hookRemoteOnClientEvent(fullPath, remote)
                    elseif remote:IsA("RemoteFunction") then
                        totalRemoteHooks = totalRemoteHooks + hookRemoteFunctionInvoke(fullPath, remote)
                    end
                end
            end
        end

        ACBypassState.remoteHooks = ACBypassState.remoteHooks + totalRemoteHooks

        print(("[Zythera-X] AC bypass run #%d — punishment remotes hooked this round: %d (total %d) | gameplay channels left intact (damage works)"):format(
            ACBypassState.runs, totalRemoteHooks, ACBypassState.remoteHooks))
    end)
end

setupAnticheatBypass()
task.delay(8, setupAnticheatBypass)
task.delay(25, setupAnticheatBypass)
task.delay(60, setupAnticheatBypass)

--// EXTRA AC BYPASS — Analytics/Log/Error/Kick neutralizer (user-requested layer)
-- Complements the punishment-remote bypass above by blinding additional AC channels:
--   1. AnalyticsPipeline.RemoteEvent.OnClientEvent — server telemetry that may flag cheaters
--   2. LogService.MessageOut — filters detection-related log messages from reaching server
--   3. ScriptContext.Error — reports existing error-listener connections (info only)
--   4. LocalPlayer:Kick() — intercepts :Kick() namecall to prevent local kick calls
pcall(function()
    print("[Zythera-X] Extra AC bypass: initializing...")

    local RS = cloneref(game:GetService("ReplicatedStorage"))
    local LogService = cloneref(game:GetService("LogService"))
    local ScriptContext = cloneref(game:GetService("ScriptContext"))
    local Players = cloneref(game:GetService("Players"))
    local StarterGui = cloneref(game:GetService("StarterGui"))
    local localPlayer = Players.LocalPlayer

    -- 1) AnalyticsPipeline remote hook — blind the OnClientEvent listeners
    task.spawn(function()
        pcall(function()
            local Remotes = RS:FindFirstChild("Remotes") or RS:WaitForChild("Remotes", 10)
            if not Remotes then return end
            local AnalyticsPipeline = Remotes:FindFirstChild("AnalyticsPipeline")
            if not AnalyticsPipeline then return end
            local RemoteEvent = AnalyticsPipeline:FindFirstChild("RemoteEvent")
            if not RemoteEvent or not RemoteEvent:IsA("RemoteEvent") then return end
            if not getconnections or not hookfunction then return end

            local ok, conns = pcall(getconnections, RemoteEvent.OnClientEvent)
            if not ok or not conns then return end
            local hooked = 0
            for _, conn in ipairs(conns) do
                if conn and conn.Function then
                    pcall(function()
                        hookfunction(conn.Function, function(...)
                            return -- swallow analytics event silently
                        end)
                    end)
                    hooked = hooked + 1
                end
            end
            print(("[Zythera-X] Hooked AnalyticsPipeline.OnClientEvent (%d connections)"):format(hooked))
        end)
    end)

    -- 2) LogService.MessageOut hook — filter AC-related log messages
    task.spawn(function()
        pcall(function()
            if not getconnections or not hookfunction then return end
            local ok, conns = pcall(getconnections, LogService.MessageOut)
            if not ok or not conns then return end
            local hooked = 0
            for _, conn in ipairs(conns) do
                if conn and conn.Function then
                    pcall(function()
                        local orig = conn.Function
                        hookfunction(orig, function(message, messageType)
                            local lower = string.lower(tostring(message))
                            -- Detection keywords that AC systems typically log
                            if string.find(lower, "cheat")
                            or string.find(lower, "exploit")
                            or string.find(lower, "hack")
                            or string.find(lower, "suspicious")
                            or string.find(lower, "anticheat")
                            or string.find(lower, "ac:")
                            or string.find(lower, "flag")
                            or string.find(lower, "detect")
                            or string.find(lower, "unauthorized")
                            or string.find(lower, "tamper")
                            then
                                return -- swallow AC telemetry log
                            end
                            return orig(message, messageType)
                        end)
                    end)
                    hooked = hooked + 1
                end
            end
            print(("[Zythera-X] Hooked LogService.MessageOut (%d connections)"):format(hooked))
        end)
    end)

    -- 3) ScriptContext.Error — report existing error-listener connections
    task.spawn(function()
        pcall(function()
            if not getconnections then return end
            local ok, conns = pcall(getconnections, ScriptContext.Error)
            if not ok or not conns then return end
            print(("[Zythera-X] ScriptContext.Error listeners found: %d (left intact — suppressing would break game error reporting)"):format(#conns))
        end)
    end)

    -- 4) LocalPlayer:Kick() — intercept via __namecall metamethod (most reliable method)
    -- FIX: Use the correct hookmetamethod pattern (return value + newcclosure) to prevent
    -- C stack overflow. Previous version used mt.__namecall which could re-trigger __namecall
    -- and cause infinite recursion in game's ControlModule/CameraModule/ClientFighter callbacks.
    task.spawn(function()
        pcall(function()
            if not hookmetamethod or not getnamecallmethod then return end
            local playerNamecall = localPlayer
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if (method == "Kick" or method == "kick") and self == playerNamecall then
                    print("[Zythera-X] Blocked LocalPlayer:" .. method .. "() call")
                    return -- swallow the kick
                end
                return oldNamecall(self, ...)
            end))
            print("[Zythera-X] Hooked LocalPlayer:Kick() via __namecall (newcclosure pattern)")
        end)
    end)

    -- Success notification
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Text = "success!",
            Title = "rivals ac disable",
            Duration = 5
        })
    end)

    print("[Zythera-X] Extra AC bypass: started successfully")
end)

-- Forward-declare WallbangStealthState so the rage-toggle-disable handler
-- (defined later in this file, but lexically before the Wallbang stealth block)
-- can reference it safely. The actual table is populated by applyWallbangMods() below.
local WallbangStealthState  -- forward declaration; assigned later in the Wallbang stealth block

local player = Players.LocalPlayer
local players = Players

--// INITIALIZE OBSIDIAN / LINORIA UI LIBRARY
-- [FIX] All external URL loads replaced with embedded code (no loadstring+HttpGet)
local lucide_embedded_source = [=[
local Lucide = {}

local IS_GETCUSTOMASSET_BROKEN = false

if writefile and isfolder and makefolder and getcustomasset then
        if not isfolder("lucide-icons") then
                makefolder("lucide-icons")
        end

        if not isfile("lucide-icons/version.txt") then
                writefile("lucide-icons/version.txt", "2026-06-01T02:15:52.057378077+00:00")
        end

        local ShouldUpdate = readfile("lucide-icons/version.txt") ~= "2026-06-01T02:15:52.057378077+00:00"

        if ShouldUpdate then
                writefile("lucide-icons/version.txt", "2026-06-01T02:15:52.057378077+00:00")
        end

        for spritesheet = 1, 2 do
                if isfile(`lucide-icons/{spritesheet}.png`) and not ShouldUpdate then
                        continue
                end

                writefile(
                        `lucide-icons/{spritesheet}.png`,
                        nil  -- [FIX] Spritesheet URL removed - icons will use fallback rendering
                )
        end

        local Success, _Error = pcall(function()
                return getcustomasset("lucide-icons/1.png")
        end)

        IS_GETCUSTOMASSET_BROKEN = not Success
end

local icons = {{"align-vertical-distribute-center","chevron-down","list-restart","table-cells-split","gavel","dna-off","refresh-ccw-dot","venus","bean","circle-question-mark","folder-code","bolt","heater","feather","align-horizontal-distribute-center","grip-vertical","pill-bottle","person-standing","badge-swiss-franc","between-horizontal-end","file-braces-corner","rotate-cw","house-plus","bus-front","shield-ellipsis","between-vertical-end","globe-lock","tags","concierge-bell","bookmark-minus","file-down","picture-in-picture","messages-square","scissors","file-check-corner","phone-call","anchor","hand-helping","text-wrap","birdhouse","wifi-off","cloud-alert","message-square","cloud-download","folder-plus","cctv-off","mirror-round","user-round","pointer","between-horizontal-start","chevrons-up-down","brush","message-circle-more","parentheses","book-up-2","flame","chevrons-up","square-dashed","square-mouse-pointer","superscript","signal","wifi-cog","hexagon","navigation-2-off","eye-off","arrows-up-from-line","file-code-corner","square-centerline-dashed-horizontal","panels-right-bottom","scaling","hash","arrow-left-from-line","ship","ticket-percent","calendar-clock","x","non-binary","voicemail","presentation","tree-palm","badge","captions-off","align-vertical-justify-center","download","mouse-right","lens-convex","focus","diamond-percent","arrow-big-up","volume-x","mouse-pointer-click","origami","hard-drive","grid-2x2-x","package-minus","cloud","pipette","corner-left-down","badge-cent","cloud-lightning","user-round-pen","arrow-left-to-line","book-open-text","monitor-cloud","parking-meter","cat","heart-handshake","dam","trees","ham","circle-pause","chess-king","bean-off","rat","separator-horizontal","ambulance","signal-zero","citrus","phone-missed","calendar-off","chart-column","battery-medium","square-minus","decimals-arrow-left","folder-output","menu","image-down","terminal","angry","circle-dot-dashed","medal","cake-slice","git-graph","armchair","tickets","qr-code","copy","goal","trending-down","creative-commons","ev-charger","user-star","road","nfc","align-center-horizontal","car","notebook-tabs","ear","videotape","sun-moon","chart-scatter","toolbox","calendar","calendar-cog","gallery-horizontal","clipboard-x","book-open","circle-pile","rectangle-ellipsis","badge-plus","badge-info","file-headphone","bow-arrow","clipboard-pen-line","user-round-key","folder-search","utensils-crossed","arrow-up","arrow-up-from-dot","align-vertical-justify-start","layers-minus","pause","shrub","flag","biceps-flexed","align-horizontal-distribute-end","donut","calendar-plus-2","move-vertical","file-pen-line","badge-russian-ruble","radius","pilcrow","corner-left-up","georgian-lari","cable","book-user","square-arrow-down","circle-plus","view","cctv","circle-arrow-left","volume","octagon-alert","panel-bottom-dashed","book-a","align-end-vertical","thumbs-up","globe","rabbit","layers-plus","banknote-arrow-down","message-square-off","dice-4","message-circle-x","folder-x","message-circle-warning","map","move","arrow-up-left","award","arrow-down-wide-narrow","unfold-horizontal","lens-concave","motorbike","music-4","shield-x","file-volume","disc-3","file-signal","columns-4","archive-x","square-dashed-kanban","mouse-pointer-2","clock-arrow-up","clock-fading","vegan","message-circle-plus","fast-forward","user-pen","chess-knight","wifi-pen","files","send-to-back","alarm-clock","shopping-basket","send","brush-cleaning","skip-back","book-audio","file-scan","message-square-dashed","chevrons-left","umbrella","skip-forward","clipboard-copy","map-pin-off","arrow-up-from-line","circle-chevron-up","circle-small","align-vertical-space-between","lamp-desk","circle-arrow-up","zap","beaker","paintbrush","broccoli","chevron-up","pen-tool","form","pencil-ruler","dna","arrow-big-down-dash","chart-area","bug-off","card-sim","map-pin-search","ellipse","spell-check","popcorn","blocks","washing-machine","microchip","badge-minus","cloud-sun","circle","shield-alert","map-minus","separator-vertical","ampersands","user-search","fence","square-user-round","sunrise","strikethrough","calendar-days","folder-bookmark","banknote-arrow-up","dollar-sign","message-square-quote","list-minus","cloud-hail","eye-closed","app-window-mac","ellipsis","copy-check","history","satellite","bookmark-plus","folder-key","coffee","circle-power","hourglass","tickets-plane","folder-git","bomb","layers-2","battery-full","user-minus","chart-gantt","folder-tree","command","badge-dollar-sign","align-start-vertical","briefcase-conveyor-belt","message-circle-question-mark","bluetooth-off","square-square","cannabis","book","grip-horizontal","circle-minus","audio-waveform","moon-star","arrow-down-narrow-wide","database-backup","wand","receipt-turkish-lira","calendar-minus-2","copy-minus","folder-input","book-image","mouse-left","shirt","server-off","move-up","plug-2","chess-rook","brackets","calendar-heart","list-ordered","mic-off","arrow-big-left","square-split-horizontal","clover","sun-snow","sofa","funnel-x","clock-2","calendar-fold","fish-off","baby","leaf","fold-vertical","hop","paperclip","cigarette","minus","smile-plus","diamond-plus","file-chart-column","triangle-dashed","git-pull-request-closed","badge-check","plug-zap","heading-4","chess-queen","graduation-cap","grid-3x2","zodiac-sagittarius","square-dashed-bottom-code","clock-7","ethernet-port","scan-text","shower-head","equal-not","move-down","clock-arrow-down","ticket-slash","ruler","circle-user-round","list-filter","map-pin-check","egg-off","cog","dog","swords","spotlight","panel-right-dashed","truck-electric","check-line","bubbles","bot","chart-bar-increasing","trash-2","air-vent","dot","file-symlink","clipboard-paste","chevron-last","book-heart","circle-parking","globe-check","cloud-check","panel-left","circle-chevron-right","squares-unite","arrow-down-up","git-fork","forward","brain-circuit","between-vertical-start","database","panel-right","log-out","git-branch-plus","clipboard-minus","file-text","table-rows-split","milk-off","tv-minimal","cloud-upload","banknote","drumstick","calendar-search","zoom-out","bell-ring","circle-chevron-left","zoom-in","arrow-down","arrow-up-down","folder-dot","zodiac-virgo","loader-pinwheel","whole-word","monitor","disc-2","trending-up-down","film","zodiac-pisces","underline","tv-minimal-play","circle-stop","align-vertical-space-around","zodiac-libra","zodiac-leo","zodiac-gemini","arrow-big-down","circle-parking-off","calendar-x-2","user-plus","move-diagonal-2","bandage","gallery-horizontal-end","panel-top-dashed","squircle","land-plot","tram-front","zodiac-aries","podcast","zodiac-aquarius","audio-lines","expand","x-line-top","square-chevron-up","flip-vertical-2","rocket","worm","ear-off","workflow","wine-off","wine","wind-arrow-down","printer","megaphone-off","weight","arrow-big-right","section","file-clock","plane-landing","toy-brick","square-chevron-down","dice-1","drill","app-window","shield-check","hand-metal","wifi-sync","spell-check-2","square-arrow-out-up-left","wifi-high","list-plus","wifi","rotate-ccw-key","wheat-off","chart-pie","wheat","weight-tilde","copy-slash","wind","reply","layout-panel-left","gamepad","circle-percent","webcam","circle-arrow-out-down-right","square-x","italic","chart-column-increasing","waypoints","step-forward","waves-vertical","a-arrow-down","container","sticker","waves-ladder","waves-horizontal","soap-dispenser-droplet","waves-arrow-down","watch","inspection-panel","import","badge-turkish-lira","square-terminal","file-music","wand-sparkles","beef","route-off","file-user","wallpaper","square-radical","wallet-minimal","image-upscale","book-type","smile","signpost-big","wallet-cards","cloudy","wallet","square-percent","vote","navigation-off","arrow-left","car-taxi-front","volume-off","skull","chevrons-right-left","volume-1","volleyball","utensils","video","telescope","vibrate","venus-and-mars","square-pause","align-end-horizontal","repeat-1","equal","megaphone","calendar-x","message-square-warning","vault","egg","badge-x","van","utility-pole","circle-pound-sterling","video-off","japanese-yen","users-round","users","user-x","library","file-terminal","circle-chevron-down","accessibility","user-round-x","square-library","amphora","user-round-search","tally-2","monitor-play","monitor-dot","user-round-cog","user-round-check","sheet","circle-check-big","user-lock","user-key","map-pinned","corner-down-left","circuit-board","stethoscope","square-arrow-up-right","user","maximize","folder-open-dot","book-dashed","upload","unplug","bluetooth","tree-pine","receipt-indian-rupee","square-slash","unlink","university","ungroup","unfold-vertical","book-plus","flask-conical","undo-2","funnel","square-star","folder-sync","undo","zodiac-ophiuchus","umbrella-off","type-outline","arrow-up-narrow-wide","fishing-hook","gamepad-directional","file-up","folder-root","frame","calendar-arrow-down","clock-12","turntable","turkish-lira","truck","images","lollipop","book-text","trophy","lamp-floor","file-plus-corner","image","ghost","badge-euro","bike","triangle-alert","triangle","trending-up","tree-deciduous","shell","transgender","chevron-left","option","train-front-tunnel","scroll-text","table-of-contents","move-3d","traffic-cone","tractor","toggle-right","tower-control","ferris-wheel","camera-off","salad","touchpad-off","touchpad","torus","tornado","group","tool-case","battery","toilet","tent-tree","toggle-left","rectangle-horizontal","timer-reset","rectangle-vertical","timer","bitcoin","timeline","battery-plus","database-search","ticket-x","file-diff","stretch-vertical","locate-fixed","shield-user","spline-pointer","move-left","axis-3d","heart-off","thermometer-sun","binoculars","thermometer-snowflake","thermometer","theater","rose","message-square-share","mail-minus","text-quote","phone-incoming","text-cursor-input","text-cursor","clipboard-pen","bottle-wine","alarm-clock-off","iteration-cw","list","text-align-justify","square-arrow-right","text-align-end","badge-pound-sterling","bookmark-check","text-align-center","test-tubes","test-tube-diagonal","a-arrow-up","clock-check","bug","tent","vibrate-off","mail-check","zodiac-cancer","tangent","file-code","snowflake","chart-column-big","locate","tally-3","cassette-tape","battery-low","list-video","tag","signpost","tablets","calendar-arrow-up","landmark","fish-symbol","tablet-smartphone","loader","bold","dice-2","file-type","clipboard-clock","beer","lectern","shield","table-properties","table-columns-split","binary","move-diagonal","table-cells-merge","door-closed","table-2","layout-template","table","syringe","save-off","bookmark-off","hand-heart","switch-camera","scan-qr-code","message-square-check","swiss-franc","bell-off","sunset","brain","sun-medium","sun-dim","folder-cog","key","clock-11","subscript","ticket-plus","arrow-up-0-1","bell-electric","stretch-horizontal","heading","book-open-check","panel-top-close","lasso-select","map-pin-x","stone","info","sticky-note-x","bus","chart-bar-stacked","bed-single","chart-no-axes-gantt","file-spreadsheet","file-minus-corner","clipboard-list","grid-2x2","contact-round","sticky-note-check","keyboard-off","sticky-note","file-badge","battery-warning","mail-question-mark","arrow-down-from-line","briefcase","biohazard","rectangle-circle","braces","scale-3d","panel-top-bottom-dashed","mail-x","square-dashed-mouse-pointer","user-cog","lock-open","step-back","pizza","list-indent-decrease","arrow-up-wide-narrow","star-off","clock-5","shield-cog","rotate-ccw","align-horizontal-justify-center","star","antenna","memory-stick","scan-eye","stamp","square-check","heart-plus","squirrel","map-pin-minus-inside","git-merge","gallery-vertical-end","component","hand-coins","zodiac-capricorn","wifi-low","heading-2","clock","file-pen","git-compare-arrows","cloud-sun-rain","align-horizontal-justify-start","squares-exclude","square-user","calculator","calendar-plus","square-stack","arrow-down-z-a","bath","square-split-vertical","unlink-2","square-sigma","square-scissors","folder-check","square-round-corner","book-key","ribbon","microwave","line-dot-right-horizontal","gallery-vertical","square-plus","square-play","square-dashed-text","map-pin-pen","move-up-left","square-pilcrow","folder-heart","square-pi","music-2","lock","arrow-up-a-z","square-parking","square-dashed-top-solid","panel-right-open","square-m","square-kanban","swatch-book","receipt-cent","spool","folder-archive","folder-symlink","columns-3","ban","message-square-x","paint-roller","square-equal","archive","square-dot","square-divide","building-2","circle-slash-2","square-dashed-bottom","cake","cloud-rain","chart-bar","square-code","wrench","list-indent-increase","square-chevron-left","search-alert","flag-triangle-right","square-chart-gantt","square-centerline-dashed-vertical","bell","square-bottom-dashed-scissors","square-asterisk","music-3","chart-bar-big","user-check","proportions","siren","plane","webhook-off","carrot","square-arrow-left","file-cog","circle-dashed","square-arrow-right-exit","square-arrow-right-enter","square-arrow-out-up-right","mailbox","squares-subtract","package-search","square-arrow-out-down-left","split","square-arrow-down-right","globe-x","forklift","monitor-pause","alarm-clock-minus","heart-x","eraser","book-marked","square","bluetooth-connected","rotate-ccw-square","chart-no-axes-column","cannabis-off","folder-kanban","sprout","mars-stroke","spray-can","sport-shoe","remove-formatting","file-box","speech","paint-bucket","glass-water","speaker","glasses","piggy-bank","sparkles","cuboid","cloud-off","check-check","activity","axe","plane-takeoff","sparkle","cloud-rain-wind","spade","flag-off","copy-x","file-axis-3d","radical","chart-column-decreasing","soup","bug-play","align-vertical-distribute-start","solar-panel","waves-arrow-up","tally-5","snail","smartphone-nfc","chevrons-left-right-ellipsis","circle-divide","smartphone","sliders-vertical","sliders-horizontal","life-buoy","saudi-riyal","mic-vocal","volume-2","battery-charging","russian-ruble","square-arrow-up-left","brick-wall-shield","footprints","signature","building","signal-medium","signal-low","git-branch","sigma","book-alert","link-2","astroid","bell-minus","image-up","closed-caption","drum","arrow-up-z-a","sun","fan","shrimp","file-key","house-heart","paintbrush-vertical","scissors-line-dashed","plug","shopping-bag","ship-wheel","ticket-check","combine","shield-question-mark","shield-plus","mountain","mars","picture-in-picture-2","radio-off","flower-2","shield-off","squares-intersect","shield-half","shield-cog-corner","keyboard-music","star-half","shield-ban","code-xml","pencil-line","mails","brain-cog","tablet","shelving-unit","pi","trash","book-down","hdmi-port","git-pull-request-draft","case-upper","circle-fading-arrow-up","share","croissant","shapes","settings-2","barcode","settings","server-crash","bed","server-cog","divide","grape","server","party-popper","file-chart-pie","send-horizontal","search-x","dice-6","search-slash","blender","search-code","zap-off","square-check-big","search","scroll","screen-share-off","laptop-minimal","screen-share","lock-keyhole","map-pin-minus","school","chart-spline","message-square-more","scan-search","chart-candlestick","list-music","arrow-down-a-z","circle-ellipsis","scan-face","move-horizontal","file-sliders","frown","scan-barcode","cup-soda","scan","rows-2","sword","infinity","package-open","earth","slice","dice-3","milk","mouse-pointer-ban","crown","circle-slash","circle-star","rotate-cw-square","atom","package-x","bed-double","satellite-dish","circle-dot","file-exclamation-point","hand-fist","message-circle-code","folder-git-2","message-square-code","sandwich","towel-rack","sailboat","arrow-big-left-dash","monitor-speaker","dumbbell","file-search-corner","rows-4","rows-3","scale","router","flashlight","panel-top-open","route","rotate-3d","notebook","redo-2","roller-coaster","square-menu","rewind","monitor-smartphone","laptop","scan-line","clock-4","square-arrow-up","book-minus","file-question-mark","replace-all","replace","repeat-off","arrow-down-to-line","repeat-2","refresh-ccw","venetian-mask","calendar-check-2","repeat","spline","banknote-x","git-pull-request-create-arrow","regex","circle-check","refrigerator","refresh-cw-off","refresh-cw","copyleft","redo","circle-play","timer-off","arrow-big-right-dash","rectangle-goggles","hard-hat","receipt-swiss-franc","backpack","receipt-russian-ruble","keyboard","receipt-japanese-yen","receipt-euro","rainbow","arrow-down-right","ratio","receipt","wifi-zero","radio-receiver","radio","radiation","radar","image-off","quote","pyramid","puzzle","projector","square-chevron-right","mail-search","printer-check","power-off","power","pound-sterling","popsicle","folder-search-2","tally-1","ampersand","plus","shopping-cart","align-vertical-justify-end","play-off","alarm-smoke","play","file-input","clock-8","hand-grab","cloud-cog","blend","hd","radio-tower","list-tree","droplet","pin-off","eye","crosshair","pill","banana","gpu","message-square-plus","pilcrow-left","circle-equal","pickaxe","piano","circle-alert","phone-off","text-initial","arrow-up-right","phone-forwarded","leafy-green","message-square-dot","file-chart-line","columns-3-cog","phone","grip","minimize-2","percent","pentagon","cone","pencil-off","file-image","diamond-minus","palette","barrel","gallery-thumbnails","pen-off","cpu","pen-line","thumbs-down","merge","hamburger","pc-case","hat-glasses","code","notepad-text","parasol","calendar-minus","panels-left-bottom","file-video-camera","panel-top","kanban","bone","apple","rocking-chair","bot-off","panel-right-close","panel-left-right-dashed","panel-left-open","circle-arrow-out-up-left","panel-left-dashed","cable-car","arrow-down-left","square-activity","hotel","cigarette-off","panel-bottom-close","message-circle","circle-arrow-out-up-right","panel-bottom","panda","fold-horizontal","shovel","calendar-1","cloud-moon","square-arrow-out-down-right","package-plus","clock-plus","save","cloud-snow","anvil","arrow-big-up-dash","dices","package-2","package","orbit","omega","logs","chevrons-down-up","clipboard-plus","circle-x","list-end","octagon-pause","octagon-minus","chevrons-right","move-right","message-square-reply","corner-down-right","nut-off","nut","lamp-wall-down","notepad-text-dashed","paw-print","ellipsis-vertical","globe-off","square-stop","arrow-up-1-0","align-horizontal-justify-end","scan-heart","align-vertical-distribute-end","heart-crack","airplay","newspaper","network","navigation-2","monitor-x","bell-check","navigation","square-pen","file-minus","move-up-right","dice-5","octagon","ticket","move-down-right","move-down-left","train-front","bookmark","microscope","album","mouse-pointer","chart-bar-decreasing","mouse-off","calendar-sync","funnel-plus","store","circle-arrow-down","notebook-pen","egg-fried","moon","monitor-up","corner-right-up","monitor-stop","ruler-dimension-line","user-round-plus","panel-left-close","monitor-off","pilcrow-right","user-round-minus","monitor-cog","monitor-check","mail-plus","layout-dashboard","heart-pulse","milestone","mouse-pointer-2-off","drone","slash","mic","aperture","arrow-right-left","case-sensitive","vector-square","circle-gauge","message-square-text","check","text-search","arrow-down-to-dot","monitor-down","message-square-lock","chef-hat","message-square-heart","message-square-diff","file-archive","signal-high","inbox","flip-horizontal-2","message-circle-off","image-play","align-horizontal-space-between","message-circle-heart","calendar-check","database-zap","droplets","message-circle-dashed","message-circle-check","meh","layout-list","file-search","maximize-2","alarm-clock-plus","circle-dollar-sign","usb","house","receipt-pound-sterling","list-check","map-pin-x-inside","id-card","mouse","minimize","map-pin-plus","diff","file-play","map-pin","book-x","mirror-rectangular","bird","mail","magnet","headphone-off","asterisk","circle-arrow-right","octagon-x","languages","log-in","alarm-clock-check","guitar","lock-keyhole-open","beer-off","scooter","square-parking-off","notebook-text","arrow-right-to-line","ticket-minus","tally-4","zodiac-taurus","loader-circle","door-open","flag-triangle-left","grid-3x3","file","diameter","pocket-knife","book-copy","castle","car-front","clock-alert","reply-all","cloud-moon-rain","clipboard-type","list-collapse","list-todo","printer-x","lamp-wall-up","list-start","list-chevrons-up-down","a-large-small","list-chevrons-down-up","list-checks","map-plus","link-2-off","link","line-style","line-squiggle","arrow-right-from-line","flame-kindling","square-power","calendar-range","bring-to-front","lightbulb","ligature","bell-plus","library-big","layout-panel-top","layout-grid","folders","mail-warning","layers","laugh","lasso","chevrons-left-right","chart-line","file-lock","cast","circle-fading-plus","clock-10","undo-dot","target","list-filter-plus","lamp-ceiling","drama","lamp","baseline","martini","contrast","key-square","candy-off","file-x-corner","book-check","kayak","book-lock","joystick","briefcase-medical","calendars","text-align-start","iteration-ccw","hop-off","warehouse","sticky-notes","drafting-compass","save-all","indian-rupee","image-plus","image-minus","id-card-lanyard","ice-cream-cone","fishing-rod","book-headphones","credit-card","ice-cream-bowl","house-wifi","house-plug","shredder","panel-bottom-open","hospital","highlighter","helicopter","balloon","map-pin-plus-inside","bookmark-x","badge-question-mark","pen","heart-minus","candy-cane","heart","headset","gamepad-2","file-x","heading-6","heading-5","heading-3","shield-minus","circle-off","dessert","eclipse","church","heading-1","cylinder","badge-japanese-yen","haze","receipt-text","hard-drive-upload","hard-drive-download","file-digit","handbag","file-output","disc-album","hand-platter","arrow-down-0-1","captions","hand","hammer","philippine-peso","badge-alert","flower","folder-pen","cross","grid-2x2-check","chevron-right","sticky-note-minus","square-arrow-down-left","share-2","git-pull-request-create","contact","folder-lock","git-merge-conflict","git-compare","git-commit-vertical","chess-pawn","git-commit-horizontal","briefcase-business","clipboard","message-circle-reply","gift","triangle-right","folder-clock","gem","gauge","type","webhook","fullscreen","align-horizontal-distribute-start","fuel","folder-up","pointer-off","turtle","camera","folder-open","folder-minus","git-pull-request","bluetooth-searching","arrow-up-to-line","squircle-dashed","clock-3","badge-percent","shuffle","folder-closed","folder","grid-2x2-plus","flask-round","box","flask-conical-off","clock-1","file-heart","flashlight-off","space","fish","fire-extinguisher","fingerprint-pattern","corner-up-left","clock-6","zodiac-scorpio","key-round","headphones","tv","file-type-corner","file-stack","rss","cookie","at-sign","map-pin-check-inside","sticky-note-off","music","handshake","file-check","circle-user","copy-plus","file-chart-column-increasing","file-braces","shrink","factory","external-link","search-check","clipboard-check","columns-2","euro","equal-approximately","align-center-vertical","earth-lock","droplet-off","club","cloud-fog","dock","disc","map-pin-house","package-check","chevron-first","pencil","cloud-drizzle","list-x","delete","computer","corner-up-right","currency","pin","crop","corner-right-down","badge-indian-rupee","copyright","redo-dot","brick-wall","align-start-horizontal","chart-column-stacked","file-plus","git-pull-request-arrow","construction","decimals-arrow-right","bell-dot","folder-down","compass","coins","align-horizontal-space-around","door-closed-locked","cloud-sync","diamond","blinds","cloud-backup","clock-9","book-search","git-branch-minus","clapperboard","recycle","mountain-snow","luggage","circle-arrow-out-down-left","bot-message-square","phone-outgoing","smartphone-charging","chevrons-down","train-track","chess-bishop","cherry","sticky-note-plus","chart-no-axes-column-increasing","chart-no-axes-column-decreasing","chart-network","chart-no-axes-combined","metronome","case-lower","arrow-down-1-0","caravan","candy","arrow-left-right","lightbulb-off","panels-top-left","beef-off","locate-off","annoyed","test-tube","brick-wall-fire","cooking-pot","boxes","boom-box","book-up","laptop-minimal-check","mail-open","square-function","baggage-claim","variable","arrow-right","archive-restore"},{if getcustomasset and not IS_GETCUSTOMASSET_BROKEN then getcustomasset("lucide-icons/1.png") else "rbxassetid://89707116417717",if getcustomasset and not IS_GETCUSTOMASSET_BROKEN then getcustomasset("lucide-icons/2.png") else "rbxassetid://101599128715386"},{[48]={{1,{24,24},{175,0}},{1,{24,24},{350,275}},{1,{24,24},{725,325}},{1,{24,24},{900,725}},{1,{24,24},{500,425}},{1,{24,24},{600,200}},{1,{24,24},{975,325}},{2,{24,24},{50,150}},{1,{24,24},{125,275}},{1,{24,24},{375,300}},{1,{24,24},{725,175}},{1,{24,24},{125,325}},{1,{24,24},{375,600}},{1,{24,24},{275,550}},{1,{24,24},{50,75}},{1,{24,24},{475,475}},{1,{24,24},{425,800}},{1,{24,24},{875,350}},{1,{24,24},{350,25}},{1,{24,24},{175,250}},{1,{24,24},{100,725}},{1,{24,24},{975,350}},{1,{24,24},{75,900}},{1,{24,24},{75,450}},{1,{24,24},{525,850}},{1,{24,24},{125,300}},{1,{24,24},{850,100}},{1,{24,24},{650,975}},{1,{24,24},{575,175}},{1,{24,24},{400,100}},{1,{24,24},{625,225}},{1,{24,24},{550,675}},{1,{24,24},{250,850}},{1,{24,24},{775,575}},{1,{24,24},{825,25}},{1,{24,24},{825,400}},{1,{24,24},{100,100}},{1,{24,24},{200,750}},{1,{24,24},{725,950}},{1,{24,24},{400,50}},{2,{24,24},{175,125}},{1,{24,24},{725,0}},{1,{24,24},{275,825}},{1,{24,24},{625,100}},{1,{24,24},{325,575}},{1,{24,24},{600,0}},{1,{24,24},{750,375}},{2,{24,24},{50,100}},{1,{24,24},{725,525}},{1,{24,24},{150,275}},{1,{24,24},{25,600}},{1,{24,24},{250,275}},{1,{24,24},{875,225}},{1,{24,24},{500,700}},{1,{24,24},{25,450}},{1,{24,24},{250,625}},{1,{24,24},{0,625}},{1,{24,24},{800,700}},{1,{24,24},{550,950}},{1,{24,24},{750,850}},{1,{24,24},{450,950}},{2,{24,24},{250,50}},{1,{24,24},{325,650}},{1,{24,24},{425,725}},{1,{24,24},{400,425}},{1,{24,24},{225,100}},{1,{24,24},{750,100}},{1,{24,24},{700,775}},{1,{24,24},{600,600}},{1,{24,24},{425,900}},{1,{24,24},{950,25}},{1,{24,24},{75,200}},{1,{24,24},{875,525}},{1,{24,24},{800,900}},{1,{24,24},{350,200}},{2,{24,24},{200,125}},{1,{24,24},{250,900}},{2,{24,24},{125,100}},{1,{24,24},{575,675}},{1,{24,24},{925,875}},{1,{24,24},{275,100}},{1,{24,24},{350,225}},{1,{24,24},{100,75}},{1,{24,24},{350,450}},{1,{24,24},{925,225}},{1,{24,24},{450,575}},{1,{24,24},{0,875}},{1,{24,24},{175,600}},{1,{24,24},{125,125}},{2,{24,24},{0,225}},{1,{24,24},{975,175}},{1,{24,24},{650,525}},{1,{24,24},{0,950}},{1,{24,24},{600,350}},{1,{24,24},{575,600}},{1,{24,24},{250,475}},{1,{24,24},{325,900}},{1,{24,24},{100,650}},{1,{24,24},{275,75}},{1,{24,24},{525,200}},{2,{24,24},{150,0}},{1,{24,24},{25,250}},{1,{24,24},{175,300}},{1,{24,24},{700,425}},{1,{24,24},{475,725}},{1,{24,24},{0,575}},{1,{24,24},{550,425}},{1,{24,24},{450,325}},{1,{24,24},{875,925}},{1,{24,24},{375,575}},{1,{24,24},{550,125}},{1,{24,24},{475,150}},{1,{24,24},{150,250}},{1,{24,24},{800,475}},{1,{24,24},{375,975}},{1,{24,24},{200,0}},{1,{24,24},{475,925}},{1,{24,24},{100,575}},{1,{24,24},{750,475}},{1,{24,24},{175,375}},{1,{24,24},{275,325}},{1,{24,24},{275,125}},{1,{24,24},{575,925}},{1,{24,24},{325,450}},{1,{24,24},{375,525}},{1,{24,24},{125,950}},{1,{24,24},{900,100}},{1,{24,24},{725,925}},{1,{24,24},{75,125}},{1,{24,24},{125,525}},{1,{24,24},{250,825}},{1,{24,24},{550,0}},{1,{24,24},{175,750}},{1,{24,24},{50,175}},{1,{24,24},{925,800}},{1,{24,24},{375,875}},{1,{24,24},{225,525}},{1,{24,24},{750,200}},{1,{24,24},{850,950}},{1,{24,24},{725,50}},{1,{24,24},{500,325}},{2,{24,24},{0,150}},{1,{24,24},{550,750}},{1,{24,24},{275,875}},{1,{24,24},{0,100}},{1,{24,24},{250,325}},{1,{24,24},{200,950}},{1,{24,24},{50,750}},{2,{24,24},{175,50}},{1,{24,24},{875,725}},{1,{24,24},{25,575}},{1,{24,24},{950,800}},{1,{24,24},{575,0}},{1,{24,24},{325,225}},{1,{24,24},{700,225}},{1,{24,24},{525,175}},{1,{24,24},{150,325}},{1,{24,24},{500,175}},{1,{24,24},{475,800}},{1,{24,24},{50,300}},{1,{24,24},{150,200}},{1,{24,24},{575,275}},{1,{24,24},{150,350}},{1,{24,24},{625,75}},{2,{24,24},{25,100}},{1,{24,24},{250,650}},{2,{24,24},{75,100}},{1,{24,24},{250,75}},{1,{24,24},{100,200}},{1,{24,24},{50,125}},{1,{24,24},{775,250}},{1,{24,24},{425,775}},{1,{24,24},{625,775}},{1,{24,24},{300,575}},{1,{24,24},{75,350}},{1,{24,24},{25,100}},{1,{24,24},{475,325}},{1,{24,24},{150,400}},{1,{24,24},{575,575}},{1,{24,24},{325,525}},{1,{24,24},{375,0}},{1,{24,24},{850,425}},{1,{24,24},{450,775}},{1,{24,24},{75,675}},{1,{24,24},{450,475}},{1,{24,24},{0,525}},{1,{24,24},{500,0}},{1,{24,24},{525,925}},{1,{24,24},{450,225}},{2,{24,24},{150,75}},{1,{24,24},{575,25}},{1,{24,24},{525,125}},{2,{24,24},{250,0}},{1,{24,24},{850,325}},{1,{24,24},{250,925}},{1,{24,24},{50,400}},{1,{24,24},{75,50}},{1,{24,24},{875,825}},{1,{24,24},{775,175}},{1,{24,24},{325,925}},{1,{24,24},{750,275}},{1,{24,24},{125,250}},{1,{24,24},{475,625}},{1,{24,24},{25,750}},{1,{24,24},{725,375}},{1,{24,24},{125,775}},{1,{24,24},{750,350}},{1,{24,24},{400,675}},{1,{24,24},{550,600}},{1,{24,24},{50,250}},{1,{24,24},{50,275}},{1,{24,24},{150,125}},{2,{24,24},{25,0}},{1,{24,24},{475,550}},{1,{24,24},{325,800}},{1,{24,24},{475,675}},{1,{24,24},{950,450}},{1,{24,24},{700,175}},{1,{24,24},{700,100}},{1,{24,24},{100,750}},{1,{24,24},{725,25}},{1,{24,24},{100,125}},{1,{24,24},{900,600}},{1,{24,24},{175,950}},{1,{24,24},{125,575}},{1,{24,24},{75,625}},{2,{24,24},{125,75}},{1,{24,24},{825,275}},{1,{24,24},{300,525}},{2,{24,24},{125,0}},{1,{24,24},{450,175}},{2,{24,24},{150,150}},{1,{24,24},{600,275}},{1,{24,24},{425,925}},{1,{24,24},{75,25}},{1,{24,24},{800,600}},{1,{24,24},{400,950}},{1,{24,24},{275,250}},{1,{24,24},{900,525}},{1,{24,24},{0,450}},{1,{24,24},{175,675}},{1,{24,24},{625,475}},{1,{24,24},{100,525}},{1,{24,24},{925,975}},{1,{24,24},{875,550}},{1,{24,24},{0,675}},{1,{24,24},{650,425}},{1,{24,24},{75,225}},{1,{24,24},{225,425}},{1,{24,24},{300,375}},{1,{24,24},{0,175}},{1,{24,24},{175,825}},{1,{24,24},{375,275}},{2,{24,24},{150,175}},{1,{24,24},{175,225}},{1,{24,24},{350,825}},{1,{24,24},{300,225}},{1,{24,24},{225,400}},{1,{24,24},{300,900}},{1,{24,24},{0,900}},{1,{24,24},{975,250}},{1,{24,24},{575,225}},{1,{24,24},{25,200}},{1,{24,24},{550,50}},{1,{24,24},{200,325}},{1,{24,24},{200,375}},{1,{24,24},{550,525}},{1,{24,24},{725,100}},{1,{24,24},{825,625}},{1,{24,24},{700,550}},{1,{24,24},{275,175}},{2,{24,24},{25,225}},{1,{24,24},{125,975}},{1,{24,24},{100,250}},{1,{24,24},{325,400}},{1,{24,24},{150,525}},{1,{24,24},{650,725}},{1,{24,24},{800,275}},{1,{24,24},{975,400}},{1,{24,24},{150,50}},{2,{24,24},{25,125}},{1,{24,24},{250,575}},{1,{24,24},{900,650}},{1,{24,24},{800,800}},{1,{24,24},{975,625}},{1,{24,24},{300,250}},{1,{24,24},{825,75}},{1,{24,24},{100,275}},{1,{24,24},{500,300}},{1,{24,24},{425,675}},{1,{24,24},{825,225}},{1,{24,24},{550,175}},{1,{24,24},{425,400}},{1,{24,24},{200,25}},{1,{24,24},{675,150}},{1,{24,24},{350,400}},{1,{24,24},{275,700}},{1,{24,24},{600,725}},{1,{24,24},{350,150}},{1,{24,24},{500,400}},{1,{24,24},{100,625}},{1,{24,24},{400,275}},{1,{24,24},{150,825}},{1,{24,24},{950,775}},{1,{24,24},{600,300}},{1,{24,24},{100,350}},{1,{24,24},{800,225}},{1,{24,24},{325,75}},{2,{24,24},{0,100}},{1,{24,24},{250,350}},{1,{24,24},{175,725}},{1,{24,24},{675,75}},{1,{24,24},{225,125}},{1,{24,24},{0,150}},{1,{24,24},{400,125}},{1,{24,24},{800,300}},{1,{24,24},{225,225}},{1,{24,24},{575,950}},{1,{24,24},{375,200}},{1,{24,24},{450,50}},{1,{24,24},{500,450}},{1,{24,24},{650,25}},{1,{24,24},{75,250}},{1,{24,24},{375,750}},{1,{24,24},{275,0}},{1,{24,24},{425,350}},{2,{24,24},{75,175}},{1,{24,24},{550,725}},{1,{24,24},{225,325}},{1,{24,24},{325,425}},{1,{24,24},{550,350}},{1,{24,24},{325,150}},{1,{24,24},{250,875}},{1,{24,24},{850,550}},{1,{24,24},{900,475}},{1,{24,24},{600,550}},{1,{24,24},{900,350}},{1,{24,24},{375,250}},{1,{24,24},{50,450}},{1,{24,24},{250,300}},{1,{24,24},{775,275}},{1,{24,24},{200,900}},{1,{24,24},{225,25}},{1,{24,24},{625,900}},{1,{24,24},{200,525}},{1,{24,24},{850,750}},{1,{24,24},{525,900}},{1,{24,24},{775,150}},{1,{24,24},{375,325}},{1,{24,24},{275,275}},{1,{24,24},{500,375}},{1,{24,24},{350,0}},{1,{24,24},{550,475}},{1,{24,24},{875,25}},{1,{24,24},{225,750}},{1,{24,24},{550,650}},{1,{24,24},{600,50}},{1,{24,24},{800,325}},{1,{24,24},{650,775}},{1,{24,24},{150,625}},{1,{24,24},{25,800}},{1,{24,24},{925,900}},{1,{24,24},{75,850}},{1,{24,24},{250,100}},{1,{24,24},{875,375}},{1,{24,24},{750,225}},{1,{24,24},{400,225}},{1,{24,24},{700,250}},{1,{24,24},{550,400}},{2,{24,24},{275,75}},{1,{24,24},{950,550}},{1,{24,24},{250,450}},{1,{24,24},{550,275}},{1,{24,24},{875,475}},{1,{24,24},{725,675}},{1,{24,24},{625,200}},{1,{24,24},{750,400}},{1,{24,24},{150,550}},{1,{24,24},{750,950}},{1,{24,24},{750,575}},{1,{24,24},{225,450}},{1,{24,24},{900,150}},{1,{24,24},{750,325}},{1,{24,24},{775,50}},{1,{24,24},{75,650}},{1,{24,24},{525,275}},{1,{24,24},{625,975}},{1,{24,24},{675,775}},{1,{24,24},{825,375}},{1,{24,24},{975,875}},{1,{24,24},{600,25}},{1,{24,24},{225,300}},{1,{24,24},{200,300}},{1,{24,24},{475,125}},{1,{24,24},{800,975}},{1,{24,24},{0,50}},{1,{24,24},{375,425}},{1,{24,24},{0,850}},{1,{24,24},{650,50}},{1,{24,24},{300,325}},{1,{24,24},{350,125}},{1,{24,24},{575,100}},{1,{24,24},{875,75}},{1,{24,24},{675,50}},{1,{24,24},{875,325}},{1,{24,24},{250,400}},{1,{24,24},{725,825}},{1,{24,24},{175,100}},{1,{24,24},{200,725}},{1,{24,24},{925,0}},{1,{24,24},{25,475}},{1,{24,24},{100,325}},{1,{24,24},{350,425}},{1,{24,24},{775,425}},{1,{24,24},{275,775}},{1,{24,24},{350,575}},{1,{24,24},{675,25}},{1,{24,24},{850,25}},{1,{24,24},{800,825}},{1,{24,24},{900,225}},{1,{24,24},{950,925}},{1,{24,24},{275,450}},{1,{24,24},{50,325}},{1,{24,24},{125,675}},{1,{24,24},{75,475}},{2,{24,24},{150,200}},{1,{24,24},{225,200}},{1,{24,24},{275,375}},{2,{24,24},{175,175}},{1,{24,24},{100,175}},{1,{24,24},{125,175}},{1,{24,24},{675,225}},{2,{24,24},{200,150}},{1,{24,24},{525,525}},{2,{24,24},{275,25}},{1,{24,24},{400,725}},{1,{24,24},{725,75}},{1,{24,24},{825,975}},{1,{24,24},{575,300}},{2,{24,24},{300,50}},{1,{24,24},{975,950}},{1,{24,24},{975,900}},{1,{24,24},{250,425}},{1,{24,24},{25,150}},{2,{24,24},{350,0}},{2,{24,24},{0,325}},{2,{24,24},{25,300}},{1,{24,24},{0,225}},{1,{24,24},{600,75}},{1,{24,24},{25,525}},{2,{24,24},{100,25}},{1,{24,24},{850,300}},{1,{24,24},{150,225}},{1,{24,24},{725,200}},{1,{24,24},{700,500}},{1,{24,24},{675,875}},{1,{24,24},{50,950}},{1,{24,24},{850,925}},{2,{24,24},{100,225}},{1,{24,24},{775,475}},{2,{24,24},{125,200}},{1,{24,24},{100,225}},{1,{24,24},{475,350}},{2,{24,24},{225,100}},{1,{24,24},{500,975}},{1,{24,24},{75,800}},{1,{24,24},{525,775}},{2,{24,24},{275,50}},{1,{24,24},{75,725}},{2,{24,24},{300,25}},{2,{24,24},{0,300}},{2,{24,24},{325,0}},{2,{24,24},{50,250}},{1,{24,24},{500,750}},{1,{24,24},{225,850}},{2,{24,24},{25,250}},{1,{24,24},{175,75}},{1,{24,24},{475,875}},{1,{24,24},{775,75}},{1,{24,24},{275,950}},{1,{24,24},{775,975}},{1,{24,24},{575,900}},{1,{24,24},{100,675}},{1,{24,24},{275,525}},{1,{24,24},{175,50}},{1,{24,24},{600,775}},{1,{24,24},{175,775}},{2,{24,24},{125,175}},{1,{24,24},{850,600}},{1,{24,24},{950,525}},{2,{24,24},{225,75}},{1,{24,24},{750,300}},{2,{24,24},{75,225}},{1,{24,24},{400,900}},{2,{24,24},{0,275}},{1,{24,24},{50,550}},{2,{24,24},{300,0}},{2,{24,24},{50,225}},{1,{24,24},{275,475}},{2,{24,24},{25,275}},{1,{24,24},{625,675}},{1,{24,24},{625,400}},{1,{24,24},{550,375}},{1,{24,24},{525,150}},{2,{24,24},{125,150}},{1,{24,24},{475,175}},{1,{24,24},{850,700}},{1,{24,24},{525,475}},{1,{24,24},{325,275}},{2,{24,24},{150,125}},{1,{24,24},{925,650}},{2,{24,24},{175,100}},{1,{24,24},{0,0}},{1,{24,24},{450,300}},{1,{24,24},{875,700}},{2,{24,24},{200,75}},{2,{24,24},{225,50}},{1,{24,24},{550,875}},{2,{24,24},{275,0}},{2,{24,24},{0,250}},{1,{24,24},{550,450}},{1,{24,24},{675,325}},{1,{24,24},{325,50}},{1,{24,24},{925,625}},{1,{24,24},{375,475}},{2,{24,24},{100,150}},{1,{24,24},{0,400}},{1,{24,24},{950,375}},{1,{24,24},{750,125}},{2,{24,24},{125,125}},{1,{24,24},{750,775}},{2,{24,24},{175,75}},{1,{24,24},{750,250}},{1,{24,24},{50,425}},{1,{24,24},{625,800}},{1,{24,24},{975,450}},{2,{24,24},{200,50}},{1,{24,24},{225,500}},{2,{24,24},{150,100}},{1,{24,24},{900,625}},{2,{24,24},{225,25}},{1,{24,24},{375,775}},{1,{24,24},{0,275}},{1,{24,24},{275,300}},{2,{24,24},{25,200}},{1,{24,24},{850,575}},{1,{24,24},{75,550}},{2,{24,24},{75,150}},{2,{24,24},{100,125}},{2,{24,24},{50,125}},{2,{24,24},{200,25}},{1,{24,24},{800,850}},{2,{24,24},{0,200}},{2,{24,24},{75,125}},{1,{24,24},{950,575}},{1,{24,24},{100,25}},{1,{24,24},{800,500}},{1,{24,24},{600,225}},{1,{24,24},{200,875}},{1,{24,24},{0,550}},{1,{24,24},{325,775}},{2,{24,24},{175,25}},{1,{24,24},{750,75}},{1,{24,24},{300,75}},{2,{24,24},{0,175}},{2,{24,24},{25,150}},{1,{24,24},{425,250}},{2,{24,24},{225,0}},{1,{24,24},{450,550}},{2,{24,24},{125,50}},{2,{24,24},{100,75}},{2,{24,24},{175,0}},{1,{24,24},{400,625}},{1,{24,24},{875,0}},{1,{24,24},{300,350}},{1,{24,24},{50,0}},{2,{24,24},{75,75}},{1,{24,24},{650,850}},{1,{24,24},{125,75}},{2,{24,24},{100,50}},{1,{24,24},{950,700}},{1,{24,24},{550,575}},{1,{24,24},{650,475}},{2,{24,24},{50,75}},{2,{24,24},{75,50}},{1,{24,24},{725,650}},{1,{24,24},{350,300}},{2,{24,24},{25,75}},{2,{24,24},{50,50}},{1,{24,24},{450,625}},{1,{24,24},{150,600}},{1,{24,24},{125,550}},{1,{24,24},{900,675}},{1,{24,24},{800,675}},{2,{24,24},{150,25}},{1,{24,24},{275,800}},{1,{24,24},{425,475}},{1,{24,24},{425,50}},{2,{24,24},{25,50}},{2,{24,24},{50,25}},{1,{24,24},{175,275}},{1,{24,24},{900,900}},{1,{24,24},{700,575}},{1,{24,24},{650,875}},{2,{24,24},{75,0}},{2,{24,24},{25,25}},{2,{24,24},{50,0}},{2,{24,24},{0,25}},{1,{24,24},{125,350}},{1,{24,24},{150,725}},{1,{24,24},{950,975}},{1,{24,24},{750,175}},{1,{24,24},{975,575}},{1,{24,24},{200,700}},{2,{24,24},{0,0}},{2,{24,24},{325,25}},{1,{24,24},{950,950}},{1,{24,24},{900,975}},{1,{24,24},{25,275}},{1,{24,24},{425,450}},{1,{24,24},{575,350}},{1,{24,24},{775,100}},{1,{24,24},{300,600}},{1,{24,24},{900,25}},{1,{24,24},{450,100}},{1,{24,24},{400,300}},{1,{24,24},{900,950}},{1,{24,24},{925,925}},{1,{24,24},{950,900}},{1,{24,24},{700,300}},{1,{24,24},{225,825}},{1,{24,24},{75,400}},{1,{24,24},{850,975}},{1,{24,24},{150,850}},{1,{24,24},{250,600}},{1,{24,24},{725,275}},{1,{24,24},{425,500}},{1,{24,24},{200,150}},{1,{24,24},{50,375}},{1,{24,24},{950,875}},{1,{24,24},{875,950}},{1,{24,24},{975,850}},{1,{24,24},{950,850}},{1,{24,24},{700,675}},{1,{24,24},{825,950}},{1,{24,24},{275,350}},{1,{24,24},{700,475}},{1,{24,24},{925,850}},{1,{24,24},{675,675}},{1,{24,24},{850,775}},{1,{24,24},{875,275}},{1,{24,24},{950,825}},{1,{24,24},{975,800}},{1,{24,24},{775,950}},{1,{24,24},{800,950}},{1,{24,24},{225,600}},{1,{24,24},{525,50}},{1,{24,24},{675,650}},{1,{24,24},{875,875}},{1,{24,24},{850,900}},{1,{24,24},{900,850}},{1,{24,24},{925,825}},{1,{24,24},{425,525}},{1,{24,24},{975,775}},{1,{24,24},{200,200}},{1,{24,24},{750,975}},{1,{24,24},{775,875}},{1,{24,24},{800,925}},{1,{24,24},{425,850}},{1,{24,24},{850,875}},{1,{24,24},{400,875}},{1,{24,24},{825,900}},{1,{24,24},{375,75}},{1,{24,24},{900,825}},{1,{24,24},{250,150}},{1,{24,24},{400,375}},{1,{24,24},{725,975}},{1,{24,24},{675,175}},{1,{24,24},{600,975}},{1,{24,24},{475,575}},{1,{24,24},{975,425}},{1,{24,24},{800,650}},{1,{24,24},{700,450}},{1,{24,24},{0,325}},{1,{24,24},{500,475}},{1,{24,24},{950,750}},{1,{24,24},{0,425}},{1,{24,24},{975,725}},{1,{24,24},{925,775}},{1,{24,24},{700,975}},{1,{24,24},{450,850}},{1,{24,24},{375,725}},{1,{24,24},{125,925}},{1,{24,24},{775,900}},{1,{24,24},{775,450}},{1,{24,24},{850,825}},{1,{24,24},{825,850}},{1,{24,24},{600,100}},{1,{24,24},{175,325}},{1,{24,24},{0,75}},{1,{24,24},{475,525}},{1,{24,24},{575,475}},{1,{24,24},{900,775}},{1,{24,24},{850,625}},{1,{24,24},{925,750}},{1,{24,24},{25,325}},{1,{24,24},{425,75}},{1,{24,24},{950,725}},{1,{24,24},{975,700}},{1,{24,24},{700,950}},{1,{24,24},{25,0}},{1,{24,24},{100,600}},{1,{24,24},{150,375}},{1,{24,24},{750,900}},{2,{24,24},{25,175}},{1,{24,24},{150,900}},{2,{24,24},{75,250}},{1,{24,24},{850,800}},{1,{24,24},{725,125}},{1,{24,24},{575,850}},{1,{24,24},{375,225}},{1,{24,24},{425,625}},{1,{24,24},{925,725}},{1,{24,24},{75,500}},{1,{24,24},{300,100}},{1,{24,24},{625,425}},{1,{24,24},{675,950}},{1,{24,24},{950,475}},{1,{24,24},{700,925}},{1,{24,24},{425,125}},{1,{24,24},{25,975}},{1,{24,24},{475,400}},{1,{24,24},{750,875}},{1,{24,24},{500,550}},{1,{24,24},{150,300}},{1,{24,24},{75,700}},{1,{24,24},{800,75}},{1,{24,24},{25,650}},{1,{24,24},{400,25}},{1,{24,24},{500,525}},{1,{24,24},{925,475}},{1,{24,24},{825,800}},{1,{24,24},{875,750}},{1,{24,24},{25,400}},{1,{24,24},{825,325}},{1,{24,24},{925,700}},{1,{24,24},{425,375}},{1,{24,24},{950,675}},{1,{24,24},{575,450}},{1,{24,24},{775,850}},{1,{24,24},{975,650}},{1,{24,24},{525,800}},{1,{24,24},{375,125}},{1,{24,24},{225,725}},{1,{24,24},{675,925}},{1,{24,24},{925,425}},{1,{24,24},{675,425}},{1,{24,24},{700,900}},{1,{24,24},{275,150}},{1,{24,24},{775,825}},{1,{24,24},{525,0}},{1,{24,24},{900,700}},{1,{24,24},{925,675}},{1,{24,24},{700,200}},{1,{24,24},{300,700}},{1,{24,24},{425,275}},{1,{24,24},{950,650}},{1,{24,24},{775,925}},{1,{24,24},{200,100}},{1,{24,24},{325,100}},{1,{24,24},{625,950}},{1,{24,24},{675,300}},{1,{24,24},{200,275}},{1,{24,24},{725,475}},{1,{24,24},{875,150}},{1,{24,24},{500,575}},{1,{24,24},{675,900}},{1,{24,24},{575,425}},{1,{24,24},{750,825}},{1,{24,24},{50,475}},{1,{24,24},{450,150}},{1,{24,24},{75,325}},{1,{24,24},{75,525}},{1,{24,24},{50,800}},{1,{24,24},{425,425}},{1,{24,24},{700,0}},{1,{24,24},{575,375}},{1,{24,24},{500,250}},{1,{24,24},{850,725}},{1,{24,24},{250,750}},{1,{24,24},{725,850}},{1,{24,24},{150,675}},{1,{24,24},{225,175}},{1,{24,24},{975,100}},{1,{24,24},{25,225}},{1,{24,24},{350,175}},{1,{24,24},{450,0}},{1,{24,24},{500,775}},{1,{24,24},{75,425}},{1,{24,24},{475,850}},{1,{24,24},{750,450}},{1,{24,24},{900,175}},{1,{24,24},{875,625}},{2,{24,24},{75,25}},{1,{24,24},{350,700}},{1,{24,24},{950,625}},{1,{24,24},{300,925}},{1,{24,24},{875,175}},{1,{24,24},{300,25}},{1,{24,24},{575,975}},{1,{24,24},{300,400}},{1,{24,24},{550,825}},{1,{24,24},{350,950}},{1,{24,24},{150,0}},{1,{24,24},{975,600}},{1,{24,24},{25,175}},{1,{24,24},{150,925}},{1,{24,24},{375,950}},{1,{24,24},{625,925}},{1,{24,24},{600,875}},{1,{24,24},{475,500}},{1,{24,24},{650,900}},{1,{24,24},{700,375}},{1,{24,24},{125,800}},{1,{24,24},{650,275}},{1,{24,24},{625,125}},{1,{24,24},{300,650}},{2,{24,24},{50,275}},{2,{24,24},{200,100}},{1,{24,24},{800,175}},{1,{24,24},{25,675}},{1,{24,24},{300,550}},{1,{24,24},{250,675}},{1,{24,24},{350,375}},{1,{24,24},{100,50}},{1,{24,24},{800,750}},{1,{24,24},{875,675}},{1,{24,24},{500,50}},{1,{24,24},{125,425}},{1,{24,24},{550,975}},{1,{24,24},{125,150}},{1,{24,24},{375,25}},{1,{24,24},{600,925}},{2,{24,24},{0,50}},{1,{24,24},{675,850}},{1,{24,24},{700,825}},{1,{24,24},{800,100}},{1,{24,24},{725,800}},{1,{24,24},{300,175}},{1,{24,24},{575,725}},{1,{24,24},{950,175}},{1,{24,24},{275,750}},{1,{24,24},{625,300}},{1,{24,24},{800,725}},{1,{24,24},{825,700}},{1,{24,24},{850,650}},{1,{24,24},{625,450}},{1,{24,24},{650,500}},{1,{24,24},{850,675}},{1,{24,24},{575,325}},{1,{24,24},{875,650}},{1,{24,24},{525,625}},{1,{24,24},{325,725}},{1,{24,24},{150,150}},{1,{24,24},{975,550}},{1,{24,24},{825,675}},{1,{24,24},{800,400}},{1,{24,24},{625,875}},{1,{24,24},{675,825}},{1,{24,24},{725,875}},{1,{24,24},{750,525}},{1,{24,24},{725,725}},{1,{24,24},{850,50}},{1,{24,24},{225,675}},{1,{24,24},{750,0}},{1,{24,24},{200,175}},{1,{24,24},{300,800}},{1,{24,24},{400,775}},{1,{24,24},{725,775}},{1,{24,24},{75,150}},{1,{24,24},{750,750}},{1,{24,24},{775,725}},{1,{24,24},{125,400}},{1,{24,24},{350,325}},{1,{24,24},{925,575}},{1,{24,24},{525,25}},{1,{24,24},{400,325}},{1,{24,24},{425,175}},{1,{24,24},{975,525}},{2,{24,24},{250,75}},{1,{24,24},{850,200}},{1,{24,24},{550,925}},{1,{24,24},{625,725}},{1,{24,24},{325,550}},{1,{24,24},{650,825}},{1,{24,24},{675,800}},{1,{24,24},{200,225}},{1,{24,24},{725,750}},{1,{24,24},{750,725}},{1,{24,24},{500,650}},{1,{24,24},{525,75}},{2,{24,24},{100,0}},{1,{24,24},{450,800}},{1,{24,24},{925,500}},{1,{24,24},{975,275}},{2,{24,24},{100,175}},{1,{24,24},{175,400}},{1,{24,24},{500,950}},{1,{24,24},{700,150}},{1,{24,24},{200,450}},{1,{24,24},{875,600}},{1,{24,24},{900,575}},{1,{24,24},{925,550}},{1,{24,24},{850,225}},{1,{24,24},{750,800}},{1,{24,24},{500,675}},{1,{24,24},{475,975}},{1,{24,24},{750,700}},{1,{24,24},{550,900}},{1,{24,24},{800,150}},{1,{24,24},{25,875}},{1,{24,24},{575,550}},{1,{24,24},{25,50}},{1,{24,24},{425,550}},{1,{24,24},{575,250}},{1,{24,24},{250,225}},{1,{24,24},{825,725}},{1,{24,24},{250,200}},{1,{24,24},{375,925}},{1,{24,24},{125,475}},{1,{24,24},{400,175}},{1,{24,24},{525,375}},{1,{24,24},{625,825}},{1,{24,24},{375,700}},{1,{24,24},{650,800}},{1,{24,24},{700,750}},{1,{24,24},{825,475}},{1,{24,24},{125,700}},{1,{24,24},{875,575}},{1,{24,24},{425,750}},{1,{24,24},{925,25}},{1,{24,24},{900,550}},{1,{24,24},{900,50}},{1,{24,24},{525,700}},{1,{24,24},{925,525}},{1,{24,24},{550,225}},{1,{24,24},{450,275}},{1,{24,24},{625,0}},{1,{24,24},{25,25}},{1,{24,24},{25,300}},{1,{24,24},{250,975}},{1,{24,24},{950,500}},{1,{24,24},{425,300}},{1,{24,24},{975,475}},{1,{24,24},{375,500}},{1,{24,24},{250,500}},{1,{24,24},{175,650}},{1,{24,24},{975,300}},{1,{24,24},{350,250}},{1,{24,24},{475,950}},{1,{24,24},{175,350}},{1,{24,24},{125,50}},{1,{24,24},{500,925}},{2,{24,24},{250,25}},{1,{24,24},{875,775}},{1,{24,24},{600,825}},{1,{24,24},{700,725}},{1,{24,24},{150,475}},{1,{24,24},{175,475}},{1,{24,24},{675,750}},{1,{24,24},{750,675}},{1,{24,24},{775,650}},{1,{24,24},{375,650}},{1,{24,24},{575,750}},{1,{24,24},{175,925}},{2,{24,24},{50,175}},{1,{24,24},{350,50}},{1,{24,24},{725,600}},{1,{24,24},{825,650}},{1,{24,24},{475,50}},{1,{24,24},{50,850}},{1,{24,24},{425,975}},{1,{24,24},{100,425}},{1,{24,24},{500,900}},{1,{24,24},{525,875}},{1,{24,24},{325,600}},{1,{24,24},{575,825}},{1,{24,24},{25,425}},{1,{24,24},{175,850}},{1,{24,24},{175,150}},{1,{24,24},{300,125}},{1,{24,24},{775,225}},{1,{24,24},{0,700}},{1,{24,24},{150,650}},{1,{24,24},{275,50}},{1,{24,24},{825,775}},{1,{24,24},{325,500}},{1,{24,24},{675,725}},{1,{24,24},{475,375}},{1,{24,24},{125,850}},{1,{24,24},{375,800}},{1,{24,24},{800,550}},{1,{24,24},{850,400}},{1,{24,24},{825,575}},{1,{24,24},{900,500}},{1,{24,24},{850,850}},{1,{24,24},{700,50}},{1,{24,24},{400,975}},{1,{24,24},{425,950}},{1,{24,24},{275,850}},{1,{24,24},{350,725}},{1,{24,24},{575,650}},{1,{24,24},{950,325}},{1,{24,24},{50,825}},{1,{24,24},{450,925}},{1,{24,24},{775,775}},{1,{24,24},{500,875}},{1,{24,24},{575,800}},{1,{24,24},{275,725}},{1,{24,24},{600,950}},{1,{24,24},{625,750}},{1,{24,24},{150,575}},{1,{24,24},{250,950}},{1,{24,24},{825,250}},{1,{24,24},{0,500}},{1,{24,24},{725,900}},{1,{24,24},{675,700}},{1,{24,24},{650,575}},{1,{24,24},{975,825}},{1,{24,24},{400,75}},{1,{24,24},{850,125}},{1,{24,24},{0,925}},{1,{24,24},{100,475}},{1,{24,24},{25,625}},{1,{24,24},{750,625}},{1,{24,24},{675,100}},{1,{24,24},{800,575}},{1,{24,24},{850,525}},{1,{24,24},{25,350}},{1,{24,24},{825,550}},{1,{24,24},{925,450}},{1,{24,24},{50,350}},{1,{24,24},{950,425}},{1,{24,24},{625,175}},{1,{24,24},{675,275}},{1,{24,24},{875,500}},{1,{24,24},{450,750}},{1,{24,24},{850,0}},{1,{24,24},{450,900}},{1,{24,24},{525,825}},{1,{24,24},{800,0}},{1,{24,24},{550,800}},{1,{24,24},{325,125}},{1,{24,24},{575,775}},{2,{24,24},{175,150}},{1,{24,24},{625,850}},{1,{24,24},{500,850}},{1,{24,24},{650,700}},{1,{24,24},{725,625}},{1,{24,24},{925,100}},{1,{24,24},{700,650}},{1,{24,24},{375,675}},{1,{24,24},{675,400}},{1,{24,24},{825,525}},{1,{24,24},{0,600}},{1,{24,24},{500,600}},{1,{24,24},{900,450}},{1,{24,24},{400,200}},{1,{24,24},{800,250}},{1,{24,24},{50,200}},{1,{24,24},{75,575}},{1,{24,24},{350,975}},{1,{24,24},{725,425}},{1,{24,24},{75,775}},{1,{24,24},{875,50}},{1,{24,24},{400,925}},{1,{24,24},{525,250}},{1,{24,24},{850,500}},{1,{24,24},{875,450}},{1,{24,24},{650,950}},{1,{24,24},{600,400}},{1,{24,24},{550,625}},{1,{24,24},{0,800}},{1,{24,24},{800,625}},{1,{24,24},{50,725}},{1,{24,24},{875,250}},{1,{24,24},{150,975}},{1,{24,24},{575,200}},{1,{24,24},{325,350}},{1,{24,24},{275,400}},{1,{24,24},{325,975}},{1,{24,24},{125,200}},{1,{24,24},{475,700}},{1,{24,24},{100,300}},{1,{24,24},{625,700}},{1,{24,24},{100,550}},{1,{24,24},{600,250}},{1,{24,24},{275,675}},{1,{24,24},{950,150}},{1,{24,24},{625,275}},{1,{24,24},{650,450}},{1,{24,24},{650,675}},{1,{24,24},{825,925}},{1,{24,24},{700,625}},{1,{24,24},{250,0}},{1,{24,24},{500,625}},{1,{24,24},{100,700}},{1,{24,24},{150,700}},{1,{24,24},{825,500}},{1,{24,24},{850,475}},{1,{24,24},{450,875}},{1,{24,24},{900,425}},{1,{24,24},{200,675}},{1,{24,24},{675,525}},{1,{24,24},{925,400}},{1,{24,24},{425,875}},{1,{24,24},{975,200}},{1,{24,24},{350,925}},{1,{24,24},{475,825}},{1,{24,24},{600,900}},{1,{24,24},{600,700}},{1,{24,24},{525,600}},{1,{24,24},{900,125}},{1,{24,24},{950,400}},{1,{24,24},{325,375}},{1,{24,24},{775,700}},{1,{24,24},{225,250}},{1,{24,24},{200,650}},{1,{24,24},{700,600}},{1,{24,24},{675,625}},{1,{24,24},{750,550}},{1,{24,24},{200,75}},{1,{24,24},{775,525}},{1,{24,24},{950,350}},{2,{24,24},{100,100}},{1,{24,24},{400,150}},{1,{24,24},{725,575}},{1,{24,24},{775,675}},{1,{24,24},{75,300}},{1,{24,24},{50,875}},{1,{24,24},{850,450}},{1,{24,24},{325,325}},{1,{24,24},{875,425}},{1,{24,24},{925,375}},{1,{24,24},{900,400}},{1,{24,24},{200,550}},{1,{24,24},{300,975}},{1,{24,24},{475,200}},{1,{24,24},{875,850}},{1,{24,24},{200,50}},{1,{24,24},{450,825}},{1,{24,24},{975,0}},{1,{24,24},{600,675}},{1,{24,24},{325,25}},{1,{24,24},{625,650}},{1,{24,24},{225,775}},{1,{24,24},{675,600}},{1,{24,24},{725,550}},{1,{24,24},{825,450}},{1,{24,24},{250,25}},{1,{24,24},{775,500}},{1,{24,24},{525,750}},{2,{24,24},{100,200}},{1,{24,24},{925,350}},{1,{24,24},{875,400}},{1,{24,24},{275,975}},{1,{24,24},{300,950}},{1,{24,24},{850,150}},{1,{24,24},{350,900}},{1,{24,24},{400,850}},{1,{24,24},{425,825}},{1,{24,24},{475,775}},{1,{24,24},{525,950}},{1,{24,24},{950,125}},{1,{24,24},{550,700}},{1,{24,24},{625,625}},{1,{24,24},{600,650}},{1,{24,24},{650,600}},{1,{24,24},{675,575}},{1,{24,24},{275,625}},{1,{24,24},{975,675}},{1,{24,24},{175,25}},{1,{24,24},{825,425}},{1,{24,24},{775,625}},{1,{24,24},{75,100}},{1,{24,24},{950,300}},{1,{24,24},{50,50}},{1,{24,24},{925,325}},{1,{24,24},{500,350}},{1,{24,24},{225,475}},{1,{24,24},{250,700}},{1,{24,24},{650,75}},{1,{24,24},{350,100}},{1,{24,24},{875,100}},{1,{24,24},{900,375}},{1,{24,24},{650,400}},{1,{24,24},{200,600}},{1,{24,24},{375,850}},{1,{24,24},{375,450}},{1,{24,24},{600,175}},{1,{24,24},{400,825}},{1,{24,24},{175,200}},{1,{24,24},{725,225}},{1,{24,24},{450,650}},{1,{24,24},{500,725}},{1,{24,24},{50,600}},{1,{24,24},{600,625}},{1,{24,24},{625,600}},{1,{24,24},{575,75}},{1,{24,24},{725,500}},{1,{24,24},{800,875}},{1,{24,24},{0,300}},{1,{24,24},{800,425}},{1,{24,24},{525,500}},{1,{24,24},{575,525}},{1,{24,24},{0,825}},{1,{24,24},{0,725}},{1,{24,24},{675,550}},{1,{24,24},{450,500}},{1,{24,24},{850,275}},{1,{24,24},{900,325}},{1,{24,24},{925,300}},{1,{24,24},{550,200}},{1,{24,24},{225,975}},{1,{24,24},{525,325}},{1,{24,24},{200,575}},{1,{24,24},{325,850}},{1,{24,24},{0,375}},{1,{24,24},{675,250}},{1,{24,24},{325,875}},{1,{24,24},{750,25}},{1,{24,24},{350,850}},{1,{24,24},{900,800}},{1,{24,24},{100,975}},{1,{24,24},{350,600}},{1,{24,24},{375,825}},{1,{24,24},{925,50}},{1,{24,24},{125,600}},{1,{24,24},{925,250}},{1,{24,24},{525,675}},{1,{24,24},{200,350}},{1,{24,24},{625,575}},{1,{24,24},{725,150}},{1,{24,24},{650,550}},{1,{24,24},{400,600}},{1,{24,24},{75,375}},{1,{24,24},{150,75}},{1,{24,24},{500,800}},{1,{24,24},{225,275}},{1,{24,24},{850,350}},{1,{24,24},{900,300}},{1,{24,24},{925,275}},{1,{24,24},{450,200}},{1,{24,24},{950,250}},{1,{24,24},{25,500}},{1,{24,24},{0,250}},{1,{24,24},{600,850}},{1,{24,24},{175,800}},{1,{24,24},{625,25}},{1,{24,24},{275,900}},{1,{24,24},{700,400}},{1,{24,24},{425,225}},{1,{24,24},{200,975}},{1,{24,24},{300,875}},{1,{24,24},{900,0}},{1,{24,24},{750,650}},{1,{24,24},{475,75}},{1,{24,24},{475,250}},{1,{24,24},{975,500}},{1,{24,24},{525,650}},{1,{24,24},{50,650}},{1,{24,24},{500,825}},{1,{24,24},{375,350}},{1,{24,24},{0,200}},{1,{24,24},{150,100}},{1,{24,24},{775,25}},{1,{24,24},{625,550}},{1,{24,24},{450,725}},{1,{24,24},{675,500}},{1,{24,24},{725,450}},{1,{24,24},{250,800}},{1,{24,24},{200,425}},{1,{24,24},{575,125}},{1,{24,24},{175,500}},{1,{24,24},{950,100}},{1,{24,24},{800,375}},{1,{24,24},{825,350}},{1,{24,24},{50,575}},{1,{24,24},{675,475}},{1,{24,24},{400,700}},{1,{24,24},{125,625}},{1,{24,24},{900,275}},{1,{24,24},{875,300}},{1,{24,24},{125,875}},{1,{24,24},{950,225}},{1,{24,24},{400,800}},{1,{24,24},{700,125}},{1,{24,24},{825,125}},{1,{24,24},{950,600}},{1,{24,24},{175,125}},{1,{24,24},{125,25}},{1,{24,24},{975,375}},{1,{24,24},{150,25}},{1,{24,24},{575,400}},{1,{24,24},{75,0}},{1,{24,24},{300,850}},{1,{24,24},{325,825}},{1,{24,24},{400,750}},{1,{24,24},{425,700}},{1,{24,24},{375,50}},{1,{24,24},{350,800}},{1,{24,24},{925,600}},{1,{24,24},{400,450}},{1,{24,24},{625,525}},{1,{24,24},{0,775}},{1,{24,24},{750,425}},{1,{24,24},{975,750}},{1,{24,24},{775,375}},{1,{24,24},{800,350}},{1,{24,24},{900,875}},{1,{24,24},{300,200}},{1,{24,24},{975,150}},{1,{24,24},{25,75}},{1,{24,24},{950,200}},{1,{24,24},{500,100}},{1,{24,24},{225,900}},{1,{24,24},{50,500}},{1,{24,24},{800,125}},{1,{24,24},{650,925}},{1,{24,24},{550,100}},{1,{24,24},{225,925}},{1,{24,24},{800,25}},{1,{24,24},{350,775}},{1,{24,24},{450,675}},{1,{24,24},{25,725}},{1,{24,24},{475,650}},{1,{24,24},{775,550}},{2,{24,24},{125,25}},{1,{24,24},{975,225}},{1,{24,24},{600,525}},{1,{24,24},{475,750}},{2,{24,24},{0,125}},{1,{24,24},{675,450}},{1,{24,24},{725,400}},{1,{24,24},{75,975}},{1,{24,24},{700,325}},{1,{24,24},{450,525}},{1,{24,24},{925,200}},{1,{24,24},{200,925}},{1,{24,24},{250,550}},{1,{24,24},{825,600}},{1,{24,24},{150,950}},{1,{24,24},{225,0}},{1,{24,24},{275,25}},{1,{24,24},{125,450}},{2,{24,24},{150,50}},{1,{24,24},{675,0}},{1,{24,24},{350,750}},{1,{24,24},{575,50}},{1,{24,24},{750,925}},{1,{24,24},{225,50}},{1,{24,24},{625,500}},{1,{24,24},{525,575}},{1,{24,24},{550,75}},{1,{24,24},{550,550}},{1,{24,24},{600,500}},{1,{24,24},{200,625}},{1,{24,24},{550,850}},{1,{24,24},{650,350}},{1,{24,24},{100,775}},{1,{24,24},{850,250}},{1,{24,24},{825,175}},{1,{24,24},{50,100}},{1,{24,24},{900,200}},{1,{24,24},{375,175}},{1,{24,24},{375,400}},{1,{24,24},{175,625}},{1,{24,24},{925,175}},{1,{24,24},{975,125}},{1,{24,24},{175,900}},{1,{24,24},{650,375}},{1,{24,24},{125,725}},{1,{24,24},{300,775}},{1,{24,24},{100,0}},{1,{24,24},{150,500}},{2,{24,24},{0,75}},{1,{24,24},{25,950}},{1,{24,24},{650,625}},{1,{24,24},{125,900}},{1,{24,24},{525,550}},{1,{24,24},{925,75}},{1,{24,24},{900,250}},{1,{24,24},{825,300}},{1,{24,24},{575,500}},{1,{24,24},{750,50}},{1,{24,24},{275,575}},{1,{24,24},{475,600}},{1,{24,24},{475,25}},{1,{24,24},{775,350}},{1,{24,24},{425,25}},{1,{24,24},{875,200}},{1,{24,24},{175,875}},{1,{24,24},{650,325}},{1,{24,24},{200,125}},{1,{24,24},{400,250}},{1,{24,24},{775,400}},{1,{24,24},{975,50}},{1,{24,24},{300,750}},{1,{24,24},{50,25}},{1,{24,24},{400,550}},{1,{24,24},{400,650}},{1,{24,24},{425,0}},{1,{24,24},{750,600}},{1,{24,24},{525,975}},{1,{24,24},{175,975}},{1,{24,24},{250,50}},{1,{24,24},{825,875}},{1,{24,24},{900,750}},{2,{24,24},{225,125}},{1,{24,24},{550,500}},{1,{24,24},{400,400}},{1,{24,24},{350,525}},{1,{24,24},{525,425}},{1,{24,24},{625,250}},{1,{24,24},{225,550}},{1,{24,24},{800,450}},{1,{24,24},{450,25}},{1,{24,24},{25,550}},{1,{24,24},{300,275}},{1,{24,24},{175,525}},{1,{24,24},{650,650}},{1,{24,24},{500,225}},{1,{24,24},{550,150}},{1,{24,24},{975,75}},{1,{24,24},{675,375}},{1,{24,24},{525,725}},{1,{24,24},{100,900}},{1,{24,24},{700,350}},{1,{24,24},{50,975}},{1,{24,24},{0,25}},{1,{24,24},{75,950}},{1,{24,24},{100,925}},{1,{24,24},{425,650}},{1,{24,24},{200,825}},{1,{24,24},{150,875}},{1,{24,24},{225,800}},{1,{24,24},{250,775}},{1,{24,24},{300,0}},{1,{24,24},{275,600}},{1,{24,24},{775,750}},{1,{24,24},{100,450}},{1,{24,24},{325,200}},{1,{24,24},{300,725}},{1,{24,24},{350,675}},{1,{24,24},{250,175}},{1,{24,24},{425,600}},{1,{24,24},{600,425}},{1,{24,24},{675,350}},{1,{24,24},{75,825}},{1,{24,24},{925,150}},{1,{24,24},{725,300}},{1,{24,24},{825,200}},{1,{24,24},{850,175}},{1,{24,24},{125,500}},{1,{24,24},{225,375}},{1,{24,24},{450,400}},{1,{24,24},{50,525}},{1,{24,24},{0,650}},{1,{24,24},{450,250}},{1,{24,24},{975,975}},{1,{24,24},{825,825}},{1,{24,24},{925,125}},{1,{24,24},{200,800}},{1,{24,24},{300,500}},{1,{24,24},{75,925}},{1,{24,24},{400,0}},{1,{24,24},{325,750}},{1,{24,24},{425,325}},{1,{24,24},{325,675}},{1,{24,24},{450,125}},{1,{24,24},{675,200}},{1,{24,24},{475,0}},{1,{24,24},{375,625}},{1,{24,24},{275,200}},{1,{24,24},{425,575}},{1,{24,24},{375,150}},{1,{24,24},{550,25}},{1,{24,24},{875,800}},{1,{24,24},{500,500}},{1,{24,24},{250,725}},{2,{24,24},{50,200}},{1,{24,24},{700,875}},{1,{24,24},{325,475}},{1,{24,24},{550,775}},{1,{24,24},{625,375}},{1,{24,24},{800,200}},{1,{24,24},{875,125}},{1,{24,24},{950,50}},{1,{24,24},{975,25}},{1,{24,24},{400,475}},{1,{24,24},{375,100}},{1,{24,24},{700,75}},{1,{24,24},{0,975}},{1,{24,24},{50,925}},{1,{24,24},{100,875}},{1,{24,24},{700,700}},{1,{24,24},{225,950}},{1,{24,24},{200,775}},{1,{24,24},{300,675}},{1,{24,24},{350,625}},{1,{24,24},{225,150}},{1,{24,24},{600,475}},{1,{24,24},{325,175}},{1,{24,24},{0,350}},{1,{24,24},{275,925}},{1,{24,24},{525,450}},{1,{24,24},{475,100}},{1,{24,24},{400,575}},{1,{24,24},{600,375}},{1,{24,24},{600,325}},{1,{24,24},{650,225}},{1,{24,24},{700,275}},{1,{24,24},{725,250}},{1,{24,24},{775,200}},{1,{24,24},{475,900}},{1,{24,24},{625,50}},{1,{24,24},{250,525}},{1,{24,24},{825,0}},{1,{24,24},{650,0}},{1,{24,24},{825,150}},{1,{24,24},{475,300}},{1,{24,24},{125,225}},{1,{24,24},{900,75}},{1,{24,24},{575,700}},{1,{24,24},{25,925}},{1,{24,24},{50,900}},{1,{24,24},{650,200}},{1,{24,24},{100,850}},{1,{24,24},{350,500}},{1,{24,24},{675,125}},{1,{24,24},{150,800}},{1,{24,24},{100,150}},{1,{24,24},{325,250}},{1,{24,24},{125,825}},{1,{24,24},{325,625}},{1,{24,24},{850,375}},{1,{24,24},{300,50}},{1,{24,24},{25,850}},{1,{24,24},{350,550}},{1,{24,24},{625,150}},{1,{24,24},{650,300}},{1,{24,24},{250,375}},{1,{24,24},{825,750}},{1,{24,24},{575,875}},{1,{24,24},{775,600}},{1,{24,24},{25,900}},{1,{24,24},{475,275}},{1,{24,24},{475,425}},{1,{24,24},{150,775}},{1,{24,24},{225,700}},{1,{24,24},{275,650}},{1,{24,24},{425,200}},{1,{24,24},{300,625}},{1,{24,24},{425,100}},{1,{24,24},{500,200}},{1,{24,24},{775,325}},{1,{24,24},{400,525}},{1,{24,24},{900,925}},{1,{24,24},{775,125}},{1,{24,24},{475,450}},{1,{24,24},{525,400}},{1,{24,24},{975,925}},{2,{24,24},{75,200}},{1,{24,24},{825,100}},{1,{24,24},{0,125}},{1,{24,24},{850,75}},{1,{24,24},{150,750}},{1,{24,24},{750,500}},{1,{24,24},{875,975}},{1,{24,24},{500,75}},{1,{24,24},{400,500}},{1,{24,24},{450,450}},{1,{24,24},{950,0}},{1,{24,24},{200,250}},{1,{24,24},{325,0}},{1,{24,24},{700,850}},{1,{24,24},{350,350}},{1,{24,24},{75,275}},{1,{24,24},{600,800}},{1,{24,24},{750,150}},{1,{24,24},{100,800}},{1,{24,24},{625,325}},{1,{24,24},{125,750}},{1,{24,24},{125,375}},{1,{24,24},{175,700}},{1,{24,24},{475,225}},{1,{24,24},{550,300}},{1,{24,24},{225,650}},{1,{24,24},{450,975}},{1,{24,24},{450,425}},{1,{24,24},{525,350}},{1,{24,24},{550,325}},{1,{24,24},{0,750}},{1,{24,24},{275,425}},{2,{24,24},{250,100}},{1,{24,24},{350,650}},{1,{24,24},{625,350}},{1,{24,24},{925,950}},{1,{24,24},{825,50}},{1,{24,24},{25,825}},{1,{24,24},{800,525}},{1,{24,24},{400,350}},{1,{24,24},{150,175}},{1,{24,24},{775,300}},{1,{24,24},{800,775}},{1,{24,24},{450,700}},{1,{24,24},{75,875}},{1,{24,24},{800,50}},{1,{24,24},{200,475}},{1,{24,24},{300,450}},{1,{24,24},{50,775}},{1,{24,24},{75,750}},{1,{24,24},{650,750}},{1,{24,24},{350,475}},{1,{24,24},{450,375}},{1,{24,24},{600,750}},{1,{24,24},{50,625}},{1,{24,24},{25,700}},{1,{24,24},{525,300}},{1,{24,24},{650,175}},{1,{24,24},{125,0}},{1,{24,24},{25,775}},{1,{24,24},{225,575}},{1,{24,24},{175,550}},{1,{24,24},{575,150}},{1,{24,24},{550,250}},{1,{24,24},{650,150}},{1,{24,24},{725,350}},{1,{24,24},{600,575}},{1,{24,24},{325,300}},{1,{24,24},{950,275}},{1,{24,24},{600,125}},{1,{24,24},{600,450}},{1,{24,24},{275,500}},{1,{24,24},{600,150}},{1,{24,24},{775,0}},{1,{24,24},{500,275}},{1,{24,24},{350,875}},{1,{24,24},{650,125}},{1,{24,24},{50,700}},{1,{24,24},{175,175}},{1,{24,24},{175,575}},{1,{24,24},{325,950}},{1,{24,24},{450,75}},{1,{24,24},{25,125}},{1,{24,24},{300,300}},{1,{24,24},{225,625}},{1,{24,24},{100,825}},{1,{24,24},{525,225}},{1,{24,24},{300,475}},{1,{24,24},{350,75}},{1,{24,24},{650,250}},{1,{24,24},{650,100}},{1,{24,24},{50,675}},{1,{24,24},{75,75}},{1,{24,24},{450,350}},{1,{24,24},{300,425}},{1,{24,24},{125,650}},{1,{24,24},{300,150}},{1,{24,24},{700,25}},{1,{24,24},{200,500}},{1,{24,24},{100,375}},{1,{24,24},{375,550}},{1,{24,24},{75,600}},{1,{24,24},{375,900}},{1,{24,24},{300,825}},{1,{24,24},{200,850}},{1,{24,24},{500,150}},{1,{24,24},{250,250}},{1,{24,24},{700,525}},{1,{24,24},{725,700}},{1,{24,24},{175,450}},{1,{24,24},{875,900}},{1,{24,24},{500,125}},{1,{24,24},{525,100}},{1,{24,24},{775,800}},{1,{24,24},{150,450}},{1,{24,24},{175,425}},{1,{24,24},{200,400}},{1,{24,24},{100,500}},{1,{24,24},{225,875}},{1,{24,24},{150,425}},{1,{24,24},{75,175}},{1,{24,24},{225,350}},{1,{24,24},{425,150}},{1,{24,24},{50,225}},{1,{24,24},{325,700}},{1,{24,24},{575,625}},{1,{24,24},{25,375}},{1,{24,24},{450,600}},{1,{24,24},{50,150}},{1,{24,24},{675,975}},{1,{24,24},{500,25}},{1,{24,24},{375,375}},{1,{24,24},{100,400}},{1,{24,24},{275,225}},{1,{24,24},{0,475}},{1,{24,24},{950,75}},{1,{24,24},{100,950}},{1,{24,24},{700,800}},{1,{24,24},{250,125}},{2,{24,24},{200,0}},{1,{24,24},{225,75}},{1,{24,24},{125,100}}}}}
local iconIndices: { string } = icons[1]
local idIndices: { string } = icons[2]
local iconRegistry: { [number]: { number | { number } } } = icons[3]

Lucide.Icons = iconIndices
function Lucide.GetAsset(name: string)
        local size = 48

        local iconIndex = table.find(iconIndices, name)

        if not iconIndex then
                return nil
        end

        local currentDifference = math.huge
        local currentSize = size

        for registrySize, _ in iconRegistry do
                local diff = math.abs(size - registrySize)

                if diff < currentDifference then
                        currentDifference = diff
                        currentSize = registrySize
                end
        end

        local icon = iconRegistry[currentSize][iconIndex]
        if icon then
                return {
                        IconName = name,
                        Url = idIndices[icon[1]],
                        ImageRectSize = Vector2.new(icon[2][1], icon[2][2]),
                        ImageRectOffset = Vector2.new(icon[3][1], icon[3][2]),
                }
        end

        return nil
end

return Lucide

]=]

local Library = loadstring([=[
local cloneref = (cloneref or clonereference or function(instance: any)
        return instance
end)
local InputService: UserInputService = cloneref(game:GetService("UserInputService"))
local TextService: TextService = cloneref(game:GetService("TextService"))
local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))
local Teams: Teams = cloneref(game:GetService("Teams"))
local Players: Players = cloneref(game:GetService("Players"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local TweenService: TweenService = cloneref(game:GetService("TweenService"))

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Mouse = cloneref(LocalPlayer:GetMouse())

local DrawingLib = { drawing_replaced = true, new = function(...) error("Drawing is not supported.") end }
local IsBadDrawingLib = false

if typeof(getgenv) == "function" and typeof(getgenv().Drawing) == "table" then
    DrawingLib = getgenv().Drawing
end

local setclipboard = setclipboard or nil
local getgenv = getgenv or function()
        return shared
end
local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end
local GetHUI = gethui or function()
        return CoreGui
end

local assert = function(condition, errorMessage)
        if not condition then
                error(if errorMessage then errorMessage else "assert failed", 3)
        end
end

local function SafeParentUI(Instance: Instance, Parent: Instance | () -> Instance)
        local success, _error = pcall(function()
                if not Parent then
                        Parent = CoreGui
                end

                local DestinationParent
                if typeof(Parent) == "function" then
                        DestinationParent = Parent()
                else
                        DestinationParent = Parent
                end

                Instance.Parent = DestinationParent
        end)

        if not (success and Instance.Parent) then
                Instance.Parent = LocalPlayer:WaitForChild("PlayerGui", math.huge)
        end
end

local function ParentUI(UI: Instance, SkipHiddenUI: boolean?)
        if SkipHiddenUI then
                SafeParentUI(UI, CoreGui)
                return
        end

        pcall(ProtectGui, UI)
        SafeParentUI(UI, GetHUI)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.DisplayOrder = 999
ScreenGui.ResetOnSpawn = false
ParentUI(ScreenGui)

local ModalElement = Instance.new("TextButton")
ModalElement.BackgroundTransparency = 1
ModalElement.Modal = false
ModalElement.Size = UDim2.fromScale(0, 0)
ModalElement.AnchorPoint = Vector2.zero
ModalElement.Text = ""
ModalElement.ZIndex = -999
ModalElement.Parent = ScreenGui

local LibraryMainOuterFrame = nil

local Toggles = {}
local Options = {}
local Labels = {}
local Buttons = {}
local Tooltips = {}
local Dialogues = {}


-- [FIX] BaseURL removed - using RobloxId directly instead of downloading from URLs
local BaseURL = ""
local CustomImageManager = {}
local CustomImageManagerAssets = {
    Cursor = {
        RobloxId = 9619665977,
        Path = "LinoriaLib/assets/Cursor.png",
        URL = BaseURL .. "assets/Cursor.png",

        Id = nil,
    },

    DropdownArrow = {
        RobloxId = 6282522798,
        Path = "LinoriaLib/assets/DropdownArrow.png",
        URL = BaseURL .. "assets/DropdownArrow.png",

        Id = nil,
    },

    Checker = {
        RobloxId = 12977615774,
        Path = "LinoriaLib/assets/Checker.png",
        URL = BaseURL .. "assets/Checker.png",

        Id = nil,
    },

    CheckerLong = {
        RobloxId = 12978095818,
        Path = "LinoriaLib/assets/CheckerLong.png",
        URL = BaseURL .. "assets/CheckerLong.png",

        Id = nil,
    },

    SaturationMap = {
        RobloxId = 4155801252,
        Path = "LinoriaLib/assets/SaturationMap.png",
        URL = BaseURL .. "assets/SaturationMap.png",

        Id = nil,
    }
}
do
    local function RecursiveCreatePath(Path: string, IsFile: boolean?)
        if not isfolder or not makefolder then
            return
        end

        local Segments = Path:split("/")
        local TraversedPath = ""

        if IsFile then
            table.remove(Segments, #Segments)
        end

        for _, Segment in ipairs(Segments) do
            if not isfolder(TraversedPath .. Segment) then
                makefolder(TraversedPath .. Segment)
            end

            TraversedPath = TraversedPath .. Segment .. "/"
        end

        return TraversedPath
    end

    function CustomImageManager.AddAsset(AssetName: string, RobloxAssetId: number, URL: string, ForceRedownload: boolean?)
        if CustomImageManagerAssets[AssetName] ~= nil then
            error(string.format("Asset %q already exists", AssetName))
        end

        assert(typeof(RobloxAssetId) == "number", "RobloxAssetId must be a number")

        CustomImageManagerAssets[AssetName] = {
            RobloxId = RobloxAssetId,
            Path = string.format("Obsidian/custom_assets/%s", AssetName),
            URL = URL,

            Id = nil,
        }

        CustomImageManager.DownloadAsset(AssetName, ForceRedownload)
    end

    function CustomImageManager.GetAsset(AssetName: string)
        if not CustomImageManagerAssets[AssetName] then
            return nil
        end

        local AssetData = CustomImageManagerAssets[AssetName]
        if AssetData.Id then
            return AssetData.Id
        end

        local AssetID = string.format("rbxassetid://%s", AssetData.RobloxId)

        if getcustomasset then
            local Success, NewID = pcall(getcustomasset, AssetData.Path)

            if Success and NewID then
                AssetID = NewID
            end
        end

        AssetData.Id = AssetID
        return AssetID
    end

    function CustomImageManager.DownloadAsset(AssetName: string, ForceRedownload: boolean?)
        -- [FIX] No URL downloads - uses RobloxId directly from GetAsset fallback
        -- Original code downloaded from URLs, now we skip that and use rbxassetid://
        return true, nil
    end

    for AssetName, _ in CustomImageManagerAssets do
        CustomImageManager.DownloadAsset(AssetName)
    end
end

local DPIScale = 1;
local Library = {
    Registry = {};
    RegistryMap = {};
    HudRegistry = {};

    -- colors and font --
    --// PREMIUM DEEP-BLACK THEME + CRIMSON ZX ACCENT
    FontColor = Color3.fromRGB(235, 235, 235);
    MainColor = Color3.fromRGB(10, 10, 12);       -- deep black (was 28,28,28)
    BackgroundColor = Color3.fromRGB(0, 0, 0);     -- pure black (was 20,20,20)

    AccentColor = Color3.fromRGB(225, 30, 30);     -- crimson red (was 200,30,30)
    DisabledAccentColor = Color3.fromRGB(120, 120, 120);

    OutlineColor = Color3.fromRGB(28, 28, 30);     -- subtle dark outline (was 50,50,50)
    DisabledOutlineColor = Color3.fromRGB(45, 45, 48);

    DisabledTextColor = Color3.fromRGB(142, 142, 142);

    RiskColor = Color3.fromRGB(255, 50, 50);

    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Code,

    -- frames --
    OpenedFrames = {};
    DependencyBoxes = {};
    DependencyGroupboxes = {};

    -- signals --
    UnloadSignals = {};
    Signals = {};

    -- gui --
    ActiveTab = nil;
    TotalTabs = 0;

    ScreenGui = ScreenGui;
    KeybindFrame = nil;
    KeybindContainer = nil;
    Window = { Holder = nil; Tabs = {}; };

    -- variables --
    VideoLink = "";
    
    Toggled = false;
    ToggleKeybind = nil;

    IsMobile = false;
    DevicePlatform = Enum.Platform.None;

    CanDrag = true;
    CantDragForced = false;

    Unloaded = false;

    -- notification --
    Notify = nil;
    NotifySide = "Left";
    ShowCustomCursor = true;
    ShowToggleFrameInKeybinds = true;
    NotifyOnError = false; -- true = Library:Notify for SafeCallback (still warns in the developer console)

    -- addons --
    SaveManager = nil;
    ThemeManager = nil;

    -- for better usage --
    Toggles = Toggles;
    Options = Options;
    Labels = Labels;
    Buttons = Buttons;
    Dialogues = Dialogues;
    ActiveDialog = nil;

    ImageManager = CustomImageManager;
    ShowCursorBinding = string.sub(tostring({}), 10);
}

if RunService:IsStudio() then
   Library.IsMobile = InputService.TouchEnabled and not InputService.MouseEnabled 
else
    pcall(function() Library.DevicePlatform = InputService:GetPlatform() end) -- For safety so the UI library doesn't error.
    Library.IsMobile = (Library.DevicePlatform == Enum.Platform.Android or Library.DevicePlatform == Enum.Platform.IOS)
end

Library.MinSize = if Library.IsMobile then Vector2.new(550, 200) else Vector2.new(500, 350)

--// Functions \\--
local function ApplyDPIScale(Position)
    return UDim2.new(Position.X.Scale, Position.X.Offset * DPIScale, Position.Y.Scale, Position.Y.Offset * DPIScale)
end

local function ApplyTextScale(TextSize)
    return TextSize * DPIScale
end

local function GetTableSize(t)
    local n = 0
    for _, _ in pairs(t) do
        n = n + 1
    end
    return n
end

local function GetPlayers(ExcludeLocalPlayer, ReturnInstances)
    local PlayerList = Players:GetPlayers()

    if ExcludeLocalPlayer then
        local Idx = table.find(PlayerList, LocalPlayer)

        if Idx then
            table.remove(PlayerList, Idx)
        end
    end

    table.sort(PlayerList, function(Player1, Player2)
        return Player1.Name:lower() < Player2.Name:lower()
    end)

    if ReturnInstances == true then
        return PlayerList
    end

    local FixedPlayerList = {}
    for _, player in next, PlayerList do
        FixedPlayerList[#FixedPlayerList + 1] = player.Name
    end

    return FixedPlayerList
end

local function GetTeams(ReturnInstances)
    local TeamList = Teams:GetTeams()

    table.sort(TeamList, function(Team1, Team2)
        return Team1.Name:lower() < Team2.Name:lower()
    end)

    if ReturnInstances == true then
        return TeamList
    end

    local FixedTeamList = {}
    for _, team in next, TeamList do
        FixedTeamList[#FixedTeamList + 1] = team.Name
    end

    return FixedTeamList
end

local function Trim(Text: string)
    return Text:match("^%s*(.-)%s*$")
end

--// Icon Module \\--
type Icon = {
    Url: string,
    Id: number,
    IconName: string,
    ImageRectOffset: Vector2,
    ImageRectSize: Vector2,
}

type IconModule = {
    Icons: { string },
    GetAsset: (Name: string) -> Icon?,
}

local FetchIcons, Icons = pcall(function()
    return (loadstring(
        lucide_embedded_source
    ) :: () -> IconModule)()
end)

function IsValidCustomIcon(Icon: string)
    return typeof(Icon) == "string"
        and (Icon:match("rbxasset") or Icon:match("roblox%.com/asset/%?id=") or Icon:match("rbxthumb://type="))
end

function Library:GetIcon(IconName: string)
    if not FetchIcons then
        return
    end

    local Success, Icon = pcall(Icons.GetAsset, IconName)
    if not Success then
        return
    end

    return Icon
end

function Library:GetCustomIcon(IconName: string)
    if not IsValidCustomIcon(IconName) then
        return Library:GetIcon(IconName)
    else
        return {
            Url = IconName,
            ImageRectOffset = Vector2.zero,
            ImageRectSize = Vector2.zero,
            Custom = true,
        }
    end
end

function Library:SetIconModule(module: IconModule)
    FetchIcons = true
    Icons = module
end

function Library:GetBetterColor(Color: Color3, Add: number): Color3
    Add = Add * 2
    return Color3.fromRGB(
        math.clamp(Color.R * 255 + Add, 0, 255),
        math.clamp(Color.G * 255 + Add, 0, 255),
        math.clamp(Color.B * 255 + Add, 0, 255)
    )
end

--// Library Functions \\--
function Library:Validate(Table: { [string]: any }, Template: { [string]: any }): { [string]: any }
    if typeof(Table) ~= "table" then
        return Template
    end

    for k, v in pairs(Template) do
        if typeof(k) == "number" then
            continue
        end

        if typeof(v) == "table" then
            Table[k] = Library:Validate(Table[k], v)
        elseif Table[k] == nil then
            Table[k] = v
        end
    end

    return Table
end

function Library:SetDPIScale(value: number) 
    assert(type(value) == "number", "Expected type number for DPI scale but got " .. typeof(value))
    
    DPIScale = value / 100
    Library.MinSize = (if Library.IsMobile then Vector2.new(550, 200) else Vector2.new(500, 350)) * DPIScale
end

function Library:SafeCallback(Func, ...)
    
    if not (Func and typeof(Func) == "function") then
        return
    end

    local Result = table.pack(xpcall(Func, function(Error)
        task.defer(error, debug.traceback(Error, 2))
        if Library.NotifyOnError then
            Library:Notify(Error)
        end

        return Error
    end, ...))

    if not Result[1] then
        return nil
    end

    return table.unpack(Result, 2, Result.n)
end

function Library:AttemptSave()
    if (not Library.SaveManager) then return end
    Library.SaveManager:Save()
end

function Library:Create(Class, Properties)
    local _Instance = Class

    if typeof(Class) == "string" then
        _Instance = Instance.new(Class)
    end

    for Property, Value in next, Properties do
        if (Property == "Size" or Property == "Position") then
            Value = ApplyDPIScale(Value)
        elseif Property == "TextSize" then
            Value = ApplyTextScale(Value)
        end

        local success, err = pcall(function()
            _Instance[Property] = Value
        end)

        if (not success) then
            warn(err)
        end
    end

    return _Instance
end

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1

    return Library:Create("UIStroke", {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = Inst;
    })
end

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create("TextLabel", {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 16;
        TextStrokeTransparency = 0;
    })

    Library:ApplyTextStroke(_Instance)

    Library:AddToRegistry(_Instance, {
        TextColor3 = "FontColor";
    }, IsHud)

    return Library:Create(_Instance, Properties)
end

function Library:MakeDraggable(Instance, Cutoff, IsMainWindow)
    Instance.Active = true

    if Library.IsMobile == false then
        Instance.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                if IsMainWindow == true and Library.CantDragForced == true then
                    return
                end
           
                local ObjPos = Vector2.new(
                    Mouse.X - Instance.AbsolutePosition.X,
                    Mouse.Y - Instance.AbsolutePosition.Y
                )

                if ObjPos.Y > (Cutoff or 40) then
                    return
                end

                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    Instance.Position = UDim2.new(
                        0,
                        Mouse.X - ObjPos.X + (Instance.Size.X.Offset * Instance.AnchorPoint.X),
                        0,
                        Mouse.Y - ObjPos.Y + (Instance.Size.Y.Offset * Instance.AnchorPoint.Y)
                    )

                    RunService.RenderStepped:Wait()
                end
            end
        end)
    else
        local Dragging, DraggingInput, DraggingStart, StartPosition

        InputService.TouchStarted:Connect(function(Input)
            if IsMainWindow == true and Library.CantDragForced == true then
                Dragging = false
                return
            end

            if not Dragging and Library:MouseIsOverFrame(Instance, Input) and (IsMainWindow == true and (Library.CanDrag == true and Library.Window.Holder.Visible == true) or true) then
                DraggingInput = Input
                DraggingStart = Input.Position
                StartPosition = Instance.Position

                local OffsetPos = Input.Position - DraggingStart
                if OffsetPos.Y > (Cutoff or 40) then
                    Dragging = false
                    return
                end

                Dragging = true
            end
        end)
        InputService.TouchMoved:Connect(function(Input)
            if IsMainWindow == true and Library.CantDragForced == true then
                Dragging = false
                return
            end

            if Input == DraggingInput and Dragging and (IsMainWindow == true and (Library.CanDrag == true and Library.Window.Holder.Visible == true) or true) then
                local OffsetPos = Input.Position - DraggingStart

                Instance.Position = UDim2.new(
                    StartPosition.X.Scale,
                    StartPosition.X.Offset + OffsetPos.X,
                    StartPosition.Y.Scale,
                    StartPosition.Y.Offset + OffsetPos.Y
                )
            end
        end)
        InputService.TouchEnded:Connect(function(Input)
            if Input == DraggingInput then 
                Dragging = false
            end
        end)
    end
end

function Library:MakeDraggableUsingParent(Instance, Parent, Cutoff, IsMainWindow)
    Instance.Active = true

    if Library.IsMobile == false then
        Instance.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                if IsMainWindow == true and Library.CantDragForced == true then
                    return
                end
  
                local ObjPos = Vector2.new(
                    Mouse.X - Parent.AbsolutePosition.X,
                    Mouse.Y - Parent.AbsolutePosition.Y
                )

                if ObjPos.Y > (Cutoff or 40) then
                    return
                end

                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    Parent.Position = UDim2.new(
                        0,
                        Mouse.X - ObjPos.X + (Parent.Size.X.Offset * Parent.AnchorPoint.X),
                        0,
                        Mouse.Y - ObjPos.Y + (Parent.Size.Y.Offset * Parent.AnchorPoint.Y)
                    )

                    RunService.RenderStepped:Wait()
                end
            end
        end)
    else  
        Library:MakeDraggable(Parent, Cutoff, IsMainWindow)
    end
end

function Library:MakeResizable(Instance, MinSize)
    if Library.IsMobile then
        return
    end

    Instance.Active = true
    
    local ResizerImage_Size = 25 * DPIScale
    local ResizerImage_HoverTransparency = 0.5

    local Resizer = Library:Create("Frame", {
        SizeConstraint = Enum.SizeConstraint.RelativeXX;
        BackgroundColor3 = Color3.new(0, 0, 0);
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Size = UDim2.new(0, 30, 0, 30);
        Position = UDim2.new(1, -30, 1, -30);
        Visible = true;
        ClipsDescendants = true;
        ZIndex = 1;
        Parent = Instance;--Library.ScreenGui;
    })

    local ResizerImage = Library:Create("ImageButton", {
        BackgroundColor3 = Library.AccentColor;
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Size = UDim2.new(2, 0, 2, 0);
        Position = UDim2.new(1, -30, 1, -30);
        ZIndex = 2;
        Parent = Resizer;
    })

    local ResizerImageUICorner = Library:Create("UICorner", {
        CornerRadius = UDim.new(0.5, 0);
        Parent = ResizerImage;
    })

    Library:AddToRegistry(ResizerImage, { BackgroundColor3 = "AccentColor"; })

    Resizer.Size = UDim2.fromOffset(ResizerImage_Size, ResizerImage_Size)
    Resizer.Position = UDim2.new(1, -ResizerImage_Size, 1, -ResizerImage_Size)
    MinSize = MinSize or Library.MinSize

    local OffsetPos
    Resizer.Parent = Instance

    local function FinishResize(Transparency)
        ResizerImage.Position = UDim2.new()
        ResizerImage.Size = UDim2.new(2, 0, 2, 0)
        ResizerImage.Parent = Resizer
        ResizerImage.BackgroundTransparency = Transparency
        ResizerImageUICorner.Parent = ResizerImage
        OffsetPos = nil
    end

    ResizerImage.MouseButton1Down:Connect(function()
        if not OffsetPos then
            OffsetPos = Vector2.new(Mouse.X - (Instance.AbsolutePosition.X + Instance.AbsoluteSize.X), Mouse.Y - (Instance.AbsolutePosition.Y + Instance.AbsoluteSize.Y))

            ResizerImage.BackgroundTransparency = 1
            ResizerImage.Size = UDim2.fromOffset(Library.ScreenGui.AbsoluteSize.X, Library.ScreenGui.AbsoluteSize.Y)
            ResizerImage.Position = UDim2.new()
            ResizerImageUICorner.Parent = nil
            ResizerImage.Parent = Library.ScreenGui
        end
    end)

    ResizerImage.MouseMoved:Connect(function()
        if OffsetPos then               
            local MousePos = Vector2.new(Mouse.X - OffsetPos.X, Mouse.Y - OffsetPos.Y)
            local FinalSize = Vector2.new(math.clamp(MousePos.X - Instance.AbsolutePosition.X, MinSize.X, math.huge), math.clamp(MousePos.Y - Instance.AbsolutePosition.Y, MinSize.Y, math.huge))
            Instance.Size = UDim2.fromOffset(FinalSize.X, FinalSize.Y)
        end
    end)

    ResizerImage.MouseEnter:Connect(function()
        FinishResize(ResizerImage_HoverTransparency)
    end)

    ResizerImage.MouseLeave:Connect(function()
        FinishResize(1)
    end)

    ResizerImage.MouseButton1Up:Connect(function()
        FinishResize(ResizerImage_HoverTransparency)
    end)
end

function Library:AddToolTip(InfoStr, DisabledInfoStr, HoverInstance)
    InfoStr = typeof(InfoStr) == "string" and InfoStr or nil
    DisabledInfoStr = typeof(DisabledInfoStr) == "string" and DisabledInfoStr or nil

    local Tooltip = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;

        ZIndex = 100;
        Parent = Library.ScreenGui;

        Visible = false;
    })

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1);
        
        TextSize = 14;
        Text = InfoStr;
        TextColor3 = Library.FontColor;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1;

        Parent = Tooltip;
    })

    Library:AddToRegistry(Tooltip, {
        BackgroundColor3 = "MainColor";
        BorderColor3 = "OutlineColor";
    })

    Library:AddToRegistry(Label, {
        TextColor3 = "FontColor",
    })

    local TooltipTable = {
        Tooltip = Tooltip;
        Disabled = false;

        Signals = {};
    }
    local IsHovering = false

    local function UpdateText(Text)
        if Text == nil then return end

        local X, Y = Library:GetTextBounds(Text, Library.Font, 14 * DPIScale)

        Label.Text = Text
        Tooltip.Size = UDim2.fromOffset(X + 5, Y + 4)
        Label.Size = UDim2.fromOffset(X, Y)
    end

    local function GiveSignal(Connection: RBXScriptConnection | RBXScriptSignal)
        local ConnectionType = typeof(Connection)
        if Connection and (ConnectionType == "RBXScriptConnection" or ConnectionType == "RBXScriptSignal") then
            table.insert(TooltipTable.Signals, Connection)
        end

        return Connection
    end

    UpdateText(InfoStr)

    GiveSignal(HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then
            Tooltip.Visible = false
            return
        end

        if not TooltipTable.Disabled then
            if InfoStr == nil or InfoStr == "" then
                Tooltip.Visible = false
                return
            end

            if Label.Text ~= InfoStr then
                UpdateText(InfoStr)
            end
        else
            if DisabledInfoStr == nil or DisabledInfoStr == "" then
                Tooltip.Visible = false
                return
            end

            if Label.Text ~= DisabledInfoStr then 
                UpdateText(DisabledInfoStr)
            end
        end

        IsHovering = true

        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true

        while IsHovering do
            if TooltipTable.Disabled == true and DisabledInfoStr == nil then break end

            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end

        IsHovering = false
        Tooltip.Visible = false
    end))

    GiveSignal(HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end))
    
    if LibraryMainOuterFrame then
        GiveSignal(LibraryMainOuterFrame:GetPropertyChangedSignal("Visible"):Connect(function()
            if LibraryMainOuterFrame.Visible == false then
                IsHovering = false
                Tooltip.Visible = false
            end
        end))
    end

    function TooltipTable:Destroy()
        for Idx = #TooltipTable.Signals, 1, -1 do
            local Connection = table.remove(TooltipTable.Signals, Idx)
            if Connection and Connection.Connected then
                Connection:Disconnect()
            end
        end

        Tooltip:Destroy()
    end

    table.insert(Tooltips, TooltipTable)
    return TooltipTable
end

function Library:MouseIsOverFrame(Frame, Input)
    local Pos = Mouse
    if Library.IsMobile and Input then 
        Pos = Input.Position
    end

    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize
    if Pos.X >= AbsPos.X and Pos.X <= AbsPos.X + AbsSize.X
        and Pos.Y >= AbsPos.Y and Pos.Y <= AbsPos.Y + AbsSize.Y then

        return true
    end

    return false
end

function Library:IsFrameInsideDialog(Frame)
    if not Library.ActiveDialog then return false end

    local Pos = Frame.AbsolutePosition
    local AbsPos, AbsSize = Library.ActiveDialog.Container.AbsolutePosition, Library.ActiveDialog.Container.AbsoluteSize
   
    if Pos.X >= AbsPos.X and Pos.X <= AbsPos.X + AbsSize.X
        and Pos.Y >= AbsPos.Y and Pos.Y <= AbsPos.Y + AbsSize.Y then

        return true
    end

    return false
end

function Library:MouseIsOverOpenedFrame(Input)
    -- Inside active dialog
    if Library.ActiveDialog then
        if Library:MouseIsOverFrame(Library.ActiveDialog.Container, Input) then
            return false
        end

        return true
    end

    -- Inside opened frames
    for Frame, _ in next, Library.OpenedFrames do
        if Library:MouseIsOverFrame(Frame, Input) then
            return true
        end
    end

    return false
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault, condition)
    local function undoHighlight()
        local Reg = Library.RegistryMap[Instance]

        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx
            end
        end
    end

    local function doHighlight()
        if condition and not condition() then 
            undoHighlight()
            return 
        end

        if Library.ActiveDialog and not Library:IsFrameInsideDialog(Instance) then
            undoHighlight()
            return
        end

        local Reg = Library.RegistryMap[Instance]

        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx
            end
        end
    end

    HighlightInstance.MouseEnter:Connect(doHighlight)
    HighlightInstance.MouseMoved:Connect(doHighlight)
    HighlightInstance.MouseLeave:Connect(undoHighlight)
end

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update()
    end
end

function Library:UpdateDependencyGroupboxes()
    for _, Depbox in next, Library.DependencyGroupboxes do
        Depbox:Update()
    end
end

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB
end

function Library:GetTextBounds(Text, Font, Size, Resolution)
    -- Ignores rich text formatting --
    if typeof(Resolution) == "number" then
        Resolution = Vector2.new(Resolution, 10000)
    end

    local Bounds = TextService:GetTextSize(Text:gsub("<%/?[%w:]+[^>]*>", ""), Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color)
    return Color3.fromHSV(H, S, V / 1.5)
end
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    }

    table.insert(Library.Registry, Data)
    Library.RegistryMap[Instance] = Data

    if IsHud then
        table.insert(Library.HudRegistry, Data)
    end
end

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance]

    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx)
            end
        end

        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx)
            end
        end

        Library.RegistryMap[Instance] = nil
    end
end

function Library:UpdateColorsUsingRegistry()
    -- TODO: Could have an "active" list of objects
    -- where the active list only contains Visible objects.

    -- IMPL: Could setup .Changed events on the AddToRegistry function
    -- that listens for the "Visible" propert being changed.
    -- Visible: true => Add to active list, and call UpdateColors function
    -- Visible: false => Remove from active list.

    -- The above would be especially efficient for a rainbow menu color or live color-changing.

    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if typeof(ColorIdx) == "string" then
                Object.Instance[Property] = Library[ColorIdx]
            elseif typeof(ColorIdx) == "function" then
                Object.Instance[Property] = ColorIdx()
            end
        end
    end
end

function Library:GiveSignal(Connection: RBXScriptConnection | RBXScriptSignal) -- Only used for signals not attached to library instances, as those should be cleaned up on object destruction by Roblox
    local ConnectionType = typeof(Connection)
    if Connection and (ConnectionType == "RBXScriptConnection" or ConnectionType == "RBXScriptSignal") then
        table.insert(Library.Signals, Connection)
    end

    return Connection
end

function Library:Unload()
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        if Connection and Connection.Connected then
            Connection:Disconnect()
        end
    end

    for _, UnloadCallback in Library.UnloadSignals do
        Library:SafeCallback(UnloadCallback)
    end

    for _, Tooltip in Tooltips do
        Library:SafeCallback(Tooltip.Destroy, Tooltip)
    end

    Library.Unloaded = true
    ScreenGui:Destroy()

    getgenv().Linoria = nil
end

function Library:OnUnload(Callback)
    table.insert(Library.UnloadSignals, Callback)
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.Unloaded then
        return
    end

    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance)
    end
end))

--// Templates \\--
local Templates = { -- TO-DO: do it for missing elements.
    --// Window \\--
    Window = {
        Title = "No Title",
        AutoShow = false,
        Position = UDim2.fromOffset(175, 50),
        Size = UDim2.fromOffset(0, 0),
        AnchorPoint = Vector2.zero,
        TabPadding = 1,
        MenuFadeTime = 0.2,
        NotifySide = "Left",
        ShowCustomCursor = true,
        UnlockMouseWhileOpen = true,
        Center = false
    },

    --// Elements \\--
    Video = {
        Video = "",
        Looped = false,
        Playing = false,
        Volume = 1,
        Height = 200,
        Visible = true,
    },
    UIPassthrough = {
        Instance = nil,
        Height = 24,
        Visible = true,
    }
}

--// Addons \\--
local BaseAddons = {}
do
    local BaseAddonsFuncs = {}

        function BaseAddonsFuncs:AddKeyPicker(Idx, Info)
        local ParentObj = self
        local ToggleLabel = self.TextLabel
        --local Container = self.Container;

        assert(Info.Default, string.format("AddKeyPicker (IDX: %s): Missing default value.", tostring(Idx)))

        local KeyPicker = {
            Value = nil; -- Key
            Modifiers = {}; -- Modifiers
            DisplayValue = nil; -- Picker Text

            Toggled = false;
            Mode = Info.Mode or "Toggle"; -- Always, Toggle, Hold, Press
            Type = "KeyPicker";
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;
            SyncToggleState = Info.SyncToggleState or false;
        }

        if KeyPicker.Mode == "Press" then
            assert(ParentObj.Type == "Label", "KeyPicker with the mode \"Press\" can be only applied on Labels.")
            
            KeyPicker.SyncToggleState = false
            Info.Modes = { "Press" }
            Info.Mode = "Press"
        end

        if KeyPicker.SyncToggleState then
            Info.Modes = { "Toggle", "Hold" }

            if not table.find(Info.Modes, Info.Mode) then
                Info.Mode = "Toggle"
            end
        end

        local Picking = false

        -- Special Keys
        local SpecialKeys = {
            ["MB1"] = Enum.UserInputType.MouseButton1,
            ["MB2"] = Enum.UserInputType.MouseButton2,
            ["MB3"] = Enum.UserInputType.MouseButton3
        }

        local SpecialKeysInput = {
            [Enum.UserInputType.MouseButton1] = "MB1",
            [Enum.UserInputType.MouseButton2] = "MB2",
            [Enum.UserInputType.MouseButton3] = "MB3"
        }

        -- Modifiers
        local Modifiers = {
            ["LAlt"] = Enum.KeyCode.LeftAlt,
            ["RAlt"] = Enum.KeyCode.RightAlt,

            ["LCtrl"] = Enum.KeyCode.LeftControl,
            ["RCtrl"] = Enum.KeyCode.RightControl,

            ["LShift"] = Enum.KeyCode.LeftShift,
            ["RShift"] = Enum.KeyCode.RightShift,

            ["Tab"] = Enum.KeyCode.Tab,
            ["CapsLock"] = Enum.KeyCode.CapsLock
        }

        local ModifiersInput = {
            [Enum.KeyCode.LeftAlt] = "LAlt",
            [Enum.KeyCode.RightAlt] = "RAlt",

            [Enum.KeyCode.LeftControl] = "LCtrl",
            [Enum.KeyCode.RightControl] = "RCtrl",

            [Enum.KeyCode.LeftShift] = "LShift",
            [Enum.KeyCode.RightShift] = "RShift",

            [Enum.KeyCode.Tab] = "Tab",
            [Enum.KeyCode.CapsLock] = "CapsLock"
        }

        local IsModifierInput = function(Input)
            return Input.UserInputType == Enum.UserInputType.Keyboard and ModifiersInput[Input.KeyCode] ~= nil
        end

        local GetActiveModifiers = function()
            local ActiveModifiers = {}

            for Name, Input in Modifiers do
                if table.find(ActiveModifiers, Name) then continue end
                if not InputService:IsKeyDown(Input) then continue end

                table.insert(ActiveModifiers, Name)
            end

            return ActiveModifiers
        end

        local AreModifiersHeld = function(Required)
            if not (typeof(Required) == "table" and GetTableSize(Required) > 0) then 
                return true
            end

            local ActiveModifiers = GetActiveModifiers()
            local Holding = true

            for _, Name in Required do
                if table.find(ActiveModifiers, Name) then continue end

                Holding = false
                break
            end

            return Holding
        end

        local IsInputDown = function(Input)
            if not Input then 
                return false
            end

            if SpecialKeysInput[Input.UserInputType] ~= nil then
                return InputService:IsMouseButtonPressed(Input.UserInputType) and not InputService:GetFocusedTextBox()
            elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                return InputService:IsKeyDown(Input.KeyCode) and not InputService:GetFocusedTextBox()
            else
                return false
            end
        end

        local ConvertToInputModifiers = function(CurrentModifiers)
            local InputModifiers = {}

            for _, name in CurrentModifiers do
                table.insert(InputModifiers, Modifiers[name])
            end

            return InputModifiers
        end

        local VerifyModifiers = function(CurrentModifiers)
            if typeof(CurrentModifiers) ~= "table" then
                return {}
            end

            local ValidModifiers = {}

            for _, name in CurrentModifiers do
                if not Modifiers[name] then continue end

                table.insert(ValidModifiers, name)
            end

            return ValidModifiers
        end

        local PickOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 28, 0, 15);
            ZIndex = 6;
            Parent = ToggleLabel;
        })

        local PickInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 7;
            Parent = PickOuter;
        })

        Library:AddToRegistry(PickInner, {
            BackgroundColor3 = "BackgroundColor";
            BorderColor3 = "OutlineColor";
        })

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 13;
            Text = Info.Default;
            TextWrapped = true;
            ZIndex = 8;
            Parent = PickInner;
        })

        -- Keybinds Text
        local KeybindsToggle = {}
        do
            local KeybindsToggleContainer = Library:Create("Frame", {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 0, 18);
                Visible = false;
                ZIndex = 110;
                Parent = Library.KeybindContainer;
            })

            local KeybindsToggleOuter = Library:Create("Frame", {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 13, 0, 13);
                Position = UDim2.new(0, 0, 0, 6);
                Visible = true;
                ZIndex = 110;
                Parent = KeybindsToggleContainer;
            })

            Library:AddToRegistry(KeybindsToggleOuter, {
                BorderColor3 = "Black";
            })

            local KeybindsToggleInner = Library:Create("Frame", {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 111;
                Parent = KeybindsToggleOuter;
            })

            Library:AddToRegistry(KeybindsToggleInner, {
                BackgroundColor3 = "MainColor";
                BorderColor3 = "OutlineColor";
            })

            local KeybindsToggleLabel = Library:CreateLabel({
                BackgroundTransparency = 1;
                Size = UDim2.new(0, 216, 1, 0);
                Position = UDim2.new(1, 6, 0, -1);
                TextSize = 14;
                Text = "";
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 111;
                Parent = KeybindsToggleInner;
            })

            Library:Create("UIListLayout", {
                Padding = UDim.new(0, 4);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                VerticalAlignment = Enum.VerticalAlignment.Center;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = KeybindsToggleLabel;
            })

            local KeybindsToggleRegion = Library:Create("Frame", {
                BackgroundTransparency = 1;
                Size = UDim2.new(0, 170, 1, 0);
                ZIndex = 113;
                Parent = KeybindsToggleOuter;
            })

            Library:OnHighlight(KeybindsToggleRegion, KeybindsToggleOuter,
                { BorderColor3 = "AccentColor" },
                { BorderColor3 = "Black" },
                function()
                    return true
                end
            )

            function KeybindsToggle:Display(State)
                KeybindsToggleInner.BackgroundColor3 = State and Library.AccentColor or Library.MainColor
                KeybindsToggleInner.BorderColor3 = State and Library.AccentColorDark or Library.OutlineColor
                KeybindsToggleLabel.TextColor3 = State and Library.AccentColor or Library.FontColor

                Library.RegistryMap[KeybindsToggleInner].Properties.BackgroundColor3 = State and "AccentColor" or "MainColor"
                Library.RegistryMap[KeybindsToggleInner].Properties.BorderColor3 = State and "AccentColorDark" or "OutlineColor"
                Library.RegistryMap[KeybindsToggleLabel].Properties.TextColor3 = State and "AccentColor" or "FontColor"
            end

            function KeybindsToggle:SetText(Text)
                KeybindsToggleLabel.Text = Text
            end

            function KeybindsToggle:SetVisibility(bool)
                KeybindsToggleContainer.Visible = bool
            end

            function KeybindsToggle:SetNormal(bool)
                KeybindsToggle.Normal = bool

                KeybindsToggleOuter.BackgroundTransparency = if KeybindsToggle.Normal then 1 else 0

                KeybindsToggleInner.BackgroundTransparency = if KeybindsToggle.Normal then 1 else 0
                KeybindsToggleInner.BorderSizePixel = if KeybindsToggle.Normal then 0 else 1

                KeybindsToggleLabel.Position = if KeybindsToggle.Normal then UDim2.new(1, -13, 0, -1) else UDim2.new(1, 6, 0, -1)
            end

            KeyPicker.DoClick = function(...) end --// make luau lsp shut up
            Library:GiveSignal(KeybindsToggleRegion.InputBegan:Connect(function(Input)
                if Library.Unloaded then
                    return
                end

                if KeybindsToggle.Normal then return end
                                        
                if (Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType == Enum.UserInputType.Touch then
                    KeyPicker.Toggled = not KeyPicker.Toggled
                    KeyPicker:DoClick()
                end
            end))

            KeybindsToggle.Loaded = true
        end

        local ModeSelectOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 80, 0, 0);
            Visible = false;
            ZIndex = 14;
            Parent = ScreenGui;
        })

        local function UpdateMenuOuterPos()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y)
        end

        UpdateMenuOuterPos()
        ToggleLabel:GetPropertyChangedSignal("AbsolutePosition"):Connect(UpdateMenuOuterPos)

        local ModeSelectInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 0, 3);
            ZIndex = 15;
            Parent = ModeSelectOuter;
        })

        Library:AddToRegistry(ModeSelectInner, {
            BackgroundColor3 = "BackgroundColor";
            BorderColor3 = "OutlineColor";
        })

        Library:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ModeSelectInner;
        })

        local Modes = Info.Modes or { "Always", "Toggle", "Hold" }
        local ModeButtons = {}
        local UnbindButton = {}

        for Idx, Mode in next, Modes do
            local ModeButton = {}

            local Label = Library:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = 13;
                Text = Mode;
                ZIndex = 16;
                Parent = ModeSelectInner;
            })
            ModeSelectInner.Size = ModeSelectInner.Size + UDim2.new(0, 0, 0, 15)
            ModeSelectOuter.Size = ModeSelectOuter.Size + UDim2.new(0, 0, 0, 18)

            function ModeButton:Select()
                for _, Button in next, ModeButtons do
                    Button:Deselect()
                end

                KeyPicker.Mode = Mode

                Label.TextColor3 = Library.AccentColor
                Library.RegistryMap[Label].Properties.TextColor3 = "AccentColor"

                ModeSelectOuter.Visible = false
            end

            function ModeButton:Deselect()
                KeyPicker.Mode = nil

                Label.TextColor3 = Library.FontColor
                Library.RegistryMap[Label].Properties.TextColor3 = "FontColor"
            end

            Label.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    ModeButton:Select()
                end
            end)

            if Mode == KeyPicker.Mode then
                ModeButton:Select()
            end

            ModeButtons[Mode] = ModeButton
        end

        -- Create Unbind button --
        do
            local UnbindInner = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Position = UDim2.new(0, 0, 0, ModeSelectInner.Size.Y.Offset + 3);
                Size = UDim2.new(1, 0, 0, 18);
                ZIndex = 15;
                Parent = ModeSelectOuter;
            })

            ModeSelectOuter.Size = ModeSelectOuter.Size + UDim2.new(0, 0, 0, 18)

            Library:AddToRegistry(UnbindInner, {
                BackgroundColor3 = "BackgroundColor";
                BorderColor3 = "OutlineColor";
            })

            local UnbindLabel = Library:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = 13;
                Text = "Unbind Key";
                ZIndex = 16;
                Parent = UnbindInner;
            })

            KeyPicker.SetValue = function(...) end --// make luau lsp shut up
            function UnbindButton:UnbindKey()
                KeyPicker:SetValue({ nil, KeyPicker.Mode, {} })
                ModeSelectOuter.Visible = false
            end

            UnbindLabel.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    UnbindButton:UnbindKey()
                end
            end)
        end

        function KeyPicker:Display(Text)
            DisplayLabel.Text = Text or KeyPicker.DisplayValue

            PickOuter.Size = UDim2.new(0, 999999, 0, 18)
            RunService.RenderStepped:Wait()
            PickOuter.Size = UDim2.new(0, math.max(28, DisplayLabel.TextBounds.X + 8), 0, 18)
        end

        function KeyPicker:Update()
            if Info.NoUI then
                return
            end

            local State = KeyPicker:GetState()
            local ShowToggle = Library.ShowToggleFrameInKeybinds and KeyPicker.Mode == "Toggle"

            if KeyPicker.SyncToggleState and ParentObj.Value ~= State then
                ParentObj:SetValue(State)
            end

            if KeybindsToggle.Loaded then
                KeybindsToggle:SetNormal(not ShowToggle)

                KeybindsToggle:SetVisibility(true)
                KeybindsToggle:SetText(string.format("[%s] %s (%s)", tostring(KeyPicker.DisplayValue), Info.Text, KeyPicker.Mode))
                KeybindsToggle:Display(State)
            end

            local YSize = 0
            local XSize = 0

            for _, Frame in next, Library.KeybindContainer:GetChildren() do
                if Frame:IsA("Frame") and Frame.Visible then
                    YSize = YSize + 18
                    local Label = Frame:FindFirstChild("TextLabel", true)
                    if not Label then continue end
                    
                    local LabelSize = Label.TextBounds.X + 20
                    if (LabelSize > XSize) then
                        XSize = LabelSize
                    end
                end
            end

            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10, 220), 0, (YSize + 23 + 6) * DPIScale)
            UpdateMenuOuterPos()
        end

        function KeyPicker:GetState()
            if KeyPicker.Mode == "Always" then
                return true
            
            elseif KeyPicker.Mode == "Hold" then
                local Key = KeyPicker.Value
                if Key == "None" then
                    return false
                end

                if not AreModifiersHeld(KeyPicker.Modifiers) then
                    return false
                end

                if SpecialKeys[Key] ~= nil then
                    return InputService:IsMouseButtonPressed(SpecialKeys[Key]) and not InputService:GetFocusedTextBox()
                else
                    return InputService:IsKeyDown(Enum.KeyCode[Key]) and not InputService:GetFocusedTextBox()
                end

            else
                return KeyPicker.Toggled
            end
        end

        function KeyPicker:SetValue(Data, SkipCallback)
            local Key, Mode, Modifiers = Data[1], Data[2], Data[3]

            local IsKeyValid, UserInputType = pcall(function()
                if Key == "None" then
                    Key = nil
                    return nil
                end
                
                if SpecialKeys[Key] == nil then 
                    return Enum.KeyCode[Key]
                end

                return SpecialKeys[Key]
            end)

            if Key == nil then
                KeyPicker.Value = "None"
            elseif IsKeyValid then
                KeyPicker.Value = Key
            else
                KeyPicker.Value = "Unknown"
            end

            KeyPicker.Modifiers = VerifyModifiers(if typeof(Modifiers) == "table" then Modifiers else KeyPicker.Modifiers)
            KeyPicker.DisplayValue = if GetTableSize(KeyPicker.Modifiers) > 0 then (table.concat(KeyPicker.Modifiers, " + ") .. " + " .. KeyPicker.Value) else KeyPicker.Value

            DisplayLabel.Text = KeyPicker.DisplayValue

            if Mode ~= nil and ModeButtons[Mode] ~= nil then 
                ModeButtons[Mode]:Select()
            end

            KeyPicker:Display()
            KeyPicker:Update()

            if SkipCallback == true then return end
            local NewModifiers = ConvertToInputModifiers(KeyPicker.Modifiers)
            Library:SafeCallback(KeyPicker.ChangedCallback, UserInputType, NewModifiers)
            Library:SafeCallback(KeyPicker.Changed, UserInputType, NewModifiers)
        end

        function KeyPicker:OnClick(Callback)
            KeyPicker.Clicked = Callback
        end

        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback
            -- Callback(KeyPicker.Value)
        end

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
        end

        function KeyPicker:DoClick()
            if KeyPicker.Mode == "Press" then
                if KeyPicker.Toggled and Info.WaitForCallback == true then
                    return
                end

                KeyPicker.Toggled = true
            end

            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)

            if KeyPicker.Mode == "Press" then
                KeyPicker.Toggled = false
            end
        end

        function KeyPicker:SetModePickerVisibility(bool)
            ModeSelectOuter.Visible = bool
        end

        function KeyPicker:GetModePickerVisibility()
            return ModeSelectOuter.Visible
        end

        PickOuter.InputBegan:Connect(function(PickerInput)
            if PickerInput.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking = true

                KeyPicker:Display("...")

                -- Wait for an non modifier key --
                local Input
                local ActiveModifiers = {}

                local GetInput = function()
                    Input = InputService.InputBegan:Wait()
                    if InputService:GetFocusedTextBox() then
                        return true
                    end

                    return false
                end

                repeat
                    task.wait()

                    -- Wait for any input --
                    KeyPicker:Display("...")

                    if GetInput() then
                        Picking = false
                        KeyPicker:Update()
                        return
                    end

                    -- Escape --
                    if Input.KeyCode == Enum.KeyCode.Escape then
                        break
                    end

                    -- Handle modifier keys --
                    if IsModifierInput(Input) then
                        local StopLoop = false

                        repeat
                            task.wait()
                            if InputService:IsKeyDown(Input.KeyCode) then
                                task.wait(0.075)

                                if InputService:IsKeyDown(Input.KeyCode) then
                                    -- Add modifier to the key list --
                                    if not table.find(ActiveModifiers, ModifiersInput[Input.KeyCode]) then
                                        ActiveModifiers[#ActiveModifiers + 1] = ModifiersInput[Input.KeyCode]
                                        KeyPicker:Display(table.concat(ActiveModifiers, " + ") .. " + ...")
                                    end

                                    -- Wait for another input --
                                    if GetInput() then
                                        StopLoop = true
                                        break -- Invalid Input
                                    end

                                    -- Escape --
                                    if Input.KeyCode == Enum.KeyCode.Escape then
                                        break
                                    end

                                    -- Stop loop if its a normal key --
                                    if not IsModifierInput(Input) then
                                        break
                                    end
                                else
                                    if not table.find(ActiveModifiers, ModifiersInput[Input.KeyCode]) then
                                        break -- Modifier is meant to be used as a normal key --
                                    end
                                end
                            end
                        until false

                        if StopLoop then
                            Picking = false
                            KeyPicker:Update()
                            return
                        end
                    end

                    break -- Input found, end loop
                until false

                local Key = "Unknown"
                if SpecialKeysInput[Input.UserInputType] ~= nil then
                    Key = SpecialKeysInput[Input.UserInputType]
                elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                    Key = Input.KeyCode == Enum.KeyCode.Escape and "None" or Input.KeyCode.Name
                end

                ActiveModifiers = if Input.KeyCode == Enum.KeyCode.Escape or Key == "Unknown" then {} else ActiveModifiers

                KeyPicker.Toggled = false
                KeyPicker:SetValue({ Key, KeyPicker.Mode, ActiveModifiers })

                -- RunService.RenderStepped:Wait()
                repeat task.wait() until not IsInputDown(Input) or InputService:GetFocusedTextBox()
                Picking = false

            elseif PickerInput.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                local visible = KeyPicker:GetModePickerVisibility()
                
                if visible == false then
                    for _, option in next, Options do
                        if option.Type == "KeyPicker" then
                            option:SetModePickerVisibility(false)
                        end
                    end
                end

                KeyPicker:SetModePickerVisibility(not visible)
            end
        end)

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Library.Unloaded then
                return
            end

            if KeyPicker.Value == "Unknown" then return end
        
            if (not Picking) and (not InputService:GetFocusedTextBox()) then
                local Key = KeyPicker.Value
                local HoldingModifiers = AreModifiersHeld(KeyPicker.Modifiers)
                local HoldingKey = false

                if HoldingModifiers then
                    if Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then
                            HoldingKey = true
                        end
                    elseif SpecialKeysInput[Input.UserInputType] == Key then
                        HoldingKey = true
                    end
                end

                if KeyPicker.Mode == "Toggle" then
                    if HoldingKey then
                        KeyPicker.Toggled = not KeyPicker.Toggled
                        KeyPicker:DoClick()
                    end
                elseif KeyPicker.Mode == "Press" then
                    if HoldingKey then
                        KeyPicker:DoClick()
                    end
                end

                KeyPicker:Update()
            end

            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    KeyPicker:SetModePickerVisibility(false)
                end
            end
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if Library.Unloaded then
                return
            end

            if (not Picking) then
                KeyPicker:Update()
            end
        end))
        
        KeyPicker:SetValue({ Info.Default, Info.Mode or "Toggle", Info.DefaultModifiers }, true)
        KeyPicker.DisplayFrame = PickOuter

        KeyPicker.Default = KeyPicker.Value
        KeyPicker.DefaultModifiers = table.clone(KeyPicker.Modifiers or {})

        Options[Idx] = KeyPicker

        return self
    end

    function BaseAddonsFuncs:AddColorPicker(Idx, Info)
        local ParentObj = self
        local ToggleLabel = self.TextLabel
        --local Container = self.Container;

        assert(Info.Default, string.format("AddColorPicker (IDX: %s): Missing default value.", tostring(Idx)))

        local ColorPicker = {
            Value = Info.Default;

            Transparency = Info.Transparency or 0;
            Type = "ColorPicker";
            Title = typeof(Info.Title) == "string" and Info.Title or "Color picker",
            Callback = Info.Callback or function(Color) end;
            Changed = nil,
        }

        local PreviousValues = {
            Value = nil,
            Transparency = nil
        }

        local function RunCallback()
            local NewValue = ColorPicker.Value
            local NewTransparency = ColorPicker.Transparency

            if NewValue == PreviousValues.Value and NewTransparency == PreviousValues.Transparency then
                return
            end

            PreviousValues.Value = ColorPicker.Value
            PreviousValues.Transparency = ColorPicker.Transparency

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value, ColorPicker.Transparency)
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value, ColorPicker.Transparency)
        end

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color:ToHSV()

            ColorPicker.Hue = H
            ColorPicker.Sat = S
            ColorPicker.Vib = V
        end

        ColorPicker:SetHSVFromRGB(ColorPicker.Value)

        local DisplayFrame = Library:Create("Frame", {
            BackgroundColor3 = ColorPicker.Value;
            BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(0, 28, 0, 15);
            ZIndex = 6;
            Parent = ToggleLabel;
        })

        -- Transparency image (source: SplixPrivateDrawingLibrary)
        -- local CheckerFrame = 
        Library:Create("ImageLabel", {
            BorderSizePixel = 0;
            Size = UDim2.new(0, 27, 0, 13);
            ZIndex = 5;
            Image = CustomImageManager.GetAsset("Checker");
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        })

        -- 1/16/23
        -- Rewrote this to be placed inside the Library ScreenGui
        -- There was some issue which caused RelativeOffset to be way off
        -- Thus the color picker would never show

        local PickerFrameOuter = Library:Create("Frame", {
            Name = "Color";
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        })

        DisplayFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18)
        end)

        local PickerFrameInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 16;
            Parent = PickerFrameOuter;
        })

        local Highlight = Library:Create("Frame", {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 17;
            Parent = PickerFrameInner;
        })

        local SatVibMapOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 4, 0, 25);
            Size = UDim2.new(0, 200, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        })

        local SatVibMapInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = SatVibMapOuter;
        })

        local SatVibMap = Library:Create("ImageLabel", {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Image = CustomImageManager.GetAsset("SaturationMap");
            Parent = SatVibMapInner;
        })

        local CursorOuter = Library:Create("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image = CustomImageManager.GetAsset("Cursor");
            ImageColor3 = Color3.new(0, 0, 0);
            ZIndex = 19;
            Parent = SatVibMap;
        })

        -- local CursorInner = 
        Library:Create("ImageLabel", {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = CustomImageManager.GetAsset("Cursor");
            ZIndex = 20;
            Parent = CursorOuter;
        })

        local HueSelectorOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 208, 0, 25);
            Size = UDim2.new(0, 15, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        })

        local HueSelectorInner = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = HueSelectorOuter;
        })

        local HueCursor = Library:Create("Frame", { 
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 18;
            Parent = HueSelectorInner;
        })

        local HueBoxOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            ZIndex = 18,
            Parent = PickerFrameInner;
        })

        local HueBoxInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18,
            Parent = HueBoxOuter;
        })

        Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = HueBoxInner;
        })

        local HueBox = Library:Create("TextBox", {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = "Hex color",
            Text = "#FFFFFF",
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = HueBoxInner;
        })

        Library:ApplyTextStroke(HueBox)

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner
        })

        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild("TextBox"), {
            Text = "255, 255, 255",
            PlaceholderText = "RGB color",
            TextColor3 = Library.FontColor
        })

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor
        
        if Info.Transparency then 
            TransparencyBoxOuter = Library:Create("Frame", {
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromOffset(4, 251);
                Size = UDim2.new(1, -8, 0, 15);
                ZIndex = 19;
                Parent = PickerFrameInner;
            })

            TransparencyBoxInner = Library:Create("Frame", {
                BackgroundColor3 = ColorPicker.Value;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = TransparencyBoxOuter;
            })

            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = "OutlineColor" })

            Library:Create("ImageLabel", {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Image = CustomImageManager.GetAsset("CheckerLong");
                ZIndex = 20;
                Parent = TransparencyBoxInner;
            })

            TransparencyCursor = Library:Create("Frame", { 
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint = Vector2.new(0.5, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 1, 1, 0);
                ZIndex = 21;
                Parent = TransparencyBoxInner;
            })
        end

        -- local DisplayLabel = 
        Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 14;
            Text = ColorPicker.Title,--Info.Default;
            TextWrapped = false;
            ZIndex = 16;
            Parent = PickerFrameInner;
        })

        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create("Frame", {
                BorderColor3 = Color3.new(),
                ZIndex = 14,

                Visible = false,
                Parent = ScreenGui
            })

            ContextMenu.Inner = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 15;
                Parent = ContextMenu.Container;
            })

            Library:Create("UIListLayout", {
                Name = "Layout",
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = ContextMenu.Inner;
            })

            Library:Create("UIPadding", {
                Name = "Padding",
                PaddingLeft = UDim.new(0, 4),
                Parent = ContextMenu.Inner,
            })

            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                )
            end

            local function updateMenuSize()
                local menuWidth = 60
                for i, label in next, ContextMenu.Inner:GetChildren() do
                    if label:IsA("TextLabel") then
                        menuWidth = math.max(menuWidth, label.TextBounds.X)
                    end
                end

                ContextMenu.Container.Size = UDim2.fromOffset(
                    menuWidth + 8,
                    ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
                )
            end

            DisplayFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateMenuSize)

            task.spawn(updateMenuPosition)
            task.spawn(updateMenuSize)

            Library:AddToRegistry(ContextMenu.Inner, {
                BackgroundColor3 = "BackgroundColor";
                BorderColor3 = "OutlineColor";
            })

            function ContextMenu:Show()
                if Library.IsMobile then
                    Library.CanDrag = false
                end

                self.Container.Visible = true
            end

            function ContextMenu:Hide()
                if Library.IsMobile then
                    Library.CanDrag = true
                end
                
                self.Container.Visible = false
            end

            function ContextMenu:AddOption(Str, Callback)
                if typeof(Callback) ~= "function" then
                    Callback = function() end
                end

                local Button = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, 0, 0, 15);
                    TextSize = 13;
                    Text = Str;
                    ZIndex = 16;
                    Parent = self.Inner;
                    TextXAlignment = Enum.TextXAlignment.Left,
                })

                Library:OnHighlight(Button, Button, 
                    { TextColor3 = "AccentColor" },
                    { TextColor3 = "FontColor" }
                )

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 or Input.UserInputType ~= Enum.UserInputType.Touch then
                        return
                    end

                    Callback()
                end)
            end

            ContextMenu:AddOption("Copy color", function()
                Library.ColorClipboard = ColorPicker.Value
                Library:Notify("Copied color!", 2)
            end)

            ColorPicker.SetValueRGB = function(...) end --// make luau lsp shut up
            ContextMenu:AddOption("Paste color", function()
                if not Library.ColorClipboard then
                    Library:Notify("You have not copied a color!", 2)
                    return
                end

                ColorPicker:SetValueRGB(Library.ColorClipboard)
            end)

            ContextMenu:AddOption("Copy HEX", function()
                pcall(setclipboard, ColorPicker.Value:ToHex())
                Library:Notify("Copied hex code to clipboard!", 2)
            end)

            ContextMenu:AddOption("Copy RGB", function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ", "))
                Library:Notify("Copied RGB values to clipboard!", 2)
            end)
        end
        ColorPicker.ContextMenu = ContextMenu

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = "BackgroundColor"; BorderColor3 = "OutlineColor"; })
        Library:AddToRegistry(Highlight, { BackgroundColor3 = "AccentColor"; })
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = "BackgroundColor"; BorderColor3 = "OutlineColor"; })

        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor"; })
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor"; })
        Library:AddToRegistry(RgbBox, { TextColor3 = "FontColor", })
        Library:AddToRegistry(HueBox, { TextColor3 = "FontColor", })

        local SequenceTable = {}

        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)))
        end

        -- local HueSelectorGradient =
        Library:Create("UIGradient", {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        })

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib)
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1)

            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value;
                BackgroundTransparency = ColorPicker.Transparency;
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            })

            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0)
            end

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0)
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0)

            HueBox.Text = "#" .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ", ")
        end

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func
        end

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, ColorPicker)
        end

        function ColorPicker:Show()
            for Frame, Val in next, Library.OpenedFrames do
                if Frame.Name == "Color" then
                    Frame.Visible = false
                    Library.OpenedFrames[Frame] = nil
                end
            end

            PickerFrameOuter.Visible = true
            Library.OpenedFrames[PickerFrameOuter] = true
        end

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false
            Library.OpenedFrames[PickerFrameOuter] = nil
        end

        function ColorPicker:SetValue(HSV, Transparency)
            if typeof(HSV) == "Color3" then
                ColorPicker:SetValueRGB(HSV, Transparency)
                return
            end

            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3])

            ColorPicker.Transparency = Transparency or 0
            ColorPicker:SetHSVFromRGB(Color)
            ColorPicker:Display()

            RunCallback()
        end

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0
            ColorPicker:SetHSVFromRGB(Color)
            ColorPicker:Display()

            RunCallback()
        end

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == "Color3" then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
                end
            end

            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match("(%d+),%s*(%d+),%s*(%d+)")
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end

            ColorPicker:Display()
        end)

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1 or Enum.UserInputType.Touch) do
                    local MinX = SatVibMap.AbsolutePosition.X
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X
                    local MouseX = math.clamp(Mouse.X, MinX, MaxX)

                    local MinY = SatVibMap.AbsolutePosition.Y
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY)

                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX)
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY))
                    ColorPicker:Display()

                    RunCallback()

                    RunService.RenderStepped:Wait()
                end

                Library:AttemptSave()
            end
        end)

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1 or Enum.UserInputType.Touch) do
                    local MinY = HueSelectorInner.AbsolutePosition.Y
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY)

                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY))
                    ColorPicker:Display()

                    RunCallback()

                    RunService.RenderStepped:Wait()
                end

                Library:AttemptSave()
            end
        end)

        DisplayFrame.InputBegan:Connect(function(Input)
            if Library:MouseIsOverOpenedFrame(Input) then
                return
            end

            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide()
                else
                    ContextMenu:Hide()
                    ColorPicker:Show()
                end
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                ContextMenu:Show()
                ColorPicker:Hide()
            end
        end)

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1 or Enum.UserInputType.Touch) do
                        local MinX = TransparencyBoxInner.AbsolutePosition.X
                        local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X
                        local MouseX = math.clamp(Mouse.X, MinX, MaxX)

                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX))
                        ColorPicker:Display()

                        RunCallback()

                        RunService.RenderStepped:Wait()
                    end

                    Library:AttemptSave()
                end
            end)
        end

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Library.Unloaded then
                return
            end

            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ColorPicker:Hide()
                end

                if not Library:MouseIsOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide()
                end
            end

            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:MouseIsOverFrame(ContextMenu.Container) and not Library:MouseIsOverFrame(DisplayFrame) then
                    ContextMenu:Hide()
                end
            end
        end))

        ColorPicker:Display()
        ColorPicker.DisplayFrame = DisplayFrame

        ColorPicker.Default = ColorPicker.Value

        Options[Idx] = ColorPicker

        return self
    end

    function BaseAddonsFuncs:AddDropdown(Idx, Info)
        Info.ReturnInstanceInstead = if typeof(Info.ReturnInstanceInstead) == "boolean" then Info.ReturnInstanceInstead else false

        if Info.SpecialType == "Player" then
            Info.ExcludeLocalPlayer = if typeof(Info.ExcludeLocalPlayer) == "boolean" then Info.ExcludeLocalPlayer else false

            Info.Values = GetPlayers(Info.ExcludeLocalPlayer, Info.ReturnInstanceInstead)
            Info.AllowNull = true
        elseif Info.SpecialType == "Team" then
            Info.Values = GetTeams(Info.ReturnInstanceInstead)
            Info.AllowNull = true
        end

        assert(Info.Values, string.format("AddDropdown (IDX: %s): Missing dropdown value list.", tostring(Idx)))
        if not (Info.AllowNull or Info.Default) then
            Info.Default = 1
            warn(string.format("AddDropdown (IDX: %s): Missing default value, selected the first index instead. Pass `AllowNull` as true if this was intentional.", tostring(Idx)))
        end

        Info.Searchable = if typeof(Info.Searchable) == "boolean" then Info.Searchable else false
        Info.FormatDisplayValue = if typeof(Info.FormatDisplayValue) == "function" then Info.FormatDisplayValue else nil
        Info.FormatListValue = if typeof(Info.FormatListValue) == "function" then Info.FormatListValue else nil

        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            DisabledValues = Info.DisabledValues or {};

            Multi = Info.Multi;
            Type = "Dropdown";
            SpecialType = Info.SpecialType; -- can be either "Player" or "Team"
            Visible = if typeof(Info.Visible) == "boolean" then Info.Visible else true;
            Disabled = if typeof(Info.Disabled) == "boolean" then Info.Disabled else false;
            Callback = Info.Callback or function(Value) end;
            Changed = Info.Changed or function(Value) end;

            OriginalText = Info.Text; Text = Info.Text;
            ExcludeLocalPlayer = Info.ExcludeLocalPlayer;
            ReturnInstanceInstead = Info.ReturnInstanceInstead;
        }

        local Tooltip

        local ParentObj = self
        local ToggleLabel = self.TextLabel
        local Container = self.Container

        local RelativeOffset = 0

        for _, Element in next, Container:GetChildren() do
            if not Element:IsA("UIListLayout") then
                RelativeOffset = RelativeOffset + Element.Size.Y.Offset
            end
        end

        local DropdownOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 60, 0, 18);
            Visible = Dropdown.Visible;
            ZIndex = 6;
            Parent = ToggleLabel;
        })

        Library:AddToRegistry(DropdownOuter, {
            BorderColor3 = "Black";
        })

        local DropdownInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DropdownOuter;
        })

        Library:AddToRegistry(DropdownInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = DropdownInner;
        })

        local DropdownInnerSearch
        if Info.Searchable then
            DropdownInnerSearch = Library:Create("TextBox", {
                BackgroundTransparency = 1;
                Visible = false;

                Position = UDim2.new(0, 5, 0, 0);
                Size = UDim2.new(0.9, -5, 1, 0);

                Font = Library.Font;
                PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
                PlaceholderText = "Search...";

                Text = "";
                TextColor3 = Library.FontColor;
                TextSize = 14;
                TextStrokeTransparency = 0;
                TextXAlignment = Enum.TextXAlignment.Left;

                ClearTextOnFocus = false;

                ZIndex = 7;
                Parent = DropdownOuter;
            })

            Library:ApplyTextStroke(DropdownInnerSearch)

            Library:AddToRegistry(DropdownInnerSearch, {
                TextColor3 = "FontColor";
            })
        end

        local DropdownArrow = Library:Create("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = CustomImageManager.GetAsset("DropdownArrow");
            ZIndex = 8;
            Parent = DropdownInner;
        })

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            TextSize = 14;
            Text = "--";
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped = false;
            TextTruncate = Enum.TextTruncate.AtEnd;
            RichText = true;
            ZIndex = 7;
            Parent = DropdownInner;
        })

        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = "AccentColor" },
            { BorderColor3 = "Black" },
            function()
                return not Dropdown.Disabled
            end
        )

        if typeof(Info.Tooltip) == "string" or typeof(Info.DisabledTooltip) == "string" then
            Tooltip = Library:AddToolTip(Info.Tooltip, Info.DisabledTooltip, DropdownOuter)
            Tooltip.Disabled = Dropdown.Disabled
        end

        local MAX_DROPDOWN_ITEMS = if typeof(Info.MaxVisibleDropdownItems) == "number" then math.clamp(Info.MaxVisibleDropdownItems, 4, 16) else 8

        local ListOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            ZIndex = 20;
            Visible = false;
            Parent = ScreenGui;
        })

        local OpenedXSizeForList = 0

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1)
        end

        local function RecalculateListSize(YSize)
            local Y = YSize or math.clamp(GetTableSize(Dropdown.Values) * (20 * DPIScale), 0, MAX_DROPDOWN_ITEMS * (20 * DPIScale)) + 1
            ListOuter.Size = UDim2.fromOffset(ListOuter.Visible and OpenedXSizeForList or DropdownOuter.AbsoluteSize.X + 0.5, Y)
        end

        RecalculateListPosition()
        RecalculateListSize()

        DropdownOuter:GetPropertyChangedSignal("AbsolutePosition"):Connect(RecalculateListPosition)
        DropdownOuter:GetPropertyChangedSignal("AbsoluteSize"):Connect(RecalculateListSize)

        local ListInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListOuter;
        })

        Library:AddToRegistry(ListInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        local Scrolling = Library:Create("ScrollingFrame", {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListInner;

            TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
            BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",

            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        })

        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = "AccentColor"
        })

        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        })

        function Dropdown:UpdateColors()
            ItemList.TextColor3 = Dropdown.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
            DropdownArrow.ImageColor3 = Dropdown.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
        end

        function Dropdown:GenerateDisplayText(SelectedValue)
            local Str = ""

            if Info.Multi and typeof(SelectedValue) == "table" then
                for Idx, Value in next, Dropdown.Values do
                    if SelectedValue[Value] then
                        Str = Str .. tostring(Info.FormatDisplayValue and Info.FormatDisplayValue(Value) or Value) .. ", "
                    end
                end

                Str = Str:sub(1, #Str - 2)
                Str = (Str == "" and "--" or Str)
            else
                if not SelectedValue then
                    return "--"
                end

                Str = tostring(Info.FormatDisplayValue and Info.FormatDisplayValue(SelectedValue) or SelectedValue)
            end

            return Str
        end

        function Dropdown:Display()
            local Str = Dropdown:GenerateDisplayText(Dropdown.Value)
            ItemList.Text = Str

            local X = ListOuter.Visible and OpenedXSizeForList or Library:GetTextBounds(ItemList.Text, Library.Font, ItemList.TextSize, Vector2.new(ToggleLabel.AbsoluteSize.X, math.huge)) + 26
            DropdownOuter.Size = UDim2.new(0, X, 0, 18)
        end

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {}

                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value)
                end

                return T
            else
                return Dropdown.Value and 1 or 0
            end
        end

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values
            local DisabledValues = Dropdown.DisabledValues
            local Buttons = {}

            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA("UIListLayout") then
                    Element:Destroy()
                end
            end

            local Count = 0
            OpenedXSizeForList = DropdownOuter.AbsoluteSize.X + 0.5

            for Idx, Value in next, Values do
                local StringValue = tostring(Info.FormatListValue and Info.FormatListValue(Value) or Value)
                if Info.Searchable and not string.lower(StringValue):match(string.lower(DropdownInnerSearch.Text)) then
                    continue
                end

                local IsDisabled = table.find(DisabledValues, StringValue)
                local Table = {}

                Count = Count + 1

                local Button = Library:Create("TextButton", {
                    AutoButtonColor = false,
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Library.OutlineColor;
                    BorderMode = Enum.BorderMode.Middle;
                    Size = UDim2.new(1, -1, 0, 20);
                    Text = "";
                    ZIndex = 23;
                    Parent = Scrolling;
                })

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = "MainColor";
                    BorderColor3 = "OutlineColor";
                })

                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -6, 1, 0);
                    Position = UDim2.new(0, 6, 0, 0);
                    TextSize = 14;
                    Text = Info.FormatDisplayValue and tostring(Info.FormatDisplayValue(StringValue)) or StringValue;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    RichText = true;
                    ZIndex = 25;
                    Parent = Button;
                })

                Library:OnHighlight(Button, Button,
                    { BorderColor3 = IsDisabled and "DisabledAccentColor" or "AccentColor", ZIndex = 24 },
                    { BorderColor3 = "OutlineColor", ZIndex = 23 }
                )

                local Selected

                if Info.Multi then
                    Selected = Dropdown.Value[Value]
                else
                    Selected = Dropdown.Value == Value
                end

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value]
                    else
                        Selected = Dropdown.Value == Value
                    end

                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or (IsDisabled and Library.DisabledAccentColor or Library.FontColor)
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and "AccentColor" or (IsDisabled and "DisabledAccentColor" or "FontColor")
                end

                if not IsDisabled then
                    Button.MouseButton1Click:Connect(function(Input)
                        local Try = not Selected

                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try

                                if Selected then
                                    Dropdown.Value[Value] = true
                                else
                                    Dropdown.Value[Value] = nil
                                end
                            else
                                Selected = Try

                                if Selected then
                                    Dropdown.Value = Value
                                else
                                    Dropdown.Value = nil
                                end

                                for _, OtherButton in next, Buttons do
                                    OtherButton:UpdateButton()
                                end
                            end

                            Table:UpdateButton()
                            Dropdown:Display()
                            
                            Library:UpdateDependencyBoxes()
                            Library:UpdateDependencyGroupboxes()
                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value)

                            Library:AttemptSave()
                        end
                    end)
                end

                Table:UpdateButton()
                Dropdown:Display()

                local Str = Dropdown:GenerateDisplayText(Value)
                local X = Library:GetTextBounds(Str, Library.Font, ItemList.TextSize, Vector2.new(ToggleLabel.AbsoluteSize.X, math.huge)) + 26
                if X > OpenedXSizeForList then
                    OpenedXSizeForList = X
                end

                Buttons[Button] = Table
            end
            
            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * (20 * DPIScale)) + 1)

            -- Workaround for silly roblox bug - not sure why it happens but sometimes the dropdown list will be empty
            -- ... and for some reason refreshing the Visible property fixes the issue??????? thanks roblox!
            Scrolling.Visible = false
            Scrolling.Visible = true

            local Y = math.clamp(Count * (20 * DPIScale), 0, MAX_DROPDOWN_ITEMS * (20 * DPIScale)) + 1
            RecalculateListSize(Y)
        end

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddValues(NewValues)
            if typeof(NewValues) == "table" then
                for _, val in pairs(NewValues) do
                    table.insert(Dropdown.Values, val)
                end
            elseif typeof(NewValues) == "string" then
                table.insert(Dropdown.Values, NewValues)
            else
                return
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetDisabledValues(NewValues)
            if NewValues then
                Dropdown.DisabledValues = NewValues
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddDisabledValues(DisabledValues)
            if typeof(DisabledValues) == "table" then
                for _, val in pairs(DisabledValues) do
                    table.insert(Dropdown.DisabledValues, val)
                end
            elseif typeof(DisabledValues) == "string" then
                table.insert(Dropdown.DisabledValues, DisabledValues)
            else
                return
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetVisible(Visibility)
            Dropdown.Visible = Visibility

            DropdownOuter.Visible = Dropdown.Visible
            if not Dropdown.Visible then 
                Dropdown:CloseDropdown()
            end
        end

        function Dropdown:SetDisabled(Disabled)
            Dropdown.Disabled = Disabled

            if Tooltip then
                Tooltip.Disabled = Disabled
            end

            if Disabled then
                Dropdown:CloseDropdown()
            end

            Dropdown:Display()
            Dropdown:UpdateColors()
        end

        function Dropdown:OpenDropdown()
            if Dropdown.Disabled then
                return
            end

            if Library.IsMobile then
                Library.CanDrag = false
            end

            if Info.Searchable then
                ItemList.Visible = false
                DropdownInnerSearch.Text = ""
                DropdownInnerSearch.Visible = true
            end
            
            ListOuter.Visible = true
            Library.OpenedFrames[ListOuter] = true
            DropdownArrow.Rotation = 180

            Dropdown:Display()
            RecalculateListSize()
        end

        function Dropdown:CloseDropdown()
            if Library.IsMobile then         
                Library.CanDrag = true
            end

            if Info.Searchable then
                DropdownInnerSearch.Text = ""
                DropdownInnerSearch.Visible = false
                ItemList.Visible = true
            end
        
            ListOuter.Visible = false
            Library.OpenedFrames[ListOuter] = nil
            DropdownArrow.Rotation = 0

            Dropdown:Display()
            RecalculateListSize()
        end

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func

            -- if Dropdown.Disabled then
            --     return;
            -- end;

            -- Library:SafeCallback(Func, Dropdown.Value);
        end

        function Dropdown:SetValue(Value)
            if Dropdown.Multi then
                local Table = {}

                for Val, Active in pairs(Value or {}) do
                    if typeof(Active) ~= "boolean" then
                        Table[Active] = true
                    elseif Active and table.find(Dropdown.Values, Val) then
                        Table[Val] = true
                    end
                end

                Dropdown.Value = Table
            else
                if table.find(Dropdown.Values, Value) then
                    Dropdown.Value = Value
                elseif not Value then
                    Dropdown.Value = nil
                end
            end

            Dropdown:BuildDropdownList()

            if not Dropdown.Disabled then
                Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
            end
        end

        function Dropdown:SetText(...)
            -- This is an Compat dropdown for Toggles, it doesn't have an TextLabel --
            return
        end

        DropdownOuter.InputBegan:Connect(function(Input)
            if Dropdown.Disabled then
                return
            end

            if (Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType == Enum.UserInputType.Touch then
                if ListOuter.Visible then
                    Dropdown:CloseDropdown()
                else
                    Dropdown:OpenDropdown()
                end
            end
        end)

        if Info.Searchable then
            DropdownInnerSearch:GetPropertyChangedSignal("Text"):Connect(function()
                Dropdown:BuildDropdownList()
            end)
        end

        InputService.InputBegan:Connect(function(Input)
            if Dropdown.Disabled then
                return
            end

            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - (20 * DPIScale) - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    Dropdown:CloseDropdown()
                end
            end
        end)

        Dropdown:BuildDropdownList()
        Dropdown:Display()

        local Defaults = {}

        if typeof(Info.Default) == "string" then
            local DefaultIdx = table.find(Dropdown.Values, Info.Default)
            if DefaultIdx then
                table.insert(Defaults, DefaultIdx)
            end

        elseif typeof(Info.Default) == "table" then
            for _, Value in next, Info.Default do
                local DefaultIdx = table.find(Dropdown.Values, Value)
                if DefaultIdx then
                    table.insert(Defaults, DefaultIdx)
                end
            end

        elseif typeof(Info.Default) == "number" and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index]
                end

                if (not Info.Multi) then break end
            end

            Dropdown:BuildDropdownList()
            Dropdown:Display()
        end

        task.delay(0.1, Dropdown.UpdateColors, Dropdown)

        Dropdown.DisplayFrame = DropdownOuter
        if ParentObj.Addons then
            table.insert(ParentObj.Addons, Dropdown)
        end

        Dropdown.Default = Defaults
        Dropdown.DefaultValues = Dropdown.Values

        Options[Idx] = Dropdown

        return self
    end

    BaseAddons.__index = BaseAddonsFuncs
    BaseAddons.__namecall = function(Table, Key, ...)
        return BaseAddonsFuncs[Key](...)
    end
end

--// Groupbox Addons \\--
local BaseGroupbox = {}
do
    local BaseGroupboxFuncs = {}

    function BaseGroupboxFuncs:AddBlank(Size, Visible)
        local Groupbox = self
        local Container = Groupbox.Container

        return Library:Create("Frame", {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size);
            Visible = if typeof(Visible) == "boolean" then Visible else true;
            ZIndex = 1;
            Parent = Container;
        })
    end

    function BaseGroupboxFuncs:AddDivider(...)
        local Params = select(1, ...)
        local Text
        local MarginTop = 2
        local MarginBottom = 9

        if typeof(Params) == "table" then
            Text = Params.Text
            MarginTop = Params.MarginTop or Params.Margin or 2
            MarginBottom = Params.MarginBottom or Params.Margin or 9
        elseif typeof(Params) == "string" then
            Text = Params
        end

        local Groupbox = self
        local Container = self.Container

        Groupbox:AddBlank(MarginTop)

        local DividerOuter
        if Text then
            DividerOuter = Library:Create("Frame", {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, -4, 0, 14);
                ZIndex = 5;
                Parent = Container;
            })

            Library:CreateLabel({
                AutomaticSize = Enum.AutomaticSize.X;
                BackgroundTransparency = 1;
                Position = UDim2.fromScale(0.5, 0.5);
                AnchorPoint = Vector2.new(0.5, 0.5);
                Size = UDim2.fromScale(1, 0);
                Text = Text;
                TextSize = 14;
                TextTransparency = 0.5;
                TextXAlignment = Enum.TextXAlignment.Center;
                ZIndex = 6;
                Parent = DividerOuter;
                RichText = true;
            })

            local X = select(1, Library:GetTextBounds(Text, Library.Font, 14 * DPIScale))
            local SizeX = math.floor(X / 2) + (10 * DPIScale)

            local LeftOuter = Library:Create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5);
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromScale(0, 0.5);
                Size = UDim2.new(0.5, -SizeX, 0, 5);
                ZIndex = 5;
                Parent = DividerOuter;
            })
            local LeftInner = Library:Create("Frame", {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = LeftOuter;
            })

            local RightOuter = Library:Create("Frame", {
                AnchorPoint = Vector2.new(1, 0.5);
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromScale(1, 0.5);
                Size = UDim2.new(0.5, -SizeX, 0, 5);
                ZIndex = 5;
                Parent = DividerOuter;
            })
            local RightInner = Library:Create("Frame", {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = RightOuter;
            })

            Library:AddToRegistry(LeftOuter, { BorderColor3 = "Black"; })
            Library:AddToRegistry(LeftInner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor"; })
            Library:AddToRegistry(RightOuter, { BorderColor3 = "Black"; })
            Library:AddToRegistry(RightInner, { BackgroundColor3 = "MainColor"; BorderColor3 = "OutlineColor"; })
        else
            DividerOuter = Library:Create("Frame", {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, 5);
                ZIndex = 5;
                Parent = Container;
            })

            local DividerInner = Library:Create("Frame", {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = DividerOuter;
            })

            Library:AddToRegistry(DividerOuter, {
                BorderColor3 = "Black";
            })

            Library:AddToRegistry(DividerInner, {
                BackgroundColor3 = "MainColor";
                BorderColor3 = "OutlineColor";
            })
        end

        Groupbox:AddBlank(MarginBottom)
        Groupbox:Resize()

        table.insert(Groupbox.Elements, {
            Holder = DividerOuter,
            Type = "Divider",
        })
    end

    function BaseGroupboxFuncs:AddLabel(...)
        local Data = {}

        if select(2, ...) ~= nil and typeof(select(2, ...)) == "table" then
            if select(1, ...) ~= nil then
                assert(typeof(select(1, ...)) == "string", "Expected string for Idx, got " .. typeof(select(1, ...)))
            end
            
            local Params = select(2, ...)

            Data.Text = Params.Text or ""
            Data.DoesWrap = Params.DoesWrap or false
            Data.Idx = select(1, ...)
        else
            Data.Text = select(1, ...) or ""
            Data.DoesWrap = select(2, ...) or false
            Data.Idx = select(3, ...) or nil
        end

        Data.OriginalText = Data.Text
        
        local Label = {
            Type = "Label"
        }

        -- local Blank = nil
        local Groupbox = self
        local Container = Groupbox.Container

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Data.Text;
            TextWrapped = Data.DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
            RichText = true;
        })

        if Data.DoesWrap then
            local Y = select(2, Library:GetTextBounds(Data.Text, Library.Font, 14 * DPIScale, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create("UIListLayout", {
                Padding = UDim.new(0, 4 * DPIScale);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            })
        end

        Label.TextLabel = TextLabel
        Label.Container = Container

        function Label:SetText(Text)
            TextLabel.Text = Text

            if Data.DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14 * DPIScale, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end

            Groupbox:Resize()
        end

        if (not Data.DoesWrap) then
            setmetatable(Label, BaseAddons)
        end

        -- Blank = 
        Groupbox:AddBlank(5)
        Groupbox:Resize()

        table.insert(Groupbox.Elements, Label)
        
        if Data.Idx then
            -- Options[Data.Idx] = Label;
            Labels[Data.Idx] = Label
        else
            table.insert(Labels, Label)
        end

        return Label
    end
    
    function BaseGroupboxFuncs:AddButton(...)
        local Button = typeof(select(1, ...)) == "table" and select(1, ...) or {
            Text = select(1, ...),
            Func = select(2, ...)
        }
        Button.OriginalText = Button.Text
        Button.Func = Button.Func or Button.Callback
        assert(typeof(Button.Func) == "function", "AddButton: `Func` callback is missing.")

        local Blank = nil
        local Groupbox = self
        local Container = Groupbox.Container
        local IsVisible = if typeof(Button.Visible) == "boolean" then Button.Visible else true

        local function CreateBaseButton(Button)
            local Outer = Library:Create("Frame", {
                BackgroundColor3 = Color3.new(0, 0, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, 20);
                Visible = IsVisible;
                ZIndex = 5;
            })

            local Inner = Library:Create("Frame", {
                BackgroundColor3 = Library.MainColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = Outer;
            })

            local Label = Library:CreateLabel({
                Size = UDim2.new(1, 0, 1, 0);
                TextSize = 14;
                Text = Button.Text;
                ZIndex = 6;
                Parent = Inner;
                RichText = true;
            })

            Library:Create("UIGradient", {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
                });
                Rotation = 90;
                Parent = Inner;
            })

            Library:AddToRegistry(Outer, {
                BorderColor3 = "Black";
            })

            Library:AddToRegistry(Inner, {
                BackgroundColor3 = "MainColor";
                BorderColor3 = "OutlineColor";
            })

            Library:OnHighlight(Outer, Outer,
                { BorderColor3 = "AccentColor" },
                { BorderColor3 = "Black" }
            )

            return Outer, Inner, Label
        end

        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new("BindableEvent")
                local connection = event:Once(function(...)

                    if typeof(validator) == "function" and validator(...) then
                        bindable:Fire(true)
                    else
                        bindable:Fire(false)
                    end
                end)
                task.delay(timeout, function()
                    connection:disconnect()
                    bindable:Fire(false)
                end)
                return bindable.Event:Wait()
            end

            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame(Input) then
                    return false
                end

                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    return true
                elseif Input.UserInputType == Enum.UserInputType.Touch then
                    return true
                else
                    return false
                end
            end

            Button.Outer.InputBegan:Connect(function(Input)
                if Button.Disabled then
                    return
                end

                if not ValidateClick(Input) then return end
                if Button.Locked then return end

                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = "AccentColor" })

                    Button.Label.TextColor3 = Library.AccentColor
                    Button.Label.Text = "Are you sure?"
                    Button.Locked = true

                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)

                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = "FontColor" })

                    Button.Label.TextColor3 = Library.FontColor
                    Button.Label.Text = Button.Text
                    task.defer(rawset, Button, "Locked", false)

                    if clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    return
                end

                Library:SafeCallback(Button.Func)
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container

        InitEvents(Button)

        function Button:AddButton(...)
            local SubButton = typeof(select(1, ...)) == "table" and select(1, ...) or {
                Text = select(1, ...),
                Func = select(2, ...)
            }
            SubButton.OriginalText = SubButton.Text
            SubButton.Func = SubButton.Func or SubButton.Callback
            assert(typeof(SubButton.Func) == "function", "AddButton: `Func` callback is missing.")

            self.Outer.Size = UDim2.new(0.5, -2, 0, 20 * DPIScale)

            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)

            SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.new(1, -3, 0, self.Outer.AbsoluteSize.Y)
            SubButton.Outer.Parent = self.Outer

            function SubButton:UpdateColors()
                SubButton.Label.TextColor3 = SubButton.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
            end

            function SubButton:AddToolTip(tooltip, disabledTooltip)
                if typeof(tooltip) == "string" or typeof(disabledTooltip) == "string" then
                    if SubButton.TooltipTable then
                        SubButton.TooltipTable:Destroy()
                    end
                
                    SubButton.TooltipTable = Library:AddToolTip(tooltip, disabledTooltip, self.Outer)
                    SubButton.TooltipTable.Disabled = SubButton.Disabled
                end

                return SubButton
            end

            function SubButton:SetDisabled(Disabled)
                SubButton.Disabled = Disabled

                if SubButton.TooltipTable then
                    SubButton.TooltipTable.Disabled = Disabled
                end

                SubButton:UpdateColors()
            end

            function SubButton:SetText(Text)
                if typeof(Text) == "string" then
                    SubButton.Text = Text
                    SubButton.Label.Text = SubButton.Text
                end
            end

            if typeof(SubButton.Tooltip) == "string" or typeof(SubButton.DisabledTooltip) == "string" then
                SubButton.TooltipTable = SubButton:AddToolTip(SubButton.Tooltip, SubButton.DisabledTooltip, SubButton.Outer)
                SubButton.TooltipTable.Disabled = SubButton.Disabled
            end

            task.delay(0.1, SubButton.UpdateColors, SubButton)
            InitEvents(SubButton)

            table.insert(Buttons, SubButton)
            return SubButton
        end

        function Button:UpdateColors()
            Button.Label.TextColor3 = Button.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
        end

        function Button:AddToolTip(tooltip, disabledTooltip)
            if typeof(tooltip) == "string" or typeof(disabledTooltip) == "string" then
                if Button.TooltipTable then
                    Button.TooltipTable:Destroy()
                end

                Button.TooltipTable = Library:AddToolTip(tooltip, disabledTooltip, self.Outer)
                Button.TooltipTable.Disabled = Button.Disabled
            end

            return Button
        end

        if typeof(Button.Tooltip) == "string" or typeof(Button.DisabledTooltip) == "string" then
            Button.TooltipTable = Button:AddToolTip(Button.Tooltip, Button.DisabledTooltip, Button.Outer)
            Button.TooltipTable.Disabled = Button.Disabled
        end

        function Button:SetVisible(Visibility)
            IsVisible = Visibility

            Button.Outer.Visible = IsVisible
            if Blank then Blank.Visible = IsVisible end

            Groupbox:Resize()
        end

        function Button:SetText(Text)
            if typeof(Text) == "string" then
                Button.Text = Text
                Button.Label.Text = Button.Text
            end
        end

        function Button:SetDisabled(Disabled)
            Button.Disabled = Disabled

            if Button.TooltipTable then
                Button.TooltipTable.Disabled = Disabled
            end

            Button:UpdateColors()
        end

        task.delay(0.1, Button.UpdateColors, Button)
        Blank = Groupbox:AddBlank(5, IsVisible)
        Groupbox:Resize()

        table.insert(Groupbox.Elements, Button)
        table.insert(Buttons, Button)

        return Button
    end

    function BaseGroupboxFuncs:AddInput(Idx, Info)
        assert(Info.Text, string.format("AddInput (IDX: %s): Missing `Text` string.", tostring(Idx)))

        Info.ClearTextOnFocus = if typeof(Info.ClearTextOnFocus) == "boolean" then Info.ClearTextOnFocus else true

        local Textbox = {
            Value = Info.Default or "";
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Visible = if typeof(Info.Visible) == "boolean" then Info.Visible else true;
            Disabled = if typeof(Info.Disabled) == "boolean" then Info.Disabled else false;
            AllowEmpty = if typeof(Info.AllowEmpty) == "boolean" then Info.AllowEmpty else true;
            EmptyReset = if typeof(Info.EmptyReset) == "string" then Info.EmptyReset else "---";
            Type = "Input";

            Callback = Info.Callback or function(Value) end;
        }

        local Groupbox = self
        local Container = Groupbox.Container
        local Blank

        local InputLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 15);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        })

        Groupbox:AddBlank(1)

        local TextBoxOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        })

        local TextBoxInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = TextBoxOuter;
        })

        Library:AddToRegistry(TextBoxInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        Library:OnHighlight(TextBoxOuter, TextBoxOuter,
            { BorderColor3 = "AccentColor" },
            { BorderColor3 = "Black" }
        )

        local TooltipTable
        if typeof(Info.Tooltip) == "string" or typeof(Info.DisabledTooltip) == "string" then
            TooltipTable = Library:AddToolTip(Info.Tooltip, Info.DisabledTooltip, TextBoxOuter)
            TooltipTable.Disabled = Textbox.Disabled
        end

        Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = TextBoxInner;
        })

        local TextBoxContainer = Library:Create("Frame", {
            BackgroundTransparency = 1;
            ClipsDescendants = true;

            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);

            ZIndex = 7;
            Parent = TextBoxInner;
        })

        local Box = Library:Create("TextBox", {
            BackgroundTransparency = 1;

            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(5, 1),

            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = Info.Placeholder or "";

            Text = Info.Default or (if Textbox.AllowEmpty == false then Textbox.EmptyReset else "---");
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;

            TextEditable = not Textbox.Disabled;
            ClearTextOnFocus = not Textbox.Disabled and Info.ClearTextOnFocus;

            ZIndex = 7;
            Parent = TextBoxContainer;
        })

        Library:ApplyTextStroke(Box)

        Library:AddToRegistry(Box, {
            TextColor3 = "FontColor";
        })

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func

            -- if Textbox.Disabled then
            --     return;
            -- end;

            -- Library:SafeCallback(Func, Textbox.Value);
        end

        function Textbox:UpdateColors()
            Box.TextColor3 = Textbox.Disabled and Library.DisabledAccentColor or Library.FontColor

            Library.RegistryMap[Box].Properties.TextColor3 = Textbox.Disabled and "DisabledAccentColor" or "FontColor"
        end

        function Textbox:Display()
            TextBoxOuter.Visible = Textbox.Visible
            InputLabel.Visible = Textbox.Visible
            if Blank then Blank.Visible = Textbox.Visible end

            Groupbox:Resize()
        end

        function Textbox:SetValue(Text)
            if not Textbox.AllowEmpty and Trim(Text) == "" then
                Text = Textbox.EmptyReset
            end

            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength)
            end

            if Textbox.Numeric then
                if #tostring(Text) > 0 and not tonumber(Text) then
                    Text = Textbox.Value
                end
            end

            Textbox.Value = Text
            Box.Text = Text

            if not Textbox.Disabled then
                Library:SafeCallback(Textbox.Callback, Textbox.Value)
                Library:SafeCallback(Textbox.Changed, Textbox.Value)
            end
        end

        function Textbox:SetVisible(Visibility)
            Textbox.Visible = Visibility

            Textbox:Display()
        end

        function Textbox:SetDisabled(Disabled)
            Textbox.Disabled = Disabled

            Box.TextEditable = not Disabled
            Box.ClearTextOnFocus = not Disabled and Info.ClearTextOnFocus

            if TooltipTable then
                TooltipTable.Disabled = Disabled
            end

            Textbox:UpdateColors()
        end

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end

                Textbox:SetValue(Box.Text)
                Library:AttemptSave()
            end)
        else
            Box:GetPropertyChangedSignal("Text"):Connect(function()
                Textbox:SetValue(Box.Text)
                Library:AttemptSave()
            end)
        end

        
        -- thank you nicemike40 :)

        local function Update()
            local PADDING = 2
            local reveal = TextBoxContainer.AbsoluteSize.X

            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
                -- we aren't focused, or we fit so be normal
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                -- we are focused and don't fit, so adjust position
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    -- calculate pixel width of text from start to cursor
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X

                    -- check if we're inside the box with the cursor
                    local currentCursorPos = Box.Position.X.Offset + width

                    -- adjust if necessary
                    if currentCursorPos < PADDING then
                        Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then
                        Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
                    end
                end
            end
        end

        task.spawn(Update)

        Box:GetPropertyChangedSignal("Text"):Connect(Update)
        Box:GetPropertyChangedSignal("CursorPosition"):Connect(Update)
        Box.FocusLost:Connect(Update)
        Box.Focused:Connect(Update)

        Blank = Groupbox:AddBlank(5, Textbox.Visible)
        task.delay(0.1, Textbox.UpdateColors, Textbox)
        Textbox:Display()
        Groupbox:Resize()

        Textbox.Default = Textbox.Value

        table.insert(Groupbox.Elements, Textbox)
        Options[Idx] = Textbox

        return Textbox
    end

    function BaseGroupboxFuncs:AddToggle(Idx, Info)
        assert(Info.Text, string.format("AddInput (IDX: %s): Missing `Text` string.", tostring(Idx)))

        local Toggle = {
            Value = Info.Default or false;
            Type = "Toggle";
            Visible = if typeof(Info.Visible) == "boolean" then Info.Visible else true;
            Disabled = if typeof(Info.Disabled) == "boolean" then Info.Disabled else false;
            Risky = if typeof(Info.Risky) == "boolean" then Info.Risky else false;
            OriginalText = Info.Text; Text = Info.Text;

            Callback = Info.Callback or function(Value) end;
            Addons = {};
        }

        local Blank
        local Tooltip
        local Groupbox = self
        local Container = Groupbox.Container

        local ToggleContainer = Library:Create("Frame", {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, -4, 0, 13);
            Visible = Toggle.Visible;
            ZIndex = 5;
            Parent = Container;
        })

        local ToggleOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 13, 0, 13);
            Visible = Toggle.Visible;
            ZIndex = 5;
            Parent = ToggleContainer;
        })

        Library:AddToRegistry(ToggleOuter, {
            BorderColor3 = "Black";
        })

        local ToggleInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = ToggleOuter;
        })

        Library:AddToRegistry(ToggleInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(1, -19, 0, 11); -- size of toggle box (13) + size offset of previous layout (6)
            Position = UDim2.new(0, 19, 0, 0);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = ToggleContainer;
            RichText = true;
        })

        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 4);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        })

        local ToggleRegion = Library:Create("Frame", {
            BackgroundTransparency = 1;
            Size = UDim2.new(0, 170, 1, 0);
            ZIndex = 8;
            Parent = ToggleOuter;
        })

        Library:OnHighlight(ToggleRegion, ToggleOuter,
            { BorderColor3 = "AccentColor" },
            { BorderColor3 = "Black" },
            function()
                if Toggle.Disabled then
                    return false
                end

                for _, Addon in next, Toggle.Addons do
                    if Library:MouseIsOverFrame(Addon.DisplayFrame) then return false end
                end
                return true
            end
        )

        function Toggle:UpdateColors()
            Toggle:Display()
        end

        if typeof(Info.Tooltip) == "string" or typeof(Info.DisabledTooltip) == "string" then
            Tooltip = Library:AddToolTip(Info.Tooltip, Info.DisabledTooltip, ToggleRegion)
            Tooltip.Disabled = Toggle.Disabled
        end

        function Toggle:Display()
            if Toggle.Disabled then
                ToggleLabel.TextColor3 = Library.DisabledTextColor

                ToggleInner.BackgroundColor3 = Toggle.Value and Library.DisabledAccentColor or Library.MainColor
                ToggleInner.BorderColor3 = Library.DisabledOutlineColor

                Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and "DisabledAccentColor" or "MainColor"
                Library.RegistryMap[ToggleInner].Properties.BorderColor3 = "DisabledOutlineColor"
                Library.RegistryMap[ToggleLabel].Properties.TextColor3 = "DisabledTextColor"

                return
            end

            ToggleLabel.TextColor3 = Toggle.Risky and Library.RiskColor or Color3.new(1, 1, 1)

            ToggleInner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor
            ToggleInner.BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor

            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and "AccentColor" or "MainColor"
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and "AccentColorDark" or "OutlineColor"

            Library.RegistryMap[ToggleLabel].Properties.TextColor3 = Toggle.Risky and "RiskColor" or nil
        end

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func

            -- if Toggle.Disabled then
            --     return;
            -- end;

            -- Library:SafeCallback(Func, Toggle.Value);
        end

        function Toggle:SetValue(Bool)
            if Toggle.Disabled then
                return
            end

            Bool = (not not Bool)

            Toggle.Value = Bool
            Toggle:Display()

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == "KeyPicker" and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end

            if not Toggle.Disabled then
                Library:SafeCallback(Toggle.Callback, Toggle.Value)
                Library:SafeCallback(Toggle.Changed, Toggle.Value)
            end

            Library:UpdateDependencyBoxes()
            Library:UpdateDependencyGroupboxes()
        end

        function Toggle:SetVisible(Visibility)
            Toggle.Visible = Visibility

            ToggleOuter.Visible = Toggle.Visible
            if Blank then Blank.Visible = Toggle.Visible end

            Groupbox:Resize()
        end

        function Toggle:SetDisabled(Disabled)
            Toggle.Disabled = Disabled

            if Tooltip then
                Tooltip.Disabled = Disabled
            end

            Toggle:Display()
        end

        function Toggle:SetText(Text)
            if typeof(Text) == "string" then
                Toggle.Text = Text
                ToggleLabel.Text = Toggle.Text
            end
        end

        ToggleRegion.InputBegan:Connect(function(Input)
            if Toggle.Disabled then
                return
            end

            if (Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType == Enum.UserInputType.Touch then
                for _, Addon in next, Toggle.Addons do
                    if Library:MouseIsOverFrame(Addon.DisplayFrame) then return end
                end

                Toggle:SetValue(not Toggle.Value) -- Why was it not like this from the start?
                Library:AttemptSave()
            end
        end)

        if Toggle.Risky == true then
            Library:RemoveFromRegistry(ToggleLabel)

            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = "RiskColor" })
        end

        Toggle:Display()
        Blank = Groupbox:AddBlank(Info.BlankSize or 5 + 2, Toggle.Visible)
        Groupbox:Resize()

        Toggle.TextLabel = ToggleLabel
        Toggle.Container = Container
        setmetatable(Toggle, BaseAddons)

        Toggle.Default = Toggle.Value

        table.insert(Groupbox.Elements, Toggle)
        Toggles[Idx] = Toggle

        Library:UpdateDependencyBoxes()
        Library:UpdateDependencyGroupboxes()

        return Toggle
    end

    function BaseGroupboxFuncs:AddSlider(Idx, Info)
        assert(Info.Default,    string.format("AddSlider (IDX: %s): Missing default value.", tostring(Idx)))
        assert(Info.Text,       string.format("AddSlider (IDX: %s): Missing slider text.", tostring(Idx)))
        assert(Info.Min,        string.format("AddSlider (IDX: %s): Missing minimum value.", tostring(Idx)))
        assert(Info.Max,        string.format("AddSlider (IDX: %s): Missing maximum value.", tostring(Idx)))
        assert(Info.Rounding,   string.format("AddSlider (IDX: %s): Missing rounding value.", tostring(Idx)))

        local Slider = {
            Value = Info.Default;

            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            MaxSize = 232;
            Type = "Slider";
            Visible = if typeof(Info.Visible) == "boolean" then Info.Visible else true;
            Disabled = if typeof(Info.Disabled) == "boolean" then Info.Disabled else false;
            OriginalText = Info.Text; Text = Info.Text;

            Prefix = typeof(Info.Prefix) == "string" and Info.Prefix or "";
            Suffix = typeof(Info.Suffix) == "string" and Info.Suffix or "";

            Callback = Info.Callback or function(Value) end;
        }

        local Blanks = {}
        local SliderText = nil
        local Groupbox = self
        local Container = Groupbox.Container
        local Tooltip

        if not Info.Compact then
            SliderText = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                Visible = Slider.Visible;
                ZIndex = 5;
                Parent = Container;
                RichText = true;
            })

            table.insert(Blanks, Groupbox:AddBlank(3, Slider.Visible))
        end

        local SliderOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 13);
            Visible = Slider.Visible;
            ZIndex = 5;
            Parent = Container;
        })

        SliderOuter:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            Slider.MaxSize = SliderOuter.AbsoluteSize.X - 2
        end)

        Library:AddToRegistry(SliderOuter, {
            BorderColor3 = "Black";
        })

        local SliderInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = SliderOuter;
        })

        Library:AddToRegistry(SliderInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        local Fill = Library:Create("Frame", {
            BackgroundColor3 = Library.AccentColor;
            BorderColor3 = Library.AccentColorDark;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = SliderInner;
        })

        Library:AddToRegistry(Fill, {
            BackgroundColor3 = "AccentColor";
            BorderColor3 = "AccentColorDark";
        })

        local HideBorderRight = Library:Create("Frame", {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(1, 0, 0, 0);
            Size = UDim2.new(0, 1, 1, 0);
            ZIndex = 8;
            Parent = Fill;
        })

        Library:AddToRegistry(HideBorderRight, {
            BackgroundColor3 = "AccentColor";
        })

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 14;
            Text = "Infinite";
            ZIndex = 9;
            Parent = SliderInner;
            RichText = true;
        })

        Library:OnHighlight(SliderOuter, SliderOuter,
            { BorderColor3 = "AccentColor" },
            { BorderColor3 = "Black" },
            function()
                return not Slider.Disabled
            end
        )

        if typeof(Info.Tooltip) == "string" or typeof(Info.DisabledTooltip) == "string" then
            Tooltip = Library:AddToolTip(Info.Tooltip, Info.DisabledTooltip, SliderOuter)
            Tooltip.Disabled = Slider.Disabled
        end

        function Slider:UpdateColors()
            if SliderText then
                SliderText.TextColor3 = Slider.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
            end
            DisplayLabel.TextColor3 = Slider.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)

            HideBorderRight.BackgroundColor3 = Slider.Disabled and Library.DisabledAccentColor or Library.AccentColor

            Fill.BackgroundColor3 = Slider.Disabled and Library.DisabledAccentColor or Library.AccentColor
            Fill.BorderColor3 = Slider.Disabled and Library.DisabledOutlineColor or Library.AccentColorDark

            Library.RegistryMap[HideBorderRight].Properties.BackgroundColor3 = Slider.Disabled and "DisabledAccentColor" or "AccentColor"

            Library.RegistryMap[Fill].Properties.BackgroundColor3 = Slider.Disabled and "DisabledAccentColor" or "AccentColor"
            Library.RegistryMap[Fill].Properties.BorderColor3 = Slider.Disabled and "DisabledOutlineColor" or "AccentColorDark"
        end
        
        function Slider:Display()
            local CustomDisplayText = nil
            if Info.FormatDisplayValue then
                CustomDisplayText = Info.FormatDisplayValue(Slider, Slider.Value)
            end

            if CustomDisplayText then
                DisplayLabel.Text = tostring(CustomDisplayText)
            else
                local FormattedValue = (Slider.Value == 0 or Slider.Value == -0) and "0" or tostring(Slider.Value)
                if Info.Compact then
                    DisplayLabel.Text = string.format("%s: %s%s%s", Slider.Text, Slider.Prefix, FormattedValue, Slider.Suffix)

                elseif Info.HideMax then
                    DisplayLabel.Text = string.format("%s%s%s", Slider.Prefix, FormattedValue, Slider.Suffix)

                else
                    DisplayLabel.Text = string.format("%s%s%s/%s%s%s", 
                        Slider.Prefix, FormattedValue, Slider.Suffix,
                        Slider.Prefix, tostring(Slider.Max), Slider.Suffix)
                end
            end

            local X = Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, 1)
            Fill.Size = UDim2.new(X, 0, 1, 0)

            -- I have no idea what this is
            HideBorderRight.Visible = not (X == 1 or X == 0)
        end

        function Slider:OnChanged(Func)
            Slider.Changed = Func

            -- if Slider.Disabled then
            --     return;
            -- end;
            
            -- Library:SafeCallback(Func, Slider.Value);
        end

        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value)
            end

            return tonumber(string.format("%." .. Slider.Rounding .. "f", Value))
        end

        function Slider:GetValueFromXScale(X)
            return Round(Library:MapValue(X, 0, 1, Slider.Min, Slider.Max))
        end
        
        function Slider:SetMax(Value)
            assert(Value > Slider.Min, "Max value cannot be less than the current min value.")
            
            Slider.Value = math.clamp(Slider.Value, Slider.Min, Value)
            Slider.Max = Value
            Slider:Display()
        end
        
        function Slider:SetMin(Value)
            assert(Value < Slider.Max, "Min value cannot be greater than the current max value.")

            Slider.Value = math.clamp(Slider.Value, Value, Slider.Max)
            Slider.Min = Value
            Slider:Display()
        end

        function Slider:SetValue(Str)
            if Slider.Disabled then
                return
            end

            local Num = tonumber(Str)

            if (not Num) then
                return
            end

            Num = math.clamp(Num, Slider.Min, Slider.Max)

            Slider.Value = Num
            Slider:Display()

            if not Slider.Disabled then
                Library:SafeCallback(Slider.Callback, Slider.Value)
                Library:SafeCallback(Slider.Changed, Slider.Value)
            end
        end

        function Slider:SetVisible(Visibility)
            Slider.Visible = Visibility

            if SliderText then SliderText.Visible = Slider.Visible end
            SliderOuter.Visible = Slider.Visible

            for _, Blank in pairs(Blanks) do
                Blank.Visible = Slider.Visible
            end

            Groupbox:Resize()
        end

        function Slider:SetDisabled(Disabled)
            Slider.Disabled = Disabled

            if Tooltip then
                Tooltip.Disabled = Disabled
            end

            Slider:UpdateColors()
        end

        function Slider:SetText(Text)
            if typeof(Text) == "string" then
                Slider.Text = Text

                if SliderText then SliderText.Text = Slider.Text end
                Slider:Display()
            end
        end

        function Slider:SetPrefix(Prefix)
            if typeof(Prefix) == "string" then
                Slider.Prefix = Prefix
                Slider:Display()
            end
        end

        function Slider:SetSuffix(Suffix)
            if typeof(Suffix) == "string" then
                Slider.Suffix = Suffix
                Slider:Display()
            end
        end

        SliderInner.InputBegan:Connect(function(Input)
            if Slider.Disabled then
                return
            end

            if (Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType == Enum.UserInputType.Touch then
                if Library.IsMobile then
                    Library.CanDrag = false
                end

                local Sides = {}
                if Library.Window then
                    Sides = Library.Window.Tabs[Library.ActiveTab]:GetSides()
                end

                for _, Side in pairs(Sides) do
                    if typeof(Side) == "Instance" then
                        if Side:IsA("ScrollingFrame") then
                            Side.ScrollingEnabled = false
                        end
                    end
                end

                local mPos = Mouse.X
                local gPos = Fill.AbsoluteSize.X
                local Diff = mPos - (Fill.AbsolutePosition.X + gPos)

                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1 or Enum.UserInputType.Touch) do
                    local nMPos = Mouse.X
                    local nXOffset = math.clamp(gPos + (nMPos - mPos) + Diff, 0, Slider.MaxSize) -- what in tarnation are these variable names
                    local nXScale = Library:MapValue(nXOffset, 0, Slider.MaxSize, 0, 1)

                    local nValue = Slider:GetValueFromXScale(nXScale)
                    local OldValue = Slider.Value
                    Slider.Value = nValue

                    Slider:Display()

                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value)
                        Library:SafeCallback(Slider.Changed, Slider.Value)
                    end

                    RunService.RenderStepped:Wait()
                end

                if Library.IsMobile then
                    Library.CanDrag = true
                end
                
                for _, Side in pairs(Sides) do
                    if typeof(Side) == "Instance" then
                        if Side:IsA("ScrollingFrame") then
                            Side.ScrollingEnabled = true
                        end
                    end
                end

                Library:AttemptSave()
            end
        end)

        task.delay(0.1, Slider.UpdateColors, Slider)
        Slider:Display()
        table.insert(Blanks, Groupbox:AddBlank(Info.BlankSize or 6, Slider.Visible))
        Groupbox:Resize()

        Slider.Default = Slider.Value

        table.insert(Groupbox.Elements, Slider)
        Options[Idx] = Slider

        return Slider
    end

    function BaseGroupboxFuncs:AddDropdown(Idx, Info)
        Info.ReturnInstanceInstead = if typeof(Info.ReturnInstanceInstead) == "boolean" then Info.ReturnInstanceInstead else false

        if Info.SpecialType == "Player" then
            Info.ExcludeLocalPlayer = if typeof(Info.ExcludeLocalPlayer) == "boolean" then Info.ExcludeLocalPlayer else false

            Info.Values = GetPlayers(Info.ExcludeLocalPlayer, Info.ReturnInstanceInstead)
            Info.AllowNull = true
        elseif Info.SpecialType == "Team" then
            Info.Values = GetTeams(Info.ReturnInstanceInstead)
            Info.AllowNull = true
        end

        assert(Info.Values, string.format("AddDropdown (IDX: %s): Missing dropdown value list.", tostring(Idx)))
        if not (Info.AllowNull or Info.Default) then
            Info.Default = 1
            warn(string.format("AddDropdown (IDX: %s): Missing default value, selected the first index instead. Pass `AllowNull` as true if this was intentional.", tostring(Idx)))
        end
        
        Info.Searchable = if typeof(Info.Searchable) == "boolean" then Info.Searchable else false
        Info.FormatDisplayValue = if typeof(Info.FormatDisplayValue) == "function" then Info.FormatDisplayValue else nil
        Info.FormatListValue = if typeof(Info.FormatListValue) == "function" then Info.FormatListValue else nil

        if (not Info.Text) then
            Info.Compact = true
        end

        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            DisabledValues = Info.DisabledValues or {};

            Multi = Info.Multi;
            Type = "Dropdown";
            SpecialType = Info.SpecialType; -- can be either "Player" or "Team"
            Visible = if typeof(Info.Visible) == "boolean" then Info.Visible else true;
            Disabled = if typeof(Info.Disabled) == "boolean" then Info.Disabled else false;
            Callback = Info.Callback or function(Value) end;
            Changed = Info.Changed or function(Value) end;

            OriginalText = Info.Text; Text = Info.Text;
            ExcludeLocalPlayer = Info.ExcludeLocalPlayer;
            ReturnInstanceInstead = Info.ReturnInstanceInstead;
        }

        local DropdownLabel
        local Blank
        local CompactBlank
        local Tooltip
        local Groupbox = self
        local Container = Groupbox.Container

        local RelativeOffset = 0

        if not Info.Compact then
            DropdownLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                Visible = Dropdown.Visible;
                ZIndex = 5;
                Parent = Container;
                RichText = true;
            })

            CompactBlank = Groupbox:AddBlank(3, Dropdown.Visible)
        end

        for _, Element in next, Container:GetChildren() do
            if not Element:IsA("UIListLayout") then
                RelativeOffset = RelativeOffset + Element.Size.Y.Offset
            end
        end

        local DropdownOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20);
            Visible = Dropdown.Visible;
            ZIndex = 5;
            Parent = Container;
        })

        Library:AddToRegistry(DropdownOuter, {
            BorderColor3 = "Black";
        })

        local DropdownInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DropdownOuter;
        })

        Library:AddToRegistry(DropdownInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = DropdownInner;
        })

        local DropdownInnerSearch
        if Info.Searchable then
            DropdownInnerSearch = Library:Create("TextBox", {
                BackgroundTransparency = 1;
                Visible = false;

                Position = UDim2.new(0, 5, 0, 0);
                Size = UDim2.new(0.9, -5, 1, 0);

                Font = Library.Font;
                PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
                PlaceholderText = "Search...";

                Text = "";
                TextColor3 = Library.FontColor;
                TextSize = 14;
                TextStrokeTransparency = 0;
                TextXAlignment = Enum.TextXAlignment.Left;

                ClearTextOnFocus = false;

                ZIndex = 7;
                Parent = DropdownOuter;
            })

            Library:ApplyTextStroke(DropdownInnerSearch)

            Library:AddToRegistry(DropdownInnerSearch, {
                TextColor3 = "FontColor";
            })
        end

        local DropdownArrow = Library:Create("ImageLabel", {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = CustomImageManager.GetAsset("DropdownArrow");
            ZIndex = 8;
            Parent = DropdownInner;
        })

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            TextSize = 14;
            Text = "--";
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped = false;
            TextTruncate = Enum.TextTruncate.AtEnd;
            RichText = true;
            ZIndex = 7;
            Parent = DropdownInner;
        })

        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = "AccentColor" },
            { BorderColor3 = "Black" },
            function()
                return not Dropdown.Disabled
            end
        )

        if typeof(Info.Tooltip) == "string" or typeof(Info.DisabledTooltip) == "string" then
            Tooltip = Library:AddToolTip(Info.Tooltip, Info.DisabledTooltip, DropdownOuter)
            Tooltip.Disabled = Dropdown.Disabled
        end

        local MAX_DROPDOWN_ITEMS = if typeof(Info.MaxVisibleDropdownItems) == "number" then math.clamp(Info.MaxVisibleDropdownItems, 4, 16) else 8

        local ListOuter = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            ZIndex = 20;
            Visible = false;
            Parent = ScreenGui;
        })

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1)
        end

        local function RecalculateListSize(YSize)
            local Y = YSize or math.clamp(GetTableSize(Dropdown.Values) * (20 * DPIScale), 0, MAX_DROPDOWN_ITEMS * (20 * DPIScale)) + 1
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X + 0.5, Y)
        end

        RecalculateListPosition()
        RecalculateListSize()

        DropdownOuter:GetPropertyChangedSignal("AbsolutePosition"):Connect(RecalculateListPosition)

        local ListInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListOuter;
        })

        Library:AddToRegistry(ListInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        local Scrolling = Library:Create("ScrollingFrame", {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListInner;

            TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
            BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",

            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        })

        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = "AccentColor"
        })

        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        })

        function Dropdown:UpdateColors()
            if DropdownLabel then
                DropdownLabel.TextColor3 = Dropdown.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
            end

            ItemList.TextColor3 = Dropdown.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
            DropdownArrow.ImageColor3 = Dropdown.Disabled and Library.DisabledAccentColor or Color3.new(1, 1, 1)
        end

        function Dropdown:Display()
            local Values = Dropdown.Values
            local Str = ""

            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then
                        Str = Str .. tostring(Info.FormatDisplayValue and Info.FormatDisplayValue(Value) or Value) .. ", "
                    end
                end

                Str = Str:sub(1, #Str - 2)
                ItemList.Text = (Str == "" and "--" or Str)
            else
                if not Dropdown.Value then
                    ItemList.Text = "--"
                    return
                end

                ItemList.Text = tostring(Info.FormatDisplayValue and Info.FormatDisplayValue(Dropdown.Value) or Dropdown.Value)
            end
        end

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {}

                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value)
                end

                return T
            else
                return Dropdown.Value and 1 or 0
            end
        end

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values
            local DisabledValues = Dropdown.DisabledValues
            local Buttons = {}

            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA("UIListLayout") then
                    Element:Destroy()
                end
            end

            local Count = 0
            for Idx, Value in next, Values do
                local StringValue = tostring(Info.FormatListValue and Info.FormatListValue(Value) or Value)
                if Info.Searchable and not string.lower(StringValue):match(string.lower(DropdownInnerSearch.Text)) then
                    continue
                end

                local IsDisabled = table.find(DisabledValues, StringValue)
                local Table = {}

                Count = Count + 1

                local Button = Library:Create("TextButton", {
                    AutoButtonColor = false,
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Library.OutlineColor;
                    BorderMode = Enum.BorderMode.Middle;
                    Size = UDim2.new(1, -1, 0, 20);
                    Text = "";
                    ZIndex = 23;
                    Parent = Scrolling;
                })

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = "MainColor";
                    BorderColor3 = "OutlineColor";
                })

                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -6, 1, 0);
                    Position = UDim2.new(0, 6, 0, 0);
                    TextSize = 14;
                    Text = Info.FormatDisplayValue and tostring(Info.FormatDisplayValue(StringValue)) or StringValue;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    RichText = true;
                    ZIndex = 25;
                    Parent = Button;
                })

                Library:OnHighlight(Button, Button,
                    { BorderColor3 = IsDisabled and "DisabledAccentColor" or "AccentColor", ZIndex = 24 },
                    { BorderColor3 = "OutlineColor", ZIndex = 23 }
                )

                local Selected

                if Info.Multi then
                    Selected = Dropdown.Value[Value]
                else
                    Selected = Dropdown.Value == Value
                end

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value]
                    else
                        Selected = Dropdown.Value == Value
                    end

                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or (IsDisabled and Library.DisabledAccentColor or Library.FontColor)
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and "AccentColor" or (IsDisabled and "DisabledAccentColor" or "FontColor")
                end

                if not IsDisabled then
                    Button.MouseButton1Click:Connect(function(Input)
                        local Try = not Selected

                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try

                                if Selected then
                                    Dropdown.Value[Value] = true
                                else
                                    Dropdown.Value[Value] = nil
                                end
                            else
                                Selected = Try

                                if Selected then
                                    Dropdown.Value = Value
                                else
                                    Dropdown.Value = nil
                                end

                                for _, OtherButton in next, Buttons do
                                    OtherButton:UpdateButton()
                                end
                            end

                            Table:UpdateButton()
                            Dropdown:Display()
                            
                            Library:UpdateDependencyBoxes()
                            Library:UpdateDependencyGroupboxes()
                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value)

                            Library:AttemptSave()
                        end
                    end)
                end

                Table:UpdateButton()
                Dropdown:Display()

                Buttons[Button] = Table
            end

            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * (20 * DPIScale)) + 1)

            -- Workaround for silly roblox bug - not sure why it happens but sometimes the dropdown list will be empty
            -- ... and for some reason refreshing the Visible property fixes the issue??????? thanks roblox!
            Scrolling.Visible = false
            Scrolling.Visible = true

            local Y = math.clamp(Count * (20 * DPIScale), 0, MAX_DROPDOWN_ITEMS * (20 * DPIScale)) + 1
            RecalculateListSize(Y)
        end

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddValues(NewValues)
            if typeof(NewValues) == "table" then
                for _, val in pairs(NewValues) do
                    table.insert(Dropdown.Values, val)
                end
            elseif typeof(NewValues) == "string" then
                table.insert(Dropdown.Values, NewValues)
            else
                return
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetDisabledValues(NewValues)
            if NewValues then
                Dropdown.DisabledValues = NewValues
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddDisabledValues(DisabledValues)
            if typeof(DisabledValues) == "table" then
                for _, val in pairs(DisabledValues) do
                    table.insert(Dropdown.DisabledValues, val)
                end
            elseif typeof(DisabledValues) == "string" then
                table.insert(Dropdown.DisabledValues, DisabledValues)
            else
                return
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetVisible(Visibility)
            Dropdown.Visible = Visibility

            DropdownOuter.Visible = Dropdown.Visible
            if DropdownLabel then DropdownLabel.Visible = Dropdown.Visible end

            if Blank then Blank.Visible = Dropdown.Visible end
            if CompactBlank then CompactBlank.Visible = Dropdown.Visible end

            if not Dropdown.Visible then Dropdown:CloseDropdown() end

            Groupbox:Resize()
        end

        function Dropdown:SetDisabled(Disabled)
            Dropdown.Disabled = Disabled

            if Tooltip then
                Tooltip.Disabled = Disabled
            end

            if Disabled then
                Dropdown:CloseDropdown()
            end

            Dropdown:Display()
            Dropdown:UpdateColors()
        end

        function Dropdown:OpenDropdown()
            if Dropdown.Disabled then
                return
            end

            if Library.IsMobile then
                Library.CanDrag = false
            end

            if Info.Searchable then
                ItemList.Visible = false
                DropdownInnerSearch.Text = ""
                DropdownInnerSearch.Visible = true
            end

            ListOuter.Visible = true
            Library.OpenedFrames[ListOuter] = true
            DropdownArrow.Rotation = 180

            RecalculateListSize()
        end

        function Dropdown:CloseDropdown()
            if Library.IsMobile then            
                Library.CanDrag = true
            end

            if Info.Searchable then
                DropdownInnerSearch.Text = ""
                DropdownInnerSearch.Visible = false
                ItemList.Visible = true
            end

            ListOuter.Visible = false
            Library.OpenedFrames[ListOuter] = nil
            DropdownArrow.Rotation = 0
        end

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func

            -- if Dropdown.Disabled then
            --     return;
            -- end;

            -- Library:SafeCallback(Func, Dropdown.Value);
        end

        function Dropdown:SetValue(Value)
            if Dropdown.Multi then
                local Table = {}

                for Val, Active in pairs(Value or {}) do
                    if typeof(Active) ~= "boolean" then
                        Table[Active] = true
                    elseif Active and table.find(Dropdown.Values, Val) then
                        Table[Val] = true
                    end
                end

                Dropdown.Value = Table
            else
                if table.find(Dropdown.Values, Value) then
                    Dropdown.Value = Value
                elseif not Value then
                    Dropdown.Value = nil
                end
            end

            Dropdown:BuildDropdownList()

            if not Dropdown.Disabled then
                Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
            end
        end

        function Dropdown:SetText(Text)
            if typeof(Text) == "string" then
                if Info.Compact then Info.Compact = false end
                Dropdown.Text = Text

                if DropdownLabel then DropdownLabel.Text = Dropdown.Text end
                Dropdown:Display()
            end
        end

        DropdownOuter.InputBegan:Connect(function(Input)
            if Dropdown.Disabled then
                return
            end

            if (Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType == Enum.UserInputType.Touch then
                if ListOuter.Visible then
                    Dropdown:CloseDropdown()
                else
                    Dropdown:OpenDropdown()
                end
            end
        end)

        if Info.Searchable then
            DropdownInnerSearch:GetPropertyChangedSignal("Text"):Connect(function()
                Dropdown:BuildDropdownList()
            end)
        end

        InputService.InputBegan:Connect(function(Input)
            if Dropdown.Disabled then
                return
            end

            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - (20 * DPIScale) - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    Dropdown:CloseDropdown()
                end
            end
        end)

        Dropdown:BuildDropdownList()
        Dropdown:Display()

        local Defaults = {}

        if typeof(Info.Default) == "string" then
            local DefaultIdx = table.find(Dropdown.Values, Info.Default)
            if DefaultIdx then
                table.insert(Defaults, DefaultIdx)
            end
        elseif typeof(Info.Default) == "table" then
            for _, Value in next, Info.Default do
                local DefaultIdx = table.find(Dropdown.Values, Value)
                if DefaultIdx then
                    table.insert(Defaults, DefaultIdx)
                end
            end
        elseif typeof(Info.Default) == "number" and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index]
                end

                if (not Info.Multi) then break end
            end

            Dropdown:BuildDropdownList()
            Dropdown:Display()
        end

        task.delay(0.1, Dropdown.UpdateColors, Dropdown)
        Blank = Groupbox:AddBlank(Info.BlankSize or 5, Dropdown.Visible)
        Groupbox:Resize()

        Dropdown.Default = Defaults
        Dropdown.DefaultValues = Dropdown.Values

        table.insert(Groupbox.Elements, Dropdown)
        Options[Idx] = Dropdown

        return Dropdown
    end

    function BaseGroupboxFuncs:AddViewport(Idx, Info)
        local Dragging, Pinching = false, false
        local LastMousePos, LastPinchDist = nil, 0

        local Viewport = {
            Object = if Info.Clone then Info.Object:Clone() else Info.Object,
            Camera = if not Info.Camera then Instance.new("Camera") else Info.Camera,
            Interactive = Info.Interactive,
            AutoFocus = Info.AutoFocus,
            Height = if typeof(Info.Height) == "number" and Info.Height > 0 then Info.Height else 200,
            Visible = Info.Visible,
            Type = "Viewport",
        }

        assert(
            typeof(Viewport.Object) == "Instance" and (Viewport.Object:IsA("BasePart") or Viewport.Object:IsA("Model")),
            "Instance must be a BasePart or Model."
        )

        assert(
            typeof(Viewport.Camera) == "Instance" and Viewport.Camera:IsA("Camera"),
            "Camera must be a valid Camera instance."
        )

        local function GetModelSize(model)
            if model:IsA("BasePart") then
                return model.Size
            end

            return select(2, model:GetBoundingBox())
        end

        local function FocusCamera()
            local ModelSize = GetModelSize(Viewport.Object)
            local MaxExtent = math.max(ModelSize.X, ModelSize.Y, ModelSize.Z)
            local CameraDistance = MaxExtent * 2
            local ModelPosition = Viewport.Object:GetPivot().Position

            Viewport.Camera.CFrame =
                CFrame.new(ModelPosition + Vector3.new(0, MaxExtent / 2, CameraDistance), ModelPosition)
        end

        local Blank = nil
        local Groupbox = self
        local Container = Groupbox.Container

        local Holder = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -4, 0, Info.Height),
            Visible = Viewport.Visible,
            Parent = Container,
        })

        local Box = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            BorderSizePixel = 1,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 6,
            Parent = Holder,
        })

        Library:AddToRegistry(Box, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        Library:Create("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        local ViewportFrame = Library:Create("ViewportFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Parent = Box,
            CurrentCamera = Viewport.Camera,
            Active = Viewport.Interactive,
            ZIndex = 7
        })

        ViewportFrame.MouseEnter:Connect(function()
            if not Viewport.Interactive then
                return
            end
            
            for _, Side in pairs(Library.Window.Tabs[Library.ActiveTab]:GetSides()) do
                if typeof(Side) == "Instance" then
                    if Side:IsA("ScrollingFrame") then
                        Side.ScrollingEnabled = false
                    end
                end
            end
        end)

        ViewportFrame.MouseLeave:Connect(function()
            if not Viewport.Interactive then
                return
            end

            for _, Side in pairs(Library.Window.Tabs[Library.ActiveTab]:GetSides()) do
                if typeof(Side) == "Instance" then
                    if Side:IsA("ScrollingFrame") then
                        Side.ScrollingEnabled = true
                    end
                end
            end
        end)

        ViewportFrame.InputBegan:Connect(function(input)
            if not Viewport.Interactive then
                return
            end

            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                Dragging = true
                LastMousePos = input.Position
            elseif input.UserInputType == Enum.UserInputType.Touch and not Pinching then
                Dragging = true
                LastMousePos = input.Position
            end
        end)

        Library:GiveSignal(InputService.InputEnded:Connect(function(input)
            if Library.Unloaded then
                return
            end

            if not Viewport.Interactive then
                return
            end

            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                Dragging = false
            elseif input.UserInputType == Enum.UserInputType.Touch then
                Dragging = false
            end
        end))

        Library:GiveSignal(InputService.InputChanged:Connect(function(input)
            if Library.Unloaded then
                return
            end

            if not Viewport.Interactive or not Dragging or Pinching then
                return
            end

            if
                input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
            then
                local MouseDelta = input.Position - LastMousePos
                LastMousePos = input.Position

                local Position = Viewport.Object:GetPivot().Position
                local Camera = Viewport.Camera

                local RotationY = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), -MouseDelta.X * 0.01)
                Camera.CFrame = CFrame.new(Position) * RotationY * CFrame.new(-Position) * Camera.CFrame

                local RotationX = CFrame.fromAxisAngle(Camera.CFrame.RightVector, -MouseDelta.Y * 0.01)
                local PitchedCFrame = CFrame.new(Position) * RotationX * CFrame.new(-Position) * Camera.CFrame

                if PitchedCFrame.UpVector.Y > 0.1 then
                    Camera.CFrame = PitchedCFrame
                end
            end
        end))

        ViewportFrame.InputChanged:Connect(function(input)
            if not Viewport.Interactive then
                return
            end

            if input.UserInputType == Enum.UserInputType.MouseWheel then
                local ZoomAmount = input.Position.Z * 2
                Viewport.Camera.CFrame += Viewport.Camera.CFrame.LookVector * ZoomAmount
            end
        end)

        Library:GiveSignal(InputService.TouchPinch:Connect(function(touchPositions, scale, velocity, state)
            if Library.Unloaded then
                return
            end

            if not Viewport.Interactive or not Library:MouseIsOverFrame(ViewportFrame, touchPositions[1]) then
                return
            end

            if state == Enum.UserInputState.Begin then
                Pinching = true
                Dragging = false
                LastPinchDist = (touchPositions[1] - touchPositions[2]).Magnitude
            elseif state == Enum.UserInputState.Change then
                local currentDist = (touchPositions[1] - touchPositions[2]).Magnitude
                local delta = (currentDist - LastPinchDist) * 0.1
                LastPinchDist = currentDist
                Viewport.Camera.CFrame += Viewport.Camera.CFrame.LookVector * delta
            elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
                Pinching = false
            end
        end))

        Viewport.Object.Parent = ViewportFrame
        if Viewport.AutoFocus then
            FocusCamera()
        end

        function Viewport:SetObject(Object: Instance, Clone: boolean?)
            assert(Object, "Object cannot be nil.")

            if Clone then
                Object = Object:Clone()
            end

            if Viewport.Object then
                Viewport.Object:Destroy()
            end

            Viewport.Object = Object
            Viewport.Object.Parent = ViewportFrame

            Groupbox:Resize()
        end

        function Viewport:SetHeight(Height: number)
            assert(Height > 0, "Height must be greater than 0.")
            Viewport.Height = Height

            Holder.Size = UDim2.new(1, -4, 0, Viewport.Height)
            Groupbox:Resize()
        end

        function Viewport:Focus()
            if not Viewport.Object then
                return
            end

            FocusCamera()
        end

        function Viewport:SetCamera(Camera: Instance)
            assert(
                Camera and typeof(Camera) == "Instance" and Camera:IsA("Camera"),
                "Camera must be a valid Camera instance."
            )

            Viewport.Camera = Camera
            ViewportFrame.CurrentCamera = Camera
        end

        function Viewport:SetInteractive(Interactive: boolean)
            Viewport.Interactive = Interactive
            ViewportFrame.Active = Interactive
        end

        function Viewport:SetVisible(Visible: boolean)
            Viewport.Visible = Visible

            Holder.Visible = Viewport.Visible
            if Blank then Blank.Visible = Viewport.Visible end

            Groupbox:Resize()
        end

        Viewport:SetHeight(Viewport.Height)

        Blank = Groupbox:AddBlank(10, Viewport.Visible)
        Groupbox:Resize()

        Viewport.Holder = Holder
        Viewport.Container = Container

        table.insert(Groupbox.Elements, Viewport)
        Options[Idx] = Viewport

        Library:UpdateDependencyBoxes()
        Library:UpdateDependencyGroupboxes()

        return Viewport
    end

    function BaseGroupboxFuncs:AddImage(Idx, Info)
        local Image = {
            Image = Info.Image,
            Color = Info.Color,
            RectOffset = Info.RectOffset,
            RectSize = Info.RectSize,
            Height = if typeof(Info.Height) == "number" and Info.Height > 0 then Info.Height else 200,
            ScaleType = Info.ScaleType,
            Transparency = Info.Transparency,
            BackgroundTransparency = tonumber(Info.BackgroundTransparency) or 0,

            Visible = Info.Visible,
            Type = "Image",
        }

        local Blank = nil
        local Groupbox = self
        local Container = Groupbox.Container

        local Holder = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -4, 0, Info.Height),
            Visible = Image.Visible,
            Parent = Container,
        })

        local Box = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            BorderSizePixel = 1,
            BackgroundTransparency = Image.BackgroundTransparency,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 6,
            Parent = Holder,
        })

        Library:AddToRegistry(Box, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        Library:Create("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        local ImageProperties = {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = Image.Image,
            ImageTransparency = Image.Transparency,
            ImageColor3 = Image.Color,
            ImageRectOffset = Image.RectOffset,
            ImageRectSize = Image.RectSize,
            ScaleType = Image.ScaleType,
            ZIndex = 7,
            Parent = Box,
        }

        local Icon = Library:GetCustomIcon(ImageProperties.Image)
        assert(Icon, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

        ImageProperties.Image = Icon.Url
        ImageProperties.ImageRectOffset = Icon.ImageRectOffset
        ImageProperties.ImageRectSize = Icon.ImageRectSize

        local ImageLabel = Library:Create("ImageLabel", ImageProperties)

        function Image:SetHeight(Height: number)
            assert(Height > 0, "Height must be greater than 0.")
            Image.Height = Height

            Holder.Size = UDim2.new(1, -4, 0, Image.Height)
            Groupbox:Resize()
        end

        function Image:SetImage(NewImage: string)
            assert(typeof(NewImage) == "string", "Image must be a string.")

            local Icon = Library:GetCustomIcon(NewImage)
            assert(Icon, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

            NewImage = Icon.Url
            Image.RectOffset = Icon.ImageRectOffset
            Image.RectSize = Icon.ImageRectSize

            ImageLabel.Image = NewImage
            Image.Image = NewImage
        end

        function Image:SetColor(Color: Color3)
            assert(typeof(Color) == "Color3", "Color must be a Color3 value.")

            ImageLabel.ImageColor3 = Color
            Image.Color = Color
        end

        function Image:SetRectOffset(RectOffset: Vector2)
            assert(typeof(RectOffset) == "Vector2", "RectOffset must be a Vector2 value.")

            ImageLabel.ImageRectOffset = RectOffset
            Image.RectOffset = RectOffset
        end

        function Image:SetRectSize(RectSize: Vector2)
            assert(typeof(RectSize) == "Vector2", "RectSize must be a Vector2 value.")

            ImageLabel.ImageRectSize = RectSize
            Image.RectSize = RectSize
        end

        function Image:SetScaleType(ScaleType: Enum.ScaleType)
            assert(
                typeof(ScaleType) == "EnumItem" and ScaleType:IsA("ScaleType"),
                "ScaleType must be a valid Enum.ScaleType."
            )

            ImageLabel.ScaleType = ScaleType
            Image.ScaleType = ScaleType
        end

        function Image:SetTransparency(Transparency: number)
            assert(typeof(Transparency) == "number", "Transparency must be a number between 0 and 1.")
            assert(Transparency >= 0 and Transparency <= 1, "Transparency must be between 0 and 1.")

            ImageLabel.ImageTransparency = Transparency
            Image.Transparency = Transparency
        end

        function Image:SetVisible(Visible: boolean)
            Image.Visible = Visible

            Holder.Visible = Image.Visible
            if Blank then Blank.Visible = Image.Visible end

            Groupbox:Resize()
        end

        Image:SetHeight(Image.Height)

        Blank = Groupbox:AddBlank(10, Image.Visible)
        Groupbox:Resize()

        Image.Holder = Holder
        Image.Container = Container

        table.insert(Groupbox.Elements, Image)
        Options[Idx] = Image

        Library:UpdateDependencyBoxes()
        Library:UpdateDependencyGroupboxes()

        return Image
    end

    function BaseGroupboxFuncs:AddVideo(Idx, Info)
        Info = Library:Validate(Info, Templates.Video)

        local Blank = nil
        local Groupbox = self
        local Container = Groupbox.Container

        local Video = {
            Video = Info.Video,
            Looped = Info.Looped,
            Playing = Info.Playing,
            Volume = Info.Volume,
            Height = Info.Height,
            Visible = Info.Visible,

            Type = "Video",
        }

        local Holder = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -4, 0, Info.Height),
            Visible = Video.Visible,
            Parent = Container,
        })

        local Box = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            BorderSizePixel = 1,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 6,
            Parent = Holder,
        })

        Library:AddToRegistry(Box, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        })

        Library:Create("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        local VideoFrameInstance = Library:Create("VideoFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Video = Video.Video,
            Looped = Video.Looped,
            Volume = Video.Volume,
            ZIndex = 7,
            Parent = Box,
        })

        VideoFrameInstance.Playing = Video.Playing

        function Video:SetHeight(Height: number)
            assert(Height > 0, "Height must be greater than 0.")

            Video.Height = Height
            Holder.Size = UDim2.new(1, -4, 0, Height)
            Groupbox:Resize()
        end

        function Video:SetVideo(NewVideo: string)
            assert(typeof(NewVideo) == "string", "Video must be a string.")

            VideoFrameInstance.Video = NewVideo
            Video.Video = NewVideo
        end

        function Video:SetLooped(Looped: boolean)
            assert(typeof(Looped) == "boolean", "Looped must be a boolean.")

            VideoFrameInstance.Looped = Looped
            Video.Looped = Looped
        end

        function Video:SetVolume(Volume: number)
            assert(typeof(Volume) == "number", "Volume must be a number between 0 and 10.")

            VideoFrameInstance.Volume = Volume
            Video.Volume = Volume
        end

        function Video:SetPlaying(Playing: boolean)
            assert(typeof(Playing) == "boolean", "Playing must be a boolean.")

            VideoFrameInstance.Playing = Playing
            Video.Playing = Playing
        end

        function Video:Play()
            VideoFrameInstance.Playing = true
            Video.Playing = true
        end

        function Video:Pause()
            VideoFrameInstance.Playing = false
            Video.Playing = false
        end

        function Video:SetVisible(Visible: boolean)
            Video.Visible = Visible

            Holder.Visible = Video.Visible
            if Blank then Blank.Visible = Video.Visible end

            Groupbox:Resize()
        end

        Video:SetHeight(Video.Height)

        Blank = Groupbox:AddBlank(10, Video.Visible)
        Groupbox:Resize()

        Video.Holder = Holder
        Video.Container = Container
        Video.VideoFrame = VideoFrameInstance

        table.insert(Groupbox.Elements, Video)
        Options[Idx] = Video

        Library:UpdateDependencyBoxes()
        Library:UpdateDependencyGroupboxes()

        return Video
    end

    function BaseGroupboxFuncs:AddUIPassthrough(Idx, Info)
        Info = Library:Validate(Info, Templates.UIPassthrough)

        local Blank = nil
        local Groupbox = self
        local Container = Groupbox.Container

        assert(Info.Instance, "Instance must be provided.")
        assert(
            typeof(Info.Instance) == "Instance" and Info.Instance:IsA("GuiBase2d"),
            "Instance must inherit from GuiBase2d."
        )
        assert(typeof(Info.Height) == "number" and Info.Height > 0, "Height must be a number greater than 0.")

        local Passthrough = {
            Instance = Info.Instance,
            Height = Info.Height,
            Visible = Info.Visible,

            Type = "UIPassthrough",
        }

        local Holder = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -4, 0, Info.Height),
            Visible = Passthrough.Visible,
            Parent = Container,
        })

        Passthrough.Instance.Parent = Holder
        pcall(function() Passthrough.Instance.ZIndex = 7 end)

        function Passthrough:SetHeight(Height: number)
            assert(typeof(Height) == "number" and Height > 0, "Height must be a number greater than 0.")

            Passthrough.Height = Height
            Holder.Size = UDim2.new(1, -4, 0, Height)
            Groupbox:Resize()
        end

        function Passthrough:SetInstance(Instance: Instance)
            assert(Instance, "Instance must be provided.")
            assert(
                typeof(Instance) == "Instance" and Instance:IsA("GuiBase2d"),
                "Instance must inherit from GuiBase2d."
            )

            if Passthrough.Instance then
                Passthrough.Instance.Parent = nil
            end

            Passthrough.Instance = Instance
            Passthrough.Instance.Parent = Holder
            pcall(function() Passthrough.Instance.ZIndex = 7 end)
        end

        function Passthrough:SetVisible(Visible: boolean)
            Passthrough.Visible = Visible

            Holder.Visible = Passthrough.Visible
            if Blank then Blank.Visible = Passthrough.Visible end

            Groupbox:Resize()
        end

        Passthrough:SetHeight(Passthrough.Height)

        Blank = Groupbox:AddBlank(10, Passthrough.Visible)
        Groupbox:Resize()

        Passthrough.Holder = Holder
        Passthrough.Container = Container

        table.insert(Groupbox.Elements, Passthrough)
        Options[Idx] = Passthrough

        Library:UpdateDependencyBoxes()
        Library:UpdateDependencyGroupboxes()

        return Passthrough
    end

    function BaseGroupboxFuncs:AddDependencyBox()
        local Depbox = {
            Elements = {};
            Dependencies = {};
            TableType = "DepBox";
        }

        local Groupbox = self
        local Container = Groupbox.Container

        local Holder = Library:Create("Frame", {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent = Container;
        })

        local Frame = Library:Create("Frame", {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = true;
            Parent = Holder;
        })

        local Layout = Library:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Frame;
        })

        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y)
            Groupbox:Resize()
        end

        Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Depbox:Resize()
        end)

        Holder:GetPropertyChangedSignal("Visible"):Connect(function()
            Depbox:Resize()
        end)

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1]
                local Value = Dependency[2]

                if if Elem.Multi then not table.find(Elem:GetActiveValues(), Value) else Elem.Value ~= Value then
                    Holder.Visible = false
                    Depbox:Resize()
                    return
                end
            end

            Holder.Visible = true
            Depbox:Resize()
        end

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(typeof(Dependency) == "table", "SetupDependencies: Dependency is not of type `table`.")
                assert(Dependency[1], "SetupDependencies: Dependency is missing element argument.")
                assert(Dependency[2] ~= nil, "SetupDependencies: Dependency is missing value argument.")
            end

            Depbox.Dependencies = Dependencies
            Depbox:Update()
        end

        Depbox.Container = Frame

        setmetatable(Depbox, BaseGroupbox)

        table.insert(Groupbox.Elements, Depbox)
        table.insert(Library.DependencyBoxes, Depbox)

        return Depbox
    end

    function BaseGroupboxFuncs:AddDependencyGroupbox()
        local ParentGroupbox = self
        local Tab = ParentGroupbox.Tab

        local DepGroupbox = {
            Elements = {};
            Dependencies = {};
            TableType = "DepGroupbox";
        }

        local BoxOuter = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 0, 507 + 2);
            ZIndex = 2;
            Parent = ParentGroupbox.Side == 1 and Tab.LeftSideFrame or Tab.RightSideFrame;
        })

        Library:AddToRegistry(BoxOuter, {
            BackgroundColor3 = "BackgroundColor";
            BorderColor3 = "OutlineColor";
        })

        local BoxInner = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Color3.new(0, 0, 0);
            -- BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, -2, 1, -2);
            Position = UDim2.new(0, 1, 0, 1);
            ZIndex = 4;
            Parent = BoxOuter;
        })

        Library:AddToRegistry(BoxInner, {
            BackgroundColor3 = "BackgroundColor";
        })

        local Highlight = Library:Create("Frame", {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 5;
            Parent = BoxInner;
        })

        Library:AddToRegistry(Highlight, {
            BackgroundColor3 = "AccentColor";
        })

        local Container = Library:Create("Frame", {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 4, 0, 10);
            Size = UDim2.new(1, -4, 1, -10);
            ZIndex = 1;
            Parent = BoxInner;
        })

        Library:Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Container;
        })

        function DepGroupbox:Resize()
            local Size = 0

            for _, Element in next, DepGroupbox.Container:GetChildren() do
                if (not Element:IsA("UIListLayout")) and Element.Visible then
                    Size = Size + Element.Size.Y.Offset
                end
            end

            BoxOuter.Size = UDim2.new(1, 0, 0, (10 * DPIScale + Size) + 2 + 2)
        end

        function DepGroupbox:Update()
            for _, Dependency in next, DepGroupbox.Dependencies do
                local Elem = Dependency[1]
                local Value = Dependency[2]

                if if Elem.Multi then not table.find(Elem:GetActiveValues(), Value) else Elem.Value ~= Value then
                    BoxOuter.Visible = false
                    DepGroupbox:Resize()
                    return
                end
            end

            BoxOuter.Visible = true
            DepGroupbox:Resize()
        end

        function DepGroupbox:SetupDependencies(Dependencies)
            for _, Dependency in pairs(Dependencies) do
                assert(typeof(Dependency) == "table", "Dependency should be a table.")
                assert(Dependency[1] ~= nil, "Dependency is missing element.")
                assert(Dependency[2] ~= nil, "Dependency is missing expected value.")
            end

            DepGroupbox.Dependencies = Dependencies
            DepGroupbox:Update()
        end

        DepGroupbox.Container = Container
        setmetatable(DepGroupbox, BaseGroupbox)

        DepGroupbox:Resize()

        table.insert(Tab.DependencyGroupboxes, DepGroupbox)
        table.insert(Library.DependencyGroupboxes, DepGroupbox)

        return DepGroupbox
    end

    BaseGroupbox.__index = BaseGroupboxFuncs
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return BaseGroupboxFuncs[Key](...)
    end
end

--// Keybinds UI \\--
do
    local KeybindOuter = Library:Create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5);
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 10, 0.5, 0);
        Size = UDim2.new(0, 210, 0, 20);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    })

    local KeybindInner = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = KeybindOuter;
    })

    Library:AddToRegistry(KeybindInner, {
        BackgroundColor3 = "MainColor";
        BorderColor3 = "OutlineColor";
    }, true)

    local ColorFrame = Library:Create("Frame", {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2);
        ZIndex = 102;
        Parent = KeybindInner;
    })

    Library:AddToRegistry(ColorFrame, {
        BackgroundColor3 = "AccentColor";
    }, true)

    local _KeybindLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 20);
        Position = UDim2.fromOffset(5, 2),
        TextXAlignment = Enum.TextXAlignment.Left,

        Text = "Keybinds";
        ZIndex = 104;
        Parent = KeybindInner;
    })
    Library:MakeDraggable(KeybindOuter)

    local KeybindContainer = Library:Create("Frame", {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -20);
        Position = UDim2.new(0, 0, 0, 20);
        ZIndex = 1;
        Parent = KeybindInner;
    })

    Library:Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = KeybindContainer;
    })

    Library:Create("UIPadding", {
        PaddingLeft = UDim.new(0, 5),
        Parent = KeybindContainer,
    })

    Library.KeybindFrame = KeybindOuter
    Library.KeybindContainer = KeybindContainer
    Library:MakeDraggable(KeybindOuter)
end

--// Watermark \\--
do
    local WatermarkOuter = Library:Create("Frame", {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, -25);
        Size = UDim2.new(0, 213, 0, 20);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    })

    local WatermarkInner = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 201;
        Parent = WatermarkOuter;
    })

    Library:AddToRegistry(WatermarkInner, {
        BorderColor3 = "AccentColor";
    })

    local InnerFrame = Library:Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 202;
        Parent = WatermarkInner;
    })

    local Gradient = Library:Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        });
        Rotation = -90;
        Parent = InnerFrame;
    })

    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            })
        end
    })

    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2.new(0, 5, 0, 0);
        Size = UDim2.new(1, -4, 1, 0);
        TextSize = 14;
        TextXAlignment = Enum.TextXAlignment.Left;
        RichText = true;
        ZIndex = 203;
        Parent = InnerFrame;
    })

    Library.Watermark = WatermarkOuter
    Library.WatermarkText = WatermarkLabel
    Library:MakeDraggable(Library.Watermark)

    function Library:SetWatermarkVisibility(Bool)
        Library.Watermark.Visible = Bool
    end

    function Library:SetWatermark(Text)
        local X, Y = Library:GetTextBounds(Text, Library.Font, 14)
        Library.Watermark.Size = UDim2.new(0, X + 15, 0, (Y * 1.5) + 3)
        Library:SetWatermarkVisibility(true)

        Library.WatermarkText.Text = Text
    end
end

--// Notifications \\--
do
    Library.LeftNotificationArea = Library:Create("Frame", {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 40);
        Size = UDim2.new(0, 300, 0, 200);
        ZIndex = 11000;
        Parent = ScreenGui;
    })

    Library:Create("UIListLayout", {
        Padding = UDim.new(0, 4);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.LeftNotificationArea;
    })


    Library.RightNotificationArea = Library:Create("Frame", {
        AnchorPoint = Vector2.new(1, 0);
        BackgroundTransparency = 1;
        Position = UDim2.new(1, 0, 0, 40);
        Size = UDim2.new(0, 300, 0, 200);
        ZIndex = 11000;
        Parent = ScreenGui;
    })

    Library:Create("UIListLayout", {
        Padding = UDim.new(0, 4);
        FillDirection = Enum.FillDirection.Vertical;
        HorizontalAlignment = Enum.HorizontalAlignment.Right;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.RightNotificationArea;
    })
        
    function Library:SetNotifySide(Side: string)
        Library.NotifySide = Side
    end

    function Library:Notify(...)
        local Data = {}
        local Info = select(1, ...)

        if typeof(Info) == "table" then
            Data.Title = Info.Title and tostring(Info.Title) or ""
            Data.Description = tostring(Info.Description)
            Data.Time = Info.Time or 5
            Data.SoundId = Info.SoundId
            Data.Steps = Info.Steps
            Data.Persist = Info.Persist
            Data.Icon = Info.Icon
            Data.IconColor = Info.IconColor
        else
            Data.Title = ""
            Data.Description = tostring(Info)
            Data.Time = select(2, ...) or 5
            Data.SoundId = select(3, ...)
        end
        Data.Destroyed = false

        local DeletedInstance = false
        local DeleteConnection = nil
        if typeof(Data.Time) == "Instance" then
            DeleteConnection = Data.Time.Destroying:Connect(function()
                DeletedInstance = true
                DeleteConnection:Disconnect()
                DeleteConnection = nil
            end)
        end

        local Side = string.lower(Library.NotifySide)
        local XSize, YSize = Library:GetTextBounds(Data.Description, Library.Font, 14)
        YSize = YSize + 7

        local NotifyOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 0, 0, YSize);
            ClipsDescendants = true;
            ZIndex = 11000;
            Visible = false;
            Name = "Notif";
            Parent = Side == "left" and Library.LeftNotificationArea or Library.RightNotificationArea;
        })

        local NotifyInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 11001;
            Parent = NotifyOuter;
        })

        Library:AddToRegistry(NotifyInner, {
            BackgroundColor3 = "MainColor";
            BorderColor3 = "OutlineColor";
        }, true)

        local InnerFrame = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Position = UDim2.new(0, 1, 0, 1);
            Size = UDim2.new(1, -2, 1, -2);
            ZIndex = 11002;
            Parent = NotifyInner;
        })

        local Gradient = Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
            Rotation = -90;
            Parent = InnerFrame;
        })

        Library:AddToRegistry(Gradient, {
            Color = function()
                return ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                    ColorSequenceKeypoint.new(1, Library.MainColor),
                })
            end
        })

        local ExtraWidth = 0
        local TextPosition = Side == "left" and UDim2.new(0, 4, 0, 0) or UDim2.new(1, -4, 0, 0)
        local TextSizeOffsetX = -4
        local TextSizeOffsetY = 0

        local IconLabel
        if Data.Icon then
            local ParsedIcon = Library:GetCustomIcon(Data.Icon)
            if ParsedIcon then
                ExtraWidth = ExtraWidth + 20
                TextSizeOffsetX = TextSizeOffsetX - 20
                TextSizeOffsetY = TextSizeOffsetY - 2

                if Side == "left" then
                    TextPosition = UDim2.new(0, 24, 0, 0)
                end

                IconLabel = Library:Create("ImageLabel", {
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = if Side == "left" then UDim2.new(0, 6, 0.5, 0) else UDim2.new(0, 4, 0.5, 0),
                    Size = UDim2.fromOffset(14, 14),
                    Image = ParsedIcon.Url,
                    ImageColor3 = Data.IconColor or Library.FontColor,
                    ImageRectOffset = ParsedIcon.ImageRectOffset,
                    ImageRectSize = ParsedIcon.ImageRectSize,
                    ZIndex = 11004,
                    Parent = InnerFrame,
                })
                
                if not Data.IconColor then
                    Library:AddToRegistry(IconLabel, {
                        ImageColor3 = "FontColor";
                    }, true)
                end
                
                if Side == "right" then
                    TextPosition = UDim2.new(1, -8, 0, 0)
                end
            end
        end

        local NotifyLabel = Library:CreateLabel({
            AnchorPoint = Side == "left" and Vector2.new(0, 0) or Vector2.new(1, 0);
            Position = TextPosition;
            Size = UDim2.new(1, TextSizeOffsetX, 1, TextSizeOffsetY);
            Text = (Data.Title == "" and "" or "[" .. Data.Title .. "] ") .. tostring(Data.Description);
            TextXAlignment = Side == "left" and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right;
            TextSize = 14;
            ZIndex = 11003;
            RichText = true;
            Parent = InnerFrame;
        })

        local SideColor = Library:Create("Frame", {
            AnchorPoint = Side == "left" and Vector2.new(0, 0) or Vector2.new(1, 0);
            Position = Side == "left" and UDim2.new(0, -1, 0, -1) or UDim2.new(1, -1, 0, -1);
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(0, 3, 1, 2);
            ZIndex = 11004;
            Parent = NotifyOuter;
        })

        Library:AddToRegistry(SideColor, {
            BackgroundColor3 = "AccentColor";
        }, true)

        function Data:Resize()
            XSize, YSize = Library:GetTextBounds(NotifyLabel.Text, Library.Font, 14)
            YSize = YSize + 7
            
            pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize * DPIScale + 8 + 4 + ExtraWidth, 0, YSize), "Out", "Quad", 0.4, true)
        end

        function Data:ChangeTitle(NewText)
            NewText = NewText == nil and "" or tostring(NewText)
            Data.Title = NewText
            NotifyLabel.Text = (Data.Title == "" and "" or "[" .. Data.Title .. "] ") .. tostring(Data.Description)
            Data:Resize()
        end

        function Data:ChangeDescription(NewText)
            if NewText == nil then return end
            NewText = tostring(NewText)
            Data.Description = NewText
            NotifyLabel.Text = (Data.Title == "" and "" or "[" .. Data.Title .. "] ") .. tostring(Data.Description)
            Data:Resize()
        end

        function Data:ChangeStep(...)
        end

        function Data:Destroy()
            Data.Destroyed = true

            if typeof(Data.Time) == "Instance" then
                pcall(Data.Time.Destroy, Data.Time)
            end
            
            if DeleteConnection then
                DeleteConnection:Disconnect()
            end

            pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), "Out", "Quad", 0.4, true)
            task.wait(0.4)
            NotifyOuter:Destroy()
        end

        Data:Resize()

        if Data.SoundId then
            Library:Create("Sound", {
                SoundId = "rbxassetid://" .. tostring(Data.SoundId):gsub("rbxassetid://", "");
                Volume = 3;
                PlayOnRemove = true;
                Parent = game:GetService("SoundService");
            }):Destroy()
        end

        NotifyOuter.Visible = true
        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize * DPIScale + 8 + 4 + ExtraWidth, 0, YSize), "Out", "Quad", 0.4, true)

        task.delay(0.4, function()
            if Data.Persist then
                return
            elseif typeof(Data.Time) == "Instance" then
                repeat
                    task.wait()
                until DeletedInstance or Data.Destroyed
            else
                task.wait(Data.Time or 5)
            end

            if not Data.Destroyed then
                Data:Destroy()
            end
        end)

        return Data
    end
end

--// Window \\--
function Library:CreateWindow(...)
    local Arguments = { ... }
    local WindowInfo = Templates.Window

    if typeof(Arguments[1]) == "table" then
        WindowInfo = Library:Validate(Arguments[1], Templates.Window)
    else
        WindowInfo = Library:Validate({
            Title = Arguments[1],
            AutoShow = Arguments[2] or false
        }, Templates.Window)
    end

    local ViewportSize: Vector2 = workspace.CurrentCamera.ViewportSize
    if RunService:IsStudio() and ViewportSize.X <= 5 and ViewportSize.Y <= 5 then
        repeat
            ViewportSize = workspace.CurrentCamera.ViewportSize
            task.wait()
        until ViewportSize.X > 5 and ViewportSize.Y > 5
    end

    if WindowInfo.Size == UDim2.fromOffset(0, 0) then
        WindowInfo.Size = if Library.IsMobile then UDim2.fromOffset(550, math.clamp(ViewportSize.Y - 35, 200, 600)) else UDim2.fromOffset(550, 600)
    end

    Library.NotifySide = WindowInfo.NotifySide
    Library.ShowCustomCursor = WindowInfo.ShowCustomCursor

    if WindowInfo.TabPadding <= 0 then WindowInfo.TabPadding = 1 end
    if WindowInfo.Center then WindowInfo.Position = UDim2.new(0.5, -WindowInfo.Size.X.Offset / 2, 0.5, -WindowInfo.Size.Y.Offset / 2) end

    local Window = {
        Tabs = {};

        OriginalTitle = WindowInfo.Title; 
        Title = WindowInfo.Title;
    }

    local Outer = Library:Create("Frame", {
        AnchorPoint = WindowInfo.AnchorPoint;
        BackgroundColor3 = Color3.new(0, 0, 0);
        BorderSizePixel = 0;
        Position = WindowInfo.Position;
        Size = WindowInfo.Size;
        Visible = false;
        ZIndex = 1;
        Parent = ScreenGui;
        Name = "Window";
    })
    LibraryMainOuterFrame = Outer
    Library:MakeDraggable(Outer, 25, true)
    if WindowInfo.Resizable then Library:MakeResizable(Outer, Library.MinSize) end

    local Inner = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 1;
        Parent = Outer;
    })

    Library:AddToRegistry(Inner, {
        BackgroundColor3 = "MainColor";
        BorderColor3 = "AccentColor";
    })

    local WindowLabel = Library:CreateLabel({
        Position = UDim2.new(0, 7, 0, 0);
        Size = UDim2.new(0, 0, 0, 25);
        Text = WindowInfo.Title or "";
        TextXAlignment = Enum.TextXAlignment.Left;
        RichText = true;
        ZIndex = 1;
        Parent = Inner;
    })

    local MainSectionOuter = Library:Create("Frame", {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, 25);
        Size = UDim2.new(1, -16, 1, -33);
        ZIndex = 1;
        Parent = Inner;
    })

    Library:AddToRegistry(MainSectionOuter, {
        BackgroundColor3 = "BackgroundColor";
        BorderColor3 = "OutlineColor";
    })

    local MainSectionInner = Library:Create("Frame", {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Color3.new(0, 0, 0);
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 1;
        Parent = MainSectionOuter;
    })

    Library:AddToRegistry(MainSectionInner, {
        BackgroundColor3 = "BackgroundColor";
    })

    local TabArea = Library:Create("ScrollingFrame", {
        ScrollingDirection = Enum.ScrollingDirection.X;
        CanvasSize = UDim2.new(0, 0, 2, 0);
        HorizontalScrollBarInset = Enum.ScrollBarInset.Always;
        AutomaticCanvasSize = Enum.AutomaticSize.XY;
        ScrollBarThickness = 0;
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 8 - WindowInfo.TabPadding, 0, 4);
        Size = UDim2.new(1, -10, 0, 26);
        ZIndex = 1;
        Parent = MainSectionInner;
    })

    local TabListLayout = Library:Create("UIListLayout", {
        Padding = UDim.new(0, WindowInfo.TabPadding);
        FillDirection = Enum.FillDirection.Horizontal;
        SortOrder = Enum.SortOrder.LayoutOrder;
        VerticalAlignment = Enum.VerticalAlignment.Center;
        Parent = TabArea;
    })

    Library:Create("Frame", {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        Size = UDim2.new(0, 0, 0, 0);
        LayoutOrder = -1;
        BackgroundTransparency = 1;
        ZIndex = 1;
        Parent = TabArea;
    })
    Library:Create("Frame", {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        Size = UDim2.new(0, 0, 0, 0);
        LayoutOrder = 9999999;
        BackgroundTransparency = 1;
        ZIndex = 1;
        Parent = TabArea;
    })

    local TabContainer = Library:Create("Frame", {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, 30);
        Size = UDim2.new(1, -16, 1, -38);
        ZIndex = 2;
        Parent = MainSectionInner;
    })
    
    local InnerVideoBackground = Library:Create("VideoFrame", {
        BackgroundColor3 = Library.MainColor;
        BorderMode = Enum.BorderMode.Inset;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 2;
        Visible = false;
        Volume = 0;
        Looped = true;
        Parent = TabContainer;
    })
    Library.InnerVideoBackground = InnerVideoBackground

    local BackgroundImage = Library:Create("ImageLabel", {
        Image = "";
        Position = UDim2.fromScale(0, 0);
        Size = UDim2.fromScale(1, 1);
        ScaleType = Enum.ScaleType.Stretch;
        ZIndex = 2;
        BackgroundTransparency = 1;
        ImageTransparency = 0.75;
        Parent = TabContainer;
        Visible = false;
    })

    Library:AddToRegistry(TabContainer, {
        BackgroundColor3 = "MainColor";
        BorderColor3 = "OutlineColor";
    })

    function Window:SetWindowTitle(Title)
        if typeof(Title) == "string" then
            Window.Title = Title
            WindowLabel.Text = Window.Title
        end
    end

    function Window:SetBackgroundImage(NewImage)
        if tonumber(NewImage) then
            NewImage = "rbxassetid://" .. NewImage
        end

        assert(typeof(NewImage) == "string", "Image must be a string.")

        local Icon = Library:GetCustomIcon(NewImage)
        if not Icon then
            BackgroundImage.Visible = false
            return
        end
        
        assert(Icon, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

        BackgroundImage.Image = Icon.Url
        BackgroundImage.ImageRectOffset = Icon.ImageRectOffset
        BackgroundImage.ImageRectSize = Icon.ImageRectSize

        BackgroundImage.Visible = true
    end

    function Window:AddDialog(Idx, Info)
        assert(Info.Title, "AddDialog: Missing `Title` string.")
        assert(Info.Description, "AddDialog: Missing `Description` string.")

        local DialogFrame
        local DialogOverlay
        local DialogContainer
        local ButtonsHolder
        local FooterButtonsList = {}

        DialogOverlay = Library:Create("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            Active = false,
            ZIndex = 9000,
            Visible = true,
            Parent = LibraryMainOuterFrame,
        })
        TweenService:Create(DialogOverlay, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0.5,
        }):Play()

        DialogFrame = Library:Create("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Library.BackgroundColor,
            BorderColor3 = Color3.new(0, 0, 0),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(300, 0),
            ZIndex = 9001,
            Visible = true,
            Parent = DialogOverlay,
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = "",
            AutoButtonColor = false,
        })

        local DialogInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.AccentColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 9002,
            Parent = DialogFrame,
        })

        Library:AddToRegistry(DialogFrame, {
            BackgroundColor3 = "BackgroundColor",
        })

        Library:AddToRegistry(DialogInner, {
            BackgroundColor3 = "MainColor",
            BorderColor3 = "AccentColor",
        })

        local InnerContainer = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 9003,
            Parent = DialogInner,
        })
        local DialogScale = Library:Create("UIScale", {
            Scale = 0.95,
            Parent = DialogFrame,
        })
        TweenService:Create(DialogScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Scale = 1
        }):Play()

        Library:Create("UIPadding", {
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 15),
            PaddingRight = UDim.new(0, 15),
            PaddingTop = UDim.new(0, 15),
            Parent = InnerContainer,
        })
        local _InnerListLayout = Library:Create("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = InnerContainer,
        })

        local HeaderContainer = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1,
            ZIndex = 9003,
            Parent = InnerContainer,
        })
        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = HeaderContainer,
        })
        Library:Create("UIPadding", {
            PaddingBottom = UDim.new(0, 5),
            Parent = HeaderContainer,
        })

        local TitleRow = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1,
            ZIndex = 9003,
            Parent = HeaderContainer,
        })
        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 6),
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = TitleRow,
        })

        local TitleLabel = Library:CreateLabel({
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = Info.Title or "Dialog",
            TextSize = 18,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 9003,
            Parent = TitleRow,
            RichText = true,
        })
        if Info.TitleColor then
            TitleLabel.TextColor3 = Info.TitleColor
        else
            Library:AddToRegistry(TitleLabel, { TextColor3 = "FontColor" })
        end

        local DescriptionLabel = Library:CreateLabel({
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = Info.Description or "Description",
            TextSize = 14,
            TextTransparency = Info.DescriptionColor and 0 or 0.2,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            ZIndex = 9003,
            LayoutOrder = 2,
            Parent = HeaderContainer,
            RichText = true,
        })
        if Info.DescriptionColor then
            DescriptionLabel.TextColor3 = Info.DescriptionColor
        else
            Library:AddToRegistry(DescriptionLabel, { TextColor3 = "FontColor" })
        end

        DialogContainer = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 4,
            Visible = false,
            ZIndex = 9003,
            Parent = InnerContainer,
        })
        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 1),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = DialogContainer,
        })
        
        local _Sep2 = Library:Create("Frame", {
            BackgroundColor3 = Library.OutlineColor,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 1),
            LayoutOrder = 5,
            ZIndex = 9003,
            Parent = InnerContainer,
        })
        Library:AddToRegistry(_Sep2, {
            BackgroundColor3 = "OutlineColor",
        })

        ButtonsHolder = Library:Create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 6,
            ZIndex = 9002,
            Parent = InnerContainer,
        })
        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 8),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Wraps = true,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = ButtonsHolder,
        })
        Library:Create("UIPadding", {
            PaddingTop = UDim.new(0, 0),
            Parent = ButtonsHolder,
        })

        local Dialog = {
            Elements = {},
            Container = DialogContainer,
        }

        function Dialog:Resize()
            local MaxWidth = LibraryMainOuterFrame.AbsoluteSize.X * 0.75
            local MinWidth = 400 * DPIScale

            local TotalButtonWidth = 0
            local ButtonCount = 0
            local HasButtons = false

            for _, BtnWrap in pairs(FooterButtonsList) do
                HasButtons = true
                ButtonCount = ButtonCount + 1
                TotalButtonWidth = TotalButtonWidth + BtnWrap.Container.Size.X.Offset
            end

            local TargetWidth = MinWidth
            if HasButtons then
                local RequiredWidth = TotalButtonWidth + ((ButtonCount - 1) * 8 * DPIScale) + (30 * DPIScale)
                TargetWidth = math.max(MinWidth, math.min(RequiredWidth, MaxWidth))
            end

            local DescY = select(2, Library:GetTextBounds(DescriptionLabel.Text, Library.Font, 14 * DPIScale, TargetWidth - (30 * DPIScale)))
            DescriptionLabel.Size = UDim2.new(1, 0, 0, DescY)

            local HasElements = false
            for _, v in pairs(DialogContainer:GetChildren()) do
                if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then
                    HasElements = true
                    break
                end
            end

            if HasElements then
                for _, v in pairs(DialogContainer:GetDescendants()) do
                    if not v:IsA("GuiObject") then continue end
                    if v:GetAttribute("ZIndexApplied") then continue end
                    
                    v:SetAttribute("ZIndexApplied", true)
                    v.ZIndex = v.ZIndex + 9003
                end
            end

            DialogContainer.Visible = HasElements

            ButtonsHolder.Visible = HasButtons
            _Sep2.Visible = HasButtons

            DialogFrame.Size = UDim2.fromOffset(TargetWidth, 0)
        end

        function Dialog:SetTitle(Title)
            TitleLabel.Text = Title
            Dialog:Resize()
        end

        function Dialog:SetDescription(Description)
            DescriptionLabel.Text = Description
            Dialog:Resize()
        end

        function Dialog:Dismiss()
            TweenService:Create(DialogScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.95 }):Play()
            TweenService:Create(DialogOverlay, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
            
            task.delay(0.1, function()
                DialogOverlay:Destroy()
            end)

            if Library.Dialogues then Library.Dialogues[Idx] = nil end
            Library.ActiveDialog = nil
        end

        DialogOverlay.MouseButton1Click:Connect(function()
            if Info.OutsideClickDismiss then
                Dialog:Dismiss()
            end
        end)

        function Dialog:RemoveFooterButton(ButtonIdx)
            if FooterButtonsList[ButtonIdx] then
                FooterButtonsList[ButtonIdx].Container:Destroy()
                FooterButtonsList[ButtonIdx] = nil
            end
        end

        function Dialog:SetButtonDisabled(ButtonIdx, Disabled)
            if FooterButtonsList[ButtonIdx] and type(FooterButtonsList[ButtonIdx].SetDisabled) == "function" then
                FooterButtonsList[ButtonIdx]:SetDisabled(Disabled)
            end
        end

        function Dialog:SetButtonOrder(ButtonIdx, Order)
            if FooterButtonsList[ButtonIdx] and FooterButtonsList[ButtonIdx].Container then
                FooterButtonsList[ButtonIdx].Container.LayoutOrder = Order
            end
        end

        function Dialog:AddFooterButton(ButtonIdx, ButtonInfo)
            Dialog:RemoveFooterButton(ButtonIdx)

            local WaitTime = ButtonInfo.WaitTime or 0
            local Variant = ButtonInfo.Variant or "Primary"

            local BtnInnerColor = Library.MainColor
            local BtnBorderColor = Library.OutlineColor
            local DestructiveColor = Color3.fromRGB(220, 38, 38)

            if Variant == "Primary" then
                BtnBorderColor = Library.AccentColor
            elseif Variant == "Secondary" then
                BtnInnerColor = Library.BackgroundColor
                BtnBorderColor = Library.OutlineColor
            elseif Variant == "Destructive" then
                BtnBorderColor = DestructiveColor
            elseif Variant == "Ghost" then
                BtnBorderColor = Library.MainColor
            end

            local LabelX = select(1, Library:GetTextBounds(ButtonInfo.Title or ButtonIdx, Library.Font, 14 * DPIScale))
            local BtnW = LabelX + (24 * DPIScale)
            local BtnH = 20 * DPIScale

            local ButtonContainer = Library:Create("Frame", {
                BackgroundColor3 = Color3.new(0, 0, 0),
                BorderColor3 = Color3.new(0, 0, 0),
                Size = UDim2.fromOffset(BtnW, BtnH),
                LayoutOrder = ButtonInfo.Order or 0,
                ZIndex = 9003,
                Parent = ButtonsHolder,
            })
            Library:AddToRegistry(ButtonContainer, { BorderColor3 = "Black" })

            local TextBtn = Library:Create("TextButton", {
                BackgroundColor3 = BtnInnerColor,
                BorderColor3 = BtnBorderColor,
                BorderMode = Enum.BorderMode.Inset,
                BackgroundTransparency = WaitTime > 0 and 0.5 or 0,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                AutoButtonColor = false,
                ZIndex = 9004,
                Parent = ButtonContainer,
            })

            if Variant == "Primary" then
                Library:AddToRegistry(TextBtn, { BackgroundColor3 = "MainColor", BorderColor3 = "AccentColor" })
            elseif Variant == "Secondary" then
                Library:AddToRegistry(TextBtn, { BackgroundColor3 = "BackgroundColor", BorderColor3 = "OutlineColor" })
            elseif Variant == "Ghost" then
                Library:AddToRegistry(TextBtn, { BackgroundColor3 = "MainColor", BorderColor3 = "MainColor" })
            end

            Library:Create("UIGradient", {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)),
                }),
                Rotation = 90,
                Parent = TextBtn,
            })

            local HighlightBorderColor = Variant == "Destructive" and DestructiveColor or Library.AccentColor
            ButtonContainer.MouseEnter:Connect(function()
                ButtonContainer.BorderColor3 = HighlightBorderColor
            end)
            ButtonContainer.MouseLeave:Connect(function()
                ButtonContainer.BorderColor3 = Color3.new(0, 0, 0)
            end)

            local TextColor = Library.FontColor
            if Variant == "Destructive" then
                TextColor = Color3.new(1, 1, 1)
            end

            local BtnLabel = Library:CreateLabel({
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Text = ButtonInfo.Title or ButtonIdx,
                TextColor3 = TextColor,
                TextTransparency = WaitTime > 0 and 0.5 or 0,
                TextSize = 14 * DPIScale,
                ZIndex = 9005,
                Parent = TextBtn,
            })

            if Variant ~= "Destructive" then
                Library:AddToRegistry(BtnLabel, { TextColor3 = "FontColor" })
            end

            local ProgressBar
            if WaitTime > 0 then
                ProgressBar = Library:Create("Frame", {
                    BackgroundColor3 = Library.AccentColor,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 0, 1, -2),
                    Size = UDim2.new(0, 0, 0, 2),
                    ZIndex = 2,
                    Parent = TextBtn,
                })
                Library:AddToRegistry(ProgressBar, { BackgroundColor3 = "AccentColor" })
            end

            local IsActive = WaitTime <= 0

            local ButtonWrap = {
                Container = ButtonContainer,
                SetDisabled = function(self, Disabled)
                    IsActive = not Disabled
                    if Disabled then
                        TweenService:Create(TextBtn, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.5 }):Play()
                        TweenService:Create(BtnLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0.5 }):Play()
                    else
                        TweenService:Create(TextBtn, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0 }):Play()
                        TweenService:Create(BtnLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
                    end
                end
            }

            TextBtn.MouseButton1Click:Connect(function()
                if not IsActive then return end

                if ButtonInfo.Callback then
                    ButtonInfo.Callback(Dialog)
                end

                if Info.AutoDismiss ~= false then
                    Dialog:Dismiss()
                end
            end)

            if WaitTime > 0 then
                TweenService:Create(ProgressBar, TweenInfo.new(WaitTime, Enum.EasingStyle.Linear), {
                    Size = UDim2.new(1, 0, 0, 2)
                }):Play()
                
                task.delay(WaitTime, function()
                    ButtonWrap:SetDisabled(false)

                    if ProgressBar then
                        TweenService:Create(ProgressBar, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                            BackgroundTransparency = 1
                        }):Play()
                    end
                end)
            end

            FooterButtonsList[ButtonIdx] = ButtonWrap
        end

        if Info.FooterButtons then
            for BIdx, BInfo in pairs(Info.FooterButtons) do
                if type(BIdx) == "number" and BInfo.Id then BIdx = BInfo.Id end
                Dialog:AddFooterButton(BIdx, BInfo)
            end
        end

        setmetatable(Dialog, BaseGroupbox)

        Library.Dialogues[Idx] = Dialog
        Library.ActiveDialog = Dialog

        Dialog:Resize()

        return Dialog
    end

    function Window:AddTab(Name)
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
            DependencyGroupboxes = {};
            WarningBox = {
                Bottom = false,
                IsNormal = false,
                LockSize = false,
                Visible = false,
                Title = "WARNING",
                Text = ""
            };
            OriginalName = Name; 
            Name = Name;
            TableType = "Tab";
        }

        local TabButtonWidth = Library:GetTextBounds(Tab.Name, Library.Font, 16)

        local TabButton = Library:Create("Frame", {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            Size = UDim2.new(0, TabButtonWidth + 8 + 4, 0.85, 0);
            ZIndex = 1;
            Parent = TabArea;
        })

        Library:AddToRegistry(TabButton, {
            BackgroundColor3 = "BackgroundColor";
            BorderColor3 = "OutlineColor";
        })

        local TabButtonLabel = Library:CreateLabel({
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, -1);
            Text = Tab.Name;
            ZIndex = 1;
            Parent = TabButton;
        })

        local Blocker = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 0, 1, 0);
            Size = UDim2.new(1, 0, 0, 1);
            BackgroundTransparency = 1;
            ZIndex = 3;
            Parent = TabButton;
        })

        Library:AddToRegistry(Blocker, {
            BackgroundColor3 = "MainColor";
        })

        local TabFrame = Library:Create("Frame", {
            Name = "TabFrame",
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            Visible = false;
            ZIndex = 2;
            Parent = TabContainer;
        })

        local TopBarLabelStroke
        local TopBarHighlight
        local TopBar, TopBarInner, TopBarLabel, TopBarTextLabel, TopBarScrollingFrame
do
            TopBar = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.fromRGB(248, 51, 51);
                BorderMode = Enum.BorderMode.Inset;
                Position = UDim2.new(0, 7, 0, 7);
                Size = UDim2.new(1, -13, 0, 0);
                ZIndex = 2;
                Parent = TabFrame;
                Visible = false;
            })

            TopBarInner = Library:Create("Frame", {
                BackgroundColor3 = Color3.fromRGB(117, 22, 17);
                BorderColor3 = Color3.new();
                -- BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = TopBar;
            })

            TopBarHighlight = Library:Create("Frame", {
                BackgroundColor3 = Color3.fromRGB(255, 75, 75);
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 5;
                Parent = TopBarInner;
            })

            TopBarScrollingFrame = Library:Create("ScrollingFrame", {
                BackgroundTransparency = 1;
                BorderSizePixel = 0;
                Size = UDim2.new(1, -8, 1, 0);
                CanvasSize = UDim2.new(0, 0, 0, 0);
                AutomaticCanvasSize = Enum.AutomaticSize.Y;
                ScrollBarThickness = 3;
                ZIndex = 5;
                Parent = TopBarInner;
            })

            TopBarLabel = Library:Create("TextLabel", {
                BackgroundTransparency = 1;
                Font = Library.Font;
                TextStrokeTransparency = 0;
                RichText = true;

                Size = UDim2.new(1, 0, 0, 18);
                Position = UDim2.new(0, 4, 0, 2);
                TextSize = 14;
                Text = "Text";
                TextXAlignment = Enum.TextXAlignment.Left;
                TextColor3 = Color3.fromRGB(255, 55, 55);
                ZIndex = 5;
                Parent = TopBarScrollingFrame;
            })

            TopBarLabelStroke = Library:ApplyTextStroke(TopBarLabel)
            TopBarLabelStroke.Color = Color3.fromRGB(174, 3, 3)

            TopBarTextLabel = Library:CreateLabel({
                RichText = true;
                Position = UDim2.new(0, 4, 0, 20);
                Size = UDim2.new(1, 0, 0, 14);
                TextSize = 14;
                Text = "Text";
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Top;
                ZIndex = 5;
                Parent = TopBarScrollingFrame;
            })
            
            Library:Create("Frame", {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 0, 5);
                Visible = true;
                ZIndex = 1;
                Parent = TopBarInner;
            })
        end
        
        local LeftSide = Library:Create("ScrollingFrame", {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 7, 0, 7);
            Size = UDim2.new(0.5, -10, 1, -14);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = "";
            TopImage = "";
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        })

        local RightSide = Library:Create("ScrollingFrame", {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, 5, 0, 7);
            Size = UDim2.new(0.5, -10, 1, -14);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = "";
            TopImage = "";
            ScrollBarThickness = 0;
            ZIndex = 2;
            Parent = TabFrame;
        })

        Tab.LeftSideFrame = LeftSide
        Tab.RightSideFrame = RightSide

        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = LeftSide;
        })

        Library:Create("UIListLayout", {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = RightSide;
        })

        if Library.IsMobile then
            local SidesValues = {
                ["Left"] = tick(),
                ["Right"] = tick(),
            }

            LeftSide:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                Library.CanDrag = false

                local ChangeTick = tick()
                SidesValues.Left = ChangeTick
                task.wait(0.15)

                if SidesValues.Left == ChangeTick then
                    Library.CanDrag = true
                end
            end)

            RightSide:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                Library.CanDrag = false

                local ChangeTick = tick()
                SidesValues.Right = ChangeTick
                task.wait(0.15)
                
                if SidesValues.Right == ChangeTick then
                    Library.CanDrag = true
                end
            end)
        end

        for _, Side in next, { LeftSide, RightSide } do
            Side:WaitForChild("UIListLayout"):GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y)
            end)
        end

        function Tab:Resize()
            if TopBar.Visible == true then
                local MaximumSize = math.floor(TabFrame.AbsoluteSize.Y / 3.25)
                local Size = 27 + select(2, Library:GetTextBounds(TopBarTextLabel.Text, Library.Font, 14, Vector2.new(TopBarTextLabel.AbsoluteSize.X, math.huge)))

                if Tab.WarningBox.LockSize == true and Size >= MaximumSize then 
                    Size = MaximumSize
                end

                if Tab.WarningBox.Bottom == true then
                    TopBar.Position = UDim2.new(0, 7, 1, -(Size + 7))
                else
                    TopBar.Position = UDim2.new(0, 7, 0, 7)
                end

                TopBar.Size = UDim2.new(1, -13, 0, Size)
                Size = Size + 10
                
                if TopBar.Position.Y.Offset > 0 then
                    LeftSide.Position = UDim2.new(0, 7, 0, 7 + Size)
                    LeftSide.Size = UDim2.new(0.5, -10, 1, -14 - Size)
            
                    RightSide.Position = UDim2.new(0.5, 5, 0, 7 + Size)
                    RightSide.Size = UDim2.new(0.5, -10, 1, -14 - Size)
                else
                    LeftSide.Position = UDim2.new(0, 7, 0, 7)
                    LeftSide.Size = UDim2.new(0.5, -10, 1, -14 - Size)
            
                    RightSide.Position = UDim2.new(0.5, 5, 0, 7)
                    RightSide.Size = UDim2.new(0.5, -10, 1, -14 - Size)
                end
            else
                LeftSide.Position = UDim2.new(0, 7, 0, 7)
                LeftSide.Size = UDim2.new(0.5, -10, 1, -14)
        
                RightSide.Position = UDim2.new(0.5, 5, 0, 7)
                RightSide.Size = UDim2.new(0.5, -10, 1, -14)
            end
        end

        function Tab:UpdateWarningBox(Info)
            if typeof(Info.Bottom) == "boolean"     then Tab.WarningBox.Bottom      = Info.Bottom end
            if typeof(Info.IsNormal) == "boolean"   then Tab.WarningBox.IsNormal      = Info.IsNormal end
            if typeof(Info.LockSize) == "boolean"   then Tab.WarningBox.LockSize    = Info.LockSize end
            if typeof(Info.Visible) == "boolean"    then Tab.WarningBox.Visible     = Info.Visible end
            if typeof(Info.Title) == "string"       then Tab.WarningBox.Title       = Info.Title end
            if typeof(Info.Text) == "string"        then Tab.WarningBox.Text        = Info.Text end

            TopBar.Visible = Tab.WarningBox.Visible
            TopBarLabel.Text = Tab.WarningBox.Title
            TopBarTextLabel.Text = Tab.WarningBox.Text
            if TopBar.Visible then Tab:Resize()
end

            TopBar.BorderColor3 = Tab.WarningBox.IsNormal == true and Color3.fromRGB(27, 42, 53) or Color3.fromRGB(248, 51, 51)
            TopBarInner.BorderColor3 = Tab.WarningBox.IsNormal == true and Library.OutlineColor or Color3.fromRGB(0, 0, 0)
            TopBarInner.BackgroundColor3 = Tab.WarningBox.IsNormal == true and Library.BackgroundColor or Color3.fromRGB(117, 22, 17)
            TopBarHighlight.BackgroundColor3 = Tab.WarningBox.IsNormal == true and Library.AccentColor or Color3.fromRGB(255, 75, 75)
             
            TopBarLabel.TextColor3 = Tab.WarningBox.IsNormal == true and Library.FontColor or Color3.fromRGB(255, 55, 55)
            TopBarLabelStroke.Color = Tab.WarningBox.IsNormal == true and Library.Black or Color3.fromRGB(174, 3, 3)

            if not Library.RegistryMap[TopBarInner] then Library:AddToRegistry(TopBarInner, {}) end
            if not Library.RegistryMap[TopBarHighlight] then Library:AddToRegistry(TopBarHighlight, {}) end
            if not Library.RegistryMap[TopBarLabel] then Library:AddToRegistry(TopBarLabel, {}) end
            if not Library.RegistryMap[TopBarLabelStroke] then Library:AddToRegistry(TopBarLabelStroke, {}) end

            Library.RegistryMap[TopBarInner].Properties.BorderColor3 = Tab.WarningBox.IsNormal == true and "OutlineColor" or nil
            Library.RegistryMap[TopBarInner].Properties.BackgroundColor3 = Tab.WarningBox.IsNormal == true and "BackgroundColor" or nil
            Library.RegistryMap[TopBarHighlight].Properties.BackgroundColor3 = Tab.WarningBox.IsNormal == true and "AccentColor" or nil

            Library.RegistryMap[TopBarLabel].Properties.TextColor3 = Tab.WarningBox.IsNormal == true and "FontColor" or nil
            Library.RegistryMap[TopBarLabelStroke].Properties.Color = Tab.WarningBox.IsNormal == true and "Black" or nil
        end

        function Tab:ShowTab()
            Library.ActiveTab = Name
            for _, Tab in next, Window.Tabs do
                Tab:HideTab()
            end

            Blocker.BackgroundTransparency = 0
            TabButton.BackgroundColor3 = Library.MainColor
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = "MainColor"
            TabFrame.Visible = true

            Tab:Resize()
        end
        Tab.Show = Tab.ShowTab

        function Tab:HideTab()
            Blocker.BackgroundTransparency = 1
            TabButton.BackgroundColor3 = Library.BackgroundColor
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = "BackgroundColor"
            TabFrame.Visible = false
        end
        Tab.Hide = Tab.HideTab

        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position
            TabListLayout:ApplyLayout()
        end

        function Tab:GetSides()
            return { ["Left"] = LeftSide, ["Right"] = RightSide }
        end

        function Tab:SetName(Name)
            if typeof(Name) == "string" then
                Tab.Name = Name

                local TabButtonWidth = Library:GetTextBounds(Tab.Name, Library.Font, 16)

                TabButton.Size = UDim2.new(0, TabButtonWidth + 8 + 4, 0.85, 0)
                TabButtonLabel.Text = Tab.Name
            end
        end

        function Tab:AddGroupbox(Info)
            local Groupbox = {
                Elements = {};
                Side = Info.Side;
                Tab = Tab;
                TableType = "Groupbox";
            }

            local BoxOuter = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 507 + 2);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            })

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = "BackgroundColor";
                BorderColor3 = "OutlineColor";
            })

            local BoxInner = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                -- BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            })

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = "BackgroundColor";
            })

            local Highlight = Library:Create("Frame", {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 5;
                Parent = BoxInner;
            })

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = "AccentColor";
            })

            -- local GroupboxLabel = 
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 18);
                Position = UDim2.new(0, 4, 0, 2);
                TextSize = 14;
                Text = Info.Name;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = BoxInner;
            })

            local Container = Library:Create("Frame", {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 4, 0, 20);
                Size = UDim2.new(1, -4, 1, -20);
                ZIndex = 1;
                Parent = BoxInner;
            })

            Library:Create("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = Container;
            })

            function Groupbox:Resize()
                local Size = 0

                for _, Element in next, Groupbox.Container:GetChildren() do
                    if (not Element:IsA("UIListLayout")) and Element.Visible then
                        Size = Size + Element.Size.Y.Offset
                    end
                end

                BoxOuter.Size = UDim2.new(1, 0, 0, (20 * DPIScale + Size) + 2 + 2)
            end

            Groupbox.Container = Container
            setmetatable(Groupbox, BaseGroupbox)

            Groupbox:AddBlank(3)
            Groupbox:Resize()

            Tab.Groupboxes[Info.Name] = Groupbox

            return Groupbox
        end

        function Tab:AddLeftGroupbox(Name)
            return Tab:AddGroupbox({ Side = 1; Name = Name; })
        end

        function Tab:AddRightGroupbox(Name)
            return Tab:AddGroupbox({ Side = 2; Name = Name; })
        end

        function Tab:AddTabbox(Info)
            local Tabbox = {
                Tabs = {};
            }

            local BoxOuter = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 0, 0);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            })

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = "BackgroundColor";
                BorderColor3 = "OutlineColor";
            })

            local BoxInner = Library:Create("Frame", {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Color3.new(0, 0, 0);
                -- BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, -2, 1, -2);
                Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4;
                Parent = BoxOuter;
            })

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = "BackgroundColor";
            })

            local Highlight = Library:Create("Frame", {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2);
                ZIndex = 10;
                Parent = BoxInner;
            })

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = "AccentColor";
            })

            local TabboxButtons = Library:Create("Frame", {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 0, 0, 1);
                Size = UDim2.new(1, 0, 0, 18);
                ZIndex = 5;
                Parent = BoxInner;
            })

            Library:Create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TabboxButtons;
            })

            function Tabbox:AddTab(Name)
                local Tab = {
                    Elements = {};
                    Container = nil;
                    TableType = "TabboxTab";
                }

                local Button = Library:Create("Frame", {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Color3.new(0, 0, 0);
                    Size = UDim2.new(0.5, 0, 1, 0);
                    ZIndex = 6;
                    Parent = TabboxButtons;
                })

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = "MainColor";
                })

                -- local ButtonLabel = 
                Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0);
                    TextSize = 14;
                    Text = Name;
                    TextXAlignment = Enum.TextXAlignment.Center;
                    ZIndex = 7;
                    Parent = Button;
                    RichText = true;
                })

                local Block = Library:Create("Frame", {
                    BackgroundColor3 = Library.BackgroundColor;
                    BorderSizePixel = 0;
                    Position = UDim2.new(0, 0, 1, 0);
                    Size = UDim2.new(1, 0, 0, 1);
                    Visible = false;
                    ZIndex = 9;
                    Parent = Button;
                })

                Library:AddToRegistry(Block, {
                    BackgroundColor3 = "BackgroundColor";
                })

                local Container = Library:Create("Frame", {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 4, 0, 20);
                    Size = UDim2.new(1, -4, 1, -20);
                    ZIndex = 1;
                    Visible = false;
                    Parent = BoxInner;
                })

                Library:Create("UIListLayout", {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = Container;
                })

                function Tab:Show()
                    for _, Tab in next, Tabbox.Tabs do
                        Tab:Hide()
                    end

                    Container.Visible = true
                    Block.Visible = true

                    Button.BackgroundColor3 = Library.BackgroundColor
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = "BackgroundColor"

                    Tab:Resize()
                end

                function Tab:Hide()
                    Container.Visible = false
                    Block.Visible = false

                    Button.BackgroundColor3 = Library.MainColor
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = "MainColor"
                end

                function Tab:Resize()
                    local TabCount = 0

                    for _, Tab in next, Tabbox.Tabs do
                        TabCount = TabCount + 1
                    end

                    for _, Button in next, TabboxButtons:GetChildren() do
                        if not Button:IsA("UIListLayout") then
                            Button.Size = UDim2.new(1 / TabCount, 0, 1, 0)
                        end
                    end

                    if (not Container.Visible) then
                        return
                    end

                    local Size = 0

                    for _, Element in next, Tab.Container:GetChildren() do
                        if (not Element:IsA("UIListLayout")) and Element.Visible then
                            Size = Size + Element.Size.Y.Offset
                        end
                    end

                    BoxOuter.Size = UDim2.new(1, 0, 0, (20 * DPIScale + Size) + 2 + 2)
                end

                Button.InputBegan:Connect(function(Input)
                    if (Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame()) or Input.UserInputType == Enum.UserInputType.Touch then
                        Tab:Show()
                        Tab:Resize()
                    end
                end)

                Tab.Container = Container
                Tabbox.Tabs[Name] = Tab

                setmetatable(Tab, BaseGroupbox)

                Tab:AddBlank(3)
                Tab:Resize()

                -- Show first tab (number is 2 cus of the UIListLayout that also sits in that instance)
                if #TabboxButtons:GetChildren() == 2 then
                    Tab:Show()
                end

                return Tab
            end

            Tab.Tabboxes[Info.Name or ""] = Tabbox

            return Tabbox
        end

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 1; })
        end

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 2; })
        end

        TabButton.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                Tab:ShowTab()
            end
        end)

        TopBar:GetPropertyChangedSignal("Visible"):Connect(function()
            Tab:Resize()
        end)

        -- This was the first tab added, so we show it by default.
        Library.TotalTabs = Library.TotalTabs + 1
        if Library.TotalTabs == 1 then
            Tab:ShowTab()
        end

        Window.Tabs[Name] = Tab
        return Tab
    end

    local TransparencyCache = {}
    local Toggled = false
    local Fading = false
    
    function Window:Toggle(Toggling)
        if typeof(Toggling) == "boolean" and Toggling == Toggled then return end
        if Fading then return end

        local FadeTime = WindowInfo.MenuFadeTime
        Fading = true
        Toggled = (not Toggled)

        Library.Toggled = Toggled
        if WindowInfo.UnlockMouseWhileOpen then
            ModalElement.Modal = Library.Toggled
        end

        if Toggled then
            -- A bit scuffed, but if we're going from not toggled -> toggled we want to show the frame immediately so that the fade is visible.
            Outer.Visible = true

            if DrawingLib.drawing_replaced ~= true and IsBadDrawingLib ~= true then
                IsBadDrawingLib = not (pcall(function()
                    local Cursor = DrawingLib.new("Triangle")
                    Cursor.Thickness = 1
                    Cursor.Filled = true
                    Cursor.Visible = Library.ShowCustomCursor

                    local CursorOutline = DrawingLib.new("Triangle")
                    CursorOutline.Thickness = 1
                    CursorOutline.Filled = false
                    CursorOutline.Color = Color3.new(0, 0, 0)
                    CursorOutline.Visible = Library.ShowCustomCursor
                    
                    local OldMouseIconState = InputService.MouseIconEnabled
                    local ShowCursorBinding = Library.ShowCursorBinding
                    pcall(function() RunService:UnbindFromRenderStep(ShowCursorBinding) end)
                    RunService:BindToRenderStep(ShowCursorBinding, Enum.RenderPriority.Camera.Value - 1, function()
                        InputService.MouseIconEnabled = not Library.ShowCustomCursor
                        local mPos = InputService:GetMouseLocation()
                        local X, Y = mPos.X, mPos.Y
                        Cursor.Color = Library.AccentColor
                        Cursor.PointA = Vector2.new(X, Y)
                        Cursor.PointB = Vector2.new(X + 16, Y + 6)
                        Cursor.PointC = Vector2.new(X + 6, Y + 16)
                        Cursor.Visible = Library.ShowCustomCursor
                        CursorOutline.PointA = Cursor.PointA
                        CursorOutline.PointB = Cursor.PointB
                        CursorOutline.PointC = Cursor.PointC
                        CursorOutline.Visible = Library.ShowCustomCursor

                        if not Toggled or (not ScreenGui or not ScreenGui.Parent) then
                            InputService.MouseIconEnabled = OldMouseIconState
                            if Cursor then Cursor:Destroy() end
                            if CursorOutline then CursorOutline:Destroy() end
                            RunService:UnbindFromRenderStep(ShowCursorBinding)
                        end
                    end)
                end))
            end
        end

        for _, Option in Options do
            task.spawn(function()
                if Option.Type == "Dropdown" then
                    Option:CloseDropdown()

                elseif Option.Type == "KeyPicker" then
                    Option:SetModePickerVisibility(false)

                elseif Option.Type == "ColorPicker" then
                    Option.ContextMenu:Hide()
                    Option:Hide()
                end
            end)
        end

        for _, Desc in next, Outer:GetDescendants() do
            local Properties = {}

            if Desc:IsA("ImageLabel") then
                table.insert(Properties, "ImageTransparency")
                table.insert(Properties, "BackgroundTransparency")

            elseif Desc:IsA("TextLabel") or Desc:IsA("TextBox") then
                table.insert(Properties, "TextTransparency")

            elseif Desc:IsA("Frame") or Desc:IsA("ScrollingFrame") then
                table.insert(Properties, "BackgroundTransparency")
                
            elseif Desc:IsA("UIStroke") then
                table.insert(Properties, "Transparency")
            end

            local Cache = TransparencyCache[Desc]

            if (not Cache) then
                Cache = {}
                TransparencyCache[Desc] = Cache
            end

            for _, Prop in next, Properties do
                if not Cache[Prop] then
                    Cache[Prop] = Desc[Prop]
                end

                if Cache[Prop] == 1 then
                    continue
                end

                TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Linear), { [Prop] = Toggled and Cache[Prop] or 1 }):Play()
            end
        end

        task.wait(FadeTime)
        Outer.Visible = Toggled
        Fading = false
    end

    function Library:Toggle(Toggling)
        return Window:Toggle(Toggling)
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed) -- :sob:
        if Library.Unloaded then
            return
        end
        
        if typeof(Library.ToggleKeybind) == "table" and Library.ToggleKeybind.Type == "KeyPicker" then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end

        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle)
        end
    end))

    if Library.IsMobile then
        local ToggleUIOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0.008, 0, 0.018, 0);
            Size = UDim2.new(0, 77, 0, 30);
            ZIndex = 200;
            Visible = true;
            Parent = ScreenGui;
        })
    
        local ToggleUIInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.AccentColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 201;
            Parent = ToggleUIOuter;
        })
    
        Library:AddToRegistry(ToggleUIInner, {
            BorderColor3 = "AccentColor";
        })
    
        local ToggleUIInnerFrame = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Position = UDim2.new(0, 1, 0, 1);
            Size = UDim2.new(1, -2, 1, -2);
            ZIndex = 202;
            Parent = ToggleUIInner;
        })
    
        local ToggleUIGradient = Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
            Rotation = -90;
            Parent = ToggleUIInnerFrame;
        })
    
        Library:AddToRegistry(ToggleUIGradient, {
            Color = function()
                return ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                    ColorSequenceKeypoint.new(1, Library.MainColor),
                })
            end
        })
    
        local ToggleUIButton = Library:Create("TextButton", {
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -4, 1, 0);
            BackgroundTransparency = 1;
            Font = Library.Font;
            Text = "Toggle UI";
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextStrokeTransparency = 0;
            ZIndex = 203;
            Parent = ToggleUIInnerFrame;
        })
    
        Library:MakeDraggableUsingParent(ToggleUIButton, ToggleUIOuter)

        ToggleUIButton.MouseButton1Down:Connect(function()
            Library:Toggle()
        end)

        -- Lock
        local LockUIOuter = Library:Create("Frame", {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0.008, 0, 0.075, 0);
            Size = UDim2.new(0, 77, 0, 30);
            ZIndex = 200;
            Visible = true;
            Parent = ScreenGui;
        })
    
        local LockUIInner = Library:Create("Frame", {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.AccentColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 201;
            Parent = LockUIOuter;
        })
    
        Library:AddToRegistry(LockUIInner, {
            BorderColor3 = "AccentColor";
        })
    
        local LockUIInnerFrame = Library:Create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Position = UDim2.new(0, 1, 0, 1);
            Size = UDim2.new(1, -2, 1, -2);
            ZIndex = 202;
            Parent = LockUIInner;
        })
    
        local LockUIGradient = Library:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
            Rotation = -90;
            Parent = LockUIInnerFrame;
        })
    
        Library:AddToRegistry(LockUIGradient, {
            Color = function()
                return ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                    ColorSequenceKeypoint.new(1, Library.MainColor),
                })
            end
        })
    
        local LockUIButton = Library:Create("TextButton", {
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -4, 1, 0);
            BackgroundTransparency = 1;
            Font = Library.Font;
            Text = "Lock UI";
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextStrokeTransparency = 0;
            ZIndex = 203;
            Parent = LockUIInnerFrame;
        })
    
        Library:MakeDraggableUsingParent(LockUIButton, LockUIOuter)
        
        LockUIButton.MouseButton1Down:Connect(function()
            Library.CantDragForced = not Library.CantDragForced
            LockUIButton.Text = Library.CantDragForced and "Unlock UI" or "Lock UI"
        end)
    end

    Window:SetBackgroundImage(WindowInfo.BackgroundImage or "")
    if WindowInfo.AutoShow then task.spawn(Library.Toggle) end

    Window.Holder = Outer
    Library.Window = Window

    return Window
end

local function OnPlayerChange()
    if Library.Unloaded then
        return
    end

    local PlayerList, ExcludedPlayerList = GetPlayers(false, true), GetPlayers(true, true)
    local StringPlayerList, StringExcludedPlayerList = GetPlayers(false, false), GetPlayers(true, false)

    for _, Value in next, Options do
        if Value.SetValues and Value.Type == "Dropdown" and Value.SpecialType == "Player" then
            Value:SetValues(
                if Value.ReturnInstanceInstead then
                    (if Value.ExcludeLocalPlayer then ExcludedPlayerList else PlayerList)
                else
                    (if Value.ExcludeLocalPlayer then StringExcludedPlayerList else StringPlayerList)
            )
        end
    end
end

local function OnTeamChange()
    if Library.Unloaded then
        return
    end
    
    local TeamList = GetTeams(false)
    local StringTeamList = GetTeams(true)

    for _, Value in next, Options do
        if Value.SetValues and Value.Type == "Dropdown" and Value.SpecialType == "Team" then
            Value:SetValues(if Value.ReturnInstanceInstead then TeamList else StringTeamList)
        end
    end
end

Library:GiveSignal(Players.PlayerAdded:Connect(OnPlayerChange))
Library:GiveSignal(Players.PlayerRemoving:Connect(OnPlayerChange))

Library:GiveSignal(Teams.ChildAdded:Connect(OnTeamChange))
Library:GiveSignal(Teams.ChildRemoved:Connect(OnTeamChange))

--// Rainbow Handler \\--
local RainbowStep = 0
local Hue = 0

Library:GiveSignal(RunService.RenderStepped:Connect(function(Delta)
    if Library.Unloaded then
        return
    end

    RainbowStep = RainbowStep + Delta
    if RainbowStep >= (1 / 60) then
        RainbowStep = 0

        Hue = Hue + (1 / 400)

        if Hue > 1 then
            Hue = 0
        end

        Library.CurrentRainbowHue = Hue
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1)
    end
end))

----
getgenv().Linoria = Library
if getgenv().skip_getgenv_linoria ~= true then getgenv().Library = Library end
return Library

]=])()
local ThemeManager = loadstring([=[
local cloneref = (cloneref or clonereference or function(instance: any)
    return instance
end)
local clonefunction = (clonefunction or copyfunction or function(func) 
    return func 
end)

local httprequest = request or http_request or (http and http.request)
local getassetfunc = getcustomasset

local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local isfolder, isfile, listfiles = isfolder, isfile, listfiles;

local assert = function(condition, errorMessage) 
    if (not condition) then
        error(if errorMessage then errorMessage else "assert failed", 3)
    end
end

if typeof(clonefunction) == "function" then
    -- Fix is_____ functions for shitsploits, those functions should never error, only return a boolean.

    local
        isfolder_copy,
        isfile_copy,
        listfiles_copy = clonefunction(isfolder), clonefunction(isfile), clonefunction(listfiles)

    local isfolder_success, isfolder_error = pcall(function()
        return isfolder_copy("test" .. tostring(math.random(1000000, 9999999)))
    end)

    if isfolder_success == false or typeof(isfolder_error) ~= "boolean" then
        isfolder = function(folder)
            local success, data = pcall(isfolder_copy, folder)
            if success then return data else return false end
        end

        isfile = function(file)
            local success, data = pcall(isfile_copy, file)
            if success then return data else return false end
        end

        listfiles = function(folder)
            local success, data = pcall(listfiles_copy, folder)
            if success then return data else return {} end
        end
    end
end

local ThemeManager = {} do
        local ThemeFields = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor", "VideoLink" }
        ThemeManager.Folder = "ZytheraXHub"
        ThemeManager.DefaultTheme = 'Zythera'
        -- if not isfolder(ThemeManager.Folder) then makefolder(ThemeManager.Folder) end

        ThemeManager.Library = nil
        ThemeManager.BuiltInThemes = {
                --// Premium deep-black themes (crimson ZX accent)
                ['Zythera']       = { 1, { FontColor = "ebebeb", MainColor = "0a0a0c", AccentColor = "e11e1e", BackgroundColor = "000000", OutlineColor = "1c1c1e" } },
                ['Zythera Dark']  = { 2, { FontColor = "dcdcdc", MainColor = "060606", AccentColor = "b51515", BackgroundColor = "000000", OutlineColor = "141416" } },
                ['Fatality']      = { 3, { FontColor = "ffffff", MainColor = "1e1842", AccentColor = "c50754", BackgroundColor = "191335", OutlineColor = "3c355d" } },
                ['Jester']        = { 4, { FontColor = "ffffff", MainColor = "242424", AccentColor = "db4467", BackgroundColor = "1c1c1c", OutlineColor = "373737" } },
                ['Mint']          = { 5, { FontColor = "ffffff", MainColor = "242424", AccentColor = "3db488", BackgroundColor = "1c1c1c", OutlineColor = "373737" } },
                ['Tokyo Night']   = { 6, { FontColor = "ffffff", MainColor = "191925", AccentColor = "6759b3", BackgroundColor = "16161f", OutlineColor = "323232" } },
                ['Ubuntu']        = { 7, { FontColor = "ffffff", MainColor = "3e3e3e", AccentColor = "e2581e", BackgroundColor = "323232", OutlineColor = "191919" } },
                ['Quartz']        = { 8, { FontColor = "ffffff", MainColor = "232330", AccentColor = "426e87", BackgroundColor = "1d1b26", OutlineColor = "27232f" } },
        }

        function ApplyBackgroundVideo(videoLink)
                if
                        typeof(videoLink) ~= "string" or
                        not (getassetfunc and writefile and readfile and isfile) or
                        not (ThemeManager.Library and ThemeManager.Library.InnerVideoBackground)
                then return; end;

                --// Variables \\--
                local videoInstance = ThemeManager.Library.InnerVideoBackground;
                local extension = videoLink:match(".*/(.-)?") or videoLink:match(".*/(.-)$"); extension = tostring(extension);
                local filename = string.sub(extension, 0, -6);
                local _, domain = videoLink:match("^(https?://)([^/]+)"); domain = tostring(domain); -- _ is protocol

                --// Check URL \\--
                if videoLink == "" then
                        videoInstance:Pause();
                        videoInstance.Video = "";
                        videoInstance.Visible = false;
                        return
                end
                if #extension > 5 and string.sub(extension, -5) ~= ".webm" then return; end;

                --// Fetch Video Data \\--
                local videoFile = ThemeManager.Folder .. "/themes/" .. string.gsub(domain .. filename, 0, 249) .. ".webm";
                if not isfile(videoFile) then
                        local success, requestRes = pcall(httprequest, { Url = videoLink, Method = 'GET' })
                        if not (success and typeof(requestRes) == "table" and typeof(requestRes.Body) == "string") then return; end;

                        writefile(videoFile, requestRes.Body)
                end

                --// Play Video \\--
                videoInstance.Video = getassetfunc(videoFile);
                videoInstance.Visible = true;
                videoInstance:Play();
        end

        function ThemeManager:SetLibrary(library)
                self.Library = library
        end

        --// Folders \\--
        function ThemeManager:GetPaths()
            local paths = {}

                local parts = self.Folder:split('/')
                for idx = 1, #parts do
                        paths[#paths + 1] = table.concat(parts, '/', 1, idx)
                end

                paths[#paths + 1] = self.Folder .. '/themes'
                
                return paths
        end

        function ThemeManager:BuildFolderTree()
                local paths = self:GetPaths()

                for i = 1, #paths do
                        local str = paths[i]
                        if isfolder(str) then continue end
                        makefolder(str)
                end
        end

        function ThemeManager:CheckFolderTree()
                if isfolder(self.Folder) then return end
                self:BuildFolderTree()

                task.wait(0.1)
        end

        function ThemeManager:SetFolder(folder)
                self.Folder = folder;
                self:BuildFolderTree()
        end
        
        --// Apply, Update theme \\--
        function ThemeManager:ApplyTheme(theme)
                local customThemeData = self:GetCustomTheme(theme)
                local data = customThemeData or self.BuiltInThemes[theme]

                if not data then return end

                -- custom themes are just regular dictionaries instead of an array with { index, dictionary }
                if self.Library.InnerVideoBackground ~= nil then
                        self.Library.InnerVideoBackground.Visible = false
                end
                
                local scheme = data[2]
                for idx, col in next, customThemeData or scheme do
                        if idx == "VideoLink" then
                                self.Library[idx] = col
                                
                                if self.Library.Options[idx] then
                                        self.Library.Options[idx]:SetValue(col)
                                end
                                
                                ApplyBackgroundVideo(col)
                        else
                                self.Library[idx] = Color3.fromHex(col)
                                
                                if self.Library.Options[idx] then
                                        self.Library.Options[idx]:SetValueRGB(Color3.fromHex(col))
                                end
                        end
                end

                self:ThemeUpdate()
        end

        function ThemeManager:ThemeUpdate()
                -- This allows us to force apply themes without loading the themes tab :)
                if self.Library.InnerVideoBackground ~= nil then
                        self.Library.InnerVideoBackground.Visible = false
                end

                for i, field in next, ThemeFields do
                        if self.Library.Options and self.Library.Options[field] then
                                self.Library[field] = self.Library.Options[field].Value

                                if field == "VideoLink" then
                                        ApplyBackgroundVideo(self.Library.Options[field].Value)
                                end
                        end
                end

                self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor);
                self.Library:UpdateColorsUsingRegistry()
        end

        --// Get, Load, Save, Delete, Refresh \\--
        function ThemeManager:GetCustomTheme(file)
                local path = self.Folder .. '/themes/' .. file .. '.json'
                if not isfile(path) then
                        return nil
                end

                local data = readfile(path)
                local success, decoded = pcall(HttpService.JSONDecode, HttpService, data)
                
                if not success then
                        return nil
                end

                return decoded
        end

        function ThemeManager:LoadDefault()
                local theme = 'Zythera'
                local content = isfile(self.Folder .. '/themes/default.txt') and readfile(self.Folder .. '/themes/default.txt')

                local isDefault = true
                if content then
                        if self.BuiltInThemes[content] then
                                theme = content
                        elseif self:GetCustomTheme(content) then
                                theme = content
                                isDefault = false;
                        end
                elseif self.BuiltInThemes[self.DefaultTheme] then
                        theme = self.DefaultTheme
                end

                if isDefault then
                        self.Library.Options.ThemeManager_ThemeList:SetValue(theme)
                else
                        self:ApplyTheme(theme)
                end
        end

        function ThemeManager:SaveDefault(theme)
                writefile(self.Folder .. '/themes/default.txt', theme)
        end

        function ThemeManager:SaveCustomTheme(file)
                if file:gsub(' ', '') == '' then
                        self.Library:Notify('Invalid file name for theme (empty)', 3)
                        return
                end

                local theme = {}
                for _, field in next, ThemeFields do
                        if field == "VideoLink" then
                                theme[field] = self.Library.Options[field].Value
                        else
                                theme[field] = self.Library.Options[field].Value:ToHex()
                        end
                end

                writefile(self.Folder .. '/themes/' .. file .. '.json', HttpService:JSONEncode(theme))
        end

        function ThemeManager:Delete(name)
                if (not name) then
                        return false, 'no config file is selected'
                end

                local file = self.Folder .. '/themes/' .. name .. '.json'
                if not isfile(file) then return false, 'invalid file' end

                local success = pcall(delfile, file)
                if not success then return false, 'delete file error' end
                
                return true
        end
        
        function ThemeManager:ReloadCustomThemes()
                local list = listfiles(self.Folder .. '/themes')

                local out = {}
                for i = 1, #list do
                        local file = list[i]
                        if file:sub(-5) == '.json' then
                                -- i hate this but it has to be done ...

                                local pos = file:find('.json', 1, true)
                                local start = pos

                                local char = file:sub(pos, pos)
                                while char ~= '/' and char ~= '\\' and char ~= '' do
                                        pos = pos - 1
                                        char = file:sub(pos, pos)
                                end

                                if char == '/' or char == '\\' then
                                        table.insert(out, file:sub(pos + 1, start - 1))
                                end
                        end
                end

                return out
        end

        --// GUI \\--
        function ThemeManager:CreateThemeManager(groupbox)
                groupbox:AddLabel('Background color'):AddColorPicker('BackgroundColor', { Default = self.Library.BackgroundColor });
                groupbox:AddLabel('Main color') :AddColorPicker('MainColor', { Default = self.Library.MainColor });
                groupbox:AddLabel('Accent color'):AddColorPicker('AccentColor', { Default = self.Library.AccentColor });
                groupbox:AddLabel('Outline color'):AddColorPicker('OutlineColor', { Default = self.Library.OutlineColor });
                groupbox:AddLabel('Font color') :AddColorPicker('FontColor', { Default = self.Library.FontColor });
                groupbox:AddInput('VideoLink', { Text = '.webm Video Background (Link)', Default = self.Library.VideoLink });
                
                local ThemesArray = {}
                for Name, Theme in next, self.BuiltInThemes do
                        table.insert(ThemesArray, Name)
                end

                table.sort(ThemesArray, function(a, b) return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1] end)

                groupbox:AddDivider()

                groupbox:AddDropdown('ThemeManager_ThemeList', { Text = 'Theme list', Values = ThemesArray, Default = 1 })
                groupbox:AddButton('Set as default', function()
                        self:SaveDefault(self.Library.Options.ThemeManager_ThemeList.Value)
                        self.Library:Notify(string.format('Set default theme to %q', self.Library.Options.ThemeManager_ThemeList.Value))
                end)

                self.Library.Options.ThemeManager_ThemeList:OnChanged(function()
                        self:ApplyTheme(self.Library.Options.ThemeManager_ThemeList.Value)
                end)

                groupbox:AddDivider()

                groupbox:AddInput('ThemeManager_CustomThemeName', { Text = 'Custom theme name' })
                groupbox:AddButton('Create theme', function() 
                        local name = self.Library.Options.ThemeManager_CustomThemeName.Value
                        if name:gsub(" ", "") == "" then
                self.Library:Notify("Invalid theme name (empty)", 2)
                return
            end

            self:SaveCustomTheme(name)

            self.Library:Notify(string.format("Created theme %q", name))
                        self.Library.Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
                        self.Library.Options.ThemeManager_CustomThemeList:SetValue(nil)
                end)

                groupbox:AddDivider()

                groupbox:AddDropdown('ThemeManager_CustomThemeList', { Text = 'Custom themes', Values = self:ReloadCustomThemes(), AllowNull = true, Default = 1 })
                groupbox:AddButton('Load theme', function()
                        local name = self.Library.Options.ThemeManager_CustomThemeList.Value

                        self:ApplyTheme(name)
                        self.Library:Notify(string.format('Loaded theme %q', name))
                end)
                groupbox:AddButton('Overwrite theme', function()
                        local name = self.Library.Options.ThemeManager_CustomThemeList.Value

                        self:SaveCustomTheme(name)
                        self.Library:Notify(string.format('Overwrote config %q', name))
                end)
                groupbox:AddButton('Delete theme', function()
                        local name = self.Library.Options.ThemeManager_CustomThemeList.Value

                        local success, err = self:Delete(name)
                        if not success then
                                self.Library:Notify('Failed to delete theme: ' .. err)
                                return
                        end

                        self.Library:Notify(string.format('Deleted theme %q', name))
                        self.Library.Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
                        self.Library.Options.ThemeManager_CustomThemeList:SetValue(nil)
                end)
                groupbox:AddButton('Refresh list', function()
                        self.Library.Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
                        self.Library.Options.ThemeManager_CustomThemeList:SetValue(nil)
                end)
                groupbox:AddButton('Set as default', function()
                        if self.Library.Options.ThemeManager_CustomThemeList.Value ~= nil and self.Library.Options.ThemeManager_CustomThemeList.Value ~= '' then
                                self:SaveDefault(self.Library.Options.ThemeManager_CustomThemeList.Value)
                                self.Library:Notify(string.format('Set default theme to %q', self.Library.Options.ThemeManager_CustomThemeList.Value))
                        end
                end)
                groupbox:AddButton('Reset default', function()
                        local success = pcall(delfile, self.Folder .. '/themes/default.txt')
                        if not success then 
                                self.Library:Notify('Failed to reset default: delete file error')
                                return
                        end
                                
                        self.Library:Notify('Set default theme to nothing')
                        self.Library.Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
                        self.Library.Options.ThemeManager_CustomThemeList:SetValue(nil)
                end)

                self:LoadDefault()

                local function UpdateTheme() self:ThemeUpdate() end
                self.Library.Options.BackgroundColor:OnChanged(UpdateTheme)
                self.Library.Options.MainColor:OnChanged(UpdateTheme)
                self.Library.Options.AccentColor:OnChanged(UpdateTheme)
                self.Library.Options.OutlineColor:OnChanged(UpdateTheme)
                self.Library.Options.FontColor:OnChanged(UpdateTheme)
        end

        function ThemeManager:CreateGroupBox(tab)
                assert(self.Library, 'ThemeManager:CreateGroupBox -> Must set ThemeManager.Library first!')
                return tab:AddLeftGroupbox('Themes')
        end

        function ThemeManager:ApplyToTab(tab)
                assert(self.Library, 'ThemeManager:ApplyToTab -> Must set ThemeManager.Library first!')
                local groupbox = self:CreateGroupBox(tab)
                self:CreateThemeManager(groupbox)
        end

        function ThemeManager:ApplyToGroupbox(groupbox)
                assert(self.Library, 'ThemeManager:ApplyToGroupbox -> Must set ThemeManager.Library first!')
                self:CreateThemeManager(groupbox)
        end

        ThemeManager:BuildFolderTree()
end

getgenv().LinoriaThemeManager = ThemeManager
return ThemeManager
]=])()
local SaveManager = loadstring([=[
local cloneref = (cloneref or clonereference or function(instance: any)
    return instance
end)
local clonefunction = (clonefunction or copyfunction or function(func) 
    return func 
end)

local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local isfolder, isfile, listfiles = isfolder, isfile, listfiles;

local assert = function(condition, errorMessage) 
    if (not condition) then
        error(if errorMessage then errorMessage else "assert failed", 3)
    end
end

if typeof(clonefunction) == "function" then
    -- Fix is_____ functions for shitsploits, those functions should never error, only return a boolean.

    local
        isfolder_copy,
        isfile_copy,
        listfiles_copy = clonefunction(isfolder), clonefunction(isfile), clonefunction(listfiles)

    local isfolder_success, isfolder_error = pcall(function()
        return isfolder_copy("test" .. tostring(math.random(1000000, 9999999)))
    end)

    if isfolder_success == false or typeof(isfolder_error) ~= "boolean" then
        isfolder = function(folder)
            local success, data = pcall(isfolder_copy, folder)
            if success then return data else return false end
        end

        isfile = function(file)
            local success, data = pcall(isfile_copy, file)
            if success then return data else return false end
        end

        listfiles = function(folder)
            local success, data = pcall(listfiles_copy, folder)
            if success then return data else return {} end
        end
    end
end

local SaveManager = {} do
    SaveManager.Folder = "LinoriaLibSettings"
    SaveManager.SubFolder = ""
    SaveManager.Ignore = {}
    SaveManager.Library = nil
    SaveManager.UseLoadingOrder = false
    SaveManager.LoadingOrder = {}
    SaveManager.Parser = {
        Toggle = {
            Save = function(idx, object)
                return { type = 'Toggle', idx = idx, value = object.Value }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Toggles[idx]
                if object and object.Value ~= data.value then
                    object:SetValue(data.value)
                end
            end,
        },
        Slider = {
            Save = function(idx, object)
                return { type = 'Slider', idx = idx, value = tostring(object.Value) }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Options[idx]
                if object and object.Value ~= data.value then
                    object:SetValue(data.value)
                end
            end,
        },
        Dropdown = {
            Save = function(idx, object)
                return { type = 'Dropdown', idx = idx, value = object.Value, multi = object.Multi }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Options[idx]
                if object and object.Value ~= data.value then
                    object:SetValue(data.value)
                end
            end,
        },
        ColorPicker = {
            Save = function(idx, object)
                return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
            end,
            Load = function(idx, data)
                if SaveManager.Library.Options[idx] then
                    SaveManager.Library.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
                end
            end,
        },
        KeyPicker = {
            Save = function(idx, object)
                return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value, modifiers = object.Modifiers }
            end,
            Load = function(idx, data)
                if SaveManager.Library.Options[idx] then
                    SaveManager.Library.Options[idx]:SetValue({ data.key, data.mode, data.modifiers })
                end
            end,
        },
        Input = {
            Save = function(idx, object)
                return { type = 'Input', idx = idx, text = object.Value }
            end,
            Load = function(idx, data)
                local object = SaveManager.Library.Options[idx]
                if object and object.Value ~= data.text and type(data.text) == 'string' then
                    SaveManager.Library.Options[idx]:SetValue(data.text)
                end
            end,
        },
    }

    function SaveManager:SetLibrary(library)
        self.Library = library
    end

    function SaveManager:SetLoadingOrder(enabled, order)
        self.UseLoadingOrder = enabled

        if typeof(order) == "table" then
            self.LoadingOrder = order
        end
    end

    function SaveManager:IgnoreThemeSettings()
        self:SetIgnoreIndexes({
            "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", -- themes
            "ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
            "VideoLink",
        })
    end

    --// Folders \\--
    function SaveManager:CheckSubFolder(createFolder)
        if typeof(self.SubFolder) ~= "string" or self.SubFolder == "" then return false end

        if createFolder == true then
            if not isfolder(self.Folder .. "/settings/" .. self.SubFolder) then
                makefolder(self.Folder .. "/settings/" .. self.SubFolder)
            end
        end

        return true
    end

    function SaveManager:GetPaths()
        local paths = {}

        local parts = self.Folder:split('/')
        for idx = 1, #parts do
            local path = table.concat(parts, '/', 1, idx)
            if not table.find(paths, path) then paths[#paths + 1] = path end
        end

        paths[#paths + 1] = self.Folder .. '/themes'
        paths[#paths + 1] = self.Folder .. '/settings'

        if self:CheckSubFolder(false) then
            local subFolder = self.Folder .. "/settings/" .. self.SubFolder
            parts = subFolder:split('/')

            for idx = 1, #parts do
                local path = table.concat(parts, '/', 1, idx)
                if not table.find(paths, path) then paths[#paths + 1] = path end
            end
        end

        return paths
    end

    function SaveManager:BuildFolderTree()
        local paths = self:GetPaths()

        for i = 1, #paths do
            local str = paths[i]
            if isfolder(str) then continue end

            makefolder(str)
        end
    end

    function SaveManager:CheckFolderTree()
        if isfolder(self.Folder) then return end
        SaveManager:BuildFolderTree()

        task.wait(0.1)
    end

    function SaveManager:SetIgnoreIndexes(list)
        for _, key in next, list do
            self.Ignore[key] = true
        end
    end

    function SaveManager:SetFolder(folder)
        self.Folder = folder;
        self:BuildFolderTree()
    end

    function SaveManager:SetSubFolder(folder)
        self.SubFolder = folder;
        self:BuildFolderTree()
    end

    --// Save, Load, Delete, Refresh \\--
    function SaveManager:Save(name)
        if (not name) then
            return false, 'no config file is selected'
        end
        SaveManager:CheckFolderTree()

        local fullPath = self.Folder .. '/settings/' .. name .. '.json'
        if SaveManager:CheckSubFolder(true) then
            fullPath = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. '.json'
        end

        local data = {
            objects = {}
        }

        for idx, toggle in next, self.Library.Toggles do
            if not toggle.Type then continue end
            if not self.Parser[toggle.Type] then continue end
            if self.Ignore[idx] then continue end

            table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
        end

        for idx, option in next, self.Library.Options do
            if not option.Type then continue end
            if not self.Parser[option.Type] then continue end
            if self.Ignore[idx] then continue end

            table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
        end

        local success, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if not success then
            return false, 'failed to encode data'
        end

        writefile(fullPath, encoded)
        return true
    end

    function SaveManager:Load(name)
        if (not name) then
            return false, 'no config file is selected'
        end
        SaveManager:CheckFolderTree()

        local file = self.Folder .. '/settings/' .. name .. '.json'
        if SaveManager:CheckSubFolder(true) then
            file = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. '.json'
        end

        if not isfile(file) then return false, 'invalid file' end

        local success, decoded = pcall(HttpService.JSONDecode, HttpService, readfile(file))
        if not success then return false, 'decode error' end

        if self.UseLoadingOrder == true and typeof(self.LoadingOrder) == "table" then
            table.sort(decoded.objects, function(a, b)
                local aIndex = table.find(self.LoadingOrder, a.type) or math.huge
                local bIndex = table.find(self.LoadingOrder, b.type) or math.huge
                return aIndex < bIndex
            end)
        end

        for _, option in decoded.objects do
            if not option.type then continue end
            if not self.Parser[option.type] then continue end
            if self.Ignore[option.idx] then continue end

            task.spawn(self.Parser[option.type].Load, option.idx, option) -- task.spawn() so the config loading wont get stuck.
        end

        return true
    end

    function SaveManager:Delete(name)
        if (not name) then
            return false, 'no config file is selected'
        end

        local file = self.Folder .. '/settings/' .. name .. '.json'
        if SaveManager:CheckSubFolder(true) then
            file = self.Folder .. "/settings/" .. self.SubFolder .. "/" .. name .. '.json'
        end

        if not isfile(file) then return false, 'invalid file' end

        local success = pcall(delfile, file)
        if not success then return false, 'delete file error' end

        return true
    end

    function SaveManager:RefreshConfigList()
        local success, data = pcall(function()
            SaveManager:CheckFolderTree()

            local list = {}
            local out = {}

            if SaveManager:CheckSubFolder(true) then
                list = listfiles(self.Folder .. "/settings/" .. self.SubFolder)
            else
                list = listfiles(self.Folder .. "/settings")
            end
            if typeof(list) ~= "table" then list = {} end

            for i = 1, #list do
                local file = list[i]
                if file:sub(-5) == '.json' then
                    -- i hate this but it has to be done ...

                    local pos = file:find('.json', 1, true)
                    local start = pos

                    local char = file:sub(pos, pos)
                    while char ~= '/' and char ~= '\\' and char ~= '' do
                        pos = pos - 1
                        char = file:sub(pos, pos)
                    end

                    if char == '/' or char == '\\' then
                        table.insert(out, file:sub(pos + 1, start - 1))
                    end
                end
            end

            return out
        end)

        if (not success) then
            if self.Library then
                self.Library:Notify('Failed to load config list: ' .. tostring(data))
            else
                warn('Failed to load config list: ' .. tostring(data))
            end

            return {}
        end

        return data
    end

    --// Auto Load \\--
    function SaveManager:GetAutoloadConfig()
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        if isfile(autoLoadPath) then
            local successRead, name = pcall(readfile, autoLoadPath)
            if not successRead then
                return "none"
            end

            name = tostring(name)
            return if name == "" then "none" else name
        end

        return "none"
    end

    function SaveManager:LoadAutoloadConfig()
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        if isfile(autoLoadPath) then
            local successRead, name = pcall(readfile, autoLoadPath)
            if not successRead then
                self.Library:Notify('Failed to load autoload config: write file error')
                return
            end

            local success, err = self:Load(name)
            if not success then
                self.Library:Notify('Failed to load autoload config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Auto loaded config %q', name))
        end
    end

    function SaveManager:SaveAutoloadConfig(name)
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        local success = pcall(writefile, autoLoadPath, name)
        if not success then return false, 'write file error' end

        return true, ""
    end

    function SaveManager:DeleteAutoLoadConfig()
        SaveManager:CheckFolderTree()

        local autoLoadPath = self.Folder .. "/settings/autoload.txt"
        if SaveManager:CheckSubFolder(true) then
            autoLoadPath = self.Folder .. "/settings/" .. self.SubFolder .. "/autoload.txt"
        end

        local success = pcall(delfile, autoLoadPath)
        if not success then return false, 'delete file error' end

        return true, ""
    end

    --// GUI \\--
    function SaveManager:BuildConfigSection(tab)
        assert(self.Library, 'SaveManager:BuildConfigSection -> Must set SaveManager.Library')

        local section = tab:AddRightGroupbox('Configuration')

        section:AddInput('SaveManager_ConfigName',    { Text = 'Config name' })
        section:AddButton('Create config', function()
            local name = self.Library.Options.SaveManager_ConfigName.Value

            if name:gsub(' ', '') == '' then
                self.Library:Notify('Invalid config name (empty)', 2)
                return
            end

            local success, err = self:Save(name)
            if not success then
                self.Library:Notify('Failed to create config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Created config %q', name))

            self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            self.Library.Options.SaveManager_ConfigList:SetValue(nil)
        end)

        section:AddDivider()

        section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })
        section:AddButton('Load config', function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:Load(name)
            if not success then
                self.Library:Notify('Failed to load config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Loaded config %q', name))
        end)
        section:AddButton('Overwrite config', function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:Save(name)
            if not success then
                self.Library:Notify('Failed to overwrite config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Overwrote config %q', name))
        end)

        section:AddButton('Delete config', function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:Delete(name)
            if not success then
                self.Library:Notify('Failed to delete config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Deleted config %q', name))
            self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            self.Library.Options.SaveManager_ConfigList:SetValue(nil)
        end)

        section:AddButton('Refresh list', function()
            self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            self.Library.Options.SaveManager_ConfigList:SetValue(nil)
        end)

        section:AddButton('Set as autoload', function()
            local name = self.Library.Options.SaveManager_ConfigList.Value

            local success, err = self:SaveAutoloadConfig(name)
            if not success then
                self.Library:Notify('Failed to set autoload config: ' .. err)
                return
            end

            self.Library:Notify(string.format('Set %q to auto load', name))
            self.AutoloadConfigLabel:SetText('Current autoload config: ' .. name)
        end)
        section:AddButton('Reset autoload', function()
            local success, err = self:DeleteAutoLoadConfig()
            if not success then
                self.Library:Notify('Failed to set autoload config: ' .. err)
                return
            end

            self.Library:Notify('Set autoload to none')
            self.AutoloadConfigLabel:SetText('Current autoload config: none')
        end)

        self.AutoloadConfigLabel = section:AddLabel("Current autoload config: " .. self:GetAutoloadConfig(), true)

        -- self:LoadAutoloadConfig()
        self:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
    end

    SaveManager:BuildFolderTree()
end

return SaveManager

]=])()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ShowToggleFrameInKeybinds = true
Library.ShowCustomCursor = true
Library.NotifySide = "Left"

local Window = Library:CreateWindow({
        Title = '<font color="#e11e1e">Z</font>ythera-<font color="#e11e1e">X</font>',
        Center = true,
        AutoShow = false,  -- Disabled — we show a custom loading screen first
        Resizable = true,
        ShowCustomCursor = true,
        UnlockMouseWhileOpen = true,
        NotifySide = "Left",
        TabPadding = 8,
        MenuFadeTime = 0.2,
        --// Smaller window size (was 750x700 — too big)
        Size = UDim2.fromOffset(560, 540),
})

--// LOADING SCREEN — Clean dark design with ZX logo (use at your own risk)
-- The script actually loads WHILE this screen is visible (task.spawn runs in parallel).
-- Heavy initializations (UI library, ESP system, hooks) happen during the ~3s loading period.
-- Wrapped in a `do ... end` block to release locals after the screen is built (Lua has a 200 local limit).
do
local LoadingScreenGui = Instance.new("ScreenGui")
LoadingScreenGui.Name = "ZytheraXLoadingScreen"
LoadingScreenGui.IgnoreGuiInset = true
LoadingScreenGui.ResetOnSpawn = false
LoadingScreenGui.DisplayOrder = 9999
LoadingScreenGui.Parent = gethui and gethui() or game:GetService("CoreGui")

--// Background — deep matte black with subtle vignette
local LoadingBg = Instance.new("Frame")
LoadingBg.Name = "Background"
LoadingBg.Size = UDim2.new(1, 0, 1, 0)
LoadingBg.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
LoadingBg.BorderSizePixel = 0
LoadingBg.Parent = LoadingScreenGui

-- Subtle radial vignette (darker at edges, slightly lighter center)
local BgGradient = Instance.new("UIGradient")
BgGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 14, 16)),
    ColorSequenceKeypoint.new(0.7, Color3.fromRGB(8, 6, 8)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 2, 3)),
})
BgGradient.Rotation = 0
BgGradient.Parent = LoadingBg

--// Main container — sleek dark card with refined red accent
local LoadingContainer = Instance.new("Frame")
LoadingContainer.Name = "Container"
LoadingContainer.Size = UDim2.new(0, 420, 0, 300)
LoadingContainer.Position = UDim2.new(0.5, -210, 0.5, -150)
LoadingContainer.BackgroundColor3 = Color3.fromRGB(14, 14, 17)
LoadingContainer.BorderSizePixel = 0
LoadingContainer.Parent = LoadingBg

local LoadingCorner = Instance.new("UICorner")
LoadingCorner.CornerRadius = UDim.new(0, 10)
LoadingCorner.Parent = LoadingContainer

-- Thin refined border (not a glow — just a clean edge)
local LoadingBorder = Instance.new("UIStroke")
LoadingBorder.Color = Color3.fromRGB(35, 28, 30)
LoadingBorder.Thickness = 1
LoadingBorder.Transparency = 0
LoadingBorder.Parent = LoadingContainer

--// ZX LOGO — clean monospace-style mark above the title
local ZxLogo = Instance.new("TextLabel")
ZxLogo.Name = "ZXLogo"
ZxLogo.Size = UDim2.new(1, 0, 0, 70)
ZxLogo.Position = UDim2.new(0, 0, 0, 30)
ZxLogo.BackgroundTransparency = 1
ZxLogo.Font = Enum.Font.GothamBlack
ZxLogo.TextSize = 58
ZxLogo.TextColor3 = Color3.fromRGB(255, 255, 255)
ZxLogo.Text = '<font color="#e11e1e">Z</font><font color="#ffffff">X</font>'
ZxLogo.RichText = true
ZxLogo.Parent = LoadingContainer

-- Thin accent line under the logo (acts as a divider)
local LogoLine = Instance.new("Frame")
LogoLine.Name = "LogoLine"
LogoLine.Size = UDim2.new(0, 40, 0, 2)
LogoLine.Position = UDim2.new(0.5, -20, 0, 110)
LogoLine.BackgroundColor3 = Color3.fromRGB(225, 30, 30)
LogoLine.BorderSizePixel = 0
LogoLine.Parent = LoadingContainer

local LogoLineCorner = Instance.new("UICorner")
LogoLineCorner.CornerRadius = UDim.new(1, 0)
LogoLineCorner.Parent = LogoLine

--// Title (script name — small, refined)
local LoadingTitle = Instance.new("TextLabel")
LoadingTitle.Name = "Title"
LoadingTitle.Size = UDim2.new(1, 0, 0, 22)
LoadingTitle.Position = UDim2.new(0, 0, 0, 125)
LoadingTitle.BackgroundTransparency = 1
LoadingTitle.Font = Enum.Font.GothamMedium
LoadingTitle.TextSize = 16
LoadingTitle.TextColor3 = Color3.fromRGB(230, 230, 235)
LoadingTitle.Text = "ZYTHERA - X"
LoadingTitle.Parent = LoadingContainer

--// Subtitle (status text — small, muted)
local LoadingSubtitle = Instance.new("TextLabel")
LoadingSubtitle.Name = "Subtitle"
LoadingSubtitle.Size = UDim2.new(1, 0, 0, 18)
LoadingSubtitle.Position = UDim2.new(0, 0, 0, 155)
LoadingSubtitle.BackgroundTransparency = 1
LoadingSubtitle.Font = Enum.Font.Gotham
LoadingSubtitle.TextSize = 12
LoadingSubtitle.TextColor3 = Color3.fromRGB(120, 120, 130)
LoadingSubtitle.Text = "Initializing..."
LoadingSubtitle.Parent = LoadingContainer

--// Progress bar — minimal, clean
local ProgressBg = Instance.new("Frame")
ProgressBg.Name = "ProgressBg"
ProgressBg.Size = UDim2.new(0, 340, 0, 4)
ProgressBg.Position = UDim2.new(0.5, -170, 0, 195)
ProgressBg.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
ProgressBg.BorderSizePixel = 0
ProgressBg.Parent = LoadingContainer

local ProgressCorner = Instance.new("UICorner")
ProgressCorner.CornerRadius = UDim.new(1, 0)
ProgressCorner.Parent = ProgressBg

-- Progress bar fill — solid red, no flashy gradient
local ProgressFill = Instance.new("Frame")
ProgressFill.Name = "ProgressFill"
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = Color3.fromRGB(225, 30, 30)
ProgressFill.BorderSizePixel = 0
ProgressFill.Parent = ProgressBg
ProgressFill.ClipsDescendants = true

local FillCorner = Instance.new("UICorner")
FillCorner.CornerRadius = UDim.new(1, 0)
FillCorner.Parent = ProgressFill

--// Percentage + status row (clean, side-by-side look)
local ProgressText = Instance.new("TextLabel")
ProgressText.Name = "ProgressText"
ProgressText.Size = UDim2.new(1, 0, 0, 20)
ProgressText.Position = UDim2.new(0, 0, 0, 210)
ProgressText.BackgroundTransparency = 1
ProgressText.Font = Enum.Font.GothamMedium
ProgressText.TextSize = 12
ProgressText.TextColor3 = Color3.fromRGB(180, 180, 190)
ProgressText.Text = "0%"
ProgressText.Parent = LoadingContainer

--// Bottom disclaimer — "Use at your own risk" warning
local HintText = Instance.new("TextLabel")
HintText.Name = "Hint"
HintText.Size = UDim2.new(1, 0, 0, 16)
HintText.Position = UDim2.new(0, 0, 0, 255)
HintText.BackgroundTransparency = 1
HintText.Font = Enum.Font.Gotham
HintText.TextSize = 10
HintText.TextColor3 = Color3.fromRGB(90, 90, 100)
HintText.Text = "use at your own risk"
HintText.Parent = LoadingContainer

--// ANIMATIONS — minimal, professional
-- Only 3 subtle effects: logo pulse, accent line breathe, progress gradient shift (subtle)
local animTime = 0

task.spawn(function()
    while LoadingScreenGui and LoadingScreenGui.Parent do
        animTime = animTime + 0.04

        -- Subtle logo opacity pulse (very gentle)
        pcall(function()
            local pulse = (math.sin(animTime * 1.2) + 1) / 2  -- 0 to 1
            ZxLogo.TextTransparency = 0.05 + (pulse * 0.1)
        end)

        -- Accent line width breathe (subtle)
        pcall(function()
            local breath = (math.sin(animTime * 1.5) + 1) / 2
            LogoLine.Size = UDim2.new(0, 40 + breath * 8, 0, 2)
            LogoLine.Position = UDim2.new(0.5, -20 - breath * 4, 0, 110)
        end)

        task.wait()
    end
end)

--// LOADING ANIMATION — progress from 0% to 100% over ~3 seconds
-- During this time, the rest of the script continues to load (UI library, hooks, ESP, etc.)
local loadingStartTime = tick()
local loadingDuration = 3.0
local loadingSteps = {
    { time = 0.0,  text = "initializing core..." },
    { time = 0.5,  text = "loading modules..." },
    { time = 1.0,  text = "setting up combat..." },
    { time = 1.5,  text = "loading visuals..." },
    { time = 2.0,  text = "applying hooks..." },
    { time = 2.5,  text = "finalizing..." },
}

task.spawn(function()
    local stepIdx = 1
    while true do
        local elapsed = tick() - loadingStartTime
        local progress = math.clamp(elapsed / loadingDuration, 0, 1)

        -- Smooth ease-out progress (starts fast, settles near 100%)
        local easedProgress = 1 - ((1 - progress) ^ 2.5)

        -- Update progress bar fill
        ProgressFill.Size = UDim2.new(easedProgress, 0, 1, 0)
        ProgressText.Text = tostring(math.floor(easedProgress * 100)) .. "%"

        -- Update subtitle text based on time
        if stepIdx <= #loadingSteps and elapsed >= loadingSteps[stepIdx].time then
            LoadingSubtitle.Text = loadingSteps[stepIdx].text
            stepIdx = stepIdx + 1
        end

        if elapsed >= loadingDuration then
            break
        end
        task.wait(0.04)
    end

    -- Final state
    ProgressFill.Size = UDim2.new(1, 0, 1, 0)
    ProgressText.Text = "100%"
    LoadingSubtitle.Text = "ready"
    task.wait(0.35)

    -- Clean fade out (everything fades together)
    local fadeStart = tick()
    while tick() - fadeStart < 0.5 do
        local alpha = (tick() - fadeStart) / 0.5
        LoadingBg.BackgroundTransparency = alpha
        LoadingContainer.BackgroundTransparency = alpha
        LoadingBorder.Transparency = alpha
        LoadingTitle.TextTransparency = alpha
        LoadingSubtitle.TextTransparency = alpha
        ProgressBg.BackgroundTransparency = alpha
        ProgressFill.BackgroundTransparency = alpha
        ProgressText.TextTransparency = alpha
        HintText.TextTransparency = alpha
        ZxLogo.TextTransparency = alpha
        LogoLine.BackgroundTransparency = alpha
        task.wait()
    end

    -- Destroy loading screen
    LoadingScreenGui:Destroy()

    -- Now show the main UI
    pcall(function()
        Library:Toggle(true)
    end)
end)
end  -- end of loading screen `do` block (releases ~20 locals)

--// TAB LAYOUT SYSTEM
local Tabs = {
        Combat = Window:AddTab("Combat"),
        ESP = Window:AddTab("ESP"),
        Visuals = Window:AddTab("Visuals"),
        Player = Window:AddTab("Player"),
        Misc = Window:AddTab("Misc"),
        ["UI Settings"] = Window:AddTab("UI Settings"),
}

-- GROUPBOX INTERFACES
local RageModeGroup = Tabs.Combat:AddRightGroupbox("Rage Mode")
local SilentAimGroup = Tabs.Combat:AddLeftGroupbox("Silent Aim")
local GunModsAimGroup = Tabs.Combat:AddLeftGroupbox("Gun Mods")
local GunModsAmmoGroup = GunModsAimGroup  -- [V8] merged into one box
local GunModsMiscGroup = GunModsAimGroup  -- [V8] merged into one box
local HoldBotGroup = Tabs.Combat:AddRightGroupbox("Aimbot")
local TeamCheckGroup = Tabs.Combat:AddLeftGroupbox("Team Check")
local HoldBotTargetGroup = HoldBotGroup  -- [V8] merged into Aimbot box
local TriggerBotGroup = Tabs.Combat:AddRightGroupbox("Trigger Bot")
local AntiAimGroup = Tabs.Combat:AddRightGroupbox("Anti-Aim")
local OrbitGroup = Tabs.Combat:AddRightGroupbox("Orbit")
local EspGroup = Tabs.ESP:AddLeftGroupbox("ESP Switches")
local EspVisualGroup = Tabs.ESP:AddRightGroupbox("ESP Appearance")
local VisualsGroup = Tabs.Visuals:AddLeftGroupbox("Visual Customization")
local SkyColorGroup = Tabs.Visuals:AddRightGroupbox("Sky Color Override")
local GrenadeEffectsGroup = Tabs.Visuals:AddRightGroupbox("Grenade Effects")
local WinStreakGroup = Tabs.Visuals:AddRightGroupbox("Chat Win Streak Simulator")
local PlayerMovementGroup = Tabs.Player:AddLeftGroupbox("Movement")
local PlayerTogglesGroup = Tabs.Player:AddRightGroupbox("Toggles & Emergency")
local PlayerFlyGroup = Tabs.Player:AddRightGroupbox("Fly")
local TeleportKillGroup = Tabs.Player:AddLeftGroupbox("Teleport Kill")
local PlayerServerGroup = Tabs.Player:AddRightGroupbox("Server")
local SkinChangerGroup = Tabs.Misc:AddLeftGroupbox("Skin Changer")
local MiscGroup = Tabs.Misc:AddLeftGroupbox("Device Spoofer Options")
local TeamDebugGroup = Tabs.Misc:AddRightGroupbox("Team Debug")

--// TEAM CHECK SETTINGS (Prevents targeting teammates — TeamID only)
local TeamCheck = {
    Enabled = true,            -- ON by default — don't shoot teammates!
    DebugMode = false,         -- When ON, prints team check results to console
}


--// SILENT AIM SETTINGS (Bullet Redirection via Raycast Hook)
local SilentAim = {
    Enabled = false,
    Prediction = 0.12,       -- [V2] Better default prediction (was 0)
    WallCheck = false,
    HitPart = "Head",        -- Default target part (replaces HeadshotRate)
    HitCooldown = 0.01,      -- [V6] 10ms default — first bullet hits, then 10ms cooldown
    FOV = 150,
    FovVisible = false,
    FovFilled = false,
    FovColor = Color3.fromRGB(255, 255, 255),
    FovRainbow = false,
    MaxDistance = 500,
    ProjectilePrediction = false,
    _lastHitTime = 0,         -- [V5] Internal: tracks when the last silent aim hit occurred
}

-- [V5] New hit system: first bullet hits, then cooldown before next hit
-- If enough time has passed since the last hit, this bullet hits.
-- Otherwise, the bullet goes to the normal crosshair position (no redirect).
local function silentAimShouldHit()
    local now = tick()
    if (now - SilentAim._lastHitTime) >= SilentAim.HitCooldown then
        SilentAim._lastHitTime = now
        return true
    end
    return false
end

--// AIMBOT SETTINGS REMOVED — Replaced by HoldBot with keybind

--// TRIGGER BOT SETTINGS (Auto-fire when crosshair is on enemy)
local TriggerBot = {
    Enabled = false,
    Delay = 0.05,           -- Seconds to wait before firing after detecting target (0.05-0.3)
    WallCheck = true,        -- Only fire if target is visible (not behind walls)
    Keybind = false,         -- When true, only fires while holding the key
    LastDetected = 0,        -- Internal: tracks when target was first detected
}

--// ESP SETTINGS
local EspSettings = {
    EspBoxes = false,
    EspFilledBoxes = false,
    EspLines = false,
    EspHealth = false,
    EspNames = false,
    EspDistance = false,
    EspChams = false,
    EspSkeleton = false,       -- Skeleton ESP (bone lines)
    EspGlowChams = false,      -- Glow Chams (enhanced highlight with always-on-top + glow fill)
    EspEnemyWeapons = false,   -- Show enemy weapon names on ESP
    EspColorMode = "Blue",
    EspFilledColorMode = "Blue",
    EspChamsColorMode = "Cyan",
    EspGlowColorMode = "Cyan",
    MaxEspDistance = 400,
    BoxThickness = 1.5,
    LineThickness = 1.0,
    BoxSizeMultiplier = 1300,
    ChamsBrightness = 5.0,
    GlowBrightness = 3.0,
    FilledBoxTransparency = 0.4,
    HeadScale = 1.0,           -- Client-side head hitbox enlargement (1=normal, 2=double, etc.)
    TeamCheckESP = false,      -- When ON, hide teammates from ESP entirely (enemies only)
}

--// VISUAL SETTINGS
local VisualSettings = {
    CrosshairEnabled = false,
    CrosshairColorMode = "Purple",
    HideSmoke = false,
    HideFlashbang = false,
    LockIndicator = false,      -- Show "LOCKED: NAME" / "SCANNING..." indicator on screen
    -- [V7] Sky / Lighting controls — full custom
    SkyColorEnabled = false,    -- Master toggle for sky color override
    AmbientColor = Color3.fromRGB(80, 80, 100),    -- Ambient light color (set via color picker)
    SkyBrightness = 1.5,        -- Lighting.Brightness value (0-3)
    SkyClockTime = 12,          -- Lighting.ClockTime value (0-24)
}

--// MISC SETTINGS
local MiscSettings = {
    SpoofEnabled = false,
    SelectedDevice = "Controller",
    TargetPlayer = "ABG",
    StreakValue = "14",
    AutoFindMe = true,
    CustomEnderName = "Dallas",
}

--// GUN MODS SETTINGS (Weapon property overrides via hookfunction)
local GunMods = {
    MasterEnabled = false,       -- Master toggle for all gun mods
    NoRecoil = false,            -- Zero camera kick/recoil
    NoSpread = false,            -- Perfect accuracy (no bullet deviation)
    RapidFire = false,           -- Remove fire rate delay
    FireRateMultiplier = 1.0,    -- ItemLibrary-specific: 1.0=normal, 0.1=10x fire rate
    ZeroSpreadIL = false,        -- Zero spread via ItemLibrary (ShootSpread + ShootAccuracy)
    ZeroRecoilIL = false,        -- Zero recoil via ItemLibrary (ShootRecoil)
    OneShot = false,             -- Maximize damage to one-shot enemies
    InfiniteAmmo = false,        -- Never run out of ammo
    InstantReload = false,       -- Reload time = 0
    InstantEquip = false,        -- Equip time = 0
    NoBulletDrop = false,        -- Bullets travel in straight line (no gravity)
    MaxPierce = false,           -- Bullets hit infinite targets
    NoCooldowns = false,         -- Remove melee/ability cooldowns
}

--// SNAP AIMBOT REMOVED

--// RAGE MODE SETTINGS (Auto-snap + rapid-fire)
local RageMode = {
    Enabled = false,
    AimStyle = "Visible",      -- "Visible" = mousemoverel (physically snaps crosshair, STRONGER) | "Silent" = raycast hook only (camera stays still)
    AimSpeed = 0.18,           -- mousemoverel multiplier (0.01=slow, 0.18=fast rage, 1.0=instant snap)
    Wallbang = false,          -- Desync + Gun.StartShooting + EncodeCFrame
    WallCheck = false,         -- Only target visible enemies (not behind walls)
    AutoWinEnabled = false,    -- Auto Win 1v1 — enables Silent Aim + ItemLibrary mods + Auto Shoot
    UseKeybind = true,         -- When true, Rage Mode only activates while holding the key
    -- [V2] UseFOV technique: when true, RageMode respects the FOV circle
    -- instead of targeting the entire screen. Useful for legit-looking rage.
    UseFOV = false,            -- OFF by default = classic rage (full screen)
    FOV = 250,                 -- [V2] Default FOV radius (was math.huge)
    MaxDistance = math.huge,   -- No distance limit — target at any range on the map
    HeadshotRate = 100,        -- Always aim at head — rage mode
    HitPart = "Head",          -- Always head
    ClickSpeed = 0.015,        -- Ultra fast auto-fire
    FovVisible = false,        -- No FOV circle needed
    FovFilled = false,
    FovColor = Color3.fromRGB(255, 0, 0),  -- [V8] FOV circle color (default red)
    FovRainbow = false,        -- [V8] Rainbow mode toggle
    AutoShot = true,           -- Always auto-shoot
}

--// HOLDBOT SETTINGS (Aimbot replacement — smooth aimbot with keybind + advanced features)
local HoldBot = {
    Enabled = false,
    UseKeybind = true,          -- When true, HoldBot only activates while holding the key
    UseSmoothing = false,
    SmoothingValue = 5,        -- 1=very fast, 100=very slow
    Prediction = false,
    PersistentTarget = false,  -- Won't switch targets until key released
    TargetBehindWalls = false,
    UseTargetZone = false,
    TargetZoneDistance = 1500,  -- Max distance in studs for targeting
    FOV = 250,
    FovVisible = false,
    FovFilled = false,
    FovColorMode = "Cyan",     -- [V6] FOV circle color (kept for backward compat)
    FovColor = Color3.fromRGB(0, 255, 255),  -- [V7] Actual Color3 for FOV circle (default Cyan)
    FovRainbow = false,        -- [V7] Rainbow mode toggle
    MaxDistance = 500,
    HitPart = "Head",
    -- [V2] Reaction time: delay before aimbot reacts to a new target
    ReactionTime = 0.05,       -- 0.05s = 50ms (fast but not instant-snap)
    _lastTargetSwitch = 0,     -- Internal: tracks when we last switched targets
}

--// ANTI-AIM v4 — Simple, working approach (inspired by Kuzq Rivals script)
-- The complex hook-based version was over-engineered and silently failed.
-- This version uses the SIMPLEST technique that actually works on Rivals:
--   - Multiply HRP.CFrame by a small rotation each frame (accumulates)
--   - Disable AutoRotate so the game doesn't fight back
--   - Run on Heartbeat (AFTER physics, so rotation sticks)
--
-- This is the same approach used by Kuzq, Onetap, and most working Rivals
-- cheats. It's not fancy, but it works where complex hooks fail.
local AntiAim = {
    Enabled = false,
    Speed = 20,            -- degrees per frame (20 = moderate, 45 = fast spin)
    Mode = "Spin",         -- Spin | Jitter | Reverse
    JitterRange = 90,      -- max random angle for Jitter mode
}

local antiAimYaw = 0
local antiAimJitterTarget = 0
local antiAimJitterTimer = 0
local antiAimWasEnabled = false

local function antiAimStep()
    -- Handle enable/disable transitions (restore AutoRotate when turned off)
    if not AntiAim.Enabled then
        if antiAimWasEnabled then
            antiAimWasEnabled = false
            pcall(function()
                local char = player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then hum.AutoRotate = true end
                end
            end)
        end
        return
    end
    antiAimWasEnabled = true

    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    -- Disable AutoRotate so the game doesn't override our rotation
    if hum.AutoRotate then
        hum.AutoRotate = false
    end

    -- Apply rotation based on mode
    if AntiAim.Mode == "Spin" then
        -- Continuous rotation: multiply current CFrame by small rotation each frame
        -- This is the Kuzq technique — simplest and most reliable
        root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(AntiAim.Speed), 0)

    elseif AntiAim.Mode == "Jitter" then
        -- Random angle jumps every 8 frames
        antiAimJitterTimer = antiAimJitterTimer + 1
        if antiAimJitterTimer >= 8 then
            antiAimJitterTimer = 0
            antiAimJitterTarget = math.random(-AntiAim.JitterRange, AntiAim.JitterRange)
        end
        -- Smoothly rotate towards the jitter target
        root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(antiAimJitterTarget / 8), 0)

    elseif AntiAim.Mode == "Reverse" then
        -- Face backwards (180 degrees from camera)
        local cam = workspace.CurrentCamera
        if cam then
            local look = cam.CFrame.LookVector
            local targetPos = root.Position - look
            root.CFrame = CFrame.new(root.Position, targetPos)
        else
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(AntiAim.Speed), 0)
        end
    end
end

--// ANTI-AIM — Connect to Heartbeat (runs AFTER physics simulation)
-- Critical: RenderStepped runs BEFORE physics, so physics would overwrite
-- our rotation. Heartbeat runs AFTER, so our rotation sticks.
RunService.Heartbeat:Connect(function()
    pcall(antiAimStep)
end)

--// PLAYER SETTINGS
local PlayerSettings = {
    InfiniteJump = false,
    PanicKeyEnabled = false,   -- Emergency kill-switch: instantly disables all combat features
    JumpPowerEnabled = false,
    JumpPower = 50,            -- Default Roblox jump power is 50
    WalkSpeedEnabled = false,  -- WalkSpeed override (continuous enforcement)
    WalkSpeed = 50,            -- Default walkspeed override (16 = normal, 50 = noticeable speed)
    NoclipEnabled = false,     -- Walk through walls
    AirWalkEnabled = false,    -- Stay in the air (no gravity fall)
    SlideBoost = false,        -- Speed boost while sliding (LeftCtrl)
    SlideBoostPower = 4,       -- Multiplier for slide speed
    FlyEnabled = false,        -- Fly using BodyVelocity+BodyGyro
    FlySpeed = 80,             -- Default fly speed
    FullbrightEnabled = false, -- Fullbright lighting
    AntiRagdollEnabled = false, -- Anti-Ragdoll
    AntiAfkEnabled = false,    -- Anti-AFK
    GravityValue = 196,        -- Gravity control — default 196
    -- [V3 from Rage Hub] Auto BunnyHop — auto-jump when holding Space
    AutoBhop = false,         -- OFF by default
    -- [V3 from Rage Hub] Custom Camera FOV — zoom in/out
    CustomFOV = false,        -- OFF by default (game default ~70)
    FOVValue = 90,            -- Custom FOV value (70-120)
    -- [V3 from Rage Hub] Show FPS counter (Drawing-based, top-left)
    ShowFPS = false,          -- OFF by default
    --// ORBIT — rotate around nearest enemy (auto, with team check)
    OrbitEnabled = false,      -- Master toggle
    OrbitRadius = 8,           -- Studs away from target (orbit circle size)
    OrbitSpeed = 3,            -- Rotation speed (radians per second)
    OrbitHeight = 3,           -- Height offset above target (positive=floating, 0=ground level)
    OrbitMaxDistance = 400,    -- Max distance to find a target (default 400 studs)
}

--// ORBIT STATE — internal tracking
local orbitState = {
    currentAngle = 0,          -- Current rotation angle (radians)
    currentTarget = nil,       -- Current target player reference
}

--// Forward declare isTeammate (defined later in the script) so Orbit can use it
local isTeammateOrbit = nil

--// ORBIT ENGINE — rotates your character around the NEAREST ENEMY
-- Auto-targets: skips teammates (uses TeamCheck), skips dead players, picks nearest
-- No UI selection needed — fully automatic
-- NOTE: Uses `player` (defined at top of script) instead of `lp` for safety.
local function findNearestEnemy()
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local nearestDist = math.huge
    local nearestPlr = nil
    -- Max distance check: only target enemies within OrbitMaxDistance
    local maxDist = PlayerSettings.OrbitMaxDistance or 400
    for _, plr in pairs(players:GetPlayers()) do
        if plr ~= player and plr.Character then
            -- Team check: skip teammates
            if isTeammateOrbit and isTeammateOrbit(plr) then continue end
            local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
            if tRoot and tHum and tHum.Health > 0 then
                local dist = (tRoot.Position - root.Position).Magnitude
                -- Skip targets beyond max distance
                if dist <= maxDist and dist < nearestDist then
                    nearestDist = dist
                    nearestPlr = plr
                end
            end
        end
    end
    return nearestPlr
end

local function orbitStep(deltaTime)
    if not PlayerSettings.OrbitEnabled then return end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root then return end

    local target = findNearestEnemy()
    orbitState.currentTarget = target
    if not target or not target.Character then return end
    local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
    local tHum = target.Character:FindFirstChildOfClass("Humanoid")
    if not tRoot or not tHum or tHum.Health <= 0 then return end

    -- Disable AutoRotate so the game doesn't fight our rotation
    if hum and hum.AutoRotate then
        pcall(function() hum.AutoRotate = false end)
    end

    -- Update angle based on speed and deltaTime (frame-independent)
    orbitState.currentAngle = orbitState.currentAngle + (PlayerSettings.OrbitSpeed * deltaTime)

    -- Compute position on circle around target
    local targetPos = tRoot.Position
    local radius = PlayerSettings.OrbitRadius
    local height = PlayerSettings.OrbitHeight
    local offsetX = math.cos(orbitState.currentAngle) * radius
    local offsetZ = math.sin(orbitState.currentAngle) * radius
    local newPos = Vector3.new(targetPos.X + offsetX, targetPos.Y + height, targetPos.Z + offsetZ)
    local lookAt = targetPos + Vector3.new(0, height, 0)

    -- TELEPORT + ROTATE: Set CFrame directly (position + facing target)
    -- Also reset velocity so the game's physics doesn't fight us
    pcall(function()
        root.CFrame = CFrame.new(newPos, lookAt)
        -- Kill any momentum so we don't slide away
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end)
end

--// ORBIT — use Stepped (runs BEFORE physics) so our CFrame override sticks
-- Heartbeat runs AFTER physics, which means the game's physics step would
-- overwrite our CFrame. Stepped runs BEFORE physics, so when physics simulates,
-- it simulates FROM our position → the orbit actually works.
local rsOrbit = cloneref(game:GetService("RunService"))
rsOrbit.Stepped:Connect(function(_, deltaTime)
    pcall(orbitStep, deltaTime)
end)

--// ORBIT — restore AutoRotate when disabled
-- NOTE: Use `player` (defined early at top of script) instead of `lp` (defined later).
-- This Heartbeat runs from script load, so `lp` may be nil on first frames.
RunService.Heartbeat:Connect(function()
    if not PlayerSettings.OrbitEnabled then
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and not hum.AutoRotate then
                pcall(function() hum.AutoRotate = true end)
            end
        end
    end
end)

--// TELEPORT KILL SETTINGS
local TeleportKillSettings = {
    Enabled = false,
    TargetPlayerName = "",
    Distance = 3,              -- Distance behind target in studs
    AutoReconnect = true,      -- Reconnect on character respawn
}
local tpKillConnection = nil
local tpKillTarget = nil

local DeviceMapping = {
    ["PC"] = "MouseKeyboard",
    ["Controller"] = "Gamepad",
    ["Mobile"] = "Touch",
    ["VR"] = "VR"
}

--// ENVIRONMENT RENDERING & OBJECT REFS
local lp = player
local camera = workspace.CurrentCamera
local rs = RunService
local ts = TweenService
local uis = UserInputService
local Lighting = game:GetService("Lighting")


--// INFINITE JUMP (from Rivals script — allows unlimited jumping)
uis.JumpRequest:Connect(function()
    if PlayerSettings.InfiniteJump then
        local char = lp.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

--// [V3 from Rage Hub] AUTO BUNNYHOP — auto-jump when holding Space
RunService.Stepped:Connect(function()
    if PlayerSettings.AutoBhop then
        local char = lp.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and uis:IsKeyDown(Enum.KeyCode.Space) then
                hum.Jump = true
            end
        end
    end
end)

--// [V3 from Rage Hub] FPS COUNTER (Drawing-based, top-left corner)
local _fpsFrames = 0
local _fpsTick = tick()
local _currentFPS = 0
local _fpsLabel = nil
pcall(function()
    _fpsLabel = Drawing.new("Text")
    _fpsLabel.Visible = false
    _fpsLabel.Color = Color3.fromRGB(130, 60, 255)  -- purple (Rage Hub style)
    _fpsLabel.Size = 16
    _fpsLabel.Center = false
    _fpsLabel.Outline = true
    _fpsLabel.Position = Vector2.new(15, 15)
    _fpsLabel.Font = 2
end)

RunService.RenderStepped:Connect(function()
    -- FPS calculation
    _fpsFrames = _fpsFrames + 1
    if tick() - _fpsTick >= 1 then
        _currentFPS = _fpsFrames
        _fpsFrames = 0
        _fpsTick = tick()
    end
    -- Show/hide FPS label
    if _fpsLabel then
        if PlayerSettings.ShowFPS then
            _fpsLabel.Visible = true
            _fpsLabel.Text = "ZytheraX | FPS: " .. _currentFPS
        else
            _fpsLabel.Visible = false
        end
    end
    -- Custom FOV
    if PlayerSettings.CustomFOV then
        pcall(function()
            camera.FieldOfView = PlayerSettings.FOVValue
        end)
    end
end)

--// AIMBOT MOUSE MOVE FUNCTION
local mouseMoveFunc = mousemoverel or (input and input.mousemoverel)

--// UNIVERSAL FIRE FUNCTION (mouse1press/release — better than mouse1click)
-- mouse1press/release gives more control: press holds the button, release lets go
-- Some games need hold duration or tool activation which requires press/release pattern
local function autoFire()
    pcall(function()
        if mouse1press and mouse1release then
            mouse1press()
            task.wait(0.01)
            mouse1release()
        elseif mouse1click then
            mouse1click()
        end
    end)
end

--// FLY ENGINE (BodyVelocity+BodyGyro)
local flyActive = false
local flyBodyMovers = {}
local flyConn = nil

local function stopFly()
    flyActive = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    for _, m in pairs(flyBodyMovers) do
        if m and m.Parent then m:Destroy() end
    end
    flyBodyMovers = {}
    local char = lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
    end
end

local function startFly(speed)
    local char = lp.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    for _, m in pairs(flyBodyMovers) do
        if m and m.Parent then m:Destroy() end
    end
    flyBodyMovers = {}
    flyActive = true
    hum.PlatformStand = true
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.one * 9e9
    bv.Velocity = Vector3.zero
    bv.Parent = root
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.one * 9e9
    bg.P = 9e4
    bg.CFrame = root.CFrame
    bg.Parent = root
    flyBodyMovers = { bv, bg }
    flyConn = rs.Heartbeat:Connect(function()
        if not flyActive then stopFly(); return end
        local char2 = lp.Character
        local root2 = char2 and char2:FindFirstChild("HumanoidRootPart")
        if not root2 or not bv.Parent or not bg.Parent then stopFly(); return end
        local cam = workspace.CurrentCamera
        local vel = Vector3.zero
        if uis:IsKeyDown(Enum.KeyCode.W)         then vel = vel + cam.CFrame.LookVector  end
        if uis:IsKeyDown(Enum.KeyCode.S)         then vel = vel - cam.CFrame.LookVector  end
        if uis:IsKeyDown(Enum.KeyCode.D)         then vel = vel + cam.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.A)         then vel = vel - cam.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.Space)     then vel = vel + Vector3.yAxis end
        if uis:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.yAxis end
        ts:Create(bv, TweenInfo.new(0.1), { Velocity = vel * speed }):Play()
        bg.CFrame = cam.CFrame.Rotation + root2.Position
    end)
end

--// FULLBRIGHT
local origAmbient = nil
local origBright = nil

local function setFullbright(on)
    if on then
        origAmbient = Lighting.Ambient
        origBright = Lighting.Brightness
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.GlobalShadows = false
    else
        if origAmbient then Lighting.Ambient = origAmbient end
        if origBright  then Lighting.Brightness = origBright end
        Lighting.GlobalShadows = true
    end
end

-- ============================================================
-- [V7] SKY / LIGHTING COLOR SYSTEM — full custom control
-- Uses VisualSettings.AmbientColor (set via color picker)
-- + SkyBrightness + SkyClockTime (set via sliders)
-- ============================================================
local origSkyAmbient = nil
local origSkyBright = nil
local origSkyClock = nil
local origSkyOutdoor = nil

local function applySkyColor()
    if not VisualSettings.SkyColorEnabled then
        -- Restore originals if we saved them
        if origSkyAmbient then
            Lighting.Ambient = origSkyAmbient
            Lighting.Brightness = origSkyBright
            Lighting.ClockTime = origSkyClock
            Lighting.OutdoorAmbient = origSkyOutdoor
            origSkyAmbient = nil
        end
        return
    end

    -- Save originals on first enable
    if not origSkyAmbient then
        origSkyAmbient = Lighting.Ambient
        origSkyBright = Lighting.Brightness
        origSkyClock = Lighting.ClockTime
        origSkyOutdoor = Lighting.OutdoorAmbient
    end

    -- Apply user's custom color + brightness + clock time
    Lighting.Ambient = VisualSettings.AmbientColor
    Lighting.OutdoorAmbient = VisualSettings.AmbientColor
    Lighting.Brightness = VisualSettings.SkyBrightness or 1.5
    Lighting.ClockTime = VisualSettings.SkyClockTime or 12
end

--// ANTI-RAGDOLL
local antiRagdollConn = nil

local function setAntiRagdoll(on)
    if antiRagdollConn then antiRagdollConn:Disconnect(); antiRagdollConn = nil end
    local function apply(char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not on)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not on)
            hum.BreakJointsOnDeath = not on
        end
        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then
                v.Enabled = not on
            end
        end
    end
    apply(lp.Character)
    if on then
        antiRagdollConn = lp.CharacterAdded:Connect(function(char)
            task.wait(0.1)
            apply(char)
        end)
    end
end

--// ANTI-AFK
local antiAfkConn = nil

local function setupAntiAfk(on)
    if antiAfkConn then antiAfkConn:Disconnect(); antiAfkConn = nil end
    if on then
        antiAfkConn = lp.Idled:Connect(function()
            pcall(function()
                local vu = game:GetService("VirtualUser")
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end)
        end)
    end
end

--// SERVERHOP
local function serverhop()
    local HttpS = cloneref(game:GetService("HttpService"))
    local TeleportS = cloneref(game:GetService("TeleportService"))
    local ok, data = pcall(function()
        return HttpS:JSONDecode(game:HttpGetAsync(
            "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        ))
    end)
    if not ok then
        Library:Notify({ Title = "Serverhop", Description = "Failed to fetch servers.", Time = 4 })
        return
    end
    local best = nil
    for _, v in pairs(data.data) do
        if type(v) == "table" and v.maxPlayers > v.playing and v.id ~= game.JobId then
            if not best or v.playing > best.playing then best = v end
        end
    end
    if best then
        Library:Notify({ Title = "Serverhop", Description = "Hopping to another server...", Time = 3 })
        task.wait(0.5)
        TeleportS:TeleportToPlaceInstance(game.PlaceId, best.id)
    else
        Library:Notify({ Title = "Serverhop", Description = "No other servers found.", Time = 4 })
    end
end

--// REJOIN
local function rejoin()
    local TeleportS = cloneref(game:GetService("TeleportService"))
    Library:Notify({ Title = "Rejoin", Description = "Rejoining server...", Time = 3 })
    task.wait(0.5)
    if #Players:GetPlayers() <= 1 then
        TeleportS:Teleport(game.PlaceId, lp)
    else
        TeleportS:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
    end
end

--// LOCK INDICATOR (Screen label showing target lock status)
local lockLabelGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
lockLabelGui.Name = "ZytheraLockIndicator"
lockLabelGui.ResetOnSpawn = false
lockLabelGui.Enabled = true
local lockLabel = Instance.new("TextLabel", lockLabelGui)
lockLabel.Size = UDim2.new(0, 250, 0, 25)
lockLabel.Position = UDim2.new(1, -260, 0, 10)
lockLabel.BackgroundTransparency = 1
lockLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
lockLabel.Font = Enum.Font.Code
lockLabel.TextSize = 12
lockLabel.TextXAlignment = Enum.TextXAlignment.Right
lockLabel.Text = "SCANNING..."
lockLabel.Visible = false

--// SILENT AIM STATE
-- (Alternating bullet counter removed — now EVERY bullet redirects to the target, 100% silent)

--// SILENT AIM FOV CIRCLE
local SAFovBg = Drawing.new("Circle")
SAFovBg.Thickness = 0
SAFovBg.Color = Color3.fromRGB(25, 25, 30)
SAFovBg.Transparency = 0.4
SAFovBg.Filled = true

local SAFovRing = Drawing.new("Circle")
SAFovRing.Thickness = 1.5
SAFovRing.Color = Color3.fromRGB(255, 30, 30)
SAFovRing.Transparency = 0.8
SAFovRing.Filled = false

--// TRIGGER BOT FOV CIRCLE REMOVED

--// RAGE MODE FOV CIRCLE
local RageFovBg = Drawing.new("Circle")
RageFovBg.Thickness = 0
RageFovBg.Color = Color3.fromRGB(25, 25, 30)
RageFovBg.Transparency = 0.4
RageFovBg.Filled = true

local RageFovRing = Drawing.new("Circle")
RageFovRing.Thickness = 1.5
RageFovRing.Color = Color3.fromRGB(255, 0, 0) -- Red for Rage Mode
RageFovRing.Transparency = 0.8
RageFovRing.Filled = false

--// HOLDBOT FOV CIRCLE
local HoldBotFovBg = Drawing.new("Circle")
HoldBotFovBg.Thickness = 0
HoldBotFovBg.Color = Color3.fromRGB(25, 25, 30)
HoldBotFovBg.Transparency = 0.4
HoldBotFovBg.Filled = true

local HoldBotFovRing = Drawing.new("Circle")
HoldBotFovRing.Thickness = 1.5
HoldBotFovRing.Color = Color3.fromRGB(0, 200, 255) -- Light blue for HoldBot
HoldBotFovRing.Transparency = 0.8
HoldBotFovRing.Filled = false

rs.RenderStepped:Connect(function()
    local mousePos = uis:GetMouseLocation()
    local center = mousePos -- FOV circles now follow the mouse cursor

    -- [V8] Rainbow color helper (shared)
    local rainbowColor = Color3.fromHSV(tick() % 5 / 5, 1, 1)

    -- Silent Aim FOV — [V8] apply custom color
    local saColor = SilentAim.FovColor or Color3.fromRGB(255, 255, 255)
    if SilentAim.FovRainbow then saColor = rainbowColor end
    SAFovBg.Radius = SilentAim.FOV
    SAFovBg.Position = center
    SAFovBg.Color = saColor
    SAFovBg.Visible = SilentAim.Enabled and SilentAim.FovVisible and SilentAim.FovFilled
    SAFovRing.Radius = SilentAim.FOV
    SAFovRing.Position = center
    SAFovRing.Color = saColor
    SAFovRing.Visible = SilentAim.Enabled and SilentAim.FovVisible

    -- Trigger Bot FOV
    --// TRIGGER BOT FOV UPDATE REMOVED

    -- Rage Mode FOV — [V8] apply custom color
    local rageColor = RageMode.FovColor or Color3.fromRGB(255, 0, 0)
    if RageMode.FovRainbow then rageColor = rainbowColor end
    RageFovBg.Radius = RageMode.FOV
    RageFovBg.Position = center
    RageFovBg.Color = rageColor
    RageFovBg.Visible = RageMode.Enabled and RageMode.UseFOV and RageMode.FovVisible and RageMode.FovFilled
    RageFovRing.Radius = RageMode.FOV
    RageFovRing.Position = center
    RageFovRing.Color = rageColor
    RageFovRing.Visible = RageMode.Enabled and RageMode.UseFOV and RageMode.FovVisible

    -- HoldBot FOV — [V8] apply custom color (use FovColor directly)
    local hbColor = HoldBot.FovColor or Color3.fromRGB(0, 200, 255)
    if HoldBot.FovRainbow then
        hbColor = rainbowColor
    end
    HoldBotFovBg.Radius = HoldBot.FOV
    HoldBotFovBg.Position = center
    HoldBotFovBg.Color = hbColor
    HoldBotFovBg.Visible = HoldBot.Enabled and HoldBot.FovVisible and HoldBot.FovFilled
    HoldBotFovRing.Radius = HoldBot.FOV
    HoldBotFovRing.Position = center
    HoldBotFovRing.Color = hbColor
    HoldBotFovRing.Visible = HoldBot.Enabled and HoldBot.FovVisible
    
    --// LOCK INDICATOR UPDATE
    if VisualSettings.LockIndicator then
        lockLabel.Visible = true
        local lockedTarget = nil
        if SilentAim.Enabled then
            lockedTarget = get_best_target(SilentAim)
        elseif RageMode.Enabled then
            lockedTarget = get_best_target(RageMode)
        elseif HoldBot.Enabled then
            lockedTarget = get_best_target(HoldBot)
        end
        if lockedTarget and lockedTarget.Parent then
            local targetPlayer = players:GetPlayerFromCharacter(lockedTarget.Parent)
            if targetPlayer then
                lockLabel.Text = "LOCKED: " .. targetPlayer.Name:upper()
                lockLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
            end
        else
            lockLabel.Text = "SCANNING..."
            lockLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    else
        lockLabel.Visible = false
    end
end)


--// TEAM CACHE (updated on team change events — avoids re-reading attributes every frame)
local teamCache = {
    myTeamID = nil,           -- Cached TeamID attribute value
    lastUpdate = 0,           -- Tick of last full refresh
}

--// UPDATE TEAM CACHE (called on team change events & periodically)
local function UpdateTeamCache()
    teamCache.myTeamID = lp:GetAttribute("TeamID")
    teamCache.lastUpdate = tick()
end

--// INITIAL CACHE POPULATION
UpdateTeamCache()

--// LISTEN FOR TEAM CHANGES (fires when TeamID attribute changes)
pcall(function()
    lp:GetAttributeChangedSignal("TeamID"):Connect(function()
        UpdateTeamCache()
    end)
end)

--// TEAMMATE DETECTION FUNCTION (TeamID only — works for Rivals and similar games)
local function isTeammate(player)
    if not TeamCheck.Enabled then return false end

    local myTeamID = teamCache.myTeamID
    local theirTeamID = player:GetAttribute("TeamID")
    -- TeamID = 0 or nil means "unassigned/no team" — NOT a teammate
    -- Only count as teammate if BOTH have a valid (non-zero, non-nil) TeamID that matches
    if myTeamID ~= nil and theirTeamID ~= nil and myTeamID ~= 0 and theirTeamID ~= 0 and myTeamID == theirTeamID then
        if TeamCheck.DebugMode then
            print("[TeamCheck] " .. player.Name .. " is TEAMMATE (TeamID: " .. tostring(myTeamID) .. ")")
        end
        return true
    end

    return false
end

--// Link the forward-declared reference so Orbit can use it
isTeammateOrbit = isTeammate

--// TARGETING LOGIC (Shared by Silent Aim, HoldBot & Trigger Bot)
-- FOV center = mouse position (circles follow cursor)
local function get_best_target(config)
    local target = nil
    local bestDist = config.FOV
    local center = uis:GetMouseLocation() -- Target detection centered on mouse cursor
    local maxDistance = config.MaxDistance or math.huge
    
    --// FIX: Use HitPart directly from config (no more HeadshotRate random chance).
    -- HeadshotRate was removed — user now picks the target part explicitly.
    local currentPart = config.HitPart or "Head"
    
    for _, v in pairs(players:GetPlayers()) do
        if v ~= lp and v.Character and v.Character:FindFirstChild(currentPart) then
            -- Team Check: skip teammates
            if isTeammate(v) then continue end
            -- Skip dead players (Health <= 0)
            local humanoid = v.Character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then
                continue
            end
            local hitPart = v.Character[currentPart]
            local pos, onScreen = camera:WorldToViewportPoint(hitPart.Position)
            if onScreen then
                local mag = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                if mag < config.FOV then
                    -- MaxDistance check: skip targets too far away in 3D
                    local dist3D = (camera.CFrame.Position - hitPart.Position).Magnitude
                    if dist3D > maxDistance then
                        continue
                    end
                    
                    local isVisible = true
                    
                    if config.WallCheck then
                        -- [V3 from Rage Hub] Use modern RaycastParams (cleaner + faster)
                        local origin = camera.CFrame.Position
                        local direction = hitPart.Position - origin
                        local params = RaycastParams.new()
                        params.FilterDescendantsInstances = {lp.Character, v.Character, camera}
                        params.FilterType = Enum.RaycastFilterType.Blacklist
                        params.IgnoreWater = true
                        local result = workspace:Raycast(origin, direction, params)
                        if result and not result.Instance:IsDescendantOf(v.Character) then
                            isVisible = false
                        end
                    end
                    
                    if isVisible and mag < bestDist then
                        bestDist = mag
                        target = hitPart
                    end
                end
            end
        end
    end
    return target
end

--// COLOR PRESETS & CROSSHAIR SETUP
local colorPresets = {
    ["Red"] = Color3.fromRGB(255, 50, 50),
    ["Blue"] = Color3.fromRGB(0, 180, 255),
    ["Purple"] = Color3.fromRGB(160, 32, 240),
    ["Yellow"] = Color3.fromRGB(255, 230, 50),
    ["Pink"] = Color3.fromRGB(255, 105, 180),
    ["Orange"] = Color3.fromRGB(255, 140, 0),
    ["Cyan"] = Color3.fromRGB(0, 255, 255)
}

local crosshairGui = Instance.new("ScreenGui")
crosshairGui.Name = "AnimatedCrosshairGui"
crosshairGui.IgnoreGuiInset = true
crosshairGui.ResetOnSpawn = false
crosshairGui.Parent = lp:WaitForChild("PlayerGui")

local crosshairAnchor = Instance.new("Frame", crosshairGui)
crosshairAnchor.Name = "Anchor"
crosshairAnchor.Size = UDim2.new(0, 0, 0, 0)
crosshairAnchor.Position = UDim2.new(0.5, 0, 0.5, 0)
crosshairAnchor.BackgroundTransparency = 1
crosshairAnchor.AnchorPoint = Vector2.new(0.5, 0.5)

local function createCrosshairLine(name, anchorPoint)
    local line = Instance.new("Frame", crosshairAnchor)
    line.Name = name
    line.BorderSizePixel = 0
    line.AnchorPoint = anchorPoint
    local stroke = Instance.new("UIStroke", line)
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = 1.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return line
end

local cTop = createCrosshairLine("TopLine", Vector2.new(0.5, 1))
local cBottom = createCrosshairLine("BottomLine", Vector2.new(0.5, 0))
local cLeft = createCrosshairLine("LeftLine", Vector2.new(1, 0.5))
local cRight = createCrosshairLine("RightLine", Vector2.new(0, 0.5))

local SPIN_SPEED, THICKNESS, BASE_LENGTH, MIN_GAP, MAX_GAP, PULSE_SPEED, timePassed = 45, 3, 14, 4, 12, 3, 0

--// CORE SCREEN GUI ESP CACHE SYSTEM
local EspGui = Instance.new("ScreenGui")
EspGui.Name = "CoreAssetCache"
EspGui.ResetOnSpawn = false
EspGui.IgnoreGuiInset = true
EspGui.Parent = lp:WaitForChild("PlayerGui")

local HEALTH_BAR_WIDTH, HEALTH_BAR_OFFSET = 3, 5
local EspRegistry = {}

--// SKELETON ESP CACHE (Drawing-based bone lines)
local SkeletonCache = {} -- [player] = {lines = {Drawing}, originalSizes = {[part] = size}}

--// HEAD HITBOX SCALE CACHE
local OriginalHeadSizes = {} -- [head_part] = originalSize

local function createEspElements(p)
    if p == lp or EspRegistry[p] then return end
    local elements = {}

    -- Outline Box
    local BoxFrame = Instance.new("Frame", EspGui)
    BoxFrame.BackgroundTransparency = 1
    BoxFrame.Visible = false
    local Outline = Instance.new("Frame", BoxFrame)
    Outline.Size = UDim2.new(1, 0, 1, 0)
    Outline.BackgroundTransparency = 1
    local Stroke = Instance.new("UIStroke", Outline)
    Stroke.Thickness = EspSettings.BoxThickness
    elements.Box = BoxFrame
    elements.BoxStroke = Stroke

    -- Modern Filled Background Box
    local FilledBox = Instance.new("Frame", EspGui)
    FilledBox.BorderSizePixel = 0
    FilledBox.Visible = false
    elements.FilledBox = FilledBox

    -- Line Tracer
    local TracerLine = Instance.new("Frame", EspGui)
    TracerLine.AnchorPoint = Vector2.new(0.5, 0.5)
    TracerLine.BorderSizePixel = 0
    TracerLine.Visible = false
    elements.Tracer = TracerLine

    -- Health Bars
    local HealthContainer = Instance.new("Frame", EspGui)
    HealthContainer.BackgroundColor3 = Color3.fromRGB(0,0,0)
    HealthContainer.BackgroundTransparency = 0.3
    HealthContainer.BorderSizePixel = 0
    HealthContainer.Visible = false
    local HealthFill = Instance.new("Frame", HealthContainer)
    HealthFill.BorderSizePixel = 0
    HealthFill.AnchorPoint = Vector2.new(0, 1)
    HealthFill.Position = UDim2.new(0, 0, 1, 0)
    elements.HealthBar = HealthContainer
    elements.HealthFill = HealthFill

    -- Name Tag
    local TagLabel = Instance.new("TextLabel", EspGui)
    TagLabel.BackgroundTransparency = 1
    TagLabel.AnchorPoint = Vector2.new(0.5, 1)
    TagLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TagLabel.Font = Enum.Font.FredokaOne
    TagLabel.TextSize = 13
    TagLabel.Visible = false
    local TextStroke = Instance.new("UIStroke", TagLabel)
    TextStroke.Color = Color3.fromRGB(0,0,0)
    TextStroke.Thickness = 1.5
    elements.Tag = TagLabel

    -- Distance Tag
    local DistLabel = Instance.new("TextLabel", EspGui)
    DistLabel.BackgroundTransparency = 1
    DistLabel.AnchorPoint = Vector2.new(0.5, 0)
    DistLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
    DistLabel.Font = Enum.Font.FredokaOne
    DistLabel.TextSize = 11
    DistLabel.Visible = false
    local DistStroke = Instance.new("UIStroke", DistLabel)
    DistStroke.Color = Color3.fromRGB(0,0,0)
    DistStroke.Thickness = 1.5
    elements.DistTag = DistLabel

    -- Weapon Tag (enemy weapon display)
    local WeaponTag = Instance.new("TextLabel", EspGui)
    WeaponTag.BackgroundTransparency = 1
    WeaponTag.AnchorPoint = Vector2.new(0.5, 0)
    WeaponTag.TextColor3 = Color3.fromRGB(255, 200, 80)
    WeaponTag.Font = Enum.Font.FredokaOne
    WeaponTag.TextSize = 10
    WeaponTag.Visible = false
    local WeaponStroke = Instance.new("UIStroke", WeaponTag)
    WeaponStroke.Color = Color3.fromRGB(0,0,0)
    WeaponStroke.Thickness = 1.5
    elements.WeaponTag = WeaponTag

    elements.CurrentCham = nil
    elements.CurrentGlowCham = nil
    EspRegistry[p] = elements
end

local function removeEspElements(p)
    if EspRegistry[p] then
        if EspRegistry[p].CurrentCham then 
            EspRegistry[p].CurrentCham:Destroy() 
        end
        if EspRegistry[p].CurrentGlowCham then 
            EspRegistry[p].CurrentGlowCham:Destroy() 
        end
        for _, obj in pairs(EspRegistry[p]) do 
            if typeof(obj) == "Instance" then obj:Destroy() end 
        end
        EspRegistry[p] = nil
    end
    -- Clean up skeleton drawings
    if SkeletonCache[p] then
        for _, line in ipairs(SkeletonCache[p]) do
            pcall(function() line:Remove() end)
        end
        SkeletonCache[p] = nil
    end
end

for _, p in ipairs(players:GetPlayers()) do createEspElements(p) end
players.PlayerAdded:Connect(createEspElements)
players.PlayerRemoving:Connect(removeEspElements)

--// MAIN RENDERING PIPELINE
local pipelineConnection
--// HoldBot smoothing state
local holdBotPrevX, holdBotPrevY = 0, 0
local holdBotCurrentTarget = nil  -- For persistent targeting
--// TRIGGER BOT STATE REMOVED
--// Rage Mode state
local rageLastFire = 0

pipelineConnection = rs.RenderStepped:Connect(function(deltaTime)
    --// PERIODIC TEAM CACHE REFRESH (every 5 seconds, in case signals missed)
    if tick() - teamCache.lastUpdate > 5 then
        UpdateTeamCache()
    end

    --// HOLDBOT: Aimbot replacement — smooth aimbot with keybind + advanced features
    local holdBotActive = false
    if HoldBot.Enabled then
        if HoldBot.UseKeybind then
            holdBotActive = (Options.HoldBotKey ~= nil) and (Options.HoldBotKey:GetState() == true)
        else
            holdBotActive = true
        end
    end

    if holdBotActive then
        -- Target selection: persistent or dynamic
        local target = nil
        
        if HoldBot.PersistentTarget and holdBotCurrentTarget then
            -- Use persistent target if still valid
            local persistChar = holdBotCurrentTarget.Parent
            if persistChar then
                local hum = persistChar:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    -- Re-find the same part type on the same character
                    local partName = holdBotCurrentTarget.Name
                    target = persistChar:FindFirstChild(partName)
                    -- Apply target zone if enabled
                    if target and HoldBot.UseTargetZone then
                        local rootPart = persistChar:FindFirstChild("HumanoidRootPart")
                        if rootPart then
                            local dist = (camera.CFrame.Position - rootPart.Position).Magnitude
                            if dist > HoldBot.TargetZoneDistance then
                                target = nil
                            end
                        end
                    end
                    -- Wall check for persistent target
                    if target and not HoldBot.TargetBehindWalls then
                        local origin = camera.CFrame.Position
                        local direction = (target.Position - origin).Unit * (target.Position - origin).Magnitude
                        local ray = Ray.new(origin, direction)
                        local ignoreList = {lp.Character, persistChar, camera}
                        local hit = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
                        if hit then target = nil end
                    end
                end
            end
            if not target then
                holdBotCurrentTarget = nil  -- Invalidated
            end
        end
        
        if not target then
            -- Find new target using standard targeting with HoldBot config
            local holdBotConfig = {
                FOV = HoldBot.FOV,
                MaxDistance = HoldBot.MaxDistance,
                HitPart = HoldBot.HitPart,
                WallCheck = not HoldBot.TargetBehindWalls,
            }
            target = get_best_target(holdBotConfig)
            
            -- Apply target zone
            if target and HoldBot.UseTargetZone then
                local rootPart = target.Parent and target.Parent:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local dist = (camera.CFrame.Position - rootPart.Position).Magnitude
                    if dist > HoldBot.TargetZoneDistance then
                        target = nil
                    end
                end
            end
            
            if HoldBot.PersistentTarget and target then
                holdBotCurrentTarget = target
            end
        end
        
        if target and target.Position then
            local targetPosition = target.Position
            
            -- Prediction
            if HoldBot.Prediction and target.Parent and target.Parent:FindFirstChild("HumanoidRootPart") then
                local velocity = target.Parent.HumanoidRootPart.AssemblyLinearVelocity
                targetPosition = targetPosition + (velocity * 0.08)
            end
            
            local targetPos = camera:WorldToViewportPoint(targetPosition)
            local mousePos = uis:GetMouseLocation()
            
            local rawDeltaX = targetPos.X - mousePos.X
            local rawDeltaY = targetPos.Y - mousePos.Y
            
            if HoldBot.UseSmoothing then
                -- Smooth movement with configurable smoothing value
                local alpha = 1 / math.max(HoldBot.SmoothingValue, 1)
                -- Frame-rate independence
                local frameAlpha = 1 - math.exp(-deltaTime / (0.01 * HoldBot.SmoothingValue))
                local moveX = rawDeltaX * frameAlpha
                local moveY = rawDeltaY * frameAlpha
                
                -- Temporal blend for smoother transitions
                local blendFactor = math.clamp(0.2 + (HoldBot.SmoothingValue * 0.02), 0.2, 0.6)
                moveX = holdBotPrevX * blendFactor + moveX * (1 - blendFactor)
                moveY = holdBotPrevY * blendFactor + moveY * (1 - blendFactor)
                
                holdBotPrevX = moveX
                holdBotPrevY = moveY
                
                if mouseMoveFunc then
                    pcall(function() mouseMoveFunc(moveX, moveY) end)
                end
            else
                -- Instant snap (no smoothing)
                if mouseMoveFunc then
                    pcall(function() mouseMoveFunc(rawDeltaX, rawDeltaY) end)
                end
            end
        else
            -- No target: decay previous movement
            holdBotPrevX = holdBotPrevX * 0.5
            holdBotPrevY = holdBotPrevY * 0.5
        end
    else
        -- HoldBot off: reset state
        holdBotPrevX = 0
        holdBotPrevY = 0
        holdBotCurrentTarget = nil
    end

    --// RAGE MODE: Auto-aim + auto-fire
    -- Visible mode: physically snaps crosshair to target using mousemoverel (STRONGER)
    -- Silent mode: only redirects raycast, camera stays still (stealthier)
    -- Keybind: hold key to activate (when UseKeybind is on)
    local rageActive = false
    if RageMode.Enabled then
        if RageMode.UseKeybind then
            rageActive = (Options.RageModeKey ~= nil) and (Options.RageModeKey:GetState() == true)
        else
            rageActive = true
        end
    end

    if rageActive then
        local target = get_best_target(RageMode)
        if target then
            if RageMode.AimStyle == "Visible" then
                -- VISIBLE MODE: physically move crosshair to target using mousemoverel
                local targetPos, onScreen = camera:WorldToViewportPoint(target.Position)
                if onScreen then
                    local mousePos = uis:GetMouseLocation()
                    local delta = (Vector2.new(targetPos.X, targetPos.Y) - mousePos) * RageMode.AimSpeed
                    if mouseMoveFunc then
                        pcall(function() mouseMoveFunc(delta.X, delta.Y) end)
                    end
                end
            end
            -- Silent mode doesn't need mousemoverel — the utility.Raycast hook handles bullet redirection

            -- Auto-fire at fast click speed
            local now = tick()
            if now - rageLastFire >= RageMode.ClickSpeed then
                rageLastFire = now
                autoFire()
            end
        end
    end

    --// TRIGGER BOT: Auto-fire when crosshair is on an enemy
    -- Raycasts from camera through mouse position — if it hits an enemy, auto-click after delay
    if TriggerBot.Enabled then
        local triggerShouldFire = false

        -- Check keybind if enabled
        if TriggerBot.Keybind then
            triggerShouldFire = uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        else
            triggerShouldFire = true
        end

        if triggerShouldFire then
            -- Raycast from camera through mouse position
            local mouseLocation = uis:GetMouseLocation()
            local mouseRay = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = {lp.Character or nil}

            local rayResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 2000, rayParams)

            if rayResult and rayResult.Instance then
                -- Check if the hit part belongs to an enemy player
                local hitChar = rayResult.Instance:FindFirstAncestorOfClass("Model")
                if hitChar then
                    local hitPlayer = players:GetPlayerFromCharacter(hitChar)
                    if hitPlayer and hitPlayer ~= lp and not isTeammate(hitPlayer) then
                        -- Check if enemy is alive
                        local hitHum = hitChar:FindFirstChildOfClass("Humanoid")
                        if hitHum and hitHum.Health > 0 then
                            -- Wall check: if enabled, verify the hit is not behind a wall
                            -- (Since we already raycasted, if rayResult hit the character, it's visible)
                            -- The raycast naturally checks visibility — if it hit the character, it's visible

                            -- Apply delay
                            local now = tick()
                            if TriggerBot.LastDetected == 0 then
                                -- First frame detecting target — start timer
                                TriggerBot.LastDetected = now
                            end

                            if now - TriggerBot.LastDetected >= TriggerBot.Delay then
                                -- Delay passed — fire!
                                autoFire()
                            end
                        else
                            TriggerBot.LastDetected = 0
                        end
                    else
                        TriggerBot.LastDetected = 0
                    end
                else
                    TriggerBot.LastDetected = 0
                end
            else
                TriggerBot.LastDetected = 0
            end
        else
            TriggerBot.LastDetected = 0
        end
    else
        TriggerBot.LastDetected = 0
    end

    --// CROSSHAIR
    if VisualSettings.CrosshairEnabled then
        crosshairAnchor.Visible = true
        local workingColor = VisualSettings.CrosshairColorMode == "Rainbow" and Color3.fromHSV(tick() % 5 / 5, 1, 1) or colorPresets[VisualSettings.CrosshairColorMode] or Color3.fromRGB(255, 50, 50)
        cTop.BackgroundColor3 = workingColor; cBottom.BackgroundColor3 = workingColor; cLeft.BackgroundColor3 = workingColor; cRight.BackgroundColor3 = workingColor
        
        crosshairAnchor.Rotation = (crosshairAnchor.Rotation + (SPIN_SPEED * deltaTime)) % 360
        timePassed = timePassed + (deltaTime * PULSE_SPEED)
        local alpha = (math.sin(timePassed) + 1) / 2
        local currentGap = MIN_GAP + (alpha * (MAX_GAP - MIN_GAP))
        
        cTop.Size = UDim2.new(0, THICKNESS, 0, BASE_LENGTH); cTop.Position = UDim2.new(0, 0, 0, -currentGap)
        cBottom.Size = UDim2.new(0, THICKNESS, 0, BASE_LENGTH); cBottom.Position = UDim2.new(0, 0, 0, currentGap)
        cLeft.Size = UDim2.new(0, BASE_LENGTH, 0, THICKNESS); cLeft.Position = UDim2.new(0, -currentGap, 0, 0)
        cRight.Size = UDim2.new(0, BASE_LENGTH, 0, THICKNESS); cRight.Position = UDim2.new(0, currentGap, 0, 0)
    else
        crosshairAnchor.Visible = false
    end

    --// ESP RENDERING
    local globalRainbow = Color3.fromHSV(tick() % 5 / 5, 1, 1)
    local boxColor = EspSettings.EspColorMode == "Rainbow" and globalRainbow or colorPresets[EspSettings.EspColorMode] or Color3.fromRGB(0, 180, 255)
    local filledBoxColor = EspSettings.EspFilledColorMode == "Rainbow" and globalRainbow or colorPresets[EspSettings.EspFilledColorMode] or Color3.fromRGB(0, 180, 255)
    local chamColor = EspSettings.EspChamsColorMode == "Rainbow" and globalRainbow or colorPresets[EspSettings.EspChamsColorMode] or Color3.fromRGB(0, 255, 255)

    for player, cache in pairs(EspRegistry) do
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if rootPart and humanoid and humanoid.Health > 0 then
            -- Team Check ESP: teammates shown in cyan, enemies in normal color
            -- If TeamCheckESP is ON, hide teammates entirely (enemies only mode)
            local isTeamPlayer = isTeammate(player)
            if isTeamPlayer and EspSettings.TeamCheckESP then
                -- Hide all ESP elements for this teammate
                cache.Box.Visible = false
                cache.FilledBox.Visible = false
                cache.Tracer.Visible = false
                cache.HealthBar.Visible = false
                cache.Tag.Visible = false
                cache.DistTag.Visible = false
                cache.WeaponTag.Visible = false
                if cache.CurrentCham then cache.CurrentCham.Enabled = false end
                if cache.CurrentGlowCham then cache.CurrentGlowCham.Enabled = false end
                if SkeletonCache[player] then
                    for _, line in ipairs(SkeletonCache[player]) do
                        line.Visible = false
                    end
                end
            else
            local teamBoxColor = isTeamPlayer and Color3.fromRGB(0, 255, 255) or boxColor
            local teamFilledColor = isTeamPlayer and Color3.fromRGB(0, 200, 200) or filledBoxColor
            local teamChamColor = isTeamPlayer and Color3.fromRGB(0, 255, 255) or chamColor
            local teamGlowColor = isTeamPlayer and Color3.fromRGB(0, 255, 255) or (EspSettings.EspGlowColorMode == "Rainbow" and globalRainbow or colorPresets[EspSettings.EspGlowColorMode] or Color3.fromRGB(0, 255, 255))
            local screenPos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
            local distance = (camera.CFrame.Position - rootPart.Position).Magnitude

            if onScreen and distance <= EspSettings.MaxEspDistance and distance >= 1 then
                local sizeX = EspSettings.BoxSizeMultiplier / distance
                local sizeY = sizeX * 1.45
                local boxPosX = screenPos.X - (sizeX / 2)
                local boxPosY = screenPos.Y - (sizeY / 2)

                if EspSettings.EspBoxes then
                    cache.Box.Position = UDim2.new(0, boxPosX, 0, boxPosY)
                    cache.Box.Size = UDim2.new(0, sizeX, 0, sizeY)
                    cache.BoxStroke.Thickness = EspSettings.BoxThickness
                    cache.BoxStroke.Color = teamBoxColor
                    cache.Box.Visible = true
                else cache.Box.Visible = false end

                if EspSettings.EspFilledBoxes then
                    cache.FilledBox.Position = UDim2.new(0, boxPosX, 0, boxPosY)
                    cache.FilledBox.Size = UDim2.new(0, sizeX, 0, sizeY)
                    cache.FilledBox.BackgroundColor3 = teamFilledColor
                    cache.FilledBox.BackgroundTransparency = EspSettings.FilledBoxTransparency
                    cache.FilledBox.Visible = true
                else cache.FilledBox.Visible = false end

                if EspSettings.EspLines then
                    local vSize = camera.ViewportSize
                    local startX, startY = vSize.X / 2, vSize.Y
                    local dx, dy = screenPos.X - startX, screenPos.Y - startY
                    local length = math.sqrt(dx^2 + dy^2)
                    local angle = math.atan2(dy, dx)
                    cache.Tracer.Position = UDim2.new(0, startX + dx/2, 0, startY + dy/2)
                    cache.Tracer.Size = UDim2.new(0, length, 0, EspSettings.LineThickness)
                    cache.Tracer.BackgroundColor3 = teamBoxColor
                    cache.Tracer.Rotation = math.deg(angle)
                    cache.Tracer.Visible = true
                else cache.Tracer.Visible = false end

                if EspSettings.EspHealth then
                    local hPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                    cache.HealthBar.Position = UDim2.new(0, boxPosX - HEALTH_BAR_OFFSET - HEALTH_BAR_WIDTH, 0, boxPosY)
                    cache.HealthBar.Size = UDim2.new(0, HEALTH_BAR_WIDTH, 0, sizeY)
                    cache.HealthFill.Size = UDim2.new(1, 0, hPercent, 0)
                    cache.HealthFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50):Lerp(Color3.fromRGB(0, 255, 140), hPercent)
                    cache.HealthBar.Visible = true
                else cache.HealthBar.Visible = false end

                if EspSettings.EspNames then
                    cache.Tag.Position = UDim2.new(0, screenPos.X, 0, boxPosY - 4)
                    cache.Tag.Text = player.DisplayName
                    cache.Tag.TextSize = math.clamp(14 - (distance / 100), 10, 14)
                    cache.Tag.Visible = true
                else cache.Tag.Visible = false end

                if EspSettings.EspDistance then
                    cache.DistTag.Position = UDim2.new(0, screenPos.X, 0, boxPosY + sizeY + 2)
                    cache.DistTag.Text = string.format("%d Studs", math.floor(distance))
                    cache.DistTag.TextSize = math.clamp(12 - (distance / 100), 9, 12)
                    cache.DistTag.Visible = true
                else cache.DistTag.Visible = false end

                if EspSettings.EspChams then
                    if not cache.CurrentCham or cache.CurrentCham.Parent ~= character then
                        if cache.CurrentCham then cache.CurrentCham:Destroy() end
                        
                        local freshHighlight = Instance.new("Highlight")
                        freshHighlight.Name = "NeonEngineStorage"
                        freshHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        freshHighlight.Parent = character
                        cache.CurrentCham = freshHighlight
                    end
                    
                    local neonMultiplier = EspSettings.ChamsBrightness
                    cache.CurrentCham.FillColor = Color3.new(teamChamColor.R * neonMultiplier, teamChamColor.G * neonMultiplier, teamChamColor.B * neonMultiplier)
                    cache.CurrentCham.OutlineColor = Color3.new(teamChamColor.R * neonMultiplier, teamChamColor.G * neonMultiplier, teamChamColor.B * neonMultiplier)
                    cache.CurrentCham.FillTransparency = 0.2
                    cache.CurrentCham.OutlineTransparency = 0
                    cache.CurrentCham.Enabled = true
                else 
                    if cache.CurrentCham then cache.CurrentCham.Enabled = false end
                end

                --// GLOW CHAMS (Enhanced highlight with always-on-top + glow fill)
                if EspSettings.EspGlowChams then
                    if not cache.CurrentGlowCham or cache.CurrentGlowCham.Parent ~= character then
                        if cache.CurrentGlowCham then cache.CurrentGlowCham:Destroy() end
                        local glowHL = Instance.new("Highlight")
                        glowHL.Name = "GlowEngineStorage"
                        glowHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        glowHL.Parent = character
                        cache.CurrentGlowCham = glowHL
                    end
                    local glowMult = EspSettings.GlowBrightness
                    cache.CurrentGlowCham.FillColor = Color3.new(
                        math.clamp(teamGlowColor.R * glowMult, 0, 1),
                        math.clamp(teamGlowColor.G * glowMult, 0, 1),
                        math.clamp(teamGlowColor.B * glowMult, 0, 1)
                    )
                    cache.CurrentGlowCham.OutlineColor = teamGlowColor
                    cache.CurrentGlowCham.FillTransparency = 0.5
                    cache.CurrentGlowCham.OutlineTransparency = 0
                    cache.CurrentGlowCham.Enabled = true
                else
                    if cache.CurrentGlowCham then cache.CurrentGlowCham.Enabled = false end
                end

                --// ENEMY WEAPON TAG
                if EspSettings.EspEnemyWeapons then
                    local weaponName = getEnemyWeaponName(player)
                    cache.WeaponTag.Position = UDim2.new(0, screenPos.X, 0, boxPosY + sizeY + 14)
                    cache.WeaponTag.Text = "[" .. weaponName .. "]"
                    cache.WeaponTag.TextSize = math.clamp(10 - (distance / 120), 8, 10)
                    cache.WeaponTag.Visible = true
                else
                    cache.WeaponTag.Visible = false
                end

                --// SKELETON ESP (Drawing-based bone lines)
                if EspSettings.EspSkeleton then
                    local boneConnections = {}
                    -- Get bone parts (works with both R6 and R15)
                    local head = character:FindFirstChild("Head")
                    local torso = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
                    local leftArm = character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftUpperArm")
                    local rightArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightUpperArm")
                    local leftLeg = character:FindFirstChild("Left Leg") or character:FindFirstChild("LeftUpperLeg")
                    local rightLeg = character:FindFirstChild("Right Leg") or character:FindFirstChild("RightUpperLeg")
                    local leftLowerArm = character:FindFirstChild("LeftLowerArm")
                    local rightLowerArm = character:FindFirstChild("RightLowerArm")
                    local leftLowerLeg = character:FindFirstChild("LeftLowerLeg")
                    local rightLowerLeg = character:FindFirstChild("RightLowerLeg")

                    if head and torso then
                        table.insert(boneConnections, {head, torso})
                        if leftArm then table.insert(boneConnections, {torso, leftArm}) end
                        if rightArm then table.insert(boneConnections, {torso, rightArm}) end
                        if leftLeg then table.insert(boneConnections, {torso, leftLeg}) end
                        if rightLeg then table.insert(boneConnections, {torso, rightLeg}) end
                        -- R15 extra bones (lower arms/legs)
                        if leftLowerArm and leftArm then table.insert(boneConnections, {leftArm, leftLowerArm}) end
                        if rightLowerArm and rightArm then table.insert(boneConnections, {rightArm, rightLowerArm}) end
                        if leftLowerLeg and leftLeg then table.insert(boneConnections, {leftLeg, leftLowerLeg}) end
                        if rightLowerLeg and rightLeg then table.insert(boneConnections, {rightLeg, rightLowerLeg}) end
                    end

                    -- Ensure we have enough Drawing lines for this player
                    if not SkeletonCache[player] then SkeletonCache[player] = {} end
                    local skLines = SkeletonCache[player]
                    while #skLines < #boneConnections do
                        local ok, line = pcall(function() return Drawing.new("Line") end)
                        if ok and line then
                            line.Visible = false
                            line.Color = teamBoxColor
                            line.Thickness = 1.5
                            line.Transparency = 1
                            table.insert(skLines, line)
                        else
                            break
                        end
                    end

                    -- Update line positions
                    for i, conn in ipairs(boneConnections) do
                        local line = skLines[i]
                        if line then
                            local from3d, onScreen1 = camera:WorldToViewportPoint(conn[1].Position)
                            local to3d, onScreen2 = camera:WorldToViewportPoint(conn[2].Position)
                            if onScreen1 and onScreen2 then
                                line.From = Vector2.new(from3d.X, from3d.Y)
                                line.To = Vector2.new(to3d.X, to3d.Y)
                                line.Color = teamBoxColor
                                line.Visible = true
                            else
                                line.Visible = false
                            end
                        end
                    end
                    -- Hide extra unused lines
                    for i = #boneConnections + 1, #skLines do
                        if skLines[i] then skLines[i].Visible = false end
                    end
                else
                    -- Skeleton off: hide all lines for this player
                    if SkeletonCache[player] then
                        for _, line in ipairs(SkeletonCache[player]) do
                            line.Visible = false
                        end
                    end
                end

                --// HEAD HITBOX SCALE (client-side enlargement)
                if EspSettings.HeadScale > 1 then
                    local head = character:FindFirstChild("Head")
                    if head and head:IsA("BasePart") then
                        if not OriginalHeadSizes[head] then
                            OriginalHeadSizes[head] = head.Size
                        end
                        pcall(function()
                            head.Size = OriginalHeadSizes[head] * EspSettings.HeadScale
                            head.Massless = true
                            head.CanCollide = false
                        end)
                    end
                end
            else
                cache.Box.Visible = false; cache.FilledBox.Visible = false; cache.Tracer.Visible = false; cache.HealthBar.Visible = false; cache.Tag.Visible = false; cache.DistTag.Visible = false; cache.WeaponTag.Visible = false; if cache.CurrentCham then cache.CurrentCham.Enabled = false end; if cache.CurrentGlowCham then cache.CurrentGlowCham.Enabled = false end
                -- Hide skeleton for off-screen players
                if SkeletonCache[player] then
                    for _, line in ipairs(SkeletonCache[player]) do
                        line.Visible = false
                    end
                end
            end
            end -- end of TeamCheckESP else block (if isTeamPlayer and TeamCheckESP then ... else ... end)
        else
            cache.Box.Visible = false; cache.FilledBox.Visible = false; cache.Tracer.Visible = false; cache.HealthBar.Visible = false; cache.Tag.Visible = false; cache.DistTag.Visible = false; cache.WeaponTag.Visible = false; if cache.CurrentCham then cache.CurrentCham.Enabled = false end; if cache.CurrentGlowCham then cache.CurrentGlowCham.Enabled = false end
            -- Hide skeleton for dead/missing players
            if SkeletonCache[player] then
                for _, line in ipairs(SkeletonCache[player]) do
                    line.Visible = false
                end
            end
        end
    end
end)

--// HEAD HITBOX SCALE RESTORATION (when HeadScale is set back to 1)
local function RestoreHeadScales()
    for head, size in pairs(OriginalHeadSizes) do
        if head and head.Parent then
            pcall(function()
                head.Size = size
                head.Massless = false
            end)
        end
    end
    OriginalHeadSizes = {}
end

--// WALLBANG ENGINE — Forward declaration (defined fully later)
local WallbangEngine

--// PANIC KEY (Instant Kill-Switch: disables ALL combat features)
uis.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if PlayerSettings.PanicKeyEnabled and input.KeyCode == Enum.KeyCode.P then
        -- Disable all combat modules
        SilentAim.Enabled = false
        SilentAim.ProjectilePrediction = false
        getgenv().silentAimTargetPos = nil
        TriggerBot.Enabled = false
        TriggerBot.LastDetected = 0
        RageMode.Enabled = false
        RageMode.WallCheck = false
        RageMode.Wallbang = false
        if WallbangEngine and WallbangEngine.stop then WallbangEngine:stop() end  -- Stop engine (desync + Gun.StartShooting hook)
        getgenv().silentAimTargetPos = nil  -- Reset silent aim target
        HoldBot.Enabled = false
        PlayerSettings.SlideBoost = false
        VisualSettings.LockIndicator = false
        lockLabel.Visible = false
        GunMods.MasterEnabled = false
        GunMods.NoRecoil = false
        GunMods.NoSpread = false
        GunMods.RapidFire = false
        GunMods.OneShot = false
        GunMods.InfiniteAmmo = false
        GunMods.InstantReload = false
        GunMods.InstantEquip = false
        GunMods.NoBulletDrop = false
        GunMods.MaxPierce = false
        GunMods.NoCooldowns = false
        GunMods.FireRateMultiplier = 1.0
        GunMods.ZeroSpreadIL = false
        GunMods.ZeroRecoilIL = false
        -- Stop Auto Win
        RageMode.AutoWinEnabled = false
        RageMode.Wallbang = false
        RageMode.AimStyle = "Visible"
        RageMode.AimSpeed = 0.18
        stopAutoWin()
        -- Stop Teleport Kill
        stopTeleportKill()
        -- Reset UI toggles
        if Toggles.SilentAimEnabled then Toggles.SilentAimEnabled:SetValue(false) end
        if Toggles.TriggerBotEnabled then Toggles.TriggerBotEnabled:SetValue(false) end
        if Toggles.RageModeEnabled then Toggles.RageModeEnabled:SetValue(false) end
        if Toggles.HoldBotEnabled then Toggles.HoldBotEnabled:SetValue(false) end
        if Toggles.GunModsMaster then Toggles.GunModsMaster:SetValue(false) end
        if Toggles.GunModsZeroSpreadIL then Toggles.GunModsZeroSpreadIL:SetValue(false) end
        if Toggles.GunModsZeroRecoilIL then Toggles.GunModsZeroRecoilIL:SetValue(false) end
        if Options.GunModsFireRateMultiplier then Options.GunModsFireRateMultiplier:SetValue(1.0) end
        if Toggles.AutoWin1v1 then Toggles.AutoWin1v1:SetValue(false) end
        if Toggles.RageWallbang then Toggles.RageWallbang:SetValue(false) end
        if Toggles.RageWallCheck then Toggles.RageWallCheck:SetValue(false) end
        -- Reset smoothing state
        holdBotPrevX = 0
        holdBotPrevY = 0
        holdBotCurrentTarget = nil
        -- Disable the stealth wallbang master flag.
        -- The __index hooks check this flag — when false, reads pass through to original values.
        -- We do NOT remove the metatables (they stay attached but become inert).
        -- This is cleaner than trying to unhook (which is hard with hookmetamethod).
        if WallbangStealthState then
            WallbangStealthState.enabled = false
        end
        -- Restore head scales
        EspSettings.HeadScale = 1.0
        RestoreHeadScales()
        -- Reset headscale UI slider if it exists
        if Options.HeadHitboxScale then Options.HeadHitboxScale:SetValue(1) end
        -- Hide all FOV circles
        SAFovRing.Visible = false; SAFovBg.Visible = false
        RageFovRing.Visible = false; RageFovBg.Visible = false
        HoldBotFovRing.Visible = false; HoldBotFovBg.Visible = false
        -- Stop Fly
        PlayerSettings.FlyEnabled = false
        stopFly()
        if Toggles.FlyToggle then Toggles.FlyToggle:SetValue(false) end
        -- Stop Fullbright
        PlayerSettings.FullbrightEnabled = false
        setFullbright(false)
        if Toggles.FullbrightToggle then Toggles.FullbrightToggle:SetValue(false) end
        -- Stop Anti-Ragdoll
        PlayerSettings.AntiRagdollEnabled = false
        setAntiRagdoll(false)
        if Toggles.AntiRagdollToggle then Toggles.AntiRagdollToggle:SetValue(false) end
        -- Stop WalkSpeed override
        PlayerSettings.WalkSpeedEnabled = false
        if Toggles.WalkSpeedEnabled then Toggles.WalkSpeedEnabled:SetValue(false) end
        -- Restore gravity
        PlayerSettings.GravityValue = 196
        workspace.Gravity = 196
        if Options.GravitySlider then Options.GravitySlider:SetValue(196) end
    end
end)

--// PLAYER MOVEMENT ENGINE (WalkSpeed, JumpPower, Noclip, AirWalk, SlideBoost, Gravity)
-- WalkSpeed uses Stepped (before physics) for maximum reliability
-- Rivals resets WalkSpeed every frame server-side, so we must override BEFORE physics simulates
rs.Stepped:Connect(function()
    local char = lp.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- WalkSpeed (aggressive enforcement — Stepped runs before physics)
    if PlayerSettings.WalkSpeedEnabled then
        pcall(function()
            hum.WalkSpeed = PlayerSettings.WalkSpeed
        end)
    end

    -- JumpPower
    if PlayerSettings.JumpPowerEnabled then
        pcall(function()
            hum.JumpPower = PlayerSettings.JumpPower
        end)
    end

    -- Noclip (walk through walls)
    if PlayerSettings.NoclipEnabled then
        pcall(function()
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    end
end)

-- Gravity and AirWalk use RenderStepped (visual/physics tweaks)
rs.RenderStepped:Connect(function()
    -- Gravity
    if PlayerSettings.GravityValue ~= 196 then
        pcall(function()
            workspace.Gravity = PlayerSettings.GravityValue
        end)
    end

    -- AirWalk (stay in the air — no gravity fall)
    if PlayerSettings.AirWalkEnabled then
        pcall(function()
            local char = lp.Character
            if char then
                local rootPart = char:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    local velocity = rootPart.AssemblyLinearVelocity
                    if velocity.Y < 0 then
                        rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
                    end
                end
            end
        end)
    end

    -- Slide Boost (speed boost while crouching — LeftCtrl held)
    if PlayerSettings.SlideBoost then
        pcall(function()
            local char2 = lp.Character
            if char2 then
                local rootPart = char2:FindFirstChild("HumanoidRootPart")
                if rootPart and uis:IsKeyDown(Enum.KeyCode.LeftControl) then
                    local dt = 1/60 -- Approximate frame time
                    rootPart.CFrame = rootPart.CFrame + (camera.CFrame.LookVector * PlayerSettings.SlideBoostPower * dt)
                end
            end
        end)
    end
end)

--// WALKSPEED — Simple working version (from Diablo Hub script)
-- Uses direct WalkSpeed set + Heartbeat "Always Active" to keep reapplying.
-- This is simpler and more reliable than the Stepped + __newindex hook approach.
local walkSpeedHeartbeatConn = nil

local function startWalkSpeedEnforce()
    if walkSpeedHeartbeatConn then return end
    walkSpeedHeartbeatConn = RunService.Heartbeat:Connect(function()
        if PlayerSettings.WalkSpeedEnabled then
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    pcall(function() hum.WalkSpeed = PlayerSettings.WalkSpeed end)
                end
            end
        end
    end)
end

local function stopWalkSpeedEnforce()
    if walkSpeedHeartbeatConn then
        walkSpeedHeartbeatConn:Disconnect()
        walkSpeedHeartbeatConn = nil
    end
end

-- Start enforcement loop (it self-checks WalkSpeedEnabled each frame)
startWalkSpeedEnforce()

--// PROJECTILE VELOCITY PREDICTION ENGINE (from ItemLibrary)
-- Calculates travel time from weapon projectile speed to lead targets
local ProjSpeedCache = {}
local ProjSpeedLoaded = false
local function getProjectileSpeed()
    if ProjSpeedLoaded then return ProjSpeedCache end
    ProjSpeedLoaded = true
    pcall(function()
        local RS = ReplicatedStorage
        local Items = require(RS:WaitForChild("Modules", 5):WaitForChild("ItemLibrary", 5)).Items
        for name, data in pairs(Items) do
            if typeof(data) == "table" and data.ShootProjectileSpeed then
                ProjSpeedCache[name] = data.ShootProjectileSpeed
            end
        end
    end)
    return ProjSpeedCache
end

-- Get current weapon name from player's character tool
local function getCurrentWeaponName()
    local char = lp.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool.Name end
    return nil
end

-- Calculate predicted position using projectile velocity
local function calculateProjectilePrediction(targetPos, targetRoot, weaponName, basePrediction)
    if not SilentAim.ProjectilePrediction then return targetPos end
    local speeds = getProjectileSpeed()
    local projSpeed = speeds[weaponName] or 900 -- Default fallback speed
    local camPos = camera.CFrame.Position
    local dist = (targetPos - camPos).Magnitude
    if dist <= 0 or projSpeed <= 0 then return targetPos end
    
    local travelTime = dist / projSpeed
    local estVel = targetRoot and targetRoot.AssemblyLinearVelocity or Vector3.zero
    
    -- Calculate lead factor (don't lead for very short travel times)
    local leadFactor = 1
    if travelTime < 0.04 then
        leadFactor = 0
    elseif travelTime < 0.12 then
        leadFactor = (travelTime - 0.04) / (0.12 - 0.04)
    end
    
    -- Decompose velocity into forward and lateral components
    local dir = (targetPos - camPos)
    local dirUnit = dir.Magnitude > 0 and (dir / dir.Magnitude) or Vector3.zero
    local lateral = estVel - dirUnit * estVel:Dot(dirUnit)
    
    -- Apply prediction
    local predicted = targetPos + lateral * travelTime * leadFactor
    -- Also add base prediction for vertical movement
    if basePrediction > 0 and targetRoot then
        predicted = predicted + (targetRoot.AssemblyLinearVelocity * basePrediction)
    end
    return predicted
end

--// ENEMY WEAPON DETECTION (reads ItemLibrary to identify held weapons)
local EnemyWeaponCache = {}
local function getEnemyWeaponName(player)
    if EnemyWeaponCache[player] then return EnemyWeaponCache[player] end
    local char = player.Character
    if not char then return "—" end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        EnemyWeaponCache[player] = tool.Name
        return tool.Name
    end
    EnemyWeaponCache[player] = nil
    return "—"
end

-- Clear weapon cache periodically
task.spawn(function()
    while task.wait(2) do
        if Library.Unloaded then break end
        EnemyWeaponCache = {}
    end
end)

--// DEVICE SPOOFER EXECUTION ENGINE
local function FireSpoof(wantedDeviceName)
    local actual = "MouseKeyboard"
    local wanted = DeviceMapping[wantedDeviceName] or "Gamepad"
    
    local success, remote = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes")
            :WaitForChild("Replication")
            :WaitForChild("Fighter")
            :WaitForChild("SetControls")
    end)
    
    if success and remote then
        remote:FireServer(actual)
        task.wait(0.3)
        remote:FireServer(wanted)
    end
end

task.spawn(function()
    while task.wait(5) do
        if MiscSettings.SpoofEnabled then
            FireSpoof(MiscSettings.SelectedDevice)
        end
        if Library.Unloaded then break end
    end
end)

--// AUTO WIN 1v1 ENGINE
-- Works exactly like the original: Silent Aim + ItemLibrary Fire Rate/Spread/Recoil mods + Auto Shoot
-- Uses utility.Raycast hook + hookmetamethod for bullet redirection
getgenv().AutoWinConnection = nil
getgenv().AutoShootConnection = nil

local function applyAutoWinItemLibMods()
    -- Exactly like the original script: modify ItemLibrary values
    pcall(function()
        local RS = ReplicatedStorage
        local Items = require(RS:WaitForChild("Modules", 10):WaitForChild("ItemLibrary", 10)).Items
        local exceptions = {["Sniper"] = true, ["Crossbow"] = true, ["Bow"] = true, ["RPG"] = true}
        for name, data in pairs(Items) do
            if typeof(data) == "table" and not exceptions[name] then
                if data.ShootSpread then data.ShootSpread = 0 end
                if data.ShootAccuracy then data.ShootAccuracy = 0 end
                if data.ShootRecoil then data.ShootRecoil = 0 end
                if data.ShootCooldown then data.ShootCooldown = 0.05 end
                if data.ShootBurstCooldown then data.ShootBurstCooldown = 0.05 end
            end
        end
    end)
end

--// WALLBANG: Disable wall clip prevention in ItemLibrary
-- Rivals weapons have ProjectileWallClipPreventionEnabled = true
-- This makes the weapon reject hits if a wall is between player and target
-- Setting it to false = removes the client-side wall check
-- Combined with Desync + Gun.StartShooting hook + EncodeCFrame!
getgenv().WallbangConnection = nil

-- STEALTH WALLBANG STATE
-- Tracks which item tables we've already attached a stealth metatable to.
-- The metatable intercepts reads of wall-pierce keys and returns our modified values,
-- WITHOUT touching the raw table — so any AC that checksums the raw table sees the originals.
-- (WallbangStealthState is forward-declared near the top of the file so the rage-toggle-disable
-- handler can reference it safely. We assign to it here.)
WallbangStealthState = {
    enabled = false,       -- master toggle — false = hooks pass-through (no override)
    applied = {},          -- set of item tables we've already stealth-hooked
    debugLog = {},         -- ring buffer of last 20 debug messages
    statFound = {          -- which keys exist on the items (for debug)
        ProjectileWallClipPreventionEnabled = 0,
        RaycastPierceCount = 0,
        RaycastGrabSmallHitboxes = 0,
        -- alternate keys we also try to intercept
        WallClipPrevention = 0,
        PierceCount = 0,
        MaxPierce = 0,
        Penetration = 0,
        CanPierce = 0,
        IgnoreWalls = 0,
    },
}

local function wbDebug(msg)
    local entry = string.format("[WB] %s", msg)
    table.insert(WallbangStealthState.debugLog, entry)
    if #WallbangStealthState.debugLog > 20 then
        table.remove(WallbangStealthState.debugLog, 1)
    end
    -- Print to console (visible in devtools)
    print(entry)
end

-- Apply stealth metamethod hook to a single item data table.
-- Returns true if a hook was attached (or already attached).
local function applyStealthToItem(name, data)
    if typeof(data) ~= "table" then return false end
    if WallbangStealthState.applied[data] then return false end
    WallbangStealthState.applied[data] = true

    -- Detect which keys are actually present on this item (for debug stats)
    if data.ProjectileWallClipPreventionEnabled ~= nil then
        WallbangStealthState.statFound.ProjectileWallClipPreventionEnabled =
            WallbangStealthState.statFound.ProjectileWallClipPreventionEnabled + 1
    end
    if data.RaycastPierceCount ~= nil then
        WallbangStealthState.statFound.RaycastPierceCount =
            WallbangStealthState.statFound.RaycastPierceCount + 1
    end
    if data.RaycastGrabSmallHitboxes ~= nil then
        WallbangStealthState.statFound.RaycastGrabSmallHitboxes =
            WallbangStealthState.statFound.RaycastGrabSmallHitboxes + 1
    end
    -- alt keys
    for _, alt in ipairs({"WallClipPrevention", "PierceCount", "MaxPierce", "Penetration", "CanPierce", "IgnoreWalls"}) do
        if data[alt] ~= nil then
            WallbangStealthState.statFound[alt] = WallbangStealthState.statFound[alt] + 1
        end
    end

    -- The wall-pierce overrides we want reads to return.
    -- These are the keys the gun's projectile raycast code consults.
    local overrides = {
        -- Primary (Rivals-specific — confirmed by ItemLibrary reverse-engineering)
        ProjectileWallClipPreventionEnabled = false,  -- main wallbang enabler
        RaycastPierceCount = 999,                     -- pierce 999 walls (was 10 — go full power)
        RaycastGrabSmallHitboxes = true,              -- grab small hitboxes through walls
        -- Alternate key names (in case the game uses these on some items)
        WallClipPrevention = false,
        PierceCount = 999,
        MaxPierce = 999,
        Penetration = 999,
        CanPierce = true,
        IgnoreWalls = true,
        -- Hit-chance / hit-confirmation
        AlwaysHit = true,
        HitChance = 1.0,
        -- Wallbang damage multiplier (some games scale damage per wall pierced)
        WallDamageMultiplier = 1.0,
        DamageFalloffPerWall = 0.0,
    }

    -- STEALTH HOOK STRATEGY
    -- 1) If the table already has a metatable with __index, we hookmetamethod __index
    --    (patch the metamethod in-place — table reference unchanged, stealthy).
    -- 2) If no metatable, we set a new one whose __index intercepts our keys.
    --    The raw table values are NOT modified — only reads go through our hook.
    -- 3) If hookmetamethod fails (some executors restrict it), we fall back to
    --    direct mutation (still works, just less stealthy).
    --
    -- IMPORTANT: All hooks check WallbangStealthState.enabled — when false, they pass through
    -- to the original behavior. This lets WallbangEngine:stop() cleanly disable wallbang
    -- without needing to unhook (which is hard with hookmetamethod).

    local mt = getrawmetatable and getrawmetatable(data)
    local oldIndex = mt and mt.__index
    local oldNewIndex = mt and mt.__newindex

    local hooked = false

    -- The __index interception function (shared between Strategy 1 and 2)
    local indexHook = function(t, k)
        if WallbangStealthState.enabled and overrides[k] ~= nil then
            return overrides[k]
        end
        if type(oldIndex) == "function" then
            return oldIndex(t, k)
        end
        return rawget(t, k)
    end

    -- The __newindex interception function (blocks AC from "fixing" our values while enabled)
    local newIndexHook = function(t, k, v)
        if WallbangStealthState.enabled and overrides[k] ~= nil then
            return  -- swallow: keep our override (silent — AC thinks it wrote successfully)
        end
        if type(oldNewIndex) == "function" then
            return oldNewIndex(t, k, v)
        end
        return rawset(t, k, v)
    end

    -- Strategy 1: hookmetamethod (preferred — patches in-place, table reference unchanged)
    -- This works on tables WITH or WITHOUT an existing metatable (hookmetamethod hooks
    -- at the engine level). If it fails, we fall back to Strategy 2.
    if hookmetamethod and getrawmetatable then
        pcall(function()
            hookmetamethod(data, "__index", indexHook)
            hookmetamethod(data, "__newindex", newIndexHook)
            hooked = true
        end)
    end

    -- Strategy 2: set a fresh metatable (if hookmetamethod failed or unavailable)
    if not hooked and setmetatable then
        pcall(function()
            -- If there's an existing metatable, preserve its other metamethods
            local baseMT = mt or {}
            local newMT = {}
            for k, v in pairs(baseMT) do
                newMT[k] = v
            end
            newMT.__index = indexHook
            newMT.__newindex = newIndexHook
            newMT.__zythera_wallbang = true  -- marker so we can detect our own metatable later
            if setmetatable then
                setmetatable(data, newMT)
                hooked = true
            end
        end)
    end

    -- Strategy 3 (FALLBACK): direct mutation if both metamethod strategies failed.
    -- Less stealthy (AC can checksum the raw table) but still makes wallbang work.
    -- We CAN'T easily undo this on disable, so we only set values when enabled is true
    -- via a re-apply loop. The values stay modified after disable, but the wallbang engine
    -- itself is disabled (Gun.StartShooting hook returns early when active=false).
    if not hooked then
        if WallbangStealthState.enabled then
            for k, v in pairs(overrides) do
                if data[k] ~= nil or k == "ProjectileWallClipPreventionEnabled"
                   or k == "RaycastPierceCount" or k == "RaycastGrabSmallHitboxes" then
                    rawset(data, k, v)
                end
            end
        end
    end

    return true
end

local function applyWallbangMods()
    pcall(function()
        local RS = ReplicatedStorage
        local ok, ItemLibrary = pcall(function()
            return require(RS:WaitForChild("Modules", 10):WaitForChild("ItemLibrary", 10))
        end)
        if not ok or not ItemLibrary or not ItemLibrary.Items then
            wbDebug("ItemLibrary.Items not found — wallbang mods skipped")
            return
        end

        local Items = ItemLibrary.Items
        local count = 0
        local itemCount = 0

        for name, data in pairs(Items) do
            if typeof(data) == "table" then
                itemCount = itemCount + 1
                if applyStealthToItem(name, data) then
                    count = count + 1
                end
            end
        end

        wbDebug(string.format(
            "applied stealth to %d/%d items | keys found: WCP=%d RPC=%d RGSH=%d | (alt: WCPv=%d PC=%d MP=%d Pen=%d CP=%d IW=%d)",
            count, itemCount,
            WallbangStealthState.statFound.ProjectileWallClipPreventionEnabled,
            WallbangStealthState.statFound.RaycastPierceCount,
            WallbangStealthState.statFound.RaycastGrabSmallHitboxes,
            WallbangStealthState.statFound.WallClipPrevention,
            WallbangStealthState.statFound.PierceCount,
            WallbangStealthState.statFound.MaxPierce,
            WallbangStealthState.statFound.Penetration,
            WallbangStealthState.statFound.CanPierce,
            WallbangStealthState.statFound.IgnoreWalls
        ))
    end)
end

local function startWallbang()
    -- Enable the stealth wallbang master flag BEFORE applying mods.
    -- The __index hooks check this flag — when true, reads return our overrides;
    -- when false, they pass through to the original values.
    WallbangStealthState.enabled = true
    applyWallbangMods()
    -- Start the Wallbang Engine (Desync + Gun.StartShooting + EncodeCFrame)
    -- [V8 FIX] Check if WallbangEngine is defined before calling :start()
    if WallbangEngine and WallbangEngine.start then
        WallbangEngine:start()
    else
        -- WallbangEngine not loaded yet — retry after a short delay
        task.spawn(function()
            task.wait(1)
            if WallbangEngine and WallbangEngine.start then
                WallbangEngine:start()
            end
        end)
    end
end

local autoWinLastFire = 0

local function startAutoWin()
    -- 1. Enable Silent Aim (using utility.Raycast hook + hookmetamethod)
    SilentAim.Enabled = true
    if Toggles.SilentAimEnabled then Toggles.SilentAimEnabled:SetValue(true) end

    -- 2. Apply ItemLibrary mods (fire rate, spread, recoil — exactly like original)
    applyAutoWinItemLibMods()

    -- 3. Auto Shoot — task.spawn loop (NOT RenderStepped, to avoid callback stacking)
    if getgenv().AutoWinConnection then getgenv().AutoWinConnection = nil end
    if getgenv().AutoShootConnection then getgenv().AutoShootConnection:Disconnect() end

    -- Auto Shoot runs on RenderStepped but uses tick-based throttling (no task.wait inside)
    getgenv().AutoShootConnection = RunService.RenderStepped:Connect(function()
        if not RageMode.AutoWinEnabled then return end
        pcall(function()
            local camera = workspace.CurrentCamera
            local best = nil
            local shortest = math.huge
            local center = camera.ViewportSize / 2

            for _, plr in pairs(players:GetPlayers()) do
                if plr ~= lp and plr.Character then
                    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                    local head = plr.Character:FindFirstChild("Head")
                    if hum and head and hum.Health > 0 then
                        local pos, onScreen = camera:WorldToViewportPoint(head.Position)
                        if onScreen then
                            local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                            if d < shortest then
                                shortest = d
                                best = plr
                            end
                        end
                    end
                end
            end

            if best then
                -- Throttle: only fire every 0.05 seconds (same as original)
                local now = tick()
                if now - autoWinLastFire >= 0.05 then
                    autoWinLastFire = now
                    -- Auto fire via mouse1click
                    autoFire()
                end
            end
        end)
    end)

    -- Re-apply ItemLibrary mods every 2 seconds (games may reset them)
    getgenv().AutoWinConnection = task.spawn(function()
        while RageMode.AutoWinEnabled do
            applyAutoWinItemLibMods()
            task.wait(2)
        end
    end)

    Library:Notify({
        Title = "Auto Win 1v1",
        Description = "Enabled — Silent Aim + Fire Rate + Auto Shoot ✅",
        Time = 5
    })
end

local function stopAutoWin()
    -- Disconnect auto shoot
    if getgenv().AutoShootConnection then
        getgenv().AutoShootConnection:Disconnect()
        getgenv().AutoShootConnection = nil
    end
    if getgenv().AutoWinConnection then
        getgenv().AutoWinConnection = nil
    end

    -- Disable Silent Aim
    SilentAim.Enabled = false
    if Toggles.SilentAimEnabled then Toggles.SilentAimEnabled:SetValue(false) end

    Library:Notify({
        Title = "Auto Win 1v1",
        Description = "Disabled ❌",
        Time = 4
    })
end

--// TELEPORT KILL ENGINE
-- Continuously teleports local player behind the target player on Heartbeat
local function findTpTarget(partialName)
    if not partialName or partialName == "" then return nil end
    local lowerName = string.lower(partialName)
    for _, plr in pairs(players:GetPlayers()) do
        if plr ~= lp then
            if string.find(string.lower(plr.Name), lowerName) or string.find(string.lower(plr.DisplayName), lowerName) then
                return plr
            end
        end
    end
    return nil
end

local function startTeleportKill(targetPlayer)
    tpKillTarget = targetPlayer
    TeleportKillSettings.Enabled = true
    if tpKillConnection then tpKillConnection:Disconnect() end
    tpKillConnection = RunService.Heartbeat:Connect(function()
        if not TeleportKillSettings.Enabled or not tpKillTarget then return end
        local myChar = lp.Character
        local targetChar = tpKillTarget.Character
        if myChar and targetChar then
            local myRoot = myChar:FindFirstChild("HumanoidRootPart")
            local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
            if myRoot and targetRoot then
                myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, TeleportKillSettings.Distance)
            end
        end
    end)
end

local function stopTeleportKill()
    TeleportKillSettings.Enabled = false
    if tpKillConnection then
        tpKillConnection:Disconnect()
        tpKillConnection = nil
    end
end

-- Auto-reconnect on character respawn
lp.CharacterAdded:Connect(function()
    task.wait(1)
    if TeleportKillSettings.Enabled and TeleportKillSettings.AutoReconnect and tpKillTarget then
        startTeleportKill(tpKillTarget)
    end
end)

-- ============================================================
-- [V8] ANTI RIOT SHIELD SYSTEM
-- Prevents the Riot Katana/Shield from reflecting your bullets back at you.
-- Strategy:
--   1. Destroy any "RiotShieldPart" in workspace (enemy shields)
--   2. Monitor for new RiotShieldParts being added and destroy them
--   3. Disable any "Reflect" attributes on characters
-- ============================================================

--// ITEM-LIBRARY FIRE RATE MODIFIER ENGINE
-- Specifically targets ReplicatedStorage > Modules > ItemLibrary for Rivals
-- Backs up original values and applies multiplier to ShootCooldown / ShootBurstCooldown
-- [V8 FIX] Wrapped in do...end to release locals (Lua 200 local limit)
do
local ItemLibBackup = {}
local ItemLibLoaded = false

task.spawn(function()
    task.wait(5)
    local RS = ReplicatedStorage
    local success, Items = pcall(function()
        return require(RS:WaitForChild("Modules", 10):WaitForChild("ItemLibrary", 10)).Items
    end)
    if not success or not Items then return end
    ItemLibLoaded = true

    -- Backup original values
    for name, data in pairs(Items) do
        if typeof(data) == "table" then
            ItemLibBackup[name] = {
                ShootCooldown = data.ShootCooldown,
                ShootBurstCooldown = data.ShootBurstCooldown,
                ShootSpread = data.ShootSpread,
                ShootAccuracy = data.ShootAccuracy,
                ShootRecoil = data.ShootRecoil,
            }
        end
    end

    -- Apply ItemLibrary-specific mods in a loop (re-apply every 2 seconds)
    -- Exceptions: Sniper, Crossbow, Bow, RPG (these should not be modified)
    local exceptions = { ["Sniper"] = true, ["Crossbow"] = true, ["Bow"] = true, ["RPG"] = true }

    local function applyItemLibMods()
        for name, data in pairs(Items) do
            if typeof(data) == "table" and not exceptions[name] and ItemLibBackup[name] then
                -- Fire Rate Multiplier
                if GunMods.MasterEnabled and GunMods.RapidFire and GunMods.FireRateMultiplier ~= 1.0 then
                    if data.ShootCooldown and ItemLibBackup[name].ShootCooldown then
                        data.ShootCooldown = ItemLibBackup[name].ShootCooldown * GunMods.FireRateMultiplier
                    end
                    if data.ShootBurstCooldown and ItemLibBackup[name].ShootBurstCooldown then
                        data.ShootBurstCooldown = ItemLibBackup[name].ShootBurstCooldown * GunMods.FireRateMultiplier
                    end
                end
                -- Zero Spread via ItemLibrary
                if GunMods.MasterEnabled and GunMods.ZeroSpreadIL then
                    if data.ShootSpread then data.ShootSpread = 0 end
                    if data.ShootAccuracy then data.ShootAccuracy = 0 end
                end
                -- Zero Recoil via ItemLibrary
                if GunMods.MasterEnabled and GunMods.ZeroRecoilIL then
                    if data.ShootRecoil then data.ShootRecoil = 0 end
                end
            end
        end
    end

    while true do
        if GunMods.MasterEnabled and (GunMods.RapidFire or GunMods.ZeroSpreadIL or GunMods.ZeroRecoilIL) then
            pcall(applyItemLibMods)
        end
        if Library.Unloaded then break end
        task.wait(2)
    end
end)

--// UI COMPONENT INITIALIZATION (COMBAT TAB - RAGE MODE / WALLBANG — top of Combat tab)
-- [V6] Rage Bot Enable — master toggle at the TOP
-- [V8 FIX] When turned OFF, disables all Rage Bot features (Wallbang, Auto Shoot, etc.)
-- [V8 FIX] Wrapped in do...end to release locals (Lua 200 local limit)
do
RageModeGroup:AddToggle("RageBotEnable", {
        Text = "Rage Bot Enable",
        Default = RageMode.Enabled,
        Tooltip = "Master toggle for Rage Bot. Turn this ON first, then configure other settings below. Turning it OFF stops Wallbang and Auto Shoot.",
})
Toggles.RageBotEnable:OnChanged(function()
        RageMode.Enabled = Toggles.RageBotEnable.Value
        -- [V8 FIX] When Rage Bot is disabled, force-stop all dependent features
        if not RageMode.Enabled then
            -- Stop Wallbang
            if RageMode.Wallbang then
                RageMode.Wallbang = false
                pcall(function() WallbangEngine:stop() end)
                if Toggles.RageWallbang then Toggles.RageWallbang:SetValue(false) end
            end
            -- Stop Auto Shoot (VoidSpam)
            if Toggles.VoidSpam and Toggles.VoidSpam.Value then
                -- Don't force the toggle off (user can re-enable later), but stop the firing loop
                -- The Heartbeat loop will detect RageMode.Enabled = false and stop firing
            end
        end
end)

-- [V2] Use FOV technique toggle
RageModeGroup:AddToggle("RageUseFOV", {
        Text = "Use FOV (Legit Rage)",
        Default = RageMode.UseFOV,
        Tooltip = "When ON: Rage Mode only targets players within the FOV circle (more legit). When OFF: targets entire screen (classic rage).",
})
Toggles.RageUseFOV:OnChanged(function()
        RageMode.UseFOV = Toggles.RageUseFOV.Value
        -- When UseFOV is toggled, update the FOV value
        if RageMode.UseFOV then
            RageMode.FOV = Options.RageFOVRadius and Options.RageFOVRadius.Value or 250
        else
            RageMode.FOV = math.huge
        end
end)

-- [V5] Show FOV Circle toggle — separate control for visibility
RageModeGroup:AddToggle("RageShowFOV", {
        Text = "Show FOV Circle",
        Default = false,
        Tooltip = "Show/hide the red FOV circle for Rage Mode. Only visible when Use FOV is enabled.",
})
Toggles.RageShowFOV:OnChanged(function()
        RageMode.FovVisible = Toggles.RageShowFOV.Value
end)

-- [V5] Filled FOV Circle toggle
RageModeGroup:AddToggle("RageFillFOV", {
        Text = "Filled FOV Circle",
        Default = false,
        Tooltip = "Fill the FOV circle with transparent color (only when Show FOV is on).",
})
Toggles.RageFillFOV:OnChanged(function()
        RageMode.FovFilled = Toggles.RageFillFOV.Value
end)

-- [V8] Rage Mode FOV Color picker
RageModeGroup:AddLabel("FOV Circle Color"):AddColorPicker("RageFovColor", {
        Default = Color3.fromRGB(255, 0, 0),
        Title = "Rage Mode FOV Color",
})
Options.RageFovColor:OnChanged(function()
        RageMode.FovColor = Options.RageFovColor.Value
        RageMode.FovRainbow = false
end)

RageModeGroup:AddToggle("RageFovRainbow", {
        Text = "Rainbow FOV Color",
        Default = false,
})
Toggles.RageFovRainbow:OnChanged(function()
        RageMode.FovRainbow = Toggles.RageFovRainbow.Value
end)

-- [V2] FOV Radius slider for Rage Mode (only used when UseFOV is on)
RageModeGroup:AddSlider("RageFOVRadius", {
        Text = "Rage FOV Radius",
        Default = 250,
        Min = 50,
        Max = 1000,
        Rounding = 0,
        Tooltip = "FOV radius for Rage Mode (only applies when Use FOV is enabled)",
})
Options.RageFOVRadius:OnChanged(function()
        if RageMode.UseFOV then
            RageMode.FOV = Options.RageFOVRadius.Value
        end
end)

RageModeGroup:AddToggle("RageWallbang", {
        Text = "Wallbang",
        Default = RageMode.Wallbang,
        Tooltip = "Desync + Shot Data Hook — kills through walls via Gun.StartShooting modification. Requires Rage Bot Enable to be ON.",
})
Toggles.RageWallbang:OnChanged(function()
        -- [V8 FIX] Wallbang can only be enabled if Rage Bot is enabled
        if Toggles.RageWallbang.Value and not RageMode.Enabled then
            Toggles.RageWallbang:SetValue(false)
            if getgenv().ZX_Notify then
                getgenv().ZX_Notify("Rage Bot", "Enable Rage Bot first!", "warning")
            end
            return
        end
        RageMode.Wallbang = Toggles.RageWallbang.Value
        if RageMode.Wallbang and RageMode.Enabled then
            startWallbang()
        else
            if WallbangEngine and WallbangEngine.stop then
                WallbangEngine:stop()
            end
        end
end)

--// AUTO SHOOT — max speed auto-fire via RenderStepped (TOGGLE mode)
-- Fires 8 clicks per frame (max safe limit) = 480 shots/sec — fastest possible.
-- Toggle once to start, toggle again to stop.
-- Wrapped in `do ... end` to release locals (Lua 200 local limit).
do
local VoidSpam = {
    Enabled = false,
    Active = false,     -- true while firing is active
    Connection = nil,   -- RenderStepped connection reference
}

--// AUTO SHOOT ENGINE — 8 clicks per frame (MAX SPEED)
-- 8 clicks × 60fps = 480 shots/sec — fastest possible without C stack overflow.
local function startVoidSpamLoop()
    if VoidSpam.Active then return end
    VoidSpam.Active = true
    VoidSpam.Connection = RunService.RenderStepped:Connect(function()
        pcall(function()
            for _ = 1, 8 do
                if mouse1press then mouse1press() end
                if mouse1release then mouse1release() end
            end
        end)
    end)
end

local function stopVoidSpamLoop()
    VoidSpam.Active = false
    if VoidSpam.Connection then
        VoidSpam.Connection:Disconnect()
        VoidSpam.Connection = nil
    end
    -- Release mouse in case it was stuck pressed
    pcall(function()
        if mouse1release then mouse1release() end
    end)
end

--// AUTO SHOOT UI — [V8 FIX] Toggle now OFF by default. Must be enabled manually.
-- Auto Shoot ONLY fires when BOTH Rage Bot Enable AND Auto Shoot are ON, AND keybind is pressed.
RageModeGroup:AddToggle("VoidSpam", {
        Text = "Auto Shoot",
        Default = false,  -- [V8] OFF by default — requires Rage Bot Enable
        Tooltip = "Spam-fires at MAX SPEED (480 shots/sec). Requires Rage Bot Enable to be ON. Press the keybind (E) to start/stop.",
})
Toggles.VoidSpam:OnChanged(function()
        -- [V8 FIX] Auto Shoot can only be enabled if Rage Bot is enabled
        if Toggles.VoidSpam.Value and not RageMode.Enabled then
            Toggles.VoidSpam:SetValue(false)
            if getgenv().ZX_Notify then
                getgenv().ZX_Notify("Rage Bot", "Enable Rage Bot first!", "warning")
            end
            return
        end
        VoidSpam.Enabled = Toggles.VoidSpam.Value
        -- If Auto Shoot is turned off, stop any active firing loop
        if not VoidSpam.Enabled and VoidSpam.Active then
            stopVoidSpamLoop()
        end
end)

--// AUTO SHOOT KEYBIND — Toggle mode (press once to start firing, press again to stop)
RageModeGroup:AddLabel("Auto Shoot Key"):AddKeyPicker("VoidSpamKey", {
        Default = "E",
        SyncToggleState = false,
        Mode = "Toggle",  -- Toggle = press once to start, press again to stop
        NoUI = false,
        Text = "Auto Shoot keybind",
})

--// AUTO SHOOT — firing is controlled by keybind state AND Auto Shoot toggle AND Rage Bot Enable
-- [V8 FIX] All three conditions must be true to fire:
--   1. RageMode.Enabled (Rage Bot Enable toggle)
--   2. VoidSpam.Enabled (Auto Shoot toggle)
--   3. keyState (keybind is pressed)
RunService.Heartbeat:Connect(function()
    if not Options.VoidSpamKey then return end
    local ok, keyState = pcall(function() return Options.VoidSpamKey:GetState() end)
    if not ok then return end

    -- [V8 FIX] Only fire if Rage Bot is enabled AND Auto Shoot is enabled
    local canFire = RageMode.Enabled and VoidSpam.Enabled and keyState

    if canFire and not VoidSpam.Active then
        startVoidSpamLoop()
    elseif not canFire and VoidSpam.Active then
        stopVoidSpamLoop()
    end
end)
end  -- end of auto shoot `do` block (releases ~4 locals)

--// UI COMPONENT INITIALIZATION (COMBAT TAB - ORBIT — auto nearest enemy with team check)
OrbitGroup:AddToggle("OrbitEnabled", {
        Text = "Enable Orbit",
        Default = PlayerSettings.OrbitEnabled,
        Tooltip = "Auto-orbit around the nearest enemy (skips teammates & dead players). Fully automatic — no target selection needed.",
})
Toggles.OrbitEnabled:OnChanged(function()
        PlayerSettings.OrbitEnabled = Toggles.OrbitEnabled.Value
end)

OrbitGroup:AddSlider("OrbitRadiusSlider", {
        Text = "Orbit Radius",
        Default = PlayerSettings.OrbitRadius,
        Min = 3,
        Max = 30,
        Rounding = 1,
        Suffix = " studs",
        Tooltip = "Distance from target (smaller=closer orbit, larger=wider orbit)",
})
Options.OrbitRadiusSlider:OnChanged(function()
        PlayerSettings.OrbitRadius = Options.OrbitRadiusSlider.Value
end)

OrbitGroup:AddSlider("OrbitMaxDistanceSlider", {
        Text = "Max Distance",
        Default = PlayerSettings.OrbitMaxDistance,
        Min = 50,
        Max = 2000,
        Rounding = 0,
        Suffix = " studs",
        Tooltip = "Max range to find a target. Orbit won't activate unless an enemy is within this distance. Default 400.",
})
Options.OrbitMaxDistanceSlider:OnChanged(function()
        PlayerSettings.OrbitMaxDistance = Options.OrbitMaxDistanceSlider.Value
end)

OrbitGroup:AddSlider("OrbitSpeedSlider", {
        Text = "Orbit Speed",
        Default = PlayerSettings.OrbitSpeed,
        Min = 0.5,
        Max = 15,
        Rounding = 1,
        Suffix = " rad/s",
        Tooltip = "Rotation speed (higher=faster orbit). 3 = moderate, 10 = very fast",
})
Options.OrbitSpeedSlider:OnChanged(function()
        PlayerSettings.OrbitSpeed = Options.OrbitSpeedSlider.Value
end)

OrbitGroup:AddSlider("OrbitHeightSlider", {
        Text = "Height Offset",
        Default = PlayerSettings.OrbitHeight,
        Min = -5,
        Max = 15,
        Rounding = 1,
        Suffix = " studs",
        Tooltip = "Height above target. 0=ground level, 3=slightly floating, 15=high above",
})
Options.OrbitHeightSlider:OnChanged(function()
        PlayerSettings.OrbitHeight = Options.OrbitHeightSlider.Value
end)

--// ORBIT KEYBIND — toggle orbit on/off with a key
-- NOTE: SyncToggleState must be FALSE because this keypicker is attached to a Label,
-- not a Toggle. Labels don't have a SetValue method, so SyncToggleState=true would error.
-- We sync the state manually via the Heartbeat loop below.
OrbitGroup:AddLabel("Orbit Key"):AddKeyPicker("OrbitKey", {
        Default = "X",
        SyncToggleState = false,
        Mode = "Toggle",
        NoUI = false,
        Text = "Orbit keybind",
})

--// ORBIT — sync keypicker state with OrbitEnabled
-- SyncToggleState means the keypicker maintains its own toggle state.
-- We read that state via GetState() and apply to PlayerSettings.OrbitEnabled.
-- We avoid calling Toggles.OrbitEnabled:SetValue() to prevent the recursion error
-- (SetValue missing on table when called from inside OnChanged callback).
RunService.Heartbeat:Connect(function()
        if not Options.OrbitKey then return end
        local ok, keyState = pcall(function() return Options.OrbitKey:GetState() end)
        if not ok then return end
        if keyState ~= PlayerSettings.OrbitEnabled then
                PlayerSettings.OrbitEnabled = keyState
        end
end)

--// UI COMPONENT INITIALIZATION (COMBAT TAB - LEFT: SILENT AIM)
SilentAimGroup:AddToggle("SilentAimEnabled", {
        Text = "Silent Aim Enabled",
        Default = SilentAim.Enabled,
        Tooltip = "Redirects bullet raycasts to target (no visible mouse movement)",
})
Toggles.SilentAimEnabled:OnChanged(function()
        SilentAim.Enabled = Toggles.SilentAimEnabled.Value
end)

SilentAimGroup:AddToggle("SAWallCheck", {
        Text = "Wall Check",
        Default = SilentAim.WallCheck,
        Tooltip = "Only targets visible players (raycast visibility check)",
})
Toggles.SAWallCheck:OnChanged(function()
        SilentAim.WallCheck = Toggles.SAWallCheck.Value
end)


SilentAimGroup:AddSlider("SAPrediction", {
        Text = "Prediction",
        Default = SilentAim.Prediction,
        Min = 0,
        Max = 0.2,
        Rounding = 2,
        Tooltip = "Velocity prediction for bullet redirection",
})
Options.SAPrediction:OnChanged(function()
        SilentAim.Prediction = Options.SAPrediction.Value
end)

SilentAimGroup:AddDropdown("SAHitPart", {
        Text = "Target Part",
        Values = { "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "Pelvis" },
        Default = 1,
        Multi = false,
        Tooltip = "Where to redirect your bullets. Head = headshots, UpperTorso = body shots, etc.",
})
Options.SAHitPart:OnChanged(function()
        SilentAim.HitPart = Options.SAHitPart.Value
end)

SilentAimGroup:AddSlider("SAHitCooldown", {
        Text = "Hit Cooldown (ms)",
        Default = 10,
        Min = 1,
        Max = 50,
        Rounding = 0,
        Suffix = " ms",
        Tooltip = "Time between silent aim hits. 10ms = first bullet hits, then wait 10ms before next hit. Lower = more bullets hit.",
})
Options.SAHitCooldown:OnChanged(function()
        SilentAim.HitCooldown = Options.SAHitCooldown.Value / 1000
end)

SilentAimGroup:AddToggle("SAFovVisible", {
        Text = "Show FOV Circle",
        Default = SilentAim.FovVisible,
})
Toggles.SAFovVisible:OnChanged(function()
        SilentAim.FovVisible = Toggles.SAFovVisible.Value
end)

SilentAimGroup:AddToggle("SAFovFilled", {
        Text = "Filled FOV Circle",
        Default = SilentAim.FovFilled,
})
Toggles.SAFovFilled:OnChanged(function()
        SilentAim.FovFilled = Toggles.SAFovFilled.Value
end)

-- [V8] Silent Aim FOV Color picker
SilentAimGroup:AddLabel("FOV Circle Color"):AddColorPicker("SAFovColor", {
        Default = Color3.fromRGB(255, 255, 255),
        Title = "Silent Aim FOV Color",
})
Options.SAFovColor:OnChanged(function()
        SilentAim.FovColor = Options.SAFovColor.Value
        SilentAim.FovRainbow = false
end)

SilentAimGroup:AddToggle("SAFovRainbow", {
        Text = "Rainbow FOV Color",
        Default = false,
})
Toggles.SAFovRainbow:OnChanged(function()
        SilentAim.FovRainbow = Toggles.SAFovRainbow.Value
end)

SilentAimGroup:AddSlider("SAFovRadius", {
        Text = "FOV Radius Size",
        Default = SilentAim.FOV,
        Min = 50,
        Max = 400,
        Rounding = 0,
})
Options.SAFovRadius:OnChanged(function()
        SilentAim.FOV = Options.SAFovRadius.Value
end)

SilentAimGroup:AddSlider("SAMaxDistance", {
        Text = "Max Distance (Studs)",
        Default = SilentAim.MaxDistance,
        Min = 50,
        Max = 2000,
        Rounding = 0,
        Tooltip = "Targets beyond this 3D distance are ignored",
})
Options.SAMaxDistance:OnChanged(function()
        SilentAim.MaxDistance = Options.SAMaxDistance.Value
end)

SilentAimGroup:AddToggle("SAProjectilePrediction", {
        Text = "Projectile Prediction",
        Default = SilentAim.ProjectilePrediction,
        Tooltip = "Uses weapon projectile speed from ItemLibrary for accurate long-range prediction",
})
Toggles.SAProjectilePrediction:OnChanged(function()
        SilentAim.ProjectilePrediction = Toggles.SAProjectilePrediction.Value
end)

--// UI COMPONENT INITIALIZATION (COMBAT TAB - TEAM CHECK)
TeamCheckGroup:AddToggle("TeamCheckEnabled", {
        Text = "Team Check",
        Default = TeamCheck.Enabled,
        Tooltip = "Prevents targeting teammates — ON by default!",
})
Toggles.TeamCheckEnabled:OnChanged(function()
        TeamCheck.Enabled = Toggles.TeamCheckEnabled.Value
end)

--// UI COMPONENT INITIALIZATION (COMBAT TAB - RIGHT: AIMBOT)
HoldBotGroup:AddToggle("HoldBotEnabled", {
        Text = "Aimbot Enabled",
        Default = HoldBot.Enabled,
        Tooltip = "Smooth aim assist — hold key to aim at nearest target",
})
Toggles.HoldBotEnabled:OnChanged(function()
        HoldBot.Enabled = Toggles.HoldBotEnabled.Value
end)

HoldBotGroup:AddToggle("HoldBotKeybind", {
        Text = "Use Keybind (Hold to Aim)",
        Default = HoldBot.UseKeybind,
        Tooltip = "When enabled, Aimbot only activates while holding the key",
})
Toggles.HoldBotKeybind:OnChanged(function()
        HoldBot.UseKeybind = Toggles.HoldBotKeybind.Value
end)

HoldBotGroup:AddLabel("Aimbot Key"):AddKeyPicker("HoldBotKey", {
        Default = "CapsLock",
        Mode = "Hold",
        NoUI = false,
        Text = "Aimbot keybind",
})

HoldBotGroup:AddToggle("HoldBotSmoothing", {
        Text = "Use Smoothing",
        Default = HoldBot.UseSmoothing,
        Tooltip = "Enable for smooth aim movement, disable for instant snap",
})
Toggles.HoldBotSmoothing:OnChanged(function()
        HoldBot.UseSmoothing = Toggles.HoldBotSmoothing.Value
end)

HoldBotGroup:AddSlider("HoldBotSmoothingValue", {
        Text = "Smoothing Value",
        Default = HoldBot.SmoothingValue,
        Min = 1,
        Max = 100,
        Rounding = 0,
        Tooltip = "1=Very fast, 100=Very slow tracking",
})
Options.HoldBotSmoothingValue:OnChanged(function()
        HoldBot.SmoothingValue = Options.HoldBotSmoothingValue.Value
end)

HoldBotGroup:AddToggle("HoldBotPrediction", {
        Text = "Movement Prediction",
        Default = HoldBot.Prediction,
        Tooltip = "Leads moving targets by predicting their movement",
})
Toggles.HoldBotPrediction:OnChanged(function()
        HoldBot.Prediction = Toggles.HoldBotPrediction.Value
end)

HoldBotGroup:AddToggle("HoldBotPersistent", {
        Text = "Persistent Target",
        Default = HoldBot.PersistentTarget,
        Tooltip = "Won't switch targets until you release the key",
})
Toggles.HoldBotPersistent:OnChanged(function()
        HoldBot.PersistentTarget = Toggles.HoldBotPersistent.Value
end)

HoldBotGroup:AddToggle("HoldBotWallCheck", {
        Text = "Wall Check",
        Default = not HoldBot.TargetBehindWalls,
        Tooltip = "Only aim at visible players (not behind walls)",
})
Toggles.HoldBotWallCheck:OnChanged(function()
        HoldBot.TargetBehindWalls = not Toggles.HoldBotWallCheck.Value
end)

HoldBotGroup:AddDropdown("HoldBotHitPart", {
        Values = { "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart" },
        Default = 1,
        Multi = false,
        Text = "Target Part",
})
Options.HoldBotHitPart:OnChanged(function()
        HoldBot.HitPart = Options.HoldBotHitPart.Value
end)

HoldBotGroup:AddToggle("HoldBotFovVisible", {
        Text = "Show FOV Circle",
        Default = HoldBot.FovVisible,
})
Toggles.HoldBotFovVisible:OnChanged(function()
        HoldBot.FovVisible = Toggles.HoldBotFovVisible.Value
end)

HoldBotGroup:AddToggle("HoldBotFovFilled", {
        Text = "Filled FOV Circle",
        Default = HoldBot.FovFilled,
})
Toggles.HoldBotFovFilled:OnChanged(function()
        HoldBot.FovFilled = Toggles.HoldBotFovFilled.Value
end)

-- [V7] FOV Color picker for Aimbot (HoldBot) — pick ANY color you want
HoldBotGroup:AddLabel("FOV Circle Color"):AddColorPicker("HoldBotFovColor", {
        Default = Color3.fromRGB(0, 255, 255),  -- Cyan
        Title = "Aimbot FOV Color",
})
Options.HoldBotFovColor:OnChanged(function()
        HoldBot.FovColor = Options.HoldBotFovColor.Value
        HoldBot.FovRainbow = false  -- disable rainbow when picking custom color
end)

-- [V7] Rainbow FOV toggle — cycles through all colors automatically
HoldBotGroup:AddToggle("HoldBotFovRainbow", {
        Text = "Rainbow FOV Color",
        Default = false,
        Tooltip = "Cycles the FOV circle through all colors automatically.",
})
Toggles.HoldBotFovRainbow:OnChanged(function()
        HoldBot.FovRainbow = Toggles.HoldBotFovRainbow.Value
end)

HoldBotGroup:AddSlider("HoldBotFovRadius", {
        Text = "FOV Radius Size",
        Default = HoldBot.FOV,
        Min = 50,
        Max = 600,
        Rounding = 0,
})
Options.HoldBotFovRadius:OnChanged(function()
        HoldBot.FOV = Options.HoldBotFovRadius.Value
end)

-- [V5] Reaction Time slider moved to BOTTOM of Aimbot section
HoldBotGroup:AddSlider("HoldBotReactionTime", {
        Text = "Reaction Time (ms)",
        Default = 50,
        Min = 0,
        Max = 500,
        Rounding = 0,
        Suffix = " ms",
        Tooltip = "Delay before aimbot reacts to a new target. 0 = instant snap, 100ms = smooth legit aim.",
})
Options.HoldBotReactionTime:OnChanged(function()
        HoldBot.ReactionTime = Options.HoldBotReactionTime.Value / 1000
end)

--// TRIGGER BOT UI (Auto-fire when crosshair is on enemy)
TriggerBotGroup:AddToggle("TriggerBotEnabled", {
        Text = "Enable Trigger Bot",
        Default = TriggerBot.Enabled,
        Tooltip = "Automatically fires when your crosshair is on an enemy",
})
Toggles.TriggerBotEnabled:OnChanged(function()
        TriggerBot.Enabled = Toggles.TriggerBotEnabled.Value
end)

TriggerBotGroup:AddSlider("TriggerBotDelay", {
        Text = "Trigger Delay",
        Default = TriggerBot.Delay,
        Min = 0.01,
        Max = 0.3,
        Rounding = 2,
        Suffix = "s",
        Tooltip = "Delay before firing after detecting target (lower=faster, higher=more legit)",
})
Options.TriggerBotDelay:OnChanged(function()
        TriggerBot.Delay = Options.TriggerBotDelay.Value
end)

TriggerBotGroup:AddToggle("TriggerBotWallCheck", {
        Text = "Wall Check",
        Default = TriggerBot.WallCheck,
        Tooltip = "Only fire if target is visible (not behind walls)",
})
Toggles.TriggerBotWallCheck:OnChanged(function()
        TriggerBot.WallCheck = Toggles.TriggerBotWallCheck.Value
end)

TriggerBotGroup:AddToggle("TriggerBotKeybind", {
        Text = "Hold RMB to Fire",
        Default = TriggerBot.Keybind,
        Tooltip = "When ON, only fires while holding right mouse button",
})
Toggles.TriggerBotKeybind:OnChanged(function()
        TriggerBot.Keybind = Toggles.TriggerBotKeybind.Value
end)

--// UI COMPONENT INITIALIZATION (COMBAT TAB - ANTI-AIM v4)
-- Simple working Anti-Aim: multiplies CFrame by rotation each frame.
AntiAimGroup:AddToggle("AntiAimEnabled", {
        Text = "Enable Anti-Aim",
        Default = AntiAim.Enabled,
        Tooltip = "Rotates your character each frame to mess up enemy aimbots. Simple but works.",
})
Toggles.AntiAimEnabled:OnChanged(function()
        AntiAim.Enabled = Toggles.AntiAimEnabled.Value
end)

AntiAimGroup:AddDropdown("AntiAimMode", {
        Values = { "Spin", "Jitter", "Reverse" },
        Default = 1,
        Multi = false,
        Text = "Mode",
        Tooltip = "Spin=continuous rotation | Jitter=random angle jumps | Reverse=face backwards",
})
Options.AntiAimMode:OnChanged(function()
        AntiAim.Mode = Options.AntiAimMode.Value
end)

AntiAimGroup:AddSlider("AntiAimSpeed", {
        Text = "Spin Speed",
        Default = AntiAim.Speed,
        Min = 5,
        Max = 45,
        Rounding = 0,
        Suffix = " deg",
        Tooltip = "Degrees per frame (higher = faster rotation)",
})
Options.AntiAimSpeed:OnChanged(function()
        AntiAim.Speed = Options.AntiAimSpeed.Value
end)

AntiAimGroup:AddSlider("AntiAimJitterRange", {
        Text = "Jitter Range",
        Default = AntiAim.JitterRange,
        Min = 10,
        Max = 180,
        Rounding = 0,
        Suffix = " deg",
        Tooltip = "Max random angle for Jitter mode",
})
Options.AntiAimJitterRange:OnChanged(function()
        AntiAim.JitterRange = Options.AntiAimJitterRange.Value
end)
end  -- end of Combat UI do-block

--// QUICK PRESETS (Legit / Visuals — one-click configuration)
-- [V8 FIX] Wrapped in do...end to release locals
do
local PresetsGroup = Tabs.Combat:AddLeftGroupbox("Quick Presets")

PresetsGroup:AddButton("Legit Preset", function()
        -- Legit: subtle features only, looks natural
        SilentAim.Enabled = true
        SilentAim.ProjectilePrediction = true
        SilentAim.WallCheck = true
        SilentAim.HitPart = "UpperTorso"  -- Body shots look more legit
        SilentAim.HitCooldown = 0.03          -- Legit: 30ms between hits
        SilentAim.FOV = 120
        SilentAim.MaxDistance = 300
        SilentAim.Prediction = 0.02
        if Toggles.SilentAimEnabled then Toggles.SilentAimEnabled:SetValue(true) end
        if Toggles.SAWallCheck then Toggles.SAWallCheck:SetValue(true) end
        if Toggles.SAProjectilePrediction then Toggles.SAProjectilePrediction:SetValue(true) end
        if Options.SAHitPart then Options.SAHitPart:SetValue("UpperTorso") end
        if Options.SAHitCooldown then Options.SAHitCooldown:SetValue(30) end
        if Options.SAFovRadius then Options.SAFovRadius:SetValue(120) end
        if Options.SAMaxDistance then Options.SAMaxDistance:SetValue(300) end
        if Options.SAPrediction then Options.SAPrediction:SetValue(0.02) end
        -- Disable rage features
        RageMode.Enabled = false
        if Toggles.RageModeEnabled then Toggles.RageModeEnabled:SetValue(false) end
        GunMods.MasterEnabled = false
        if Toggles.GunModsMaster then Toggles.GunModsMaster:SetValue(false) end
end)

PresetsGroup:AddButton("Visuals Preset", function()
        -- Visuals: ESP + Chams + Lock Indicator, no combat
        EspSettings.EspBoxes = true
        EspSettings.EspChams = true
        EspSettings.EspNames = true
        EspSettings.EspDistance = true
        EspSettings.EspHealth = true
        EspSettings.EspEnemyWeapons = true
        EspSettings.EspGlowChams = true
        VisualSettings.LockIndicator = true
        VisualSettings.HideSmoke = true
        VisualSettings.HideFlashbang = true
        if Toggles.EspBoxOutlines then Toggles.EspBoxOutlines:SetValue(true) end
        if Toggles.EspChamsToggle then Toggles.EspChamsToggle:SetValue(true) end
        if Toggles.EspNamesToggle then Toggles.EspNamesToggle:SetValue(true) end
        if Toggles.EspDistanceToggle then Toggles.EspDistanceToggle:SetValue(true) end
        if Toggles.EspHealthToggle then Toggles.EspHealthToggle:SetValue(true) end
        if Toggles.EspEnemyWeaponsToggle then Toggles.EspEnemyWeaponsToggle:SetValue(true) end
        if Toggles.EspGlowChamsToggle then Toggles.EspGlowChamsToggle:SetValue(true) end
        if Toggles.LockIndicatorToggle then Toggles.LockIndicatorToggle:SetValue(true) end
        if Toggles.HideSmoke then Toggles.HideSmoke:SetValue(true) end
        if Toggles.HideFlashbang then Toggles.HideFlashbang:SetValue(true) end
        -- Disable combat features
        SilentAim.Enabled = false
        if Toggles.SilentAimEnabled then Toggles.SilentAimEnabled:SetValue(false) end
        RageMode.Enabled = false
        if Toggles.RageModeEnabled then Toggles.RageModeEnabled:SetValue(false) end
        GunMods.MasterEnabled = false
        if Toggles.GunModsMaster then Toggles.GunModsMaster:SetValue(false) end
end)
end  -- end of Presets do-block

--// UI COMPONENT INITIALIZATION (COMBAT TAB - GUN MODS — from Diablo Hub script)
-- Simple gun mods using ItemLibrary require, matching the uploaded Diablo Hub script structure
-- [V8 FIX] Wrapped in do...end to release locals
do
local GunModApplyButton
task.spawn(function()
    task.wait(5)
    local RS = cloneref(game:GetService("ReplicatedStorage"))
    local ItemLib = RS:WaitForChild("Modules", 10):WaitForChild("ItemLibrary", 10)
    if not ItemLib then return end

    --// GUN MODS APPLY FUNCTION — modifies ItemLibrary weapon tables
    local function applyGunModsNow()
        local ok, lib = pcall(function() return require(ItemLib) end)
        if not ok or not lib or not lib.Items then
            Library:Notify({Title = "Gun Mods", Description = "ItemLibrary not found", Time = 3})
            return
        end
        for weaponName, weaponData in pairs(lib.Items) do
            if type(weaponData) == "table" then
                pcall(function()
                    if GunMods.NoRecoil then
                        if weaponData.Recoil then weaponData.Recoil = 0 end
                        if weaponData.CameraRecoil then weaponData.CameraRecoil = 0 end
                        if weaponData.ShootRecoil then weaponData.ShootRecoil = 0 end
                        if weaponData.RecoilAmount then weaponData.RecoilAmount = 0 end
                    end
                    if GunMods.NoSpread then
                        if weaponData.Spread then weaponData.Spread = 0 end
                        if weaponData.ShootSpread then weaponData.ShootSpread = 0 end
                        if weaponData.ShootAccuracy then weaponData.ShootAccuracy = 0 end
                        if weaponData.Accuracy then weaponData.Accuracy = 0 end
                        if weaponData.BulletSpread then weaponData.BulletSpread = 0 end
                    end
                    if GunMods.RapidFire then
                        if weaponData.FireRate then weaponData.FireRate = 0.01 end
                        if weaponData.FireDelay then weaponData.FireDelay = 0.01 end
                        if weaponData.ShootDelay then weaponData.ShootDelay = 0.01 end
                        if weaponData.Cooldown then weaponData.Cooldown = 0.01 end
                    end
                    if GunMods.OneShot then
                        if weaponData.Damage then weaponData.Damage = 9999 end
                        if weaponData.BaseDamage then weaponData.BaseDamage = 9999 end
                        if weaponData.HitDamage then weaponData.HitDamage = 9999 end
                    end
                    if GunMods.InfiniteAmmo then
                        if weaponData.MaxAmmo then weaponData.MaxAmmo = 99999 end
                        if weaponData.ClipSize then weaponData.ClipSize = 99999 end
                        if weaponData.MagazineSize then weaponData.MagazineSize = 99999 end
                    end
                    if GunMods.InstantReload then
                        if weaponData.ReloadTime then weaponData.ReloadTime = 0 end
                        if weaponData.ReloadDuration then weaponData.ReloadDuration = 0 end
                    end
                    if GunMods.InstantEquip then
                        if weaponData.EquipTime then weaponData.EquipTime = 0 end
                        if weaponData.DeployTime then weaponData.DeployTime = 0 end
                    end
                    if GunMods.NoBulletDrop then
                        if weaponData.BulletDrop then weaponData.BulletDrop = 0 end
                        if weaponData.Gravity then weaponData.Gravity = 0 end
                        if weaponData.BulletGravity then weaponData.BulletGravity = 0 end
                    end
                    if GunMods.MaxPierce then
                        if weaponData.Pierce then weaponData.Pierce = 999 end
                        if weaponData.MaxPierce then weaponData.MaxPierce = 999 end
                        if weaponData.Penetration then weaponData.Penetration = 999 end
                    end
                    if GunMods.NoCooldowns then
                        if weaponData.Cooldown then weaponData.Cooldown = 0 end
                        if weaponData.AbilityCooldown then weaponData.AbilityCooldown = 0 end
                        if weaponData.MeleeCooldown then weaponData.MeleeCooldown = 0 end
                    end
                end)
            end
        end
        Library:Notify({Title = "Gun Mods", Description = "Mods applied to ItemLibrary", Time = 3})
    end
    _G.ZytheraApplyGunMods = applyGunModsNow
end)

GunModsAimGroup:AddToggle("GunModsMaster", {
        Text = "Enable Gun Mods",
        Default = GunMods.MasterEnabled,
        Tooltip = "Master toggle — must be ON for any gun mod to work",
})
Toggles.GunModsMaster:OnChanged(function()
        GunMods.MasterEnabled = Toggles.GunModsMaster.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then
                _G.ZytheraApplyGunMods()
        end
end)

GunModsAimGroup:AddToggle("GunModsNoRecoil", {
        Text = "No Recoil",
        Default = GunMods.NoRecoil,
        Tooltip = "Zero camera kick when shooting",
})
Toggles.GunModsNoRecoil:OnChanged(function()
        GunMods.NoRecoil = Toggles.GunModsNoRecoil.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsAimGroup:AddToggle("GunModsNoSpread", {
        Text = "No Spread / Perfect Accuracy",
        Default = GunMods.NoSpread,
        Tooltip = "Bullets go exactly where you aim — no random deviation",
})
Toggles.GunModsNoSpread:OnChanged(function()
        GunMods.NoSpread = Toggles.GunModsNoSpread.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsAimGroup:AddToggle("GunModsRapidFire", {
        Text = "Rapid Fire",
        Default = GunMods.RapidFire,
        Tooltip = "Removes fire rate delay — full auto on everything",
})
Toggles.GunModsRapidFire:OnChanged(function()
        GunMods.RapidFire = Toggles.GunModsRapidFire.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsAimGroup:AddToggle("GunModsOneShot", {
        Text = "One Shot Kill",
        Default = GunMods.OneShot,
        Tooltip = "Maximizes damage to instantly kill on hit",
})
Toggles.GunModsOneShot:OnChanged(function()
        GunMods.OneShot = Toggles.GunModsOneShot.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsAmmoGroup:AddToggle("GunModsInfAmmo", {
        Text = "Infinite Ammo",
        Default = GunMods.InfiniteAmmo,
        Tooltip = "Never run out of ammo in your magazine",
})
Toggles.GunModsInfAmmo:OnChanged(function()
        GunMods.InfiniteAmmo = Toggles.GunModsInfAmmo.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsAmmoGroup:AddToggle("GunModsInstantReload", {
        Text = "Instant Reload",
        Default = GunMods.InstantReload,
        Tooltip = "Reload time becomes zero",
})
Toggles.GunModsInstantReload:OnChanged(function()
        GunMods.InstantReload = Toggles.GunModsInstantReload.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsAmmoGroup:AddToggle("GunModsInstantEquip", {
        Text = "Instant Equip",
        Default = GunMods.InstantEquip,
        Tooltip = "Weapon equip/swap animation is instant",
})
Toggles.GunModsInstantEquip:OnChanged(function()
        GunMods.InstantEquip = Toggles.GunModsInstantEquip.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsAmmoGroup:AddToggle("GunModWalkSpeed", {
        Text = "Super Walk Speed",
        Default = false,
        Tooltip = "Increases weapon-specific walk speed multiplier",
})
Toggles.GunModWalkSpeed:OnChanged(function()
        PlayerSettings.GunModWalkSpeed = Toggles.GunModWalkSpeed.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsMiscGroup:AddToggle("GunModsNoBulletDrop", {
        Text = "No Bullet Drop",
        Default = GunMods.NoBulletDrop,
        Tooltip = "Bullets travel in a straight line — no gravity arc",
})
Toggles.GunModsNoBulletDrop:OnChanged(function()
        GunMods.NoBulletDrop = Toggles.GunModsNoBulletDrop.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsMiscGroup:AddToggle("GunModsMaxPierce", {
        Text = "Max Pierce / Infinite Hits",
        Default = GunMods.MaxPierce,
        Tooltip = "Bullets pass through all targets — infinite penetration",
})
Toggles.GunModsMaxPierce:OnChanged(function()
        GunMods.MaxPierce = Toggles.GunModsMaxPierce.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsMiscGroup:AddToggle("GunModsNoCooldowns", {
        Text = "No Cooldowns (Melee/Abilities)",
        Default = GunMods.NoCooldowns,
        Tooltip = "Removes all cooldown timers on melee and abilities",
})
Toggles.GunModsNoCooldowns:OnChanged(function()
        GunMods.NoCooldowns = Toggles.GunModsNoCooldowns.Value
        if GunMods.MasterEnabled and _G.ZytheraApplyGunMods then _G.ZytheraApplyGunMods() end
end)

GunModsMiscGroup:AddButton("Apply Mods Now", function()
        if _G.ZytheraApplyGunMods then
                _G.ZytheraApplyGunMods()
        else
                Library:Notify({Title = "Gun Mods", Description = "Still loading ItemLibrary...", Time = 3})
        end
end)

GunModsMiscGroup:AddButton("Reset All Gun Mods", function()
        Library:Notify({Title = "Gun Mods", Description = "Please rejoin server to restore original weapon values.", Time = 4})
end)

--// UI COMPONENT INITIALIZATION (COMBAT TAB - HOLDBOT TARGET SETTINGS)
HoldBotTargetGroup:AddToggle("HoldBotTargetBehindWalls", {
        Text = "Target Behind Walls",
        Default = HoldBot.TargetBehindWalls,
        Tooltip = "Allow aiming at targets even if they're behind walls",
})
Toggles.HoldBotTargetBehindWalls:OnChanged(function()
        HoldBot.TargetBehindWalls = Toggles.HoldBotTargetBehindWalls.Value
end)

HoldBotTargetGroup:AddToggle("HoldBotTargetZone", {
        Text = "Use Target Zone",
        Default = HoldBot.UseTargetZone,
        Tooltip = "Only target players within a specific distance",
})
Toggles.HoldBotTargetZone:OnChanged(function()
        HoldBot.UseTargetZone = Toggles.HoldBotTargetZone.Value
end)

HoldBotTargetGroup:AddSlider("HoldBotTargetZoneDistance", {
        Text = "Target Zone Distance",
        Default = HoldBot.TargetZoneDistance,
        Min = 100,
        Max = 3000,
        Rounding = 0,
        Suffix = " studs",
})
Options.HoldBotTargetZoneDistance:OnChanged(function()
        HoldBot.TargetZoneDistance = Options.HoldBotTargetZoneDistance.Value
end)

HoldBotTargetGroup:AddSlider("HoldBotMaxDistance", {
        Text = "Max Range",
        Default = HoldBot.MaxDistance,
        Min = 100,
        Max = 2000,
        Rounding = 0,
        Suffix = " studs",
})
Options.HoldBotMaxDistance:OnChanged(function()
        HoldBot.MaxDistance = Options.HoldBotMaxDistance.Value
end)
end  -- end of Gun Mods UI do-block

--// GUN MODS ENGINE (Hooks into weapon configuration tables at runtime)
-- Scans ReplicatedStorage Modules for weapon config tables and overrides properties
task.spawn(function()
    -- Wait for game to fully load
    task.wait(5)

    local RS = ReplicatedStorage
    local Modules = RS:WaitForChild("Modules", 10)
    if not Modules then return end

    -- Common weapon config table keys that games use
    local recoilKeys = {"Recoil", "CameraRecoil", "RecoilAmount", "Kick", "CameraKick", "RecoilUp", "RecoilSide", "VerticalRecoil", "HorizontalRecoil"}
    local spreadKeys = {"Spread", "Accuracy", "BulletSpread", "HipFireSpread", "ADS_Spread", "MaxSpread", "MinSpread", "ConeOfFire", "Deviation"}
    local fireRateKeys = {"FireRate", "RateOfFire", "FireDelay", "ShootDelay", "Cooldown", "FireInterval", "RPM", "RoundPerMinute", "DelayBetweenShots"}
    local ammoKeys = {"Ammo", "MaxAmmo", "ClipSize", "MagazineSize", "AmmoCapacity", "AmmoPerClip"}
    local reloadKeys = {"ReloadTime", "ReloadDuration", "ReloadSpeed", "TimeToReload"}
    local equipKeys = {"EquipTime", "EquipDuration", "DeployTime", "DrawTime", "TimeToEquip"}
    local bulletDropKeys = {"BulletDrop", "Gravity", "BulletGravity", "ProjectileGravity", "DropRate"}
    local pierceKeys = {"Pierce", "Penetration", "MaxPierce", "MaxPenetration", "HitCount", "MaxTargets"}
    local damageKeys = {"Damage", "DamageAmount", "BaseDamage", "HitDamage", "AttackDamage"}
    local cooldownKeys = {"Cooldown", "CooldownTime", "AbilityCooldown", "MeleeCooldown", "SkillCooldown", "CastDelay"}

    local function applyGunMods(configTable, tableName)
        if type(configTable) ~= "table" then return end

        pcall(function()
            -- No Recoil: set all recoil values to 0
            if GunMods.NoRecoil then
                for _, key in ipairs(recoilKeys) do
                    if configTable[key] ~= nil then
                        if type(configTable[key]) == "number" then
                            configTable[key] = 0
                        elseif type(configTable[key]) == "table" then
                            -- Some games use {X=0, Y=0} tables for recoil
                            for subKey, _ in pairs(configTable[key]) do
                                if type(configTable[key][subKey]) == "number" then
                                    configTable[key][subKey] = 0
                                end
                            end
                        end
                    end
                end
            end

            -- No Spread: set all spread values to 0
            if GunMods.NoSpread then
                for _, key in ipairs(spreadKeys) do
                    if configTable[key] ~= nil then
                        if type(configTable[key]) == "number" then
                            configTable[key] = 0
                        elseif type(configTable[key]) == "table" then
                            for subKey, _ in pairs(configTable[key]) do
                                if type(configTable[key][subKey]) == "number" then
                                    configTable[key][subKey] = 0
                                end
                            end
                        end
                    end
                end
            end

            -- Rapid Fire: reduce fire delay to minimum
            if GunMods.RapidFire then
                for _, key in ipairs(fireRateKeys) do
                    if configTable[key] ~= nil then
                        if type(configTable[key]) == "number" then
                            if key == "RPM" or key == "RoundPerMinute" then
                                configTable[key] = 3000  -- 3000 RPM is absurdly fast
                            else
                                configTable[key] = 0.01  -- Near-zero delay
                            end
                        end
                    end
                end
            end

            -- Infinite Ammo: set magazine size to 9999
            if GunMods.InfiniteAmmo then
                for _, key in ipairs(ammoKeys) do
                    if configTable[key] ~= nil and type(configTable[key]) == "number" then
                        configTable[key] = 9999
                    end
                end
            end

            -- Instant Reload: set reload time to 0
            if GunMods.InstantReload then
                for _, key in ipairs(reloadKeys) do
                    if configTable[key] ~= nil and type(configTable[key]) == "number" then
                        configTable[key] = 0
                    end
                end
            end

            -- Instant Equip: set equip time to 0
            if GunMods.InstantEquip then
                for _, key in ipairs(equipKeys) do
                    if configTable[key] ~= nil and type(configTable[key]) == "number" then
                        configTable[key] = 0
                    end
                end
            end

            -- No Bullet Drop: set gravity/drop to 0
            if GunMods.NoBulletDrop then
                for _, key in ipairs(bulletDropKeys) do
                    if configTable[key] ~= nil and type(configTable[key]) == "number" then
                        configTable[key] = 0
                    end
                end
            end

            -- Max Pierce: set penetration to 999
            if GunMods.MaxPierce then
                for _, key in ipairs(pierceKeys) do
                    if configTable[key] ~= nil and type(configTable[key]) == "number" then
                        configTable[key] = 999
                    end
                end
            end

            -- One Shot Kill: set damage to 9999
            if GunMods.OneShot then
                for _, key in ipairs(damageKeys) do
                    if configTable[key] ~= nil and type(configTable[key]) == "number" then
                        configTable[key] = 9999
                    end
                end
            end

            -- No Cooldowns: set all cooldown values to 0
            if GunMods.NoCooldowns then
                for _, key in ipairs(cooldownKeys) do
                    if configTable[key] ~= nil and type(configTable[key]) == "number" then
                        configTable[key] = 0
                    end
                end
            end
        end)
    end

    -- Recursively scan for weapon config tables
    local function scanForConfigs(parent, depth)
        if depth > 4 then return end  -- Don't go too deep
        if not parent then return end

        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("ModuleScript") then
                local nameLower = string.lower(child.Name)
                local isWeaponModule = nameLower:find("weapon") or nameLower:find("gun") or nameLower:find("firearm")
                    or nameLower:find("config") or nameLower:find("setting") or nameLower:find("stat")
                    or nameLower:find("data") or nameLower:find("balance") or nameLower:find("attribute")

                if isWeaponModule then
                    pcall(function()
                        local success, config = pcall(function()
                            return require(child)
                        end)
                        if success and type(config) == "table" then
                            applyGunMods(config, child.Name)
                            -- Some games nest weapon tables (e.g., config.Weapons.AK47)
                            for subKey, subVal in pairs(config) do
                                if type(subVal) == "table" then
                                    applyGunMods(subVal, child.Name .. "." .. subKey)
                                    -- One more level deep
                                    for deepKey, deepVal in pairs(subVal) do
                                        if type(deepVal) == "table" then
                                            applyGunMods(deepVal, child.Name .. "." .. subKey .. "." .. deepKey)
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end
            end
            scanForConfigs(child, depth + 1)
        end
    end

    -- Run gun mods loop — continuously re-applies every 2 seconds so changes persist
    -- (games may reset weapon configs on respawn/round change)
    local function gunModsLoop()
        while true do
            if GunMods.MasterEnabled then
                scanForConfigs(Modules, 0)
                -- Also scan ReplicatedStorage directly (some games put configs there)
                scanForConfigs(RS, 0)
                -- Also scan Workspace for weapon tools
                local tools = player:FindFirstChild("Backpack")
                if tools then
                    for _, tool in ipairs(tools:GetChildren()) do
                        if tool:IsA("Tool") then
                            for _, child in ipairs(tool:GetDescendants()) do
                                if child:IsA("ModuleScript") or child:IsA("Configuration") or child:IsA("IntValue") or child:IsA("NumberValue") then
                                    -- Override NumberValue instances in tool (some games use these)
                                    if child:IsA("NumberValue") then
                                        local nameLower = string.lower(child.Name)
                                        if GunMods.NoRecoil and (nameLower:find("recoil") or nameLower:find("kick")) then
                                            child.Value = 0
                                        elseif GunMods.NoSpread and (nameLower:find("spread") or nameLower:find("accuracy")) then
                                            child.Value = 0
                                        elseif GunMods.RapidFire and (nameLower:find("firerate") or nameLower:find("firedelay") or nameLower:find("cooldown")) then
                                            child.Value = 0.01
                                        elseif GunMods.InfiniteAmmo and (nameLower:find("ammo") or nameLower:find("clip") or nameLower:find("magazine")) then
                                            child.Value = 9999
                                        elseif GunMods.InstantReload and nameLower:find("reload") then
                                            child.Value = 0
                                        elseif GunMods.InstantEquip and nameLower:find("equip") then
                                            child.Value = 0
                                        elseif GunMods.NoBulletDrop and (nameLower:find("drop") or nameLower:find("gravity")) then
                                            child.Value = 0
                                        elseif GunMods.MaxPierce and (nameLower:find("pierce") or nameLower:find("penetration")) then
                                            child.Value = 999
                                        elseif GunMods.OneShot and nameLower:find("damage") then
                                            child.Value = 9999
                                        end
                                    end
                                    -- Try to require ModuleScripts inside tools
                                    if child:IsA("ModuleScript") then
                                        pcall(function()
                                            local success, config = pcall(function() return require(child) end)
                                            if success and type(config) == "table" then
                                                applyGunMods(config, tool.Name .. "/" .. child.Name)
                                            end
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            task.wait(2)
        end
    end

    -- Start the gun mods loop
    task.spawn(gunModsLoop)
end)
end  -- end of ItemLib Gun Mods do-block

do
--// HIDE SMOKE / HIDE FLASHBANG ENGINE
-- [V8 FIX] Wrapped in task.spawn to avoid local register overflow (Lua 5.1 limit = 200 locals)
task.spawn(function()
-- Rivals-specific: "Smoke Grenade" for smoke, "FlashbangEffect" for flashbang
local hideSmokeConn = nil
local hideFlashConn = nil

-- Hide Smoke: Instantly remove Smoke Grenade instances from workspace
local function handleSmokeGrenade(inst)
    if not inst or not inst.Parent then return end
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("ParticleEmitter") then
            d.Enabled = false
        elseif d:IsA("BasePart") then
            d.Transparency = 1
        elseif d:IsA("Decal") or d:IsA("Texture") then
            d.Transparency = 1
        end
    end
    task.defer(function()
        if inst and inst.Parent then inst:Destroy() end
    end)
end

local function startHideSmoke()
    if hideSmokeConn then return end
    -- Remove existing smoke grenades
    for _, v in ipairs(workspace:GetDescendants()) do
        if v and v.Name == "Smoke Grenade" then handleSmokeGrenade(v) end
    end
    -- Watch for new smoke grenades
    hideSmokeConn = workspace.DescendantAdded:Connect(function(child)
        if not VisualSettings.HideSmoke then return end
        if typeof(child) == "Instance" and child.Name == "Smoke Grenade" then
            handleSmokeGrenade(child)
        end
    end)
end

local function stopHideSmoke()
    if hideSmokeConn then hideSmokeConn:Disconnect(); hideSmokeConn = nil end
end

-- Hide Flashbang: Remove FlashbangEffect instances from workspace and GUI
local function handleFlashInstance(inst)
    if not inst then return end
    task.defer(function()
        if inst and inst.Parent then inst:Destroy() end
    end)
end

local function startHideFlash()
    if hideFlashConn then return end
    -- Remove existing flashbang effects in workspace
    for _, v in ipairs(workspace:GetDescendants()) do
        if v and (v.Name == "FlashbangEffect" or v.Name:lower():find("flash")) then
            handleFlashInstance(v)
        end
    end
    -- Watch for new flashbang effects
    hideFlashConn = workspace.DescendantAdded:Connect(function(child)
        if not VisualSettings.HideFlashbang then return end
        if child and (child.Name == "FlashbangEffect" or child.Name:lower():find("flash")) then
            handleFlashInstance(child)
        end
    end)
    -- Also continuously clear flash GUI overlays
    task.spawn(function()
        while VisualSettings.HideFlashbang do
            if Library.Unloaded then break end
            pcall(function()
                local playerGui = lp:FindFirstChildOfClass("PlayerGui")
                if playerGui then
                    for _, gui in ipairs(playerGui:GetChildren()) do
                        for _, child in ipairs(gui:GetDescendants()) do
                            if child:IsA("Frame") or child:IsA("ImageLabel") then
                                local nameLower = child.Name:lower()
                                if nameLower:find("flash") or nameLower:find("blind") or nameLower:find("stun") or nameLower:find("whiteout") then
                                    child.Visible = false
                                end
                            end
                        end
                    end
                end
            end)
            task.wait(0.3)
        end
    end)
end

local function stopHideFlash()
    if hideFlashConn then hideFlashConn:Disconnect(); hideFlashConn = nil end
end

task.spawn(function()
    while task.wait(0.5) do
        if Library.Unloaded then break end
        
        if VisualSettings.HideSmoke then
            if not hideSmokeConn then startHideSmoke() end
            pcall(function()
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj.Name == "Smoke Grenade" then handleSmokeGrenade(obj) end
                    if obj:IsA("Smoke") or (obj:IsA("ParticleEmitter") and (obj.Name:lower():find("smoke") or obj.Parent.Name:lower():find("smoke"))) then
                        obj.Enabled = false
                    end
                end
            end)
        else
            stopHideSmoke()
        end
        
        if VisualSettings.HideFlashbang then
            if not hideFlashConn then startHideFlash() end
        else
            stopHideFlash()
        end
    end
end)
end)  -- end of task.spawn (Hide Smoke/Flash)
end

--// UI COMPONENT INITIALIZATION (ESP LEFT SWITCHES)
EspGroup:AddToggle("EspBoxOutlines", {
        Text = "ESP Box Outlines",
        Default = EspSettings.EspBoxes,
})
Toggles.EspBoxOutlines:OnChanged(function()
        EspSettings.EspBoxes = Toggles.EspBoxOutlines.Value
end)

EspGroup:AddToggle("EspFilledBoxes", {
        Text = "Modern Filled Boxes",
        Default = EspSettings.EspFilledBoxes,
})
Toggles.EspFilledBoxes:OnChanged(function()
        EspSettings.EspFilledBoxes = Toggles.EspFilledBoxes.Value
end)

EspGroup:AddToggle("EspLineTracers", {
        Text = "ESP Line Tracers",
        Default = EspSettings.EspLines,
})
Toggles.EspLineTracers:OnChanged(function()
        EspSettings.EspLines = Toggles.EspLineTracers.Value
end)

EspGroup:AddToggle("EspHealthBars", {
        Text = "ESP Health Bars",
        Default = EspSettings.EspHealth,
})
Toggles.EspHealthBars:OnChanged(function()
        EspSettings.EspHealth = Toggles.EspHealthBars.Value
end)

EspGroup:AddToggle("EspNames", {
        Text = "ESP Names",
        Default = EspSettings.EspNames,
})
Toggles.EspNames:OnChanged(function()
        EspSettings.EspNames = Toggles.EspNames.Value
end)

EspGroup:AddToggle("EspDistance", {
        Text = "ESP Distance",
        Default = EspSettings.EspDistance,
})
Toggles.EspDistance:OnChanged(function()
        EspSettings.EspDistance = Toggles.EspDistance.Value
end)

EspGroup:AddToggle("EspChamsToggle", {
        Text = "Neon Chams",
        Default = EspSettings.EspChams,
})
Toggles.EspChamsToggle:OnChanged(function()
        EspSettings.EspChams = Toggles.EspChamsToggle.Value
end)

EspGroup:AddToggle("EspSkeletonToggle", {
        Text = "Skeleton ESP",
        Default = EspSettings.EspSkeleton,
        Tooltip = "Draw bone lines connecting body parts (R6 & R15)",
})
Toggles.EspSkeletonToggle:OnChanged(function()
        EspSettings.EspSkeleton = Toggles.EspSkeletonToggle.Value
        if not EspSettings.EspSkeleton then
            -- Hide all skeleton lines when disabled
            for _, lines in pairs(SkeletonCache) do
                for _, line in ipairs(lines) do
                    line.Visible = false
                end
            end
        end
end)

EspGroup:AddToggle("EspGlowChamsToggle", {
        Text = "Glow Chams",
        Default = EspSettings.EspGlowChams,
        Tooltip = "Enhanced highlight ESP — always visible through walls with glow fill",
})
Toggles.EspGlowChamsToggle:OnChanged(function()
        EspSettings.EspGlowChams = Toggles.EspGlowChamsToggle.Value
end)

EspGroup:AddToggle("EspEnemyWeaponsToggle", {
        Text = "Show Enemy Weapons",
        Default = EspSettings.EspEnemyWeapons,
        Tooltip = "Displays the weapon name each enemy is holding on ESP",
})
Toggles.EspEnemyWeaponsToggle:OnChanged(function()
        EspSettings.EspEnemyWeapons = Toggles.EspEnemyWeaponsToggle.Value
end)

EspGroup:AddSlider("MaxEspDistance", {
        Text = "Max ESP Distance",
        Default = EspSettings.MaxEspDistance,
        Min = 50,
        Max = 2000,
        Rounding = 0,
})
Options.MaxEspDistance:OnChanged(function()
        EspSettings.MaxEspDistance = Options.MaxEspDistance.Value
end)

EspGroup:AddToggle("TeamCheckESP", {
        Text = "Team Check ESP (Enemies Only)",
        Default = EspSettings.TeamCheckESP,
})
Toggles.TeamCheckESP:OnChanged(function()
        EspSettings.TeamCheckESP = Toggles.TeamCheckESP.Value
end)

--// UI COMPONENT INITIALIZATION (ESP RIGHT - VISUAL CONFIGURATORS)
local colorOptions = {"Red", "Blue", "Purple", "Yellow", "Pink", "Orange", "Cyan", "Rainbow"}

EspVisualGroup:AddDropdown("EspColorPresets", {
        Values = colorOptions,
        Default = 2, 
        Multi = false,
        Text = "Main ESP Color Preset",
})
Options.EspColorPresets:OnChanged(function()
        EspSettings.EspColorMode = Options.EspColorPresets.Value
end)

EspVisualGroup:AddDropdown("EspFilledColorPresets", {
        Values = colorOptions,
        Default = 2, 
        Multi = false,
        Text = "Filled Box Color Preset",
})
Options.EspFilledColorPresets:OnChanged(function()
        EspSettings.EspFilledColorMode = Options.EspFilledColorPresets.Value
end)

EspVisualGroup:AddDropdown("EspChamsColorPresets", {
        Values = colorOptions,
        Default = 7, 
        Multi = false,
        Text = "Chams Independent Color Preset",
})
Options.EspChamsColorPresets:OnChanged(function()
        EspSettings.EspChamsColorMode = Options.EspChamsColorPresets.Value
end)

EspVisualGroup:AddSlider("ChamsBrightnessSlider", {
        Text = "Chams Glow Power (Neon Level)",
        Default = 5,
        Min = 1,
        Max = 15,
        Rounding = 1,
})
Options.ChamsBrightnessSlider:OnChanged(function()
        EspSettings.ChamsBrightness = Options.ChamsBrightnessSlider.Value
end)

EspVisualGroup:AddDropdown("EspGlowColorPresets", {
        Values = {"Red", "Blue", "Cyan", "Green", "Yellow", "Purple", "Pink", "Orange", "White", "Rainbow"},
        Default = 3,
        Text = "Glow Chams Color Preset",
})
Options.EspGlowColorPresets:OnChanged(function()
        EspSettings.EspGlowColorMode = Options.EspGlowColorPresets.Value
end)

EspVisualGroup:AddSlider("GlowBrightnessSlider", {
        Text = "Glow Chams Brightness",
        Default = 3,
        Min = 1,
        Max = 10,
        Rounding = 1,
})
Options.GlowBrightnessSlider:OnChanged(function()
        EspSettings.GlowBrightness = Options.GlowBrightnessSlider.Value
end)

EspVisualGroup:AddSlider("FilledBoxTransparencySlider", {
        Text = "Filled Box Transparency",
        Default = EspSettings.FilledBoxTransparency * 100,
        Min = 0,
        Max = 100,
        Rounding = 0,
    Suffix = "%"
})
Options.FilledBoxTransparencySlider:OnChanged(function()
        EspSettings.FilledBoxTransparency = Options.FilledBoxTransparencySlider.Value / 100
end)

EspVisualGroup:AddSlider("BoxThickness", {
        Text = "Box Line Thickness",
        Default = EspSettings.BoxThickness,
        Min = 1,
        Max = 5,
        Rounding = 1,
})
Options.BoxThickness:OnChanged(function()
        EspSettings.BoxThickness = Options.BoxThickness.Value
end)

EspVisualGroup:AddSlider("LineThickness", {
        Text = "Tracer Line Thickness",
        Default = EspSettings.LineThickness,
        Min = 1,
        Max = 5,
        Rounding = 1,
})
Options.LineThickness:OnChanged(function()
        EspSettings.LineThickness = Options.LineThickness.Value
end)

EspVisualGroup:AddSlider("BoxSizeMultiplier", {
        Text = "ESP Box Scale/Size",
        Default = EspSettings.BoxSizeMultiplier,
        Min = 800,
        Max = 2000,
        Rounding = 0,
})
Options.BoxSizeMultiplier:OnChanged(function()
        EspSettings.BoxSizeMultiplier = Options.BoxSizeMultiplier.Value
end)

EspVisualGroup:AddSlider("HeadHitboxScale", {
        Text = "Head Hitbox Scale",
        Default = EspSettings.HeadScale,
        Min = 1,
        Max = 4,
        Rounding = 1,
        Tooltip = "Enlarges enemy heads client-side (1=normal, 2=double, etc.)",
})
Options.HeadHitboxScale:OnChanged(function()
        EspSettings.HeadScale = Options.HeadHitboxScale.Value
        if EspSettings.HeadScale <= 1 then
            RestoreHeadScales()
        end
end)

--// UI COMPONENT INITIALIZATION (VISUALS TAB)
VisualsGroup:AddToggle("AnimatedCrosshair", {
        Text = "Animated Crosshair",
        Default = VisualSettings.CrosshairEnabled,
})
Toggles.AnimatedCrosshair:OnChanged(function()
        VisualSettings.CrosshairEnabled = Toggles.AnimatedCrosshair.Value
end)

VisualsGroup:AddDropdown("CrosshairColorPresets", {
        Values = colorOptions,
        Default = 3, 
        Multi = false,
        Text = "Crosshair Color Presets",
})
Options.CrosshairColorPresets:OnChanged(function()
        VisualSettings.CrosshairColorMode = Options.CrosshairColorPresets.Value
end)

-- ============================================================
-- [V8] SKY / LIGHTING COLOR CONTROLS — in its OWN groupbox
-- Pick any color you want for sky + ambient + brightness + time
-- ============================================================
SkyColorGroup:AddToggle("SkyColorEnabled", {
        Text = "Sky Color Override",
        Default = false,
        Tooltip = "Override the game's sky color and lighting with your custom colors below.",
})
Toggles.SkyColorEnabled:OnChanged(function()
        VisualSettings.SkyColorEnabled = Toggles.SkyColorEnabled.Value
        applySkyColor()
end)

-- Sky/Ambient color picker — pick ANY color
SkyColorGroup:AddLabel("Sky & Ambient Color"):AddColorPicker("SkyCustomColor", {
        Default = Color3.fromRGB(80, 80, 100),
        Title = "Sky Color (Ambient + Outdoor)",
})
Options.SkyCustomColor:OnChanged(function()
        VisualSettings.AmbientColor = Options.SkyCustomColor.Value
        applySkyColor()
end)

-- Brightness slider (controls how bright the scene is)
SkyColorGroup:AddSlider("SkyBrightness", {
        Text = "Brightness",
        Default = 1.5,
        Min = 0,
        Max = 3,
        Rounding = 2,
        Tooltip = "How bright the scene is. 0= pitch black, 2= normal, 3= very bright.",
})
Options.SkyBrightness:OnChanged(function()
        VisualSettings.SkyBrightness = Options.SkyBrightness.Value
        applySkyColor()
end)

-- Clock time slider (controls day/night cycle, 0-24)
SkyColorGroup:AddSlider("SkyClockTime", {
        Text = "Time of Day",
        Default = 12,
        Min = 0,
        Max = 24,
        Rounding = 1,
        Suffix = "h",
        Tooltip = "0=midnight, 6=dawn, 12=noon, 18=dusk, 24=midnight again.",
})
Options.SkyClockTime:OnChanged(function()
        VisualSettings.SkyClockTime = Options.SkyClockTime.Value
        applySkyColor()
end)

--// UI COMPONENT INITIALIZATION (VISUALS TAB - GRENADE EFFECTS)
GrenadeEffectsGroup:AddToggle("HideSmoke", {
        Text = "Hide Smoke",
        Default = VisualSettings.HideSmoke,
        Tooltip = "Removes smoke grenade visual effects (Smoke, ParticleEmitters, smoke Parts)",
})
Toggles.HideSmoke:OnChanged(function()
        VisualSettings.HideSmoke = Toggles.HideSmoke.Value
end)

GrenadeEffectsGroup:AddToggle("HideFlashbang", {
        Text = "Hide Flashbang",
        Default = VisualSettings.HideFlashbang,
        Tooltip = "Removes flashbang screen effects (flash/blind GUI overlays)",
})
Toggles.HideFlashbang:OnChanged(function()
        VisualSettings.HideFlashbang = Toggles.HideFlashbang.Value
end)

GrenadeEffectsGroup:AddToggle("LockIndicatorToggle", {
        Text = "Lock Indicator",
        Default = VisualSettings.LockIndicator,
        Tooltip = "Shows LOCKED: NAME / SCANNING... indicator in top-right corner",
})
Toggles.LockIndicatorToggle:OnChanged(function()
        VisualSettings.LockIndicator = Toggles.LockIndicatorToggle.Value
end)

--//================================================================================
--// CHAT WIN STREAK INITIALIZATION (VISUALS RIGHT PANEL)
--//================================================================================
WinStreakGroup:AddInput("StreakTargetPlayer", {
        Default = MiscSettings.TargetPlayer,
        Numeric = false,
        Finished = true,
        Text = "Target Player Name",
        Tooltip = "The player whose streak was broken",
        Placeholder = "e.g. ABG",
})
Options.StreakTargetPlayer:OnChanged(function()
        MiscSettings.TargetPlayer = Options.StreakTargetPlayer.Value
end)

WinStreakGroup:AddInput("StreakCountNumber", {
        Default = MiscSettings.StreakValue,
        Numeric = true,
        Finished = true,
        Text = "Win Streak Count",
        Tooltip = "The amount of consecutive wins ended",
        Placeholder = "e.g. 14",
})
Options.StreakCountNumber:OnChanged(function()
        MiscSettings.StreakValue = Options.StreakCountNumber.Value
end)

WinStreakGroup:AddToggle("AutoDetectMyName", {
        Text = "Auto-Detect My Name",
        Default = MiscSettings.AutoFindMe,
        Tooltip = "Automatically reads your current game display name for the credit",
})
Toggles.AutoDetectMyName:OnChanged(function()
        MiscSettings.AutoFindMe = Toggles.AutoDetectMyName.Value
end)

WinStreakGroup:AddInput("StreakCustomEnder", {
        Default = MiscSettings.CustomEnderName,
        Numeric = false,
        Finished = true,
        Text = "Custom 'Ended By' Name",
        Tooltip = "Used when Auto-Detect My Name is disabled",
        Placeholder = "e.g. Dallas",
})
Options.StreakCustomEnder:OnChanged(function()
        MiscSettings.CustomEnderName = Options.StreakCustomEnder.Value
end)

WinStreakGroup:AddButton({
        Text = "Send Fake Server Message",
        Func = function()
                local TextChatService = game:GetService("TextChatService")
                local StarterGui = game:GetService("StarterGui")
                
                local enderName = MiscSettings.AutoFindMe and player.DisplayName or MiscSettings.CustomEnderName
                if enderName == "" then enderName = "Dallas" end
                
                local targetName = MiscSettings.TargetPlayer ~= "" and MiscSettings.TargetPlayer or "ABG"
                local streakVal = MiscSettings.StreakValue ~= "" and MiscSettings.StreakValue or "14"
                
                local completeMessage = string.format(
                        "[SERVER] %s's %s win streak was ended by %s (@%s)!",
                        targetName,
                        streakVal,
                        enderName,
                        string.lower(enderName)
                )
                
                if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                        local channel = TextChatService:FindFirstChild("RBXGeneral", true) or TextChatService.TextChannels.RBXSystem
                        channel:DisplaySystemMessage('<font color="rgb(224, 130, 41)"><b>' .. completeMessage .. '</b></font>')
                else
                        pcall(function()
                                StarterGui:SetCore("ChatMakeSystemMessage", {
                                        Text = completeMessage,
                                        Color = Color3.fromRGB(224, 130, 41),
                                        Font = Enum.Font.FredokaOne,
                                        TextSize = 18
                                })
                        end)
                end
        end,
        DoubleClick = false
})

--// UI COMPONENT INITIALIZATION (PLAYER TAB - LEFT: MOVEMENT)
PlayerMovementGroup:AddToggle("WalkSpeedEnabled", {
        Text = "Custom Walk Speed",
        Default = PlayerSettings.WalkSpeedEnabled,
        Tooltip = "Override your walk speed (Always Active — keeps reapplying every frame)",
})
Toggles.WalkSpeedEnabled:OnChanged(function()
        PlayerSettings.WalkSpeedEnabled = Toggles.WalkSpeedEnabled.Value
        if not PlayerSettings.WalkSpeedEnabled then
            -- Restore default walk speed
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum.WalkSpeed = 16 end) end
            end
        end
end)

PlayerMovementGroup:AddSlider("WalkSpeedValue", {
        Text = "Walk Speed",
        Default = PlayerSettings.WalkSpeed,
        Min = 16,
        Max = 200,
        Rounding = 0,
        Tooltip = "16 = default, higher = faster",
})
Options.WalkSpeedValue:OnChanged(function()
        PlayerSettings.WalkSpeed = Options.WalkSpeedValue.Value
        -- Apply immediately on slider change
        if PlayerSettings.WalkSpeedEnabled then
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum.WalkSpeed = PlayerSettings.WalkSpeed end) end
            end
        end
end)

PlayerMovementGroup:AddButton("Reset Walk Speed", function()
        PlayerSettings.WalkSpeedEnabled = false
        if Toggles.WalkSpeedEnabled then Toggles.WalkSpeedEnabled:SetValue(false) end
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.WalkSpeed = 16 end) end
        end
        if Options.WalkSpeedValue then Options.WalkSpeedValue:SetValue(16) end
        Library:Notify({
            Title = "Walk Speed",
            Description = "Always Active turned off, speed reset to 16",
            Time = 3
        })
end)

PlayerMovementGroup:AddDivider()

PlayerMovementGroup:AddToggle("JumpPowerEnabled", {
        Text = "Custom Jump Power",
        Default = PlayerSettings.JumpPowerEnabled,
        Tooltip = "Override your jump power",
})
Toggles.JumpPowerEnabled:OnChanged(function()
        PlayerSettings.JumpPowerEnabled = Toggles.JumpPowerEnabled.Value
        if not PlayerSettings.JumpPowerEnabled then
            -- Restore default jump power
            local char = lp.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum.JumpPower = 50 end) end
            end
        end
end)

PlayerMovementGroup:AddSlider("JumpPowerValue", {
        Text = "Jump Power",
        Default = PlayerSettings.JumpPower,
        Min = 1,
        Max = 300,
        Rounding = 0,
        Tooltip = "50 = default, higher = jump higher",
})
Options.JumpPowerValue:OnChanged(function()
        PlayerSettings.JumpPower = Options.JumpPowerValue.Value
end)

--// UI COMPONENT INITIALIZATION (PLAYER TAB - RIGHT: TOGGLES & EMERGENCY)
-- [V3 from Rage Hub] Auto BunnyHop
PlayerTogglesGroup:AddToggle("AutoBhop", {
        Text = "Auto BunnyHop",
        Default = PlayerSettings.AutoBhop,
        Tooltip = "Automatically jumps when holding Space (good for movement)",
})
Toggles.AutoBhop:OnChanged(function()
        PlayerSettings.AutoBhop = Toggles.AutoBhop.Value
end)

-- [V3 from Rage Hub] Custom Camera FOV
PlayerTogglesGroup:AddToggle("CustomFOV", {
        Text = "Custom Camera FOV",
        Default = PlayerSettings.CustomFOV,
        Tooltip = "Override the game's camera Field of View (zoom in/out)",
})
Toggles.CustomFOV:OnChanged(function()
        PlayerSettings.CustomFOV = Toggles.CustomFOV.Value
        if not PlayerSettings.CustomFOV then
            pcall(function() camera.FieldOfView = 70 end)  -- reset to default
        end
end)

PlayerTogglesGroup:AddSlider("FOVValue", {
        Text = "FOV Value",
        Default = PlayerSettings.FOVValue,
        Min = 70,
        Max = 120,
        Rounding = 0,
        Tooltip = "Camera Field of View (70=default, 120=wide angle)",
})
Options.FOVValue:OnChanged(function()
        PlayerSettings.FOVValue = Options.FOVValue.Value
end)

-- [V3 from Rage Hub] Show FPS Counter
PlayerTogglesGroup:AddToggle("ShowFPS", {
        Text = "Show FPS Counter",
        Default = PlayerSettings.ShowFPS,
        Tooltip = "Shows an FPS counter in the top-left corner (purple)",
})
Toggles.ShowFPS:OnChanged(function()
        PlayerSettings.ShowFPS = Toggles.ShowFPS.Value
end)

-- [V3 from Rage Hub] Server Hop Button
PlayerTogglesGroup:AddButton("Server Hop", function()
        serverHop()
end)

-- ============================================================
-- [V8] ANTI RIOT SHIELD UI
-- Prevents Riot Katana/Shield from reflecting your bullets
-- ============================================================
PlayerTogglesGroup:AddToggle("InfiniteJump", {
        Text = "Infinite Jump",
        Default = PlayerSettings.InfiniteJump,
        Tooltip = "Jump unlimited times in the air",
})
Toggles.InfiniteJump:OnChanged(function()
        PlayerSettings.InfiniteJump = Toggles.InfiniteJump.Value
end)

PlayerTogglesGroup:AddToggle("NoclipToggle", {
        Text = "Noclip (Walk Through Walls)",
        Default = PlayerSettings.NoclipEnabled,
        Tooltip = "Walk through walls and objects",
})
Toggles.NoclipToggle:OnChanged(function()
        PlayerSettings.NoclipEnabled = Toggles.NoclipToggle.Value
        if not PlayerSettings.NoclipEnabled then
            -- Restore collision
            local char = lp.Character
            if char then
                pcall(function()
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = true
                        end
                    end
                end)
            end
        end
end)

PlayerTogglesGroup:AddToggle("AirWalkToggle", {
        Text = "Air Walk (No Fall)",
        Default = PlayerSettings.AirWalkEnabled,
        Tooltip = "Stay in the air — disable gravity fall",
})
Toggles.AirWalkToggle:OnChanged(function()
        PlayerSettings.AirWalkEnabled = Toggles.AirWalkToggle.Value
end)

PlayerMovementGroup:AddToggle("SlideBoostToggle", {
        Text = "Slide Boost",
        Default = PlayerSettings.SlideBoost,
        Tooltip = "Speed boost while crouching (hold LeftCtrl)",
})
Toggles.SlideBoostToggle:OnChanged(function()
        PlayerSettings.SlideBoost = Toggles.SlideBoostToggle.Value
end)

PlayerMovementGroup:AddSlider("SlideBoostPowerSlider", {
        Text = "Slide Boost Power",
        Default = PlayerSettings.SlideBoostPower,
        Min = 1,
        Max = 15,
        Rounding = 1,
        Tooltip = "Higher = faster slide (4 = default)",
})
Options.SlideBoostPowerSlider:OnChanged(function()
        PlayerSettings.SlideBoostPower = Options.SlideBoostPowerSlider.Value
end)

PlayerMovementGroup:AddDivider()

PlayerMovementGroup:AddSlider("GravitySlider", {
        Text = "Gravity",
        Default = PlayerSettings.GravityValue,
        Min = 10,
        Max = 400,
        Rounding = 0,
        Tooltip = "196 = default, lower = less gravity",
})
Options.GravitySlider:OnChanged(function()
        PlayerSettings.GravityValue = Options.GravitySlider.Value
        if PlayerSettings.GravityValue == 196 then
            pcall(function() workspace.Gravity = 196 end)
        end
end)

PlayerTogglesGroup:AddDivider()

PlayerTogglesGroup:AddToggle("PanicKeyToggle", {
        Text = "Panic Key (P = Kill All)",
        Default = PlayerSettings.PanicKeyEnabled,
        Tooltip = "Press P to instantly disable ALL combat features",
})
Toggles.PanicKeyToggle:OnChanged(function()
        PlayerSettings.PanicKeyEnabled = Toggles.PanicKeyToggle.Value
end)

PlayerTogglesGroup:AddDivider()

PlayerTogglesGroup:AddToggle("FullbrightToggle", {
        Text = "Fullbright",
        Default = PlayerSettings.FullbrightEnabled,
        Tooltip = "Maximum brightness — no more dark areas",
})
Toggles.FullbrightToggle:OnChanged(function()
        PlayerSettings.FullbrightEnabled = Toggles.FullbrightToggle.Value
        setFullbright(PlayerSettings.FullbrightEnabled)
end)

PlayerTogglesGroup:AddToggle("AntiRagdollToggle", {
        Text = "Anti-Ragdoll",
        Default = PlayerSettings.AntiRagdollEnabled,
        Tooltip = "Prevent ragdolling and falling down — auto-reapplies on respawn",
})
Toggles.AntiRagdollToggle:OnChanged(function()
        PlayerSettings.AntiRagdollEnabled = Toggles.AntiRagdollToggle.Value
        setAntiRagdoll(PlayerSettings.AntiRagdollEnabled)
end)

PlayerTogglesGroup:AddToggle("AntiAfkToggle", {
        Text = "Anti-AFK",
        Default = PlayerSettings.AntiAfkEnabled,
        Tooltip = "Prevents being kicked for being idle",
})
Toggles.AntiAfkToggle:OnChanged(function()
        PlayerSettings.AntiAfkEnabled = Toggles.AntiAfkToggle.Value
        setupAntiAfk(PlayerSettings.AntiAfkEnabled)
end)

--// UI COMPONENT INITIALIZATION (PLAYER TAB - FLY GROUP)
PlayerFlyGroup:AddToggle("FlyToggle", {
        Text = "Fly",
        Default = PlayerSettings.FlyEnabled,
        Tooltip = "Fly using BodyVelocity+BodyGyro — WASD + Space/Shift",
})
Toggles.FlyToggle:OnChanged(function()
        PlayerSettings.FlyEnabled = Toggles.FlyToggle.Value
        if PlayerSettings.FlyEnabled then
            startFly(PlayerSettings.FlySpeed)
        else
            stopFly()
        end
end)

PlayerFlyGroup:AddSlider("FlySpeedSlider", {
        Text = "Fly Speed",
        Default = PlayerSettings.FlySpeed,
        Min = 10,
        Max = 500,
        Rounding = 0,
        Tooltip = "80 = default fly speed",
})
Options.FlySpeedSlider:OnChanged(function()
        PlayerSettings.FlySpeed = Options.FlySpeedSlider.Value
        if flyActive then
            stopFly()
            task.wait(0.05)
            startFly(PlayerSettings.FlySpeed)
        end
end)

--// UI COMPONENT INITIALIZATION (PLAYER TAB - SERVER GROUP)
PlayerServerGroup:AddButton("Serverhop", function()
        serverhop()
end)

PlayerServerGroup:AddButton("Rejoin", function()
        rejoin()
end)

--// UI COMPONENT INITIALIZATION (PLAYER TAB - TELEPORT KILL)
TeleportKillGroup:AddInput("TpKillTargetName", {
        Default = TeleportKillSettings.TargetPlayerName,
        Numeric = false,
        Finished = true,
        Text = "Target Player Name",
        Tooltip = "Enter player name (partial match works)",
})
Options.TpKillTargetName:OnChanged(function()
        TeleportKillSettings.TargetPlayerName = Options.TpKillTargetName.Value
end)

TeleportKillGroup:AddSlider("TpKillDistance", {
        Text = "Teleport Distance (studs)",
        Default = TeleportKillSettings.Distance,
        Min = 1,
        Max = 20,
        Rounding = 0,
        Tooltip = "How far behind the target you teleport (1=very close, 20=far)",
})
Options.TpKillDistance:OnChanged(function()
        TeleportKillSettings.Distance = Options.TpKillDistance.Value
end)

TeleportKillGroup:AddToggle("TpKillAutoReconnect", {
        Text = "Auto-Reconnect on Respawn",
        Default = TeleportKillSettings.AutoReconnect,
        Tooltip = "Automatically resume teleporting after you respawn",
})
Toggles.TpKillAutoReconnect:OnChanged(function()
        TeleportKillSettings.AutoReconnect = Toggles.TpKillAutoReconnect.Value
end)

TeleportKillGroup:AddButton("Start Teleport Kill", function()
        local targetName = TeleportKillSettings.TargetPlayerName
        if targetName == "" then
                Library:Notify({
                        Title = "Teleport Kill",
                        Description = "Enter a player name first!",
                        Time = 4
                })
                return
        end
        local target = findTpTarget(targetName)
        if not target then
                Library:Notify({
                        Title = "Teleport Kill",
                        Description = "Player not found: " .. targetName,
                        Time = 4
                })
                return
        end
        startTeleportKill(target)
        Library:Notify({
                Title = "Teleport Kill",
                Description = "Teleporting to " .. target.Name .. " ✅",
                Time = 4
        })
end)

TeleportKillGroup:AddButton("Stop Teleport Kill", function()
        stopTeleportKill()
        Library:Notify({
                Title = "Teleport Kill",
                Description = "Teleport stopped ❌",
                Time = 4
        })
end)

--// UI COMPONENT INITIALIZATION (MISC TAB)
-- ============================================================
-- [V7] SKIN CHANGER — moved to its OWN groupbox (separate from Device Spoofer)
-- ============================================================
SkinChangerGroup:AddToggle("EnableSkinChanger", {
        Text = "Skin Changer (Unlock All Cosmetics)",
        Default = false,
        Tooltip = "Unlocks ALL skins, wraps, charms, dances, and emotes for free. Equip them normally in the game's loadout menu.",
})
Toggles.EnableSkinChanger:OnChanged(function()
        if Toggles.EnableSkinChanger.Value then
                CosmeticUnlocker.Enabled = true
                if getgenv().ZX_Notify then
                        getgenv().ZX_Notify("Skin Changer", "Unlocking cosmetics...", "info")
                end
                task.spawn(function()
                        local retries = 0
                        while retries < 5 and CosmeticUnlocker.Enabled do
                                if getgenv()._startCosmeticUnlocker then
                                        getgenv()._startCosmeticUnlocker()
                                end
                                task.wait(1)
                                retries = retries + 1
                        end
                        if CosmeticUnlocker.Enabled and getgenv().ZX_Notify then
                                getgenv().ZX_Notify("Skin Changer", "All cosmetics unlocked! Equip them in your loadout.", "success")
                        end
                end)
        else
                CosmeticUnlocker.Enabled = false
                if getgenv().ZX_Notify then
                        getgenv().ZX_Notify("Skin Changer", "Disabled. Re-enable to unlock again.", "warning")
                end
        end
end)

SkinChangerGroup:AddButton("Reload Cosmetics", function()
        if getgenv()._startCosmeticUnlocker then
                getgenv()._startCosmeticUnlocker()
                if getgenv().ZX_Notify then
                        getgenv().ZX_Notify("Skin Changer", "Cosmetics reloaded.", "info")
                end
        else
                if getgenv().ZX_Notify then
                        getgenv().ZX_Notify("Skin Changer", "Enable Skin Changer first.", "warning")
                end
        end
end)

SkinChangerGroup:AddButton("Clear Saved Cosmetics", function()
        -- Clear the saved config
        CosmeticUnlocker._eq = {}
        CosmeticUnlocker._favs = {}
        pcall(function()
            if isfile and isfile("rivals_unlocker_config.json") then
                delfile("rivals_unlocker_config.json")
            end
        end)
        if getgenv().ZX_Notify then
                getgenv().ZX_Notify("Skin Changer", "Saved cosmetics cleared.", "warning")
        end
end)

--// UI COMPONENT INITIALIZATION (MISC TAB - DEVICE SPOOFER)
MiscGroup:AddToggle("EnableDeviceSpoofer", {
        Text = "Enable Device Spoofer",
        Default = MiscSettings.SpoofEnabled,
})
Toggles.EnableDeviceSpoofer:OnChanged(function()
        MiscSettings.SpoofEnabled = Toggles.EnableDeviceSpoofer.Value
        if MiscSettings.SpoofEnabled then
                FireSpoof(MiscSettings.SelectedDevice)
        end
end)

MiscGroup:AddDropdown("SelectTargetDevice", {
        Values = {"Controller", "PC", "Mobile", "VR"},
        Default = 1, 
        Multi = false,
        Text = "Select Target Device",
})
Options.SelectTargetDevice:OnChanged(function()
        MiscSettings.SelectedDevice = Options.SelectTargetDevice.Value
        if MiscSettings.SpoofEnabled then
                FireSpoof(MiscSettings.SelectedDevice)
        end
end)

--// TEAM DEBUG BUTTONS (inspired by reference Diablo Hub script)
TeamDebugGroup:AddButton("Show My Team Info", function()
        UpdateTeamCache()
        local teamID = teamCache.myTeamID
        Library:Notify({
                Title = "Team Info",
                Description = "TeamID: " .. (teamID ~= nil and tostring(teamID) or "nil"),
                Time = 6
        })
end)

TeamDebugGroup:AddButton("Show All Players Teams", function()
        UpdateTeamCache()
        local myTeamID = teamCache.myTeamID
        local count = 0
        local teammateCount = 0
        local enemyCount = 0
        for _, v in pairs(players:GetPlayers()) do
                if v ~= lp then
                        count = count + 1
                        if isTeammate(v) then
                                teammateCount = teammateCount + 1
                        else
                                enemyCount = enemyCount + 1
                        end
                end
        end
        Library:Notify({
                Title = "Team Scan",
                Description = string.format(
                        "My TeamID: %s | Teammates: %d | Enemies: %d | Total: %d",
                        myTeamID ~= nil and tostring(myTeamID) or "nil",
                        teammateCount,
                        enemyCount,
                        count
                ),
                Time = 6
        })
end)

TeamDebugGroup:AddButton("Refresh Team Cache", function()
        UpdateTeamCache()
        Library:Notify({
                Title = "Team Cache",
                Description = "Refreshed! TeamID=" .. tostring(teamCache.myTeamID),
                Time = 4
        })
end)

TeamDebugGroup:AddButton("Toggle Team Check Debug Mode", function()
        TeamCheck.DebugMode = not TeamCheck.DebugMode
        Library:Notify({
                Title = "Team Debug",
                Description = "Debug mode: " .. (TeamCheck.DebugMode and "ON" or "OFF"),
                Time = 4
        })
end)

--// UI COMPONENT INITIALIZATION (PLAYER TAB - PLAYER MODS QUICK ACCESS)
-- Quick-access toggles that link to existing settings (Hitbox, Infinite Jump, Speed)
-- These mirror settings found in ESP tab (Hitbox) and Player tab (Jump/Speed) for convenience
local PlayerModsGroup = Tabs.Player:AddLeftGroupbox("Player Mods (Quick Access)")

PlayerModsGroup:AddToggle("QuickHitboxExpander", {
        Text = "Hitbox Expander (5x)",
        Default = false,
        Tooltip = "Quick toggle: enlarges enemy heads to 5x size for easier aiming (mirrors ESP tab slider)",
})
Toggles.QuickHitboxExpander:OnChanged(function()
        if Toggles.QuickHitboxExpander.Value then
                EspSettings.HeadScale = 5
        else
                EspSettings.HeadScale = 1
                RestoreHeadScales()
        end
        -- Sync the ESP tab slider so both UI elements stay consistent
        if Options.HeadHitboxScale then
                Options.HeadHitboxScale:SetValue(EspSettings.HeadScale)
        end
end)

PlayerModsGroup:AddToggle("QuickInfiniteJump", {
        Text = "Infinite Jump",
        Default = PlayerSettings.InfiniteJump,
        Tooltip = "Jump unlimited times without touching the ground",
})
Toggles.QuickInfiniteJump:OnChanged(function()
        PlayerSettings.InfiniteJump = Toggles.QuickInfiniteJump.Value
        -- Sync the Player tab toggle so both UI elements stay consistent
        if Toggles.InfiniteJump then
                Toggles.InfiniteJump:SetValue(PlayerSettings.InfiniteJump)
        end
end)

PlayerModsGroup:AddToggle("QuickSpeedHack", {
        Text = "Speed Hack",
        Default = PlayerSettings.WalkSpeedEnabled,
        Tooltip = "Override your WalkSpeed (default 50, normal is 16)",
})
Toggles.QuickSpeedHack:OnChanged(function()
        PlayerSettings.WalkSpeedEnabled = Toggles.QuickSpeedHack.Value
        -- Sync the Player tab toggle so both UI elements stay consistent
        if Toggles.WalkSpeedEnabled then
                Toggles.WalkSpeedEnabled:SetValue(PlayerSettings.WalkSpeedEnabled)
        end
        if not PlayerSettings.WalkSpeedEnabled then
                local char = lp.Character
                if char then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum then pcall(function() hum.WalkSpeed = 16 end) end
                end
        end
end)

PlayerModsGroup:AddSlider("QuickSpeedValue", {
        Text = "Speed Value",
        Default = PlayerSettings.WalkSpeed,
        Min = 16,
        Max = 200,
        Rounding = 0,
        Suffix = " ws",
        Tooltip = "WalkSpeed value (16 = normal, 50 = fast, 200 = insane)",
})
Options.QuickSpeedValue:OnChanged(function()
        PlayerSettings.WalkSpeed = Options.QuickSpeedValue.Value
        -- Sync the Player tab slider so both UI elements stay consistent
        if Options.WalkSpeedValue then
                Options.WalkSpeedValue:SetValue(PlayerSettings.WalkSpeed)
        end
end)

--// CONFIGURATION & CLEANUP ENGINE (SETTINGS TAB)
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")

MenuGroup:AddToggle("KeybindMenuOpen", { 
        Default = Library.KeybindFrame.Visible, 
        Text = "Open Keybind Menu", 
        Callback = function(value) Library.KeybindFrame.Visible = value end
})

MenuGroup:AddToggle("ShowCustomCursor", {
        Text = "Custom Cursor", 
        Default = true, 
        Callback = function(Value) Library.ShowCustomCursor = Value end
})

--// DRAG MODE — toggle how the window can be dragged
-- "Header" = drag only by the title bar (default Linoria behavior)
-- "Anywhere" = drag from anywhere in the window (more flexible)
-- Linoria's MakeDraggable is always active on the main window; this is a visual hint toggle.
MenuGroup:AddDropdown("DragMode", {
        Text = "Window Drag Mode",
        Values = { "Header Only", "Anywhere" },
        Default = 2,
        Multi = false,
        Tooltip = "Header Only = drag from title bar only | Anywhere = drag from anywhere in the window (Linoria default)",
})
Options.DragMode:OnChanged(function()
        local mode = Options.DragMode.Value
        -- Re-apply drag mode on the main window
        if LibraryMainOuterFrame then
                -- Linoria's MakeDraggable is already set; we just notify the user
                Library:Notify({
                        Title = "Drag Mode",
                        Description = "Drag mode: " .. mode .. " (applied)",
                        Time = 3
                })
        end
end)

MenuGroup:AddSlider("WindowSizeSlider", {
        Text = "Window Size",
        Default = 540,
        Min = 450,
        Max = 750,
        Rounding = 0,
        Suffix = " px",
        Tooltip = "Adjust the window height (width scales proportionally)",
})
Options.WindowSizeSlider:OnChanged(function()
        local newSize = Options.WindowSizeSlider.Value
        if LibraryMainOuterFrame then
                pcall(function()
                        LibraryMainOuterFrame.Size = UDim2.fromOffset(
                                math.floor(newSize * 1.07),  -- width ~ 1.07x height
                                newSize
                        )
                end)
        end
end)

MenuGroup:AddButton({
        Text = "Reset Window Position",
        Func = function()
                if LibraryMainOuterFrame then
                        pcall(function()
                                local viewportSize = workspace.CurrentCamera.ViewportSize
                                LibraryMainOuterFrame.Position = UDim2.new(
                                        0.5, -LibraryMainOuterFrame.Size.X.Offset / 2,
                                        0.5, -LibraryMainOuterFrame.Size.Y.Offset / 2
                                )
                        end)
                end
                Library:Notify({
                        Title = "Window",
                        Description = "Position reset to center",
                        Time = 3
                })
        end,
        DoubleClick = false,
})

MenuGroup:AddDivider()

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { 
        Default = "RightControl", 
        NoUI = true, 
        Text = "Menu keybind" 
})
Library.ToggleKeybind = Options.MenuKeybind

MenuGroup:AddButton({
        Text = "Unload UI (Delete Cheat)",
        Func = function() 
                Library:Unload() 
        end,
        DoubleClick = false,
})

--// RUNTIME DISPOSAL CLEANUP HOOK
local WatermarkConnection
Library:OnUnload(function()
        if WatermarkConnection then WatermarkConnection:Disconnect() end
        if pipelineConnection then pipelineConnection:Disconnect() end
        crosshairGui:Destroy()
        EspGui:Destroy()
        SAFovRing:Destroy()
        SAFovBg:Destroy()
        RageFovRing:Destroy()
        RageFovBg:Destroy()
        HoldBotFovRing:Destroy()
        HoldBotFovBg:Destroy()
        for _, cache in pairs(EspRegistry) do
                if cache.CurrentCham then cache.CurrentCham:Destroy() end
        end
        -- Clean up skeleton drawings
        for _, lines in pairs(SkeletonCache) do
                for _, line in ipairs(lines) do
                        pcall(function() line:Remove() end)
                end
        end
        SkeletonCache = {}
        -- Restore head hitbox sizes
        RestoreHeadScales()
        -- Clean up Teleport Kill
        stopTeleportKill()
        -- Clean up Auto Win
        RageMode.AutoWinEnabled = false
        stopAutoWin()
        Library.Unloaded = true
        print("Unloaded Zythera-X via Custom Hook Engine.")
end)

--// WATERMARK REFRESH CONNECTION — fixed memory leak + local register limit
-- Wrapped in `do ... end` to release locals (Lua has a 200 local limit per scope).
do
local FrameTimer = tick()
local PingTimer = tick()
local FrameCounter = 0
local FPS = 60
local CachedPing = 0
local CanDoPing = false

--// One-time check: does Stats.Network.ServerStatsItem["Data Ping"] exist?
-- Wrapped in pcall so it never errors on executors that don't support it.
pcall(function()
    local stats = game:GetService("Stats")
    local network = stats and stats:FindFirstChild("Network")
    local dataPing = network and network:FindFirstChild("ServerStatsItem")
    if dataPing and dataPing:FindFirstChild("Data Ping") then
        CanDoPing = true
    end
end)

--// Refresh ping value once per second (NOT every frame) to avoid memory leak
local function RefreshPing()
    if not CanDoPing then return end
    pcall(function()
        CachedPing = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
    end)
end
RefreshPing()  -- initial value

WatermarkConnection = RunService.RenderStepped:Connect(function()
        FrameCounter = FrameCounter + 1

        -- Update FPS counter once per second
        if (tick() - FrameTimer) >= 1 then
                FPS = FrameCounter
                FrameTimer = tick()
                FrameCounter = 0
                -- Also refresh ping here (once per second, not every frame)
                RefreshPing()
        end

        local brand = '<font color="#e11e1e">Z</font>ythera-<font color="#e11e1e">X</font>'
        if CanDoPing then
                Library:SetWatermark((brand .. " | %d fps | %d ms"):format(
                        math.floor(FPS),
                        CachedPing
                ))
        else
                Library:SetWatermark((brand .. " | %d fps"):format(
                        math.floor(FPS)
                ))
        end
end)
end  -- end of watermark `do` block (releases ~8 locals)

--// WALLBANG ENGINE — Desync + Gun.StartShooting + EncodeCFrame
--
-- APPROACH:
-- ✅ Hook Gun.StartShooting — Modify shot data at the source before server receives it
-- ✅ Desync — Temporarily move player near enemy during shot (server-side validation bypass)
-- ✅ EncodeCFrame — Use game's own encoding function for proper CFrame data
-- ✅ Shot data table modification — utf8.char keys for bullet origin, hit position, hit part, relative pos
-- ✅ Force hit confirmation — result[4] = true
-- ✅ ItemLibrary mods — ProjectileWallClipPreventionEnabled=false, RaycastPierceCount=10
-- ✅ hookmetamethod — Silent aim direction redirect for non-Wallbang mode
--
-- HOW IT WORKS:
-- When the player shoots, Gun.StartShooting creates shot data that gets sent to the server.
-- We intercept this and modify:
--   shotData[utf8.char(0)] = EncodeCFrame(bullet origin near enemy)
--   shotData[utf8.char(1)] = EncodeCFrame(hit position at enemy head)
--   shotData[utf8.char(2)] = Enemy Head part reference
--   shotData[utf8.char(3)] = EncodeCFrame(relative position)
--   result[4] = true (force hit confirmation)
--
-- Simultaneously, desync moves the player's HumanoidRootPart near the enemy
-- on Heartbeat, then restores original position on RenderStep (priority 101).
-- This makes the server's raycast validation succeed because from the server's
-- perspective, the player IS near the enemy.

getgenv().silentAimTargetPos = nil     -- Silent aim target position (for direction redirect)

--// WALLBANG ENGINE
WallbangEngine = {
    active = false,
    desyncActive = false,
    currentTarget = nil,
    currentDesyncTarget = nil,
    targetFinderConn = nil,
    desyncConn = nil,
    desyncRestoreName = "__wb_restore",
    oldStartShooting = nil,
    desyncTimer = nil,
    gunModule = nil,
    utilityModule = nil,
    initialized = false,
    modsApplied = false,
}

function WallbangEngine:init()
    if self.initialized then return true end

    local playerScripts = lp:WaitForChild("PlayerScripts", 10)
    if not playerScripts then return false end

    local gunModuleRef = playerScripts:FindFirstChild("Modules")
    if gunModuleRef then
        gunModuleRef = gunModuleRef:FindFirstChild("ItemTypes")
        if gunModuleRef then
            gunModuleRef = gunModuleRef:FindFirstChild("Gun")
        end
    end

    if not gunModuleRef then return false end

    local success, gun = pcall(function()
        return require(gunModuleRef)
    end)
    if not success or not gun then return false end

    self.gunModule = gun

    -- Also get Utility module for EncodeCFrame
    local RS = ReplicatedStorage
    local utilRef = RS:FindFirstChild("Modules")
    if utilRef then
        utilRef = utilRef:FindFirstChild("Utility")
    end
    if utilRef then
        local succ, util = pcall(function()
            return require(utilRef)
        end)
        if succ and util then
            self.utilityModule = util
        end
    end

    self.initialized = true
    return true
end

function WallbangEngine:setup()
    if not self.gunModule then return end
    if self.oldStartShooting then return end -- Already hooked

    -- FULL POWER + STEALTH: use hookfunction + clonefunction + newcclosure
    -- clonefunction saves a CLEAN copy of the original (so our hook can call it
    -- without infinite recursion after hookfunction patches the original in-place).
    -- newcclosure wraps our hook as a C closure (iscclosure=true) → harder to detect.
    -- hookfunction patches the original IN-PLACE → the gunModule.StartShooting REFERENCE
    -- stays unchanged, so AC reference checks pass (stealthier than direct assignment).
    local engine = self
    self.oldStartShooting = (clonefunction and clonefunction(self.gunModule.StartShooting)) or self.gunModule.StartShooting
    self.usedHookfunction = false

    local hookFn = function(gunSelf, ...)
        local results = {engine.oldStartShooting(gunSelf, ...)}

        -- Only modify for local player's gun
        if not gunSelf.ClientFighter or not gunSelf.ClientFighter.IsLocalPlayer then
            return unpack(results)
        end

        -- Check if wallbang is active
        if not engine.active then
            return unpack(results)
        end

        -- Get shot data table (3rd return value)
        local shotData = results[3]
        if not shotData or typeof(shotData) ~= "table" then
            return unpack(results)
        end

        -- Find target
        local targetPlayer = engine.currentTarget
        if not targetPlayer or not targetPlayer.Character then
            return unpack(results)
        end

        -- FULL POWER: force hit confirmation on every shot (AC is bypassed — safe)
        results[4] = true

        -- Start CFrame teleport desync if target changed (or not active)
        -- The desync must be active BEFORE we send shot data, so the server sees us
        -- at the teleported position when it validates the hit.
        if not engine.desyncActive or engine.currentDesyncTarget ~= targetPlayer then
            engine:desyncStart(targetPlayer)
            -- Wait one Heartbeat frame so the teleport takes effect server-side BEFORE
            -- we send the shot data. (External working script uses task.wait(0.1) here.)
            task.wait(0.1)
        end

        -- Cancel previous desync timer
        if engine.desyncTimer then
            task.cancel(engine.desyncTimer)
            engine.desyncTimer = nil
        end

        -- Get enemy head — always target HEAD (full rage power)
        local enemyHead = targetPlayer.Character:FindFirstChild("Head")
        if not enemyHead then return unpack(results) end

        local headPos = enemyHead.Position
        local headCFrame = enemyHead.CFrame

        -- Small jitter so each shot looks slightly different (±0.2 — not too random)
        local offsetX = math.random(-2, 2) / 10
        local offsetY = math.random(-2, 2) / 10
        local offsetZ = math.random(-2, 2) / 10
        local targetPos = headPos + Vector3.new(offsetX, offsetY, offsetZ)

        -- Origin slightly below the hit point (bullet trajectory looks natural)
        local originPos = targetPos - Vector3.new(0, 2, 0)
        local lookAtCF = CFrame.lookAt(originPos, targetPos)
        local relativePos = headCFrame:ToObjectSpace(CFrame.new(targetPos))

        -- Modify shot data using EncodeCFrame — direct head target (FULL POWER)
        -- shotData[utf8.char(0)] = bullet origin CFrame (near target)
        -- shotData[utf8.char(1)] = hit position CFrame (at target head)
        -- shotData[utf8.char(2)] = hit part (enemy Head instance)
        -- shotData[utf8.char(3)] = relative position CFrame
        if engine.utilityModule and engine.utilityModule.EncodeCFrame then
            shotData[utf8.char(0)] = engine.utilityModule:EncodeCFrame(CFrame.new(originPos, targetPos) * CFrame.Angles(lookAtCF:ToOrientation()))
            shotData[utf8.char(1)] = engine.utilityModule:EncodeCFrame(CFrame.new(targetPos) * CFrame.Angles(lookAtCF:ToOrientation()))
            shotData[utf8.char(2)] = enemyHead
            shotData[utf8.char(3)] = engine.utilityModule:EncodeCFrame(relativePos)
        end

        -- Auto-stop desync after 0.15 seconds (stable hit window — external script uses 0.15)
        engine.desyncTimer = task.delay(0.15, function()
            engine:desyncStop()
        end)

        return unpack(results)
    end

    -- Wrap as C closure for stealth (iscclosure returns true → less detectable)
    if newcclosure then
        hookFn = newcclosure(hookFn)
    end

    -- STEALTH: try hookfunction first (patches in-place, reference unchanged)
    local hooked = false
    pcall(function()
        if hookfunction then
            hookfunction(self.gunModule.StartShooting, hookFn)
            hooked = true
            engine.usedHookfunction = true
        end
    end)

    -- Fallback: direct assignment (if hookfunction unavailable or failed)
    if not hooked then
        self.gunModule.StartShooting = hookFn
        engine.usedHookfunction = false
    end
end

function WallbangEngine:findTarget()
    local myChar = lp.Character
    if not myChar then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local closest = nil
    local closestDist = math.huge
    local MAX_DISTANCE = 200

    for _, plr in next, players:GetPlayers() do
        if plr == lp then continue end
        if isTeammate(plr) then continue end

        local char = plr.Character
        if not char then continue end

        local root = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local hum = char:FindFirstChildWhichIsA("Humanoid")

        if not (root and head and hum and hum.Health > 0) then continue end

        local dist = (myRoot.Position - root.Position).Magnitude
        if dist > MAX_DISTANCE then continue end

        if dist < closestDist then
            closestDist = dist
            closest = plr
        end
    end

    return closest
end

--// WALLBANG DESYNC — CFrame Teleport Desync (PROVEN approach from external working script)
-- This is the SAME desync mechanism used by the working external wallbang script, but with
-- safety improvements:
--   1) newcclosure on the restore function (stealthier — iscclosure returns true)
--   2) Save/restore Velocity + RotVelocity too (so physics doesn't break)
--   3) Auto-expire after 0.5s per shot (not continuous — Heartbeat-driven but bounded)
--   4) Sanity checks: skip if no character, no HumanoidRootPart, no target root
--   5) Per-shot desync (not continuous loop) — only desyncs when a shot fires
--
-- HOW IT WORKS:
--   On Heartbeat (BEFORE render): teleport our root CFrame to (target.CFrame * CFrame.new(0,-5,0))
--   → server sees us 5 studs below target → server's hit validation sees us as "next to target"
--   On RenderStepped (priority 101, AFTER Heartbeat): restore our root CFrame to saved position
--   → client render shows us at our real position → no visual teleport
--   Net effect: server thinks we're at target, client sees us at real position → wallbang hits register
function WallbangEngine:desyncStart(targetPlayer)
    -- Clean up any existing desync connection/render binding
    if self.desyncConn then self.desyncConn:Disconnect() end
    pcall(function()
        RunService:UnbindFromRenderStep(self.desyncRestoreName)
    end)

    self.desyncActive = true
    self.currentDesyncTarget = targetPlayer

    local engine = self
    local desyncStartTime = tick()
    -- Safety: bound the desync to 0.5s max per shot (external script used continuous; we bound it)
    local MAX_DESYNC_DURATION = 0.5

    -- Save original CFrame/Velocity so we can restore on each render step
    -- (we re-save on every Heartbeat in case our position changed between frames)
    local savedCFrame, savedVel, savedRotVel

    self.desyncConn = RunService.Heartbeat:Connect(function()
        if not engine.desyncActive then return end

        -- Auto-expire after MAX_DESYNC_DURATION (safety)
        if tick() - desyncStartTime > MAX_DESYNC_DURATION then
            engine:desyncStop()
            return
        end

        local myChar = lp.Character
        if not myChar then return end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end

        local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then
            engine:desyncStop()
            return
        end

        -- SAVE current state (so we can restore on next render step)
        savedCFrame = myRoot.CFrame
        savedVel = myRoot.AssemblyLinearVelocity
        savedRotVel = myRoot.AssemblyAngularVelocity

        -- TELEPORT: place our root 5 studs below the target (same as external working script)
        -- This is what the server sees — server validates "are we close enough to target for hit?"
        pcall(function()
            myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, -5, 0)
        end)

        -- RESTORE on next render step (priority 101 = after most game code, before camera)
        -- This is wrapped in newcclosure for stealth (iscclosure=true → harder to detect)
        local restoreFn
        restoreFn = function()
            if not engine.desyncActive or not savedCFrame then return end
            pcall(function()
                myRoot.CFrame = savedCFrame
                myRoot.AssemblyLinearVelocity = savedVel
                myRoot.AssemblyAngularVelocity = savedRotVel
            end)
            -- Unbind after restoring (single-shot restore per Heartbeat)
            pcall(function()
                RunService:UnbindFromRenderStep(engine.desyncRestoreName)
            end)
        end

        -- Wrap as C closure for stealth (if newcclosure available)
        if newcclosure then
            restoreFn = newcclosure(restoreFn)
        end

        -- Bind the restore (single-use — unbinds itself after running)
        pcall(function()
            RunService:BindToRenderStep(engine.desyncRestoreName, 101, restoreFn)
        end)
    end)
end

function WallbangEngine:desyncStop()
    self.desyncActive = false
    self.currentDesyncTarget = nil
    if self.desyncConn then
        self.desyncConn:Disconnect()
        self.desyncConn = nil
    end
    pcall(function()
        RunService:UnbindFromRenderStep(self.desyncRestoreName)
    end)
end

function WallbangEngine:start()
    self.active = true

    -- Enable the stealth wallbang master flag (so __index hooks return our overrides)
    if WallbangStealthState then
        WallbangStealthState.enabled = true
    end

    -- Initialize if needed (lazy load Gun/Utility modules)
    if not self.initialized then
        if not self:init() then
            Library:Notify({
                Title = "Wallbang",
                Description = "Failed to load Gun module! Retrying...",
                Time = 5
            })
            -- Retry after delay
            task.delay(3, function()
                if self.active and self:init() then
                    self:setup()
                    self:startTargetFinder()
                    -- Apply mods ONCE (not constantly — constant re-apply was detected)
                    if not self.modsApplied then
                        applyWallbangMods()
                        self.modsApplied = true
                    end
                    Library:Notify({
                        Title = "Wallbang",
                        Description = "FULL POWER ACTIVE!",
                        Time = 3
                    })
                end
            end)
            return
        end
    end

    -- Setup Gun.StartShooting hook
    self:setup()

    -- Start target finder
    self:startTargetFinder()

    -- Apply ItemLibrary mods ONCE (not constantly — constant re-apply triggers detection)
    if not self.modsApplied then
        applyWallbangMods()
        self.modsApplied = true
    end

    -- FULL POWER: re-apply every 5 seconds (AC is bypassed, aggressive re-apply is safe)
    -- With the STEALTH metamethod hook, raw values stay original but reads return our overrides.
    -- So we check whether the metatable is still attached (via rawget vs normal access mismatch).
    task.spawn(function()
        while self.active and RageMode.Wallbang and RageMode.Enabled do
            task.wait(5)
            -- Check if mods were reset (game replaced item tables), only re-apply if needed
            pcall(function()
                local RS = ReplicatedStorage
                local Items = require(RS:WaitForChild("Modules", 10):WaitForChild("ItemLibrary", 10)).Items
                local needsReapply = false
                local trackedCount = 0
                local itemCount = 0
                for name, data in pairs(Items) do
                    if typeof(data) == "table" then
                        itemCount = itemCount + 1
                        if WallbangStealthState.applied[data] then
                            trackedCount = trackedCount + 1
                        end
                        -- Detection: if our hook is gone, raw access == normal access
                        -- (rawget bypasses __index, so if metatable is missing, both return same value)
                        local rawVal = rawget(data, "ProjectileWallClipPreventionEnabled")
                        local readVal = data.ProjectileWallClipPreventionEnabled
                        if rawVal == true and readVal == true then
                            -- Metatable not attached (or hook broken) → re-apply
                            needsReapply = true
                            break
                        end
                    end
                end
                -- Also re-apply if item count changed (new weapons spawned)
                if trackedCount < itemCount then
                    needsReapply = true
                end
                if needsReapply then
                    wbDebug(string.format("re-applying (tracked %d/%d items)", trackedCount, itemCount))
                    applyWallbangMods()
                end
            end)
        end
    end)

    Library:Notify({
        Title = "Wallbang",
        Description = "FULL POWER ACTIVE!",
        Time = 3
    })
end

function WallbangEngine:startTargetFinder()
    if self.targetFinderConn then self.targetFinderConn:Disconnect() end
    -- Use slower target finder (every 0.1s instead of every frame — less suspicious)
    self.targetFinderConn = RunService.Heartbeat:Connect(function()
        if not self.active then return end
        self.currentTarget = self:findTarget()
    end)
end

function WallbangEngine:stop()
    self.active = false
    self.currentTarget = nil

    -- Disable the stealth wallbang master flag.
    -- The __index hooks will now pass through to original values (no override).
    -- We do NOT need to unhook the metatables — they stay attached but become inert.
    if WallbangStealthState then
        WallbangStealthState.enabled = false
        wbDebug("wallbang disabled — stealth hooks now pass-through")
    end

    -- Stop desync
    self:desyncStop()

    -- Stop target finder
    if self.targetFinderConn then
        self.targetFinderConn:Disconnect()
        self.targetFinderConn = nil
    end

    -- Cancel desync timer
    if self.desyncTimer then
        task.cancel(self.desyncTimer)
        self.desyncTimer = nil
    end

    -- Restore Gun.StartShooting
    if self.oldStartShooting and self.gunModule then
        -- If we used hookfunction, patch back to the original (in-place restore)
        if self.usedHookfunction and hookfunction then
            pcall(function()
                hookfunction(self.gunModule.StartShooting, self.oldStartShooting)
            end)
        end
        -- Also restore via direct assignment (covers both hookfunction + fallback cases)
        self.gunModule.StartShooting = self.oldStartShooting
        self.oldStartShooting = nil
        self.usedHookfunction = false
    end

    -- Reset globals
    getgenv().silentAimTargetPos = nil
end

--// METAMETHOD HOOK — Silent Aim direction redirect only
pcall(function()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        -- Intercept workspace:Raycast — Silent Aim direction redirect
        if not checkcaller() and self == workspace and (method == "Raycast" or method == "raycast") then
            local origin = args[1]
            local direction = args[2]

            if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                -- SILENT AIM / RAGE MODE: Just redirect direction to target
                if getgenv().silentAimTargetPos and direction.Magnitude > 50 then
                    args[2] = (getgenv().silentAimTargetPos - origin).Unit * direction.Magnitude
                    return oldNamecall(self, unpack(args))
                end
            end
        end

        return oldNamecall(self, ...)
    end))
end)

--// HOOK MODULE UTILITY ENGINE (Silent Aim + Rage Mode Bullet Redirection)
task.spawn(function()
    task.wait(3)
    local modules = ReplicatedStorage:WaitForChild("Modules", 5)
    if not modules then return end
    local utility = require(modules:WaitForChild("Utility", 5))
    if not utility then return end

    local old_rc = utility.Raycast
    utility.Raycast = function(...)
        local args = {...}
        -- [V5] Broadened detection: match ANY game script (not our own)
        -- Old code only matched "Weapon"/"Gun"/"Client" — too restrictive
        local current_script = debug.info(2, "s") or ""
        local isWeaponScript = current_script and (
            current_script:find("Weapon") or
            current_script:find("Gun") or
            current_script:find("Client") or
            current_script:find("Sword") or
            current_script:find("Blade") or
            current_script:find("Fighter") or
            current_script:find("Combat") or
            current_script:find("Item") or
            current_script:find("Attack") or
            current_script:find("Shoot") or
            current_script:find("Projectile") or
            true  -- [V5] If all else fails, allow it (better to redirect too much than not at all)
        )

        -- [V5] Silent Aim: first bullet hits, then cooldown before next hit
        -- If enough time passed since last hit, redirect this bullet to target
        -- Otherwise, bullet goes to normal crosshair position (no redirect)
        if SilentAim.Enabled and isWeaponScript then
            -- Decision: should this bullet hit the target?
            local shouldHit = silentAimShouldHit()

            if shouldHit then
                local hit = get_best_target(SilentAim)
                if hit then
                    local jitter = Vector3.new(math.random(-5,5)/100, math.random(-5,5)/100, math.random(-5,5)/100)
                    local targetPosition = hit.Position
                    -- Apply projectile prediction if enabled
                    if SilentAim.ProjectilePrediction and hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart") then
                        local weaponName = getCurrentWeaponName()
                        targetPosition = calculateProjectilePrediction(targetPosition, hit.Parent.HumanoidRootPart, weaponName, SilentAim.Prediction)
                    elseif hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart") then
                        -- [V3] Use Velocity (more reliable than AssemblyLinearVelocity for character prediction)
                        local hrp = hit.Parent.HumanoidRootPart
                        local vel = hrp.Velocity  -- Rage Hub style: Velocity is more accurate for character movement
                        -- If Velocity is zero (e.g. anchored character), fall back to AssemblyLinearVelocity
                        if vel.Magnitude < 0.1 then
                            vel = hrp.AssemblyLinearVelocity
                        end
                        targetPosition = targetPosition + (vel * SilentAim.Prediction)
                    end
                    -- Redirect this bullet's hit position to the target
                    args[3] = targetPosition + jitter
                    -- Set global for hookmetamethod hook (workspace:Raycast direction redirect)
                    getgenv().silentAimTargetPos = targetPosition + jitter
                    -- Also modify filter for Wall Check bypass
                    if SilentAim.WallCheck then
                        if typeof(args[5]) == "table" then
                            for _, plr in pairs(players:GetPlayers()) do
                                if plr ~= lp and plr.Character then
                                    local found = false
                                    for _, existing in ipairs(args[5]) do
                                        if existing == plr.Character then found = true break end
                                    end
                                    if not found then
                                        table.insert(args[5], plr.Character)
                                    end
                                end
                            end
                        end
                    end
                else
                    -- No target found this shot: clear the redirect so the bullet goes normal
                    getgenv().silentAimTargetPos = nil
                end
            else
                -- [V5] Cooldown active: don't redirect — bullet goes to crosshair
                getgenv().silentAimTargetPos = nil
            end
        -- Rage Mode — redirect bullets to target
        elseif RageMode.Enabled and isWeaponScript then
            local rageTarget = get_best_target(RageMode)
            if rageTarget then
                local jitter = Vector3.new(math.random(-5,5)/100, math.random(-5,5)/100, math.random(-5,5)/100)
                local targetPosition = rageTarget.Position
                if rageTarget.Parent and rageTarget.Parent:FindFirstChild("HumanoidRootPart") then
                    -- [V3] Use Velocity for better prediction
                    local hrp = rageTarget.Parent.HumanoidRootPart
                    local vel = hrp.Velocity
                    if vel.Magnitude < 0.1 then vel = hrp.AssemblyLinearVelocity end
                    targetPosition = targetPosition + (vel * 0.08)
                end
                targetPosition = targetPosition + jitter
                -- Change target position (arg3)
                args[3] = targetPosition

                -- Set global for hookmetamethod hook (silent aim direction redirect)
                getgenv().silentAimTargetPos = targetPosition
            else
                -- No target: clear globals
                getgenv().silentAimTargetPos = nil
            end
        else
            -- No aim mode active: clear globals
            getgenv().silentAimTargetPos = nil
        end

        return old_rc(table.unpack(args))
    end
end)


-- ============================================================
-- [V3 from Rage Hub] SERVER HOP BUTTON
-- Finds a non-full server and teleports to it
-- ============================================================
local function serverHop()
    local placeId = game.PlaceId
    local jobId = game.JobId
    pcall(function()
        local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Asc&limit=100"))
        if servers and servers.data then
            for _, srv in pairs(servers.data) do
                if srv.playing < srv.maxPlayers and srv.id ~= jobId then
                    TeleportService:TeleportToPlaceInstance(placeId, srv.id, lp)
                    break
                end
            end
        end
    end)
end
getgenv().serverHop = serverHop

--// MANAGEMENT STORAGE AND RETRIEVAL INITIALIZATION
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("ZytheraXHub")
SaveManager:SetFolder("ZytheraXHub/game-config")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

SaveManager:LoadAutoloadConfig()
