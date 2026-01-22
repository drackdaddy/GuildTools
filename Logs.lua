
local GT = GuildTools
local Log = GT.Log
GT.Logs = GT.Logs or {}
local UI = GT.Logs
UI._logSubscribed = UI._logSubscribed or false
UI._syncSubscribed = UI._syncSubscribed or false
UI._syncWidgets = UI._syncWidgets or {}
local function addRow(parent, y, text)
  local fs = parent:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  fs:SetPoint('TOPLEFT', 6, y)
  fs:SetJustifyH('LEFT')
  fs:SetWordWrap(false)
  fs:SetText(text)
  return fs
end
function UI:BuildUI(parent)
  local p = CreateFrame('Frame', nil, parent)
  p:SetAllPoints(true)
  local title = p:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
  title:SetPoint('TOPLEFT',20,-20)
  title:SetText('Event Log')
  -- Sync Now button moved here from former Sync tab
  local syncBtn = CreateFrame('Button', nil, p, 'UIPanelButtonTemplate')
  syncBtn:SetSize(120,22)
  syncBtn:SetPoint('LEFT', title, 'RIGHT', 12, 0)
  syncBtn:SetText('Sync Now')
  syncBtn:SetScript('OnClick', function()
    if GT.Comm and GT.Comm.RequestSync then GT.Comm:RequestSync('MANUAL') end
  end)
  local clear = CreateFrame('Button', nil, p, 'UIPanelButtonTemplate')
  clear:SetSize(100,22)
  clear:SetPoint('TOPRIGHT', -20, -20)
  clear:SetText('Clear')
  clear:SetScript('OnClick', function()
    if GT.db and GT.db.logs then wipe(GT.db.logs) end
    UI:Refresh()
  end)
  local list = CreateFrame('Frame', nil, p, 'InsetFrameTemplate3')
  list:SetPoint('TOPLEFT', 20, -60)
  list:SetPoint('BOTTOMRIGHT', -20, 20)
  local scroll = CreateFrame('ScrollFrame', nil, list, 'UIPanelScrollFrameTemplate')
  scroll:SetPoint('TOPLEFT', 10, -10)
  scroll:SetPoint('BOTTOMRIGHT', -30, 10)
  p.scroll = scroll
  p.content = nil
  UI.parent = p
  UI:Refresh()
  if not UI._logSubscribed then
    Log:Register(function()
      if UI.parent and UI.parent:IsShown() then UI:Refresh(true) end
    end)
    UI._logSubscribed = true
  end
end
local function RebuildEventLogContent(p)
  if not p or not p.scroll then return end
  local old = p.content
  if old then
    for _,child in ipairs({old:GetChildren()}) do child:Hide(); child:SetParent(nil) end
    old:Hide()
    old:SetParent(nil)
  end
  local content = CreateFrame('Frame', nil, p.scroll)
  content:SetSize(1,1)
  content:SetFrameLevel((p:GetFrameLevel() or 0) + 2)
  p.scroll:SetScrollChild(content)
  p.content = content
  local logs = Log:GetAll()
  local lastN = 300
  local startI = math.max(1, #logs - lastN + 1)
  local y = -2
  for i = #logs, startI, -1 do
    local e = logs[i]
    local line = string.format('|cffaaaaaa%s|r |cff00ff00[%s]|r |cffffff00[%s]|r %s',
      date('%H:%M:%S', e.ts), e.level, e.cat, e.msg)
    addRow(content, y, line)
    y = y - 14
  end
  content:SetHeight(-y + 10)
  if p.scroll.UpdateScrollChildRect then p.scroll:UpdateScrollChildRect() end
  p.scroll:SetVerticalScroll(0)
end
function UI:Refresh(_appendOnly)
  if not UI.parent or not UI.parent.scroll then return end
  RebuildEventLogContent(UI.parent)
end
-- Keep the Sync widget helpers (unused now) for potential future use
local function RefreshSyncWidget(widget)
  if not widget or not widget.syncScroll or not widget.box then return end
  local oldContent = widget.syncContent
  if oldContent then
    for _,child in ipairs({oldContent:GetChildren()}) do child:Hide(); child:SetParent(nil) end
    oldContent:Hide(); oldContent:SetParent(nil)
  end
  local content = CreateFrame('Frame', nil, widget.syncScroll)
  content:SetSize(1,1)
  content:SetFrameLevel(widget.box:GetFrameLevel() + 1)
  widget.syncScroll:SetScrollChild(content)
  widget.syncContent = content
  local logs = Log:GetAll({cat='SYNC'})
  local lastN = 100
  local startI = math.max(1, #logs - lastN + 1)
  local y = -2
  for i = #logs, startI, -1 do
    local e = logs[i]
    local line = string.format('|cffaaaaaa%s|r |cff00ff00[%s]|r %s',
      date('%H:%M:%S', e.ts), e.level, e.msg)
    addRow(content, y, line)
    y = y - 14
  end
  content:SetHeight(-y + 10)
  widget.syncScroll:UpdateScrollChildRect()
  widget.syncScroll:SetVerticalScroll(0)
end
function UI:BuildSyncWidget(parent)
  local box = CreateFrame('Frame', nil, parent, 'InsetFrameTemplate3')
  box:SetPoint('TOPLEFT', 20, -90)
  box:SetPoint('BOTTOMRIGHT', -20, 20)
  local scroll = CreateFrame('ScrollFrame', nil, box, 'UIPanelScrollFrameTemplate')
  scroll:SetPoint('TOPLEFT', 10, -10)
  scroll:SetPoint('BOTTOMRIGHT', -30, 10)
  parent.box = box
  parent.syncScroll = scroll
  parent.syncContent = nil
  UI._syncWidgets[parent] = true
  parent:HookScript('OnHide', function() UI._syncWidgets[parent] = nil end)
  RefreshSyncWidget(parent)
  if not UI._syncSubscribed then
    Log:Register(function(e)
      if e and e.cat ~= 'SYNC' then return end
      for frame in pairs(UI._syncWidgets) do if frame and frame:IsShown() then RefreshSyncWidget(frame) end end
    end)
    UI._syncSubscribed = true
  end
end
