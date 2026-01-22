
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
  fs:SetWordWrap(false)            -- single-line; prevents wrap-induced overlap
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
