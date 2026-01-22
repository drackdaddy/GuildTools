-- Core.lua (FULL FILE - updated to tag FIRST_LOGIN vs LOGIN and trigger force when needed)
local ADDON_NAME = ...
_G.GuildTools = _G.GuildTools or {}
local GT = GuildTools

-- account-level defaults; guild data lives under db.guilds[key]
local defaults = {
  version = '1.0.0',
  minimap = { hide=false, angle=200 },
  debug   = false,
  guilds  = {},
}

local function copyDefaults(src, dst)
  if type(src) ~= 'table' then return end
  for k,v in pairs(src) do
    if type(v) == 'table' then
      dst[k]=dst[k] or {}; copyDefaults(v, dst[k])
    elseif dst[k]==nil then
      dst[k]=v
    end
  end
end

local function GetRealmKey()
  if GetNormalizedRealmName then return GetNormalizedRealmName() end
  return GetRealmName()
end

local function GetGuildKey()
  local gname = GetGuildInfo('player')
  local realm = GetRealmKey() or ''
  return (gname or 'UNGUILDED') .. '@' .. realm
end

-- Select or create the current guild bucket and expose GT.gdb
function GT:SelectGuildDB()
  self.db.guilds = self.db.guilds or {}
  local key = GetGuildKey()
  self.state = self.state or {}
  self.state.guildKey = key

  -- one-time migration from flat keys if they ever existed
  if not self.db._migratedGuildScope then
    local seed = {
      dataVersion = self.db.dataVersion or 1,
      events      = self.db.events or {},
      bankRequests= self.db.bankRequests or {},
      permissions = self.db.permissions or { raidsMinRank=1, bankMinRank=1, adminMinRank=0 },
      logs        = self.db.logs or {},
    }
    self.db.guilds[key] = self.db.guilds[key] or seed
    -- clear flat copies to avoid cross-guild bleed
    self.db.events, self.db.bankRequests, self.db.permissions, self.db.logs, self.db.dataVersion = nil, nil, nil, nil, nil
    self.db._migratedGuildScope = true
  end

  if not self.db.guilds[key] then
    self.db.guilds[key] = {
      dataVersion = 1,
      events = {},
      bankRequests = {},
      permissions = { raidsMinRank=1, bankMinRank=1, adminMinRank=0 },
      logs = {},
    }
  end
  self.gdb = self.db.guilds[key]
end

local function isEmpty(t) return (not t) or (next(t) == nil) end

local f = CreateFrame('Frame')
f:RegisterEvent('ADDON_LOADED')
f:RegisterEvent('PLAYER_LOGIN')
f:RegisterEvent('PLAYER_GUILD_UPDATE')
f:SetScript('OnEvent', function(self, event, ...)
  if event == 'ADDON_LOADED' then
    local addon = ...
    if addon == ADDON_NAME then
      GuildToolsSaved = GuildToolsSaved or {}
      copyDefaults(defaults, GuildToolsSaved)
      GT.db = GuildToolsSaved
      GT:SelectGuildDB()
      if GT.Admin and GT.Admin.OnInit then GT.Admin.OnInit() end
      if GT.Log and GT.Log.Add then GT.Log:Add('INFO','CORE','Addon loaded') end
      local ver = GT.db.version or 'n/a'
      DEFAULT_CHAT_FRAME:AddMessage('|cff00ffff[GuildTools]|r Loaded v'..ver..' — type |cffffff00/gt|r to open the app.')
      if GT.Log then GT.Log:Add('INFO','CORE','Loaded v'..ver..' (/gt to open)') end
      if GT.UI and GT.UI.Build then GT.UI.Build() end
    end

  elseif event == 'PLAYER_LOGIN' then
    GT:SelectGuildDB()
    if GT.Log and GT.Log.Add then GT.Log:Add('INFO','CORE','Player login') end
    if GT.Debug and GT.Debug.Instrument then GT.Debug:Instrument() end
    if GT.Minimap and GT.Minimap.Create then C_Timer.After(0.1, function() GT.Minimap:Create() end) end

    -- Decide if this is FIRST_LOGIN for this guild context (fresh/no data and not yet marked).
    local firstForGuild = (not GT.gdb or (isEmpty(GT.gdb.events) and isEmpty(GT.gdb.bankRequests))) and (not GT.gdb or not GT.gdb._firstSyncDone)
    local reason = firstForGuild and 'FIRST_LOGIN' or 'LOGIN'

    if GT.Comm and GT.Comm.RequestSync then
      C_Timer.After(3, function() GT.Comm:RequestSync(reason) end)
    end

  elseif event == 'PLAYER_GUILD_UPDATE' then
    local prevKey = GT.state and GT.state.guildKey
    GT:SelectGuildDB()
    if GT.state.guildKey ~= prevKey then
      if GT.Log and GT.Log.Add then GT.Log:Add('INFO','CORE','Guild context changed to '..GT.state.guildKey) end
      if GT.UI and GT.UI.RefreshAll then GT.UI:RefreshAll() end
    end
  end
end)

-- Slash commands
SLASH_GUILDTOOLS1='/guildtools'
SLASH_GUILDTOOLS2='/gt'
SlashCmdList['GUILDTOOLS'] = function()
  if GT.UI and GT.UI.Toggle then GT.UI:Toggle() end
end
