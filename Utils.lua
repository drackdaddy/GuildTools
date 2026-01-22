local GT = GuildTools
GT.Utils = {}
local U = GT.Utils

-- WHY: Single debug entry point; prints to chat when debug is enabled and logs DEBUG.
function U:debug(msg)
  if GT and GT.db and GT.db.debug then
    DEFAULT_CHAT_FRAME:AddMessage('|cff00ffff[GuildTools]|r '..tostring(msg))
  end
  if GT and GT.Log then GT.Log:Debug('DEBUG', msg) end
end

function U:TableSize(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
function U:NewId(prefix) prefix=prefix or 'id'; return prefix..'-'..time()..'-'..math.random(1000,9999) end

-- Simple table serializer for comm payloads (trusted local use only)
function U:Serialize(tbl)
  local t=type(tbl)
  if t=='number' or t=='boolean' then return tostring(tbl) end
  if t=='string' then return string.format('%q', tbl) end
  if t~='table' then return 'nil' end
  local out={'{'}; local first=true
  for k,v in pairs(tbl) do
    if not first then table.insert(out, ',') end
    first=false
    local key
    if type(k)=='string' and k:match('^%a[%w_]*$') then key=k else key='['..U:Serialize(k)..']' end
    table.insert(out, key .. '=' .. U:Serialize(v))
  end
  table.insert(out, '}')
  return table.concat(out)
end

function U:Deserialize(str)
  local f, err = loadstring('return '..str)
  if not f then return nil, err end
  setfenv(f, {})
  local ok, res = pcall(f)
  if not ok then return nil, res end
  return res
end

function U:GetPlayerGuildRankIndex() local _,_,ri=GetGuildInfo('player'); return ri end -- 0=GM
function U:HasPermission(minRankIndex) local ri=U:GetPlayerGuildRankIndex(); if ri==nil then return false end; return ri <= (minRankIndex or 0) end