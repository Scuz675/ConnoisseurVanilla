-- ConnoisseurVanilla (Turtle WoW 1.12)
-- FINAL SMART + LEVEL-AWARE:
--   * Auto-detects Food, Drink, Health Potions, Mana Potions via tooltip (no DB maintenance)
--   * Option B: Prefer "Well Fed" foods when buff is missing
--   * LEVEL CHECK: skips items that require a higher level than the player
--   * Bandages keyword scan ("Bandage")
--   * No minimap button; hardcoded macro icons via macro icon list (iconIndex), per Turtle wiki

CCV_Settings = CCV_Settings or { autoUpdate=true, debug=false }
CCV_Ignore = CCV_Ignore or {}

local function msg(s) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffCCV|r "..tostring(s)) end

local function dmsg(s)
  if CCV_Settings and CCV_Settings.debug then msg(s) end
end


local CCV_Macros = { food="Food", water="Water", bandage="Bandage", hpotion="Health Potion", mpotion="Mana Potion" }

local CCV_IconTextureName = {
  bandage="Spell_Holy_SealOfSacrifice",
  food="Spell_Misc_Food",
  water="Spell_Misc_Drink",
  hpotion="Spell_Nature_Strength",
  mpotion="Spell_Misc_ConjureManaJewel",
}

local CCV_WellFedNames = {
  ["Well Fed"]=true, ["Bien nourri"]=true, ["Wohlgenährt"]=true, ["Bien alimentado"]=true, ["Ben nutrito"]=true,
  ["Хорошо накормлен"]=true, ["잘 먹음"]=true, ["吃得好"]=true, ["吃飽喝足"]=true,
}

local CCV_Tip = CreateFrame("GameTooltip","CCV_ScanTip",UIParent,"GameTooltipTemplate")
CCV_Tip:SetOwner(UIParent,"ANCHOR_NONE")

local function TipLine(i)
  local fs = _G["CCV_ScanTipTextLeft"..i]
  return fs and fs:GetText() or nil
end

local function SafeItemNameFromBag(bag, slot)
  CCV_Tip:ClearLines()
  CCV_Tip:SetBagItem(bag, slot)
  CCV_Tip:Show()
  local name = TipLine(1)
  return name or "?"
end

local function ParseNum(s)
  if not s then return nil end
  local n = tonumber(s)
  if n then return n end
  s = string.gsub(s, ",", "")
  return tonumber(s)
end

local function PlayerHasWellFed()
  for i=1,32 do
    if not UnitBuff("player",i) then break end
    CCV_Tip:ClearLines()
    CCV_Tip:SetPlayerBuff(i)
    local t = TipLine(1)
    if t and CCV_WellFedNames[t] then return true end
  end
  return false
end

-- Patterns (string.find captures)
local PAT_RESTORE_HEALTH_SINGLE = "([%d%.]+)%s+health"
local PAT_RESTORE_HEALTH_RANGE  = "([%d%.]+)%s+to%s+([%d%.]+)%s+health"
local PAT_RESTORE_MANA_SINGLE   = "([%d%.]+)%s+mana"
local PAT_RESTORE_MANA_RANGE    = "([%d%.]+)%s+to%s+([%d%.]+)%s+mana"
local PAT_REQ_LEVEL             = "Requires%s+Level%s+(%d+)"

local function AvgRange(a,b)
  if not a or not b then return nil end
  return (a+b)/2
end

local function GetRequiredLevelFromTip()
  for i=2,12 do
    local line = TipLine(i)
    if not line then break end
    local _,_,lvl = string.find(line, PAT_REQ_LEVEL)
    if lvl then return tonumber(lvl) end
  end
  return nil
end

