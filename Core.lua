-- ConnoisseurVanilla (Turtle WoW 1.12)
-- FINAL PRO BUILD
--  ✅ Auto-detects Food/Drink/Health Potions/Mana Potions via tooltip (Turtle-safe)
--  ✅ Prefers Well Fed foods when buff is missing
--  ✅ Skips items above your level
--  ✅ Combat-aware: Food->Health Potion in combat, Water->Mana Potion in combat
--  ✅ Smart potion sizing: picks the smallest potion that fits missing HP/MP (reduces waste)
--  ✅ Conjured preference toggle
--  ✅ Login report + /ccv report + /ccv dump

CCV_Settings = CCV_Settings or {
  autoUpdate = true,
  preferConjured = false,  -- if true: prefer conjured food/drink over vendor
  potionUseThreshold = 0.70, -- only use potion if below 70% HP/MP (or missing is big)
}
CCV_Ignore = CCV_Ignore or {}

local function msg(s) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffCCV|r "..tostring(s)) end

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

-- Tooltip scanner (Vanilla-safe)
local CCV_Tip = CreateFrame("GameTooltip","CCV_ScanTip",UIParent,"GameTooltipTemplate")
CCV_Tip:SetOwner(UIParent,"ANCHOR_NONE")

local function TipLine(i)
  local fs = _G["CCV_ScanTipTextLeft"..i]
  return fs and fs:GetText() or nil
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
    CCV_Tip:SetOwner(UIParent,"ANCHOR_NONE")
    CCV_Tip:SetPlayerBuff(i)
    CCV_Tip:Show()
    local t = TipLine(1)
    if t and CCV_WellFedNames[t] then return true end
  end
  return false
end

-- Patterns (string.find captures; allow "Use:" etc by matching numbers)
local PAT_RESTORE_HEALTH_RANGE  = "([%d%.]+)%s+to%s+([%d%.]+)%s+health"
local PAT_RESTORE_MANA_RANGE    = "([%d%.]+)%s+to%s+([%d%.]+)%s+mana"
local PAT_RESTORE_HEALTH_SINGLE = "([%d%.]+)%s+health"
local PAT_RESTORE_MANA_SINGLE   = "([%d%.]+)%s+mana"
local PAT_REQ_LEVEL             = "Requires%s+Level%s+(%d+)"

local function AvgRange(a,b)
  if not a or not b then return nil end
  return (a+b)/2
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

local function ScanTooltipBasics(bag, slot)
  CCV_Tip:ClearLines()
  CCV_Tip:SetOwner(UIParent,"ANCHOR_NONE")
  CCV_Tip:SetBagItem(bag, slot)
  CCV_Tip:Show()

  local name = TipLine(1)
  local reqLevel = nil
  local conjured = false

  local restoresHealth, restoresMana = nil, nil
  local wellFed = false

  for i=2,12 do
    local line = TipLine(i)
    if not line then break end

    if not reqLevel then
      local _,_,lvl = string.find(line, PAT_REQ_LEVEL)
      if lvl then reqLevel = tonumber(lvl) end
    end

    if string.find(line, "Conjured Item", 1, true) then
      conjured = true
    end

    if string.find(line, "Well Fed", 1, true) then
      wellFed = true
    end

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
  end

  -- Prefer minLevel from GetItemInfo if available
  local id = GetItemIDFromLink(GetContainerItemLink(bag,slot))
  if id then
    local _,_,_,_,_,_,_,_,_,_,minLevel = GetItemInfo(id)
    if minLevel and minLevel>0 then reqLevel = minLevel end
  end

  return name, reqLevel, conjured, restoresHealth, restoresMana, wellFed
end

local function IsUsableByLevel(reqLevel, playerLevel)
  if not reqLevel then return true end
  return reqLevel <= playerLevel
end

local function FoodScore(base, isWellFedFood, playerHasWellFed, conjured)
  local s = base
  if isWellFedFood and not playerHasWellFed then
    s = s + 1000000
  end
  if conjured then
    if CCV_Settings.preferConjured then
      s = s + 25
    else
      s = s - 25
    end
  end
  return s
end

local function InCombat()
  return UnitAffectingCombat and UnitAffectingCombat("player") or false
end

local function HPPercent()
  local hp = UnitHealth("player") or 0
  local hm = UnitHealthMax("player") or 1
  return hp / hm
end

local function MPPercent()
  local mp = UnitMana("player") or 0
  local mm = UnitManaMax("player") or 1
  return mp / mm
end

