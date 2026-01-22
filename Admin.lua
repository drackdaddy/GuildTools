local GT = GuildTools
local U = GT.Utils
local Log = GT.Log
GT.Admin = GT.Admin or {}
local A = GT.Admin

function A:OnInit() end

function A:BuildUI(parent)
  local p=CreateFrame('Frame', nil, parent) p:SetAllPoints(true) A.parent=p
  local title=p:CreateFontString(nil,'OVERLAY','GameFontNormalLarge') title:SetPoint('TOPLEFT',20,-20) title:SetText('Administration & Permissions')
  local function row(lbl,key,y)
    local t=p:CreateFontString(nil,'OVERLAY','GameFontHighlight') t:SetPoint('TOPLEFT',20,y) t:SetText(lbl)
    local edit=CreateFrame('EditBox', nil, p, 'InputBoxTemplate') edit:SetSize(40,24) edit:SetPoint('LEFT', t, 'RIGHT', 10, 0) edit:SetNumeric(true) edit:SetNumber(GT.db.permissions[key] or 1)
    local save=CreateFrame('Button', nil, p, 'UIPanelButtonTemplate') save:SetSize(80,24) save:SetPoint('LEFT', edit, 'RIGHT', 6, 0) save:SetText('Save')
    save:SetScript('OnClick', function() if not U:HasPermission(GT.db.permissions.adminMinRank) then UIErrorsFrame:AddMessage('Only Admin rank can change permissions',1,0,0) return end GT.db.permissions[key]=edit:GetNumber() GT.db.dataVersion=(GT.db.dataVersion or 1)+1 if GT.Comm then GT.Comm:BroadcastFull() end end)
  end
  row('Minimum rank to administer Raids (0=GM):','raidsMinRank',-60)
  row('Minimum rank to administer Bank requests:','bankMinRank',-100)
  row('Minimum rank considered Admin (can sync/answer):','adminMinRank',-140)

  local dbg = CreateFrame('CheckButton', nil, p, 'ChatConfigCheckButtonTemplate') dbg:SetPoint('TOPLEFT', 20, -200) dbg.Text:SetText('Enable Debug Logging') dbg:SetChecked(GT.db.debug and true or false)
  dbg:SetScript('OnClick', function(self) GT.db.debug = self:GetChecked() and true or false if Log then Log:Add('INFO','ADMIN','Debug logging set to '..tostring(GT.db.debug)) end if GT.Debug and GT.Debug.Instrument then GT.Debug:Instrument() end end)

  local info=p:CreateFontString(nil,'OVERLAY','GameFontDisable') info:SetPoint('TOPLEFT',20,-240) info:SetWidth(820) info:SetJustifyH('LEFT') info:SetText('Rank index is from GetGuildInfo("player"): 0 = Guild Master, 1 = next rank, etc.')
end