local function ClassifyByTooltip(bag, slot)
  CCV_Tip:ClearLines()
  CCV_Tip:SetBagItem(bag, slot)
  CCV_Tip:Show()

  local reqLevel = GetRequiredLevelFromTip()

  local name = TipLine(1)
  local lname = name and string.lower(name) or nil
  local isPotion = (lname and string.find(lname, "potion", 1, true)) and true or false

  local restoresHealth, restoresMana = nil, nil
  local wellFed = false

  for i=2,12 do
    local line = TipLine(i)
    if not line then break end

    if not restoresHealth then
      local _,_,a,b = string.find(line, PAT_RESTORE_HEALTH_RANGE)
      if a and b then
        restoresHealth = AvgRange(ParseNum(a), ParseNum(b))
      else
        local _,_,h = string.find(line, PAT_RESTORE_HEALTH_SINGLE)
        if h then restoresHealth = ParseNum(h) end
      end
    end

    if not restoresMana then
      local _,_,a,b = string.find(line, PAT_RESTORE_MANA_RANGE)
      if a and b then
        restoresMana = AvgRange(ParseNum(a), ParseNum(b))
      else
        local _,_,m = string.find(line, PAT_RESTORE_MANA_SINGLE)
        if m then restoresMana = ParseNum(m) end
      end
    end

    if string.find(line, "Well Fed", 1, true) then wellFed = true end
  end

  -- Fallback: some Turtle tooltips wrap or prefix text; try looser "number health/mana" scan
  if not restoresHealth or not restoresMana then
    for i=2,12 do
      local line = TipLine(i)
      if not line then break end
      if not restoresHealth then
        local _,_,h = string.find(line, "([%d%.]+)%s+health")
        if h then restoresHealth = ParseNum(h) end
      end
      if not restoresMana then
        local _,_,m = string.find(line, "([%d%.]+)%s+mana")
        if m then restoresMana = ParseNum(m) end
      end
    end
  end

  -- Potions only if name contains "Potion" (avoids food/drink false positives)
  if isPotion then
    if restoresHealth and (not restoresMana or restoresMana==0) then
      return "hpotion", restoresHealth, false, reqLevel
    end
    if restoresMana then
      return "mpotion", restoresMana, false, reqLevel
    end
  end

  -- Drink (mana restore)
  if restoresMana then
    return "water", restoresMana, false, reqLevel
  end

  -- Food (health restore)
  if restoresHealth and not restoresMana then
    return "food", restoresHealth, wellFed, reqLevel
  end

  return nil, nil, false, reqLevel
end

local function LooksLikeBandage(bag, slot)
  CCV_Tip:ClearLines()
  CCV_Tip:SetBagItem(bag, slot)
  CCV_Tip:Show()
  local name = TipLine(1)
  if not name then return false, nil end
  local reqLevel = GetRequiredLevelFromTip()
  return string.find(name, "Bandage", 1, true) and true or false, reqLevel
end

local function GetItemIDFromLink(link)
  if not link then return nil end
  local _,_,id = string.find(link,"item:(%d+)")
  return id and tonumber(id) or nil
end

local CCV_ResolvedIconIndex = {}
local function ResolveIconIndex(kind)
  if CCV_ResolvedIconIndex[kind] then return CCV_ResolvedIconIndex[kind] end
  local desired = CCV_IconTextureName[kind]
  for i=1,GetNumMacroIcons() do
    local tex = GetMacroIconInfo(i)
    if tex and string.find(tex, desired, 1, true) then
      CCV_ResolvedIconIndex[kind]=i
      return i
    end
  end
  CCV_ResolvedIconIndex[kind]=1
  return 1
end

local function FoodScore(base, isWellFedFood, playerHasWellFed)
  if isWellFedFood and not playerHasWellFed then
    return base + 1000000
  end
  return base
end

local function IsUsableByLevel(reqLevel, playerLevel)
  if not reqLevel then return true end
  return reqLevel <= playerLevel
end



