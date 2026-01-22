local GT = GuildTools
local U = GT.Utils

GT.UI = {}
local UI = GT.UI

UI.TABS = { 'Calendar', 'Raids', 'Bank', 'Admin', 'Logs', 'Sync' }
UI.TAB_INDEX = { Calendar = 1, Raids = 2, Bank = 3, Admin = 4, Logs = 5, Sync = 6 }

function UI:Build()
  if UI.frame then return end
  local f = CreateFrame('Frame','GuildToolsFrame',UIParent,'BasicFrameTemplateWithInset')
  f:SetSize(900,600) f:SetPoint('CENTER') f:SetFrameStrata('DIALOG') f:SetToplevel(true) f:SetClampedToScreen(true) f:Hide()
  f:EnableMouse(true) f:SetMovable(true) f:RegisterForDrag('LeftButton') f:SetScript('OnDragStart', f.StartMoving) f:SetScript('OnDragStop', f.StopMovingOrSizing) f:SetScript('OnShow', function(self) self:Raise() end)
  f.title = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight') f.title:SetPoint('LEFT', f.TitleBg, 'LEFT', 6, 0) f.title:SetText('|cff48c9b0GuildTools|r')
  PanelTemplates_SetNumTabs(f, #UI.TABS) f.tabs = {}
  for i,name in ipairs(UI.TABS) do local tab = CreateFrame('Button', 'GuildToolsTab'..i, f, 'CharacterFrameTabButtonTemplate') tab:SetID(i) tab:SetText(name) if i == 1 then tab:SetPoint('TOPLEFT', f, 'TOPLEFT', 12, -28) else tab:SetPoint('LEFT', f.tabs[i-1], 'RIGHT', -14, 0) end tab:SetScript('OnClick', function(self) UI:SelectTab(self:GetID()) end) f.tabs[i] = tab end
  f.pages = {} for i,name in ipairs(UI.TABS) do local page = CreateFrame('Frame', nil, f) page:SetPoint('TOPLEFT', f, 'TOPLEFT', 12, -72) page:SetPoint('BOTTOMRIGHT', f, 'BOTTOMRIGHT', -12, 12) page:Hide() f.pages[i] = page end
  UI.frame = f
  if GT.Calendar and GT.Calendar.BuildUI then GT.Calendar:BuildUI(f.pages[UI.TAB_INDEX.Calendar]) end
  if GT.Raids and GT.Raids.BuildUI then GT.Raids:BuildUI(f.pages[UI.TAB_INDEX.Raids]) end
  if GT.Bank and GT.Bank.BuildUI then GT.Bank:BuildUI(f.pages[UI.TAB_INDEX.Bank]) end
  if GT.Admin and GT.Admin.BuildUI then GT.Admin:BuildUI(f.pages[UI.TAB_INDEX.Admin]) end
  if GT.Logs and GT.Logs.BuildUI then GT.Logs:BuildUI(f.pages[UI.TAB_INDEX.Logs]) end
  do
    local p = f.pages[UI.TAB_INDEX.Sync]
    local btn = CreateFrame('Button', nil, p, 'UIPanelButtonTemplate') btn:SetSize(140,24) btn:SetPoint('TOPLEFT', 20, -20) btn:SetText('Sync Now') btn:SetScript('OnClick', function() if GT.Comm and GT.Comm.RequestSync then GT.Comm:RequestSync('MANUAL') end end)
    local txt = p:CreateFontString(nil,'OVERLAY','GameFontHighlight') txt:SetPoint('TOPLEFT', btn, 'BOTTOMLEFT', 0, -10) txt:SetJustifyH('LEFT') txt:SetText('Auto-sync runs on login. Use this if you\'re missing events or permissions.')
    if GT.Logs and GT.Logs.BuildSyncWidget then GT.Logs:BuildSyncWidget(p) end
  end
  UI:SelectTab(UI.TAB_INDEX.Calendar)
end

function UI:SelectTab(i) local f = UI.frame for j=1,#UI.TABS do if j==i then f.pages[j]:Show(); PanelTemplates_SelectTab(f.tabs[j]) else f.pages[j]:Hide(); PanelTemplates_DeselectTab(f.tabs[j]) end end end
function UI:Toggle() if not UI.frame then return end if UI.frame:IsShown() then UI.frame:Hide() else UI.frame:Show() end end
function UI:RefreshAll() UI:RefreshRaids(); UI:RefreshBank(); if GT.Calendar and GT.Calendar.Refresh then GT.Calendar:Refresh() end end
function UI:RefreshRaids() if GT.Raids and GT.Raids.Refresh then GT.Raids:Refresh() end end
function UI:RefreshBank() if GT.Bank and GT.Bank.Refresh then GT.Bank:Refresh() end end