local GT = GuildTools
local U = GT.Utils
local Log = GT.Log

GT.Comm = { PREFIX='GuildTools', CHUNK=220 }
local C = GT.Comm

local SendAddonMessageFunc = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
local RegisterPrefix = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
RegisterPrefix(C.PREFIX)

C.incoming={}
local function sendRaw(msg, channel, target) return SendAddonMessageFunc(C.PREFIX, msg, channel or 'GUILD', target) end

-- WHY: Simple chunked transport for larger payloads, keeping traffic low.
function C:Send(type_, payload, channel, target)
  local body = type_..'|'..payload
  local total = math.ceil(#body / C.CHUNK)
  local id = U:NewId('m')
  for i=1,total do
    local part = body:sub((i-1)*C.CHUNK+1, i*C.CHUNK)
    sendRaw(string.format('^%s^%d^%d^%s', id, i, total, part), channel, target)
  end
end

local function onAddonMsg(prefix, msg, dist, sender)
  if prefix ~= C.PREFIX then return end
  local id, idx, total, part = msg:match('^%^(.-)^(%d+)^(%d+)%^(.*)')
  if not id then return end
  idx, total = tonumber(idx), tonumber(total)
  local buf = C.incoming[id] or { parts={}, received=0, total=total, from=sender }
  buf.parts[idx] = part
  buf.received = buf.received + 1
  C.incoming[id] = buf
  if buf.received >= buf.total then
    local payload = table.concat(buf.parts)
    C.incoming[id] = nil
    local type_, data = payload:match('^(.-)|(.*)$')
    C:OnMessage(type_, data, sender, dist)
  end
end

local f=CreateFrame('Frame')
f:RegisterEvent('CHAT_MSG_ADDON')
f:SetScript('OnEvent', function(_,_,...) onAddonMsg(...) end)

function C:RequestSync(reason)
  local pay = U:Serialize({ reason=reason or 'MANUAL', dv=GT.db.dataVersion })
  if Log then Log:Add('INFO','SYNC','Requesting sync ('..(reason or 'MANUAL')..')') end
  C:Send('SYNC_REQ', pay)
end

function C:BroadcastFull()
  if not U:HasPermission(GT.db.permissions.adminMinRank) then return end
  local snapshot = { dv=GT.db.dataVersion, events=GT.db.events, bank=GT.db.bankRequests, perms=GT.db.permissions }
  if Log then Log:Add('INFO','SYNC','Broadcasting full snapshot') end
  C:Send('SYNC_FULL', U:Serialize(snapshot))
end

function C:OnMessage(type_, data, sender, dist)
  if Log then Log:Add('INFO','SYNC','Received '..tostring(type_)..' from '..tostring(sender or '?')) end
  if type_=='SYNC_REQ' then
    if U:HasPermission(GT.db.permissions.adminMinRank) then C:BroadcastFull() end
  elseif type_=='SYNC_FULL' then
    local tbl = U:Deserialize(data)
    if tbl and type(tbl)=='table' then
      if not GT.db or tbl.dv > (GT.db.dataVersion or 0) then
        GT.db.dataVersion = (tbl.dv or GT.db.dataVersion)
        GT.db.events      = tbl.events or GT.db.events
        GT.db.bankRequests= tbl.bank   or GT.db.bankRequests
        GT.db.permissions = tbl.perms  or GT.db.permissions
        if GT.UI and GT.UI.RefreshAll then GT.UI:RefreshAll() end
        if Log then Log:Add('INFO','SYNC','Applied snapshot dv='..tostring(tbl.dv)) end
      end
    end
  elseif type_=='EVENT_UPDATE' then
    local t = U:Deserialize(data)
    if t and t.id then
      GT.db.events[t.id] = t
      GT.db.dataVersion = (GT.db.dataVersion or 1) + 1
      if GT.UI and GT.UI.RefreshRaids then GT.UI:RefreshRaids() end
      if Log then Log:Add('INFO','EVENT','Event update '..tostring(t.id)) end
    end
  elseif type_=='EVENT_DELETE' then
    local t = U:Deserialize(data)
    if t and t.id then
      GT.db.events[t.id] = nil
      if GT.UI and GT.UI.RefreshRaids then GT.UI:RefreshRaids() end
      if Log then Log:Add('INFO','EVENT','Event delete '..tostring(t.id)) end
    end
  elseif type_=='BANK_UPDATE' then
    local t = U:Deserialize(data)
    if t and t.id then
      GT.db.bankRequests[t.id] = t
      GT.db.dataVersion = (GT.db.dataVersion or 1) + 1
      if GT.UI and GT.UI.RefreshBank then GT.UI:RefreshBank() end
      if Log then Log:Add('INFO','BANK','Bank update '..tostring(t.id)) end
    end
  end
end