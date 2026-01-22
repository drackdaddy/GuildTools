local GT = GuildTools
local Log = GT.Log

GT.Logs = GT.Logs or {}
local UI = GT.Logs

-- Registry so we subscribe once and refresh any visible Sync widget(s)
UI._syncWidgets    = UI._syncWidgets    or {}
UI._syncSubscribed = UI._syncSubscribed or false

local function addRow(parent, y, text)
  local fs = parent:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
  fs:SetPoint('TOPLEFT', 6, y)
  fs:SetJustifyH('LEFT')
  fs:SetWordWrap(false)            -- ensure single-line; prevents variable wrapping/overlap
  fs:SetText(text)
  return fs
end

-- =========================
-- Logs tab (unchanged flow)
-- =========================
function UI:BuildUI(parent)
  local p = CreateFrame('Frame', nil, parent) p:SetAllPoints(true)

  local title = p:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
  title:SetPoint('TOPLEFT',20,-20)
  title:SetText('Event Log')

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

  local content = CreateFrame('Frame', nil, scroll)
  content:SetSize(1,1)
  scroll:SetScrollChild(content)
  p.content = content

  UI.parent = p
  UI:Refresh()

  if not UI._logSubscribed then
    Log:Register(function()
      if UI.parent then UI:Refresh(true) end
    end)
    UI._logSubscribed = true
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
    local line = string.format('|cffaaaaaa%s|r |cff00ff00[%s]|r |cffffff00[%s]|r %s',
      date('%H:%M:%S', e.ts), e.level, e.cat, e.msg)
    addRow(content, y, line)
    y = y - 14
  end

  content:SetHeight(-y + 10)
end

-- ===================================
-- Sync widget (top-down, no overlap)
-- ===================================

-- Internal: render a Sync widget by replacing the content frame each time.
local function RefreshSyncWidget(widget)
  if not widget or not widget.syncScroll then return end

  -- DESTROY the previous content and create a fresh one
  local oldContent = widget.syncContent
  if oldContent then
    for _,child in ipairs({oldContent:GetChildren()}) do child:Hide(); child:SetParent(nil) end
    oldContent:Hide()
    oldContent:SetParent(nil)
  end

  local content = CreateFrame('Frame', nil, widget.syncScroll)
  content:SetSize(1,1)
  widget.syncScroll:SetScrollChild(content)
  widget.syncContent = content

  -- Gather logs and place NEWEST at TOP (top-down)
  local logs = Log:GetAll({cat='SYNC'})
  local lastN = 100
  local startIdx = math.max(1, #logs - lastN + 1)

  local y = -2
  for i = #logs, startIdx, -1 do
    local e = logs[i]
    local line = string.format('|cffaaaaaa%s|r |cff00ff00[%s]|r %s',
      date('%H:%M:%S', e.ts), e.level, e.msg)
    addRow(content, y, line)
    y = y - 14
  end

  content:SetHeight(-y + 10)

  -- Show TOP (newest) right away
  widget.syncScroll:SetVerticalScroll(0)
end

function UI:BuildSyncWidget(parent)
  -- Lowered to avoid overlapping the "Sync Now" button and its helper text
  local box = CreateFrame('Frame', nil, parent, 'InsetFrameTemplate3')
  box:SetPoint('TOPLEFT', 20, -90)
  box:SetPoint('BOTTOMRIGHT', -20, 20)

  local scroll = CreateFrame('ScrollFrame', nil, box, 'UIPanelScrollFrameTemplate')
  scroll:SetPoint('TOPLEFT', 10, -10)
  scroll:SetPoint('BOTTOMRIGHT', -30, 10)

  parent.syncScroll = scroll
  parent.syncContent = nil -- will be created in RefreshSyncWidget

  -- Track this widget; remove when hidden to avoid stale references
  UI._syncWidgets[parent] = true
  parent:HookScript('OnHide', function() UI._syncWidgets[parent] = nil end)

  RefreshSyncWidget(parent)

  -- Single global subscription; refresh all visible widgets on SYNC entry
  if not UI._syncSubscribed then
    Log:Register(function(e)
      if e and e.cat ~= 'SYNC' then return end
      for frame in pairs(UI._syncWidgets) do
        if frame and frame:IsShown() then
          RefreshSyncWidget(frame)
        end
      end
    end)
    UI._syncSubscribed = true
  end
end
