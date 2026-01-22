
local GT = GuildTools
local U = GT.Utils
local Log = GT.Log
GT.Comm = GT.Comm or { PREFIX='GuildTools', CHUNK=220 }
local C = GT.Comm

local SendAddonMessageFunc = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
local RegisterPrefix = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
RegisterPrefix(C.PREFIX)

C.incoming = C.incoming or {}

local function sendRaw(msg, channel, target)
  return SendAddonMessageFunc(C.PREFIX, msg, channel or 'GUILD', target)
end

-- Chunked transport (unchanged)
function C:Send(type_, payload, channel, target)
  local body = (type_ or 'UNKNOWN')..'
'..(payload or '')
  local total = math.ceil(#body / C.CHUNK)
  local id = U:NewId('m')
  if Log then Log:Add('INFO','SYNC',('Tx %s parts=%d ch=%s to=%s'):format(type_, total, channel or 'GUILD', tostring(target or ''))) end
  for i=1,total do
    local part = body:sub((i-1)*C.CHUNK+1, i*C.CHUNK)
    sendRaw(('%s^%d^%d^%s'):format('^'..id, i, total, part), channel, target)
  end
end

-- Addon message reassembly
local function onAddonMsg(prefix, msg, dist, sender)
  if prefix ~= C.PREFIX then return end
  if dist ~= 'GUILD' then return end -- harden: only accept GUILD traffic
  if not IsInGuild() then return end
  local id, idx, total, part = msg:match('^%^(.-)%^(%d+)%^(%d+)%^(.*)')
  if not id then return end
  idx, total = tonumber(idx), tonumber(total)
  local buf = C.incoming[id] or { parts={}, received=0, total=total, from=sender }
  buf.parts[idx] = part
  buf.received = buf.received + 1
  C.incoming[id] = buf
  if buf.received >= buf.total then
    local payload = table.concat(buf.parts)
    C.incoming[id] = nil
    local type_, data = payload:match('^(.-)
(.*)$')
    if Log then Log:Add('INFO','SYNC',('Rx %s from %s parts=%d'):format(type_ or '?', tostring(sender or '?'), total or 0)) end
    C:OnMessage(type_, data, sender, dist)
  end
end

local f = CreateFrame('Frame')
f:RegisterEvent('CHAT_MSG_ADDON')
f:SetScript('OnEvent', function(_,_,...)
  onAddonMsg(...)
end)

-- === Public API ===
function C:RequestSync(reason)
  if GT.SelectGuildDB then GT:SelectGuildDB() end
  local myDv = (GT.gdb and GT.gdb.dataVersion) or 0
  local pay = U:Serialize({ reason = reason or 'MANUAL', dv = myDv })
  if Log then Log:Add('INFO','SYNC','Requesting sync reason='..(reason or 'MANUAL')..' dv='..tostring(myDv)) end
  C:Send('SYNC_REQ', pay)
end

function C:BroadcastFull()
  -- Keep admin-gated manual broadcast for safety, but normal replies to SYNC_REQ are not admin-gated (see below)
  if not U:HasPermission(GT.gdb.permissions.adminMinRank) then
    if Log then Log:Add('INFO','SYNC','BroadcastFull skipped (no admin permission)') end
    return
  end
  local snapshot = { dv=GT.gdb.dataVersion, events=GT.gdb.events, bank=GT.gdb.bankRequests, perms=GT.gdb.permissions }
  if Log then Log:Add('INFO','SYNC','Broadcasting FULL snapshot (manual/admin) dv='..tostring(GT.gdb.dataVersion or 0)) end
  C:Send('SYNC_FULL', U:Serialize(snapshot))
end

-- === Core message handling ===
function C:OnMessage(type_, data, sender, dist)
  if type_=='SYNC_REQ' then
    -- Any member with newer data should answer, so first-time/empty clients hydrate
    local req = U:Deserialize(data) or {}
    local requesterDv = tonumber(req.dv or 0) or 0
    local myDv = (GT.gdb and GT.gdb.dataVersion) or 0
    if myDv > requesterDv then
      local snapshot = { dv=GT.gdb.dataVersion, events=GT.gdb.events, bank=GT.gdb.bankRequests, perms=GT.gdb.permissions }
      if Log then Log:Add('INFO','SYNC',('Answering SYNC_REQ (my dv=%s > req dv=%s)'):format(tostring(myDv), tostring(requesterDv))) end
      C:Send('SYNC_FULL', U:Serialize(snapshot))
    else
      if Log then Log:Add('INFO','SYNC',('Not answering SYNC_REQ (my dv=%s <= req dv=%s)'):format(tostring(myDv), tostring(requesterDv))) end
    end

  elseif type_=='SYNC_FULL' then
    local tbl = U:Deserialize(data)
    if tbl and type(tbl)=='table' then
      local localDv = (GT.gdb and GT.gdb.dataVersion) or 0
      local incomingDv = tonumber(tbl.dv or 0) or 0
      local isLocalEmpty = (not GT.gdb or not GT.gdb.events or next(GT.gdb.events)==nil) and (not GT.gdb or not GT.gdb.bankRequests or next(GT.gdb.bankRequests)==nil)
      if (incomingDv > localDv) or (isLocalEmpty and incomingDv >= localDv) then
        GT.gdb.dataVersion = incomingDv
        GT.gdb.events = tbl.events or {}
        GT.gdb.bankRequests = tbl.bank or {}
        GT.gdb.permissions = tbl.perms or (GT.gdb and GT.gdb.permissions) or { raidsMinRank=1, bankMinRank=1, adminMinRank=0 }
        if GT.UI and GT.UI.RefreshAll then GT.UI:RefreshAll() end
        if Log then Log:Add('INFO','SYNC','Applied FULL snapshot dv='..tostring(incomingDv)..(isLocalEmpty and ' (local was empty)' or '')) end
      else
        if Log then Log:Add('INFO','SYNC','Ignored FULL snapshot dv='..tostring(incomingDv)..' (local dv='..tostring(localDv)..')') end
      end
    end

  elseif type_=='EVENT_UPDATE' then
    local t = U:Deserialize(data)
    if t and t.id then
      GT.gdb.events[t.id] = t
      GT.gdb.dataVersion = (GT.gdb.dataVersion or 1) + 1
      if GT.UI and GT.UI.RefreshRaids then GT.UI:RefreshRaids() end
      if Log then Log:Add('INFO','EVENT','Event update '..tostring(t.id)) end
    end

  elseif type_=='EVENT_DELETE' then
    local t = U:Deserialize(data)
    if t and t.id then
      GT.gdb.events[t.id] = nil
      if GT.UI and GT.UI.RefreshRaids then GT.UI:RefreshRaids() end
      if Log then Log:Add('INFO','EVENT','Event delete '..tostring(t.id)) end
    end

  elseif type_=='BANK_UPDATE' then
    local t = U:Deserialize(data)
    if t and t.id then
      GT.gdb.bankRequests[t.id] = t
      GT.gdb.dataVersion = (GT.gdb.dataVersion or 1) + 1
      if GT.UI and GT.UI.RefreshBank then GT.UI:RefreshBank() end
      if Log then Log:Add('INFO','BANK','Bank update '..tostring(t.id)) end
    end
  end
end
