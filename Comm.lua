
-- Comm.lua ultra-safe (uses long bracket strings only)
local GT = GuildTools
GT.Comm = GT.Comm or { PREFIX = [[GuildTools]], CHUNK = 220 }
local C = GT.Comm

local SendAddonMessageFunc = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
local RegisterPrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
RegisterPrefix(C.PREFIX)

-- Minimal RequestSync & receiver to isolate quote issues
function C:RequestSync(reason)
  local r = reason or [[MANUAL]]
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage([[GuildTools]]..[[: ]]..[[RequestSync reason=]]..r) end
  SendAddonMessageFunc(C.PREFIX, [[PING]], [[GUILD]])
end

local f = CreateFrame([[Frame]])
f:RegisterEvent([[CHAT_MSG_ADDON]])
f:SetScript([[OnEvent]], function(_, prefix, msg, channel, sender)
  if prefix ~= C.PREFIX then return end
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage([[GuildTools]]..[[: Rx ]]..tostring(msg)..[[ from ]]..tostring(sender)) end
end)

-- Stubs for API compatibility
function C:Send(type_, payload, channel, target)
  SendAddonMessageFunc(C.PREFIX, (type_ or [[ ]])..[[
]]..(payload or [[ ]]), channel or [[GUILD]], target)
end
function C:BroadcastFull() end
function C:OnMessage() end
