local ADDON = "HowToDodge"
local HTD = HowToDodge or {}
HowToDodge = HTD

HTD.bosses = (type(HowToDodgePlans) == "table" and HowToDodgePlans) or {}
if #HTD.bosses == 0 then
  print("|cffff7f00["..ADDON.."]|r Keine Pläne gefunden. Pflege data\\HTD_Plans.lua.")
end

HTD.defaultScale = 0.75
HTD.minScale     = 0.4
HTD.maxScale     = 2.0
HTD.zoomStep     = 0.05

local f = CreateFrame("Frame", "HTD_RaidPlan", UIParent, "BackdropTemplate")
f:SetSize(960, 560)
f:SetPoint("CENTER")
f:EnableMouse(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:Hide()

f:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 32, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
f:SetBackdropColor(0,0,0,0.92)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 12, -10)
title:SetText("HowToDodge – Raidplan")

local btnClose = CreateFrame("Button", nil, f, "UIPanelCloseButton")
btnClose:SetPoint("TOPRIGHT", 0, 0)

local scroll = CreateFrame("ScrollFrame", "HTD_Scroll", f, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 12, -40)
scroll:SetPoint("BOTTOMRIGHT", -12, 48)

local content = CreateFrame("Frame")
scroll:SetScrollChild(content)
content:EnableMouse(true)

local tex = content:CreateTexture(nil, "ARTWORK")
tex:SetPoint("TOPLEFT")
tex:SetTexture(nil)

local bottom = CreateFrame("Frame", nil, f)
bottom:SetPoint("BOTTOMLEFT", 12, 12)
bottom:SetPoint("BOTTOMRIGHT", -12, 12)
bottom:SetHeight(28)

local ddBoss = CreateFrame("Frame", "HTD_DDBoss", bottom, "UIDropDownMenuTemplate")
ddBoss:SetPoint("LEFT", 0, 0)
UIDropDownMenu_SetWidth(ddBoss, 220)

local ddPage = CreateFrame("Frame", "HTD_DDPage", bottom, "UIDropDownMenuTemplate")
ddPage:SetPoint("LEFT", ddBoss, "RIGHT", -10, 0)
UIDropDownMenu_SetWidth(ddPage, 140)

local btnPrev = CreateFrame("Button", nil, bottom, "UIPanelButtonTemplate")
btnPrev:SetText("⟵ Prev")
btnPrev:SetWidth(90)
btnPrev:SetPoint("LEFT", ddPage, "RIGHT", -10, 0)

local btnNext = CreateFrame("Button", nil, bottom, "UIPanelButtonTemplate")
btnNext:SetText("Next ⟶")
btnNext:SetWidth(90)
btnNext:SetPoint("LEFT", btnPrev, "RIGHT", 6, 0)

local btnFit = CreateFrame("Button", nil, bottom, "UIPanelButtonTemplate")
btnFit:SetText("Fit")
btnFit:SetWidth(60)
btnFit:SetPoint("LEFT", btnNext, "RIGHT", 6, 0)

local zoomLabel = bottom:CreateFontString(nil, "OVERLAY", "GameFontNormal")
zoomLabel:SetPoint("LEFT", btnFit, "RIGHT", 10, 0)
zoomLabel:SetText("Zoom: 75%")
local function updateZoomLabel()
  zoomLabel:SetText(("Zoom: %d%%"):format(math.floor((content:GetScale() or 1) * 100 + 0.5)))
end

local currentScale = HTD.defaultScale
local function applyScale(scale)
  currentScale = math.min(HTD.maxScale, math.max(HTD.minScale, scale))
  content:SetScale(currentScale)
  updateZoomLabel()
end
applyScale(currentScale)

local isPanning = false
local panStartX, panStartY, startH, startV
content:SetScript("OnMouseDown", function(_, btn)
  if btn == "RightButton" then
    isPanning = true
    panStartX, panStartY = GetCursorPosition()
    startH = scroll:GetHorizontalScroll()
    startV = scroll:GetVerticalScroll()
  end
end)
content:SetScript("OnMouseUp", function(_, btn)
  if btn == "RightButton" then
    isPanning = false
  end
end)
content:SetScript("OnUpdate", function()
  if not isPanning then return end
  local x, y = GetCursorPosition()
  local dx = (panStartX - x) / UIParent:GetEffectiveScale()
  local dy = (y - panStartY) / UIParent:GetEffectiveScale()
  scroll:SetHorizontalScroll(startH + dx)
  scroll:SetVerticalScroll(startV + dy)
end)

content:EnableMouseWheel(true)
content:SetScript("OnMouseWheel", function(_, delta)
  local oldScale = currentScale
  local newScale = oldScale + (delta > 0 and HTD.zoomStep or -HTD.zoomStep)

  local cursorX, cursorY = GetCursorPosition()
  cursorX = cursorX / UIParent:GetEffectiveScale()
  cursorY = cursorY / UIParent:GetEffectiveScale()
  local sLeft, sTop = scroll:GetLeft(), scroll:GetTop()
  local relX = (cursorX - sLeft) + scroll:GetHorizontalScroll()
  local relY = (sTop - cursorY) + scroll:GetVerticalScroll()

  applyScale(newScale)

  local factor = currentScale / oldScale
  scroll:SetHorizontalScroll(relX * factor - (cursorX - sLeft))
  scroll:SetVerticalScroll(relY * factor - (sTop - cursorY))
end)

