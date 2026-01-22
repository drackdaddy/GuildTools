local ADDON_NAME = ...
_G.GuildTools = _G.GuildTools or {}
local GT = GuildTools

local defaults = {
  version = '1.0.0',
  dataVersion = 1,
  permissions = { raidsMinRank = 1, bankMinRank = 1, adminMinRank = 0 },
  events = {},
  bankRequests = {},
  minimap = { hide=false, angle=200 },
  debug = false,
  logs = {},
}

local function copyDefaults(src, dst)
  if type(src) ~= 'table' then return end
  for k,v in pairs(src) do
    if type(v) == 'table' then dst[k]=dst[k] or {}; copyDefaults(v, dst[k]) elseif dst[k]==nil then dst[k]=v end
  end
end

local f = CreateFrame('Frame')
f:RegisterEvent('ADDON_LOADED')
f:RegisterEvent('PLAYER_LOGIN')

f:SetScript('OnEvent', function(self, event, ...)
  if event == 'ADDON_LOADED' then
    local addon = ...
    if addon == ADDON_NAME then
      GuildToolsSaved = GuildToolsSaved or {}
      copyDefaults(defaults, GuildToolsSaved)
      GT.db = GuildToolsSaved
      if GT.Admin and GT.Admin.OnInit then GT.Admin.OnInit() end
      if GT.Log and GT.Log.Add then GT.Log:Add('INFO','CORE','Addon loaded') end
      -- Chat banner & tip (discoverability)
      local ver = GT.db.version or 'n/a'
      DEFAULT_CHAT_FRAME:AddMessage('|cff00ffff[GuildTools]|r Loaded v'..ver..' — type |cffffff00/gt|r to open the app.')
      if GT.Log then GT.Log:Add('INFO','CORE','Loaded v'..ver..' (/gt to open)') end
      if GT.UI and GT.UI.Build then GT.UI.Build() end
    end
  elseif event == 'PLAYER_LOGIN' then
    if GT.Log and GT.Log.Add then GT.Log:Add('INFO','CORE','Player login') end
    if GT.Debug and GT.Debug.Instrument then GT.Debug:Instrument() end
    if GT.Minimap and GT.Minimap.Create then C_Timer.After(0.1, function() GT.Minimap:Create() end) end
    if GT.Comm and GT.Comm.RequestSync then C_Timer.After(3, function() GT.Comm:RequestSync('LOGIN') end) end
  end
end)

-- Slash commands
SLASH_GUILDTOOLS1='/guildtools'
SLASH_GUILDTOOLS2='/gt'
SlashCmdList['GUILDTOOLS'] = function()
  if GT.UI and GT.UI.Toggle then GT.UI:Toggle() end
end