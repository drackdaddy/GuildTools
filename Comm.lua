
-- Comm.lua (FULL FILE - updated for robust full sync on first login & manual sync)
local GT = GuildTools
local U  = GT.Utils
local Log = GT.Log

GT.Comm = { PREFIX='GuildTools', CHUNK=220 }
local C = GT.Comm

local SendAddonMessageFunc = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
local RegisterPrefix       = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
RegisterPrefix(C.PREFIX)

C.incoming = {}

local function sendRaw(msg, channel, target)
  return SendAddonMessageFunc(C.PREFIX, msg, channel or 'GUILD', target)
end

function C:Send(type_, payload, channel, target)
  local body  = type_..'\n'..payload
  local total = math.ceil(#body / C.CHUNK)
  local id    = U:NewId('m')
  for i=1,total do
    local part = body:sub((i-1)*C.CHUNK+1, i*C.CHUNK)
    sendRaw(string.format('^%s^%d^%d^%s', id, i, total, part), channel, target)
  end
end

local function onAddonMsg(prefix, msg, dist, sender)
  if prefix ~= C.PREFIX then return end
  if dist ~= 'GUILD' then return end -- only accept guild traffic
  if not IsInGuild() then return end

  local id, idx, total, part = msg:match('^%^(.-)%^(%d+)%^(%d+)%^(.*)')
  if not id then return end
  idx, total = tonumber(idx), tonumber(total)

  local buf = C.incoming[id] or { parts={}, received=0, total=total, from=sender }
  buf.parts[idx] = part
  buf.received   = buf.received + 1
  C.incoming[id] = buf

  if buf.received >= buf.total then
    local payload = table.concat(buf.parts)
    C.incoming[id] = nil
    local type_, data = payload:match('^(.-)\n(.*)$')
    C:OnMessage(type_, data, sender, dist)
  end
end

local f = CreateFrame('Frame')
f:RegisterEvent('CHAT_MSG_ADDON')
f:SetScript('OnEvent', function(_,_,...) onAddonMsg(...) end)

-- Helper: consider data "empty" for first-time force-apply decisions
local function dataIsEmpty()
  if not GT.gdb then return true end
  local evEmpty = (not GT.gdb.events) or (next(GT.gdb.events) == nil)
  local bankEmpty = (not GT.gdb.bankRequests) or (next(GT.gdb.bankRequests) == nil)
  return evEmpty and bankEmpty
end

-- Request a sync, tagging reason and dv. We also tag force for MANUAL/FIRST_LOGIN.
function C:RequestSync(reason)
  if GT.SelectGuildDB then GT:SelectGuildDB() end
  local r = reason or 'MANUAL'
  local force = (r == 'MANUAL' or r == 'FIRST_LOGIN') and true or false
  local pay = U:Serialize({
    reason = r,
    force  = force,
    dv     = (GT.gdb and GT.gdb.dataVersion) or 1,
  })
  if Log then Log:Add('INFO','SYNC','Requesting sync ('..tostring(r)..')') end
  C:Send('SYNC_REQ', pay)
end

-- Broadcast a full snapshot. Accept an optional req (table) to propagate context.
function C:BroadcastFull(req)
  if not U:HasPermission(GT.gdb.permissions.adminMinRank) then return end
  local snapshot = {
    dv    = GT.gdb.dataVersion,
    events= GT.gdb.events,
    bank  = GT.gdb.bankRequests,
    perms = GT.gdb.permissions,
    -- propagate request context so receivers can decide to force apply
    reqReason = req and req.reason or nil,
    force     = req and req.force   or false,
    ts        = time(),
  }
  if Log then Log:Add('INFO','SYNC','Broadcasting full snapshot (force='..tostring(snapshot.force)..', reason='..tostring(snapshot.reqReason or 'n/a')..')') end
  C:Send('SYNC_FULL', U:Serialize(snapshot))
end

function C:OnMessage(type_, data, sender, dist)
  if Log then Log:Add('INFO','SYNC','Received '..tostring(type_)..' from '..tostring(sender or '?')) end

  if type_ == 'SYNC_REQ' then
    local req = U:Deserialize(data) or {}
    if U:HasPermission(GT.gdb.permissions.adminMinRank) then
      C:BroadcastFull(req)
    end

  elseif type_ == 'SYNC_FULL' then
    local tbl = U:Deserialize(data)
    if tbl and type(tbl) == 'table' then
      if GT.SelectGuildDB then GT:SelectGuildDB() end

      local incomingDV = tbl.dv or 0
      local localDV    = (GT.gdb and GT.gdb.dataVersion) or 0
      local shouldForce = (tbl.force == true)
        or (tbl.reqReason == 'FIRST_LOGIN')
        or (tbl.reqReason == 'MANUAL')
        or dataIsEmpty()

      -- Apply if (force) OR (incoming dv >= local dv) OR (we have empty data)
      if shouldForce or (incomingDV >= localDV) then
        GT.gdb.events        = tbl.events or GT.gdb.events
        GT.gdb.bankRequests  = tbl.bank   or GT.gdb.bankRequests
        GT.gdb.permissions   = tbl.perms  or GT.gdb.permissions
        -- keep the higher dv (in case localDV > incomingDV but force is true)
        GT.gdb.dataVersion   = math.max(incomingDV, localDV, 1)
        GT.gdb._firstSyncDone = true

        if GT.UI and GT.UI.RefreshAll then GT.UI:RefreshAll() end
        if Log then
          Log:Add('INFO','SYNC', string.format(
            'Applied FULL snapshot dv=%s (local dv=%s, force=%s, reason=%s)',
            tostring(incomingDV), tostring(localDV), tostring(shouldForce),
            tostring(tbl.reqReason or 'n/a')))
        end
      else
        if Log then
          Log:Add('INFO','SYNC', string.format(
            'Ignored FULL snapshot dv=%s (local dv=%s, no force and not newer)',
            tostring(incomingDV), tostring(localDV)))
        end
      end
    end

  elseif type_ == 'EVENT_UPDATE' then
    local t = U:Deserialize(data)
    if t and t.id then
      GT.gdb.events[t.id] = t
      GT.gdb.dataVersion  = (GT.gdb.dataVersion or 1) + 1
      if GT.UI and GT.UI.RefreshRaids then GT.UI:RefreshRaids() end
      if Log then Log:Add('INFO','EVENT','Event update '..tostring(t.id)) end
    end

  elseif type_ == 'EVENT_DELETE' then
    local t = U:Deserialize(data)
    if t and t.id then
      GT.gdb.events[t.id] = nil
      if GT.UI and GT.UI.RefreshRaids then GT.UI:RefreshRaids() end
      if Log then Log:Add('INFO','EVENT','Event delete '..tostring(t.id)) end
    end

  elseif type_ == 'BANK_UPDATE' then
    local t = U:Deserialize(data)
    if t and t.id then
      GT.gdb.bankRequests[t.id] = t
      GT.gdb.dataVersion        = (GT.gdb.dataVersion or 1) + 1
      if GT.UI and GT.UI.RefreshBank then GT.UI:RefreshBank() end
      if Log then Log:Add('INFO','BANK','Bank update '..tostring(t.id)) end
    end
  end
end
