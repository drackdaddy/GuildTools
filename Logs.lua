local GT = GuildTools
local Log = GT.Log

GT.Logs = GT.Logs or {}
local UI = GT.Logs

local function addRow(parent, y, text)
  local fs = parent:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  fs:SetPoint('TOPLEFT', 6, y)
  fs:SetJustifyH('LEFT')
  fs:SetText(text)
  return fs
end

-- Logs tab (unchanged from your baseline)
function UI:BuildUI(parent)
  local p = CreateFrame('Frame', nil, parent) p:SetAllPoints(true)
  local title = p:CreateFontString(nil,'OVERLAY','GameFontNormalLarge') title:SetPoint('TOPLEFT',20,-20) title:SetText('Event Log')
  local clear = CreateFrame('Button', nil, p, 'UIPanelButtonTemplate') clear:SetSize(100,22) clear:SetPoint('TOPRIGHT', -20, -20) clear:SetText('Clear')
  clear:SetScript('OnClick', function() if GT.db and GT.db.logs then wipe(GT.db.logs) end UI:Refresh() end)

  local list = CreateFrame('Frame', nil, p, 'InsetFrameTemplate3')
  list:SetPoint('TOPLEFT', 20, -60)
  list:SetPoint('BOTTOMRIGHT', -20, 20)

  local scroll = CreateFrame('ScrollFrame', nil, list, 'UIPanelScrollFrameTemplate') -- no global name to avoid conflicts
  scroll:SetPoint('TOPLEFT', 10, -10)
  scroll:SetPoint('BOTTOMRIGHT', -30, 10)

  local content = CreateFrame('Frame', nil, scroll); content:SetSize(1,1)
  scroll:SetScrollChild(content)
  p.content = content

  UI.parent = p
  UI:Refresh()

  -- Single subscription for live updates
  if not UI._log_subscribed then
    Log:Register(function() if UI.parent then UI:Refresh(true) end end)
    UI._log_subscribed = true
  end
end

function UI:Refresh(appendOnly)
  if not UI.parent then return end
  local content = UI.parent.content
  if not appendOnly then
    for _,c in ipairs({content:GetChildren()}) do c:Hide(); c:SetParent(nil) end
  end
  local y = -2
  local logs = Log:GetAll()
  local lastN = 300
  local start = math.max(1, #logs - lastN + 1)
  for i = start, #logs do
    local e = logs[i]
    local line = string.format('|cffaaaaaa%s|r |cff00ff00[%s]|r |cffffff00[%s]|r %s', date('%H:%M:%S', e.ts), e.level, e.cat, e.msg)
    addRow(content, y, line)
    y = y - 14
  end
  content:SetHeight(-y + 10)
end

-- SYNC widget: newest entries at the TOP, no header label, and spacing adjusted to avoid overlap with the "Sync Now" area.
function UI:BuildSyncWidget(parent)
  -- Inset box positioned a bit lower so it doesn’t overlap the Sync button/tip above.
  local box = CreateFrame('Frame', nil, parent, 'InsetFrameTemplate3')
  box:SetPoint('TOPLEFT', 20, -80)      -- lowered from -60 to avoid overlap
  box:SetPoint('BOTTOMRIGHT', -20, 20)

  -- Anonymous ScrollFrame (avoid reusing a global name that can cause duplicate/overlapped content)
  local scroll = CreateFrame('ScrollFrame', nil, box, 'UIPanelScrollFrameTemplate')
  scroll:SetPoint('TOPLEFT', 10, -10)
  scroll:SetPoint('BOTTOMRIGHT', -30, 10)

  local content = CreateFrame('Frame', nil, scroll)
  content:SetSize(1,1)
  scroll:SetScrollChild(content)

  parent.syncContent = content
  parent.syncScroll  = scroll

  local function refresh()
    local c = parent.syncContent
    -- Clear previous lines completely to prevent any visual overlap
    for _,child in ipairs({c:GetChildren()}) do child:Hide(); child:SetParent(nil) end

    -- Gather SYNC logs and render NEWEST at the TOP (top-down, newest-first)
    local logs = Log:GetAll({cat='SYNC'})
    local lastN = 100
    local startIdx = math.max(1, #logs - lastN + 1)

    local y = -2
    for i = #logs, startIdx, -1 do
      local e = logs[i]
      local line = string.format('|cffaaaaaa%s|r |cff00ff00[%s]|r %s', date('%H:%M:%S', e.ts), e.level, e.msg)
      local fs = c:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
      fs:SetPoint('TOPLEFT', 6, y)
      fs:SetJustifyH('LEFT')
      fs:SetText(line)
      y = y - 14
    end

    c:SetHeight(-y + 10)

    -- Ensure the view is scrolled to the top so the newest entries (now at top) are immediately visible
    if parent.syncScroll then parent.syncScroll:SetVerticalScroll(0) end
  end

  parent.SyncRefresh = refresh
  refresh()

  -- Register once per parent to avoid multiple refresh triggers
  if not parent._sync_subscribed then
    Log:Register(function(e)
      if e.cat == 'SYNC' and parent.SyncRefresh then parent:SyncRefresh() end
    end)
    parent._sync_subscribed = true
  end