local function ScanBags()
  local hasWellFed = PlayerHasWellFed()
  local playerLevel = UnitLevel("player") or 1
  local best = { food={score=-1}, water={score=-1}, bandage={score=-1}, hpotion={score=-1}, mpotion={score=-1} }

  for bag=0,4 do
    local slots = GetContainerNumSlots(bag) or 0
    for slot=1,slots do
      local link = GetContainerItemLink(bag,slot)
      local id = GetItemIDFromLink(link)

      if id and not CCV_Ignore[id] then
        local entry = (CCV_DATA and CCV_DATA.items and CCV_DATA.items[id]) or nil
        local kind, score, wellFed, reqLevel = nil, nil, false, nil

        if entry then
          kind = entry.kind
          score = tonumber(entry.score) or 0
          wellFed = entry.wellFed and true or false
          -- If you want to override required level, add entry.reqLevel
          reqLevel = entry.reqLevel
        else
          kind, score, wellFed, reqLevel = ClassifyByTooltip(bag, slot)
          if id then
            local _,_,_,_,_,_,_,_,_,_,minLevel = GetItemInfo(id)
            if minLevel and minLevel>0 then reqLevel = minLevel end
          end
          if not kind then
            local isBandage
            isBandage, reqLevel = LooksLikeBandage(bag, slot)
            if isBandage then kind, score, wellFed = "bandage", 1, false end
          end
        end

        if kind and best[kind] and score and IsUsableByLevel(reqLevel, playerLevel) then
          local s = score
          if kind=="food" then s = FoodScore(score, wellFed, hasWellFed) end
          if s > best[kind].score then
            best[kind] = { id=id, bag=bag, slot=slot, score=s }
          end
        end
      end
    end
  end

  return best
end

local function DebugReportInventory()
  local best = ScanBags()
  local function report(kind, label)
    local pick = best[kind]
    if pick and pick.bag then
      local nm = SafeItemNameFromBag(pick.bag, pick.slot)
      msg(label..": "..nm.." (bag "..pick.bag.." slot "..pick.slot..")")
    else
      msg(label..": (none)")
    end
  end
  msg("Detected consumables (best usable):")
  report("food", "Food")
  report("water", "Drink")
  report("hpotion", "Health Potion")
  report("mpotion", "Mana Potion")
end


function CCV_Use(kind)
  local best = ScanBags()
  local pick = best[kind]
  if not pick or not pick.id then msg("No "..tostring(kind).." found.") return end

  UseContainerItem(pick.bag, pick.slot)

  if kind=="bandage" then
    if UnitExists("target") and UnitIsFriend("player","target") then SpellTargetUnit("target") else SpellTargetUnit("player") end
  end
end

local function SetMacro(kind, body)
  local name = CCV_Macros[kind]
  local iconIndex = ResolveIconIndex(kind) or 1
  local idx = GetMacroIndexByName(name)
  if idx==0 then
    CreateMacro(name, iconIndex, body, 1)
    idx = GetMacroIndexByName(name)
  end
  EditMacro(idx, name, iconIndex, body, 1)
end

local function UpdateMacros()
  SetMacro("food","/run CCV_Use(\"food\")")
  SetMacro("water","/run CCV_Use(\"water\")")
  SetMacro("bandage","/run CCV_Use(\"bandage\")")
  SetMacro("hpotion","/run CCV_Use(\"hpotion\")")
  SetMacro("mpotion","/run CCV_Use(\"mpotion\")")
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE")
f:SetScript("OnEvent", function()
  if CCV_Settings.autoUpdate then UpdateMacros() end
  if event=="PLAYER_LOGIN" then DebugReportInventory() end
end)

SLASH_CCV1="/ccv"
SlashCmdList["CCV"]=function(m)
  m = m and string.lower(m) or ""
  if m=="update" then
    UpdateMacros()
    msg("Macros updated.")
  elseif m=="wellfed" then
    msg("Well Fed: "..tostring(PlayerHasWellFed()))
  elseif m=="report" then
    DebugReportInventory()
  else
    msg("Commands: /ccv update | /ccv wellfed | /ccv report")
  end
end