-- Gather all candidates for a kind with their restore scores (and other metadata)
local function GatherCandidates()
  local playerLevel = UnitLevel("player") or 1
  local hasWellFed = PlayerHasWellFed()

  local c = { food={}, water={}, hpotion={}, mpotion={}, bandage={} }

  for bag=0,4 do
    local slots = GetContainerNumSlots(bag) or 0
    for slot=1,slots do
      local link = GetContainerItemLink(bag,slot)
      local id = GetItemIDFromLink(link)
      if id and not CCV_Ignore[id] then
        local entry = (CCV_DATA and CCV_DATA.items and CCV_DATA.items[id]) or nil

        local kind, score, wellFed, reqLevel, conjured = nil, nil, false, nil, false

        if entry then
          kind = entry.kind
          score = tonumber(entry.score) or 0
          wellFed = entry.wellFed and true or false
          reqLevel = entry.reqLevel
          conjured = entry.conjured and true or false
        else
          local name, rl, cj, rh, rm, wf = ScanTooltipBasics(bag, slot)
          reqLevel = rl
          conjured = cj
          wellFed = wf
          local lname = name and string.lower(name) or ""
          local isPotion = (name and string.find(lname,"potion",1,true)) and true or false

          if isPotion then
            if rh and (not rm or rm==0) then
              kind, score = "hpotion", rh
            elseif rm then
              kind, score = "mpotion", rm
            end
          end

          if not kind then
            if rm then
              kind, score = "water", rm
            elseif rh and not rm then
              kind, score = "food", rh
            end
          end

          if not kind and name and string.find(name,"Bandage",1,true) then
            kind, score = "bandage", 1
          end
        end

        if kind and score and IsUsableByLevel(reqLevel, playerLevel) then
          if kind=="food" then
            score = FoodScore(score, wellFed, hasWellFed, conjured)
          end
          table.insert(c[kind], { id=id, bag=bag, slot=slot, score=score })
        end
      end
    end
  end

  return c
end

local function PickBest(list)
  local best = nil
  for i=1, table.getn(list) do
    local it = list[i]
    if not best or it.score > best.score then best = it end
  end
  return best
end

-- Pick smallest potion that still fits missing amount, else smallest above missing
local function PickPotionSmart(list, missing)
  if table.getn(list)==0 then return nil end
  -- sort ascending by score
  table.sort(list, function(a,b) return a.score < b.score end)

  local bestBelow = nil
  local bestAbove = nil

  for i=1, table.getn(list) do
    local it = list[i]
    if it.score <= missing then
      bestBelow = it -- keep largest <= missing (since sorted ascending, overwrite)
    else
      if not bestAbove then bestAbove = it end
    end
  end

  if bestBelow then return bestBelow end
  return bestAbove
end

local function ScanBest()
  local c = GatherCandidates()
  return {
    food    = PickBest(c.food),
    water   = PickBest(c.water),
    bandage = PickBest(c.bandage),
    hpotion = PickBest(c.hpotion),
    mpotion = PickBest(c.mpotion),
    _cands  = c,
  }
end

function CCV_Use(kind)
  -- Combat-aware remap:
  if kind=="food" and InCombat() then kind="hpotion" end
  if kind=="water" and InCombat() then kind="mpotion" end

  local best = ScanBest()
  local pick = best[kind]

  if kind=="hpotion" then
    local hp = UnitHealth("player") or 0
    local hm = UnitHealthMax("player") or 1
    local missing = hm - hp
    -- threshold check to avoid wasting
    if HPPercent() > (CCV_Settings.potionUseThreshold or 0.70) and missing < 400 then
      msg("HP too high for potion.")
      return
    end
    pick = PickPotionSmart(best._cands.hpotion, missing) or pick
  elseif kind=="mpotion" then
    local mp = UnitMana("player") or 0
    local mm = UnitManaMax("player") or 1
    local missing = mm - mp
    if MPPercent() > (CCV_Settings.potionUseThreshold or 0.70) and missing < 400 then
      msg("Mana too high for potion.")
      return
    end
    pick = PickPotionSmart(best._cands.mpotion, missing) or pick
  end

  if not pick or not pick.id then
    msg("No "..tostring(kind).." found.")
    return
  end

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

local function SafeItemNameFromBag(bag, slot)
  CCV_Tip:ClearLines()
  CCV_Tip:SetOwner(UIParent,"ANCHOR_NONE")
  CCV_Tip:SetBagItem(bag, slot)
  CCV_Tip:Show()
  local name = TipLine(1)
  return name or "?"
end

local function Report()
  local best = ScanBest()
  msg("Detected consumables (best usable):")
  local function report(kind, label)
    local pick = best[kind]
    if pick and pick.bag then
      local nm = SafeItemNameFromBag(pick.bag, pick.slot)
      msg(label..": "..nm)
    else
      msg(label..": (none)")
    end
  end
  report("food","Food")
  report("water","Drink")
  report("hpotion","Health Potion")
  report("mpotion","Mana Potion")
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE")
f:SetScript("OnEvent", function()
  if CCV_Settings.autoUpdate then UpdateMacros() end
  if event=="PLAYER_LOGIN" then Report() end
end)

SLASH_CCV1="/ccv"
SlashCmdList["CCV"]=function(m)
  m = m and string.lower(m) or ""
  if m=="update" then
    UpdateMacros()
    msg("Macros updated.")
  elseif m=="report" then
    Report()
  elseif m=="wellfed" then
    msg("Well Fed: "..tostring(PlayerHasWellFed()))
  elseif m=="conjured" then
    CCV_Settings.preferConjured = not CCV_Settings.preferConjured
    msg("Prefer Conjured: "..tostring(CCV_Settings.preferConjured))
    Report()
  elseif m=="dump" then
    CCV_Tip:ClearLines()
    CCV_Tip:SetOwner(UIParent,"ANCHOR_NONE")
    CCV_Tip:SetBagItem(0,1)
    CCV_Tip:Show()
    for i=1,8 do
      local t = TipLine(i)
      if t then msg("TIP "..i..": "..t) end
    end
  else
    msg("Commands: /ccv update | /ccv report | /ccv wellfed | /ccv conjured | /ccv dump")
  end
end