local currentBoss = 1
local currentPage = 1

local function pageCount(bi)
  local b = HTD.bosses[bi]
  return (b and b.pages) and #b.pages or 0
end

local function showByIndex(bi, pi)
  if bi < 1 or bi > #HTD.bosses then return end
  local b = HTD.bosses[bi]; if not b.pages or #b.pages == 0 then return end
  if pi < 1 then pi = 1 end
  if pi > #b.pages then pi = #b.pages end

  currentBoss = bi
  currentPage = pi
  local page = b.pages[pi]

  local w = tonumber(page.width) or 1024
  local h = tonumber(page.height) or 1024

  tex:SetSize(w, h)
  content:SetSize(w, h)
  tex:SetTexture(page.file)

  UIDropDownMenu_SetText(ddBoss, b.label)
  UIDropDownMenu_SetText(ddPage, (page.label or ("Seite "..pi)) .. ("  ("..pi.."/"..#b.pages..")"))
end

UIDropDownMenu_Initialize(ddBoss, function(self, level)
  for i, boss in ipairs(HTD.bosses) do
    local info = UIDropDownMenu_CreateInfo()
    info.text = boss.label
    info.func = function()
      showByIndex(i, 1)
      CloseDropDownMenus()
    end
    info.checked = (i == currentBoss)
    UIDropDownMenu_AddButton(info, level)
  end
end)

local function refreshPageDropdown()
  UIDropDownMenu_Initialize(ddPage, function(self, level)
    local b = HTD.bosses[currentBoss]
    if not b or not b.pages then return end
    for i, p in ipairs(b.pages) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = (p.label or ("Seite "..i))
      info.func = function()
        showByIndex(currentBoss, i)
        CloseDropDownMenus()
      end
      info.checked = (i == currentPage)
      UIDropDownMenu_AddButton(info, level)
    end
  end)
end

btnPrev:SetScript("OnClick", function()
  local bPages = pageCount(currentBoss); if bPages == 0 then return end
  local p = currentPage - 1
  local b = currentBoss
  if p < 1 then
    b = currentBoss - 1
    if b < 1 then b = #HTD.bosses end
    p = pageCount(b)
  end
  showByIndex(b, p)
  refreshPageDropdown()
end)

btnNext:SetScript("OnClick", function()
  local bPages = pageCount(currentBoss); if bPages == 0 then return end
  local p = currentPage + 1
  local b = currentBoss
  if p > bPages then
    b = currentBoss + 1
    if b > #HTD.bosses then b = 1 end
    p = 1
  end
  showByIndex(b, p)
  refreshPageDropdown()
end)

btnFit:SetScript("OnClick", function()
  local viewW = scroll:GetWidth()
  local viewH = scroll:GetHeight()
  local imgW, imgH = tex:GetSize()
  local scaleW = viewW / imgW
  local scaleH = viewH / imgH
  local fit = math.min(scaleW, scaleH)
  applyScale(math.max(HTD.minScale, math.min(HTD.maxScale, fit)))
  scroll:SetHorizontalScroll(0)
  scroll:SetVerticalScroll(0)
end)

function HTD.Show()
  if not f:IsShown() then f:Show() end
  if not f._initialized then
    f._initialized = true
    showByIndex(currentBoss, currentPage)
    refreshPageDropdown()
    applyScale(HTD.defaultScale)
  end
end

function HTD.Toggle()
  if f:IsShown() then f:Hide() else HTD.Show() end
end

function HTD.OpenPlan(bossKey, page)
  for bi, b in ipairs(HTD.bosses) do
    if b.key == bossKey then
      local p = tonumber(page) or 1
      p = math.max(1, math.min(p, pageCount(bi)))
      showByIndex(bi, p)
      refreshPageDropdown()
      HTD.Show()
      return
    end
  end
  print("|cffff7f00"..ADDON.."|r Boss-Key nicht gefunden:", bossKey)
end

SLASH_HTD1 = "/howtododge"
SLASH_HTD2 = "/htd"
SlashCmdList["HTD"] = function(msg)
  msg = msg and msg:lower() or ""
  if msg == "" or msg == "plan" or msg == "plans" then
    HTD.Show()
    print("|cffffd100HowToDodge|r Befehle: /htd show  /htd next  /htd prev  /htd fit  /htd open <bossKey> [page]")
    return
  end
  if msg == "show" then
    HTD.Show()
  elseif msg == "next" then
    btnNext:Click()
  elseif msg == "prev" then
    btnPrev:Click()
  elseif msg == "fit" then
    btnFit:Click()
  else
    local key, p = msg:match("^open%s+([%w_%-]+)%s*(%d*)$")
    if key then
      HTD.OpenPlan(key, p ~= "" and p or nil)
    else
      print("|cffff7f00Unbekannter Befehl.|r  /htd show | next | prev | fit | open <bossKey> [page]")
    end
  end
end