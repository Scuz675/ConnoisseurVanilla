-- ConnoisseurVanilla (Turtle WoW 1.12)
-- FINAL SMART BUILD:
--   * Auto-detects Food, Drink, Health Potions, Mana Potions via tooltip (no DB maintenance)
--   * Option B: Prefer "Well Fed" foods when buff is missing
--   * Bandages remain DB/keyword-based (safe) and are used by "Bandage" macro via scan
--   * No minimap button; hardcoded macro icons via macro icon list (iconIndex), per Turtle wiki

CCV_Settings = CCV_Settings or { autoUpdate=true }
CCV_Ignore = CCV_Ignore or {}

local function msg(s) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffCCV|r "..tostring(s)) end

local CCV_Macros = {
  food    = "Food",
  water   = "Water",
  bandage = "Bandage",
  hpotion = "Health Potion",
  mpotion = "Mana Potion",
}

-- Macro icon texture names (must exist in macro icon list)
local CCV_IconTextureName = {
  bandage = "Spell_Holy_SealOfSacrifice",
  food    = "Spell_Misc_Food",
  water   = "Spell_Misc_Drink",
  hpotion = "Spell_Nature_Strength",
  mpotion = "Spell_Misc_ConjureManaJewel",
}

-- Localized "Well Fed" buff names (for player buff check)
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
    CCV_Tip:SetPlayerBuff(i)
    local t = TipLine(1)
    if t and CCV_WellFedNames[t] then return true end
  end
  return false
end

-- Patterns (use string.find captures; Turtle 1.12 may not have string.match)
local PAT_RESTORE_HEALTH_SINGLE = "Restores%s+([%d%.]+)%s+health"
local PAT_RESTORE_HEALTH_RANGE  = "Restores%s+([%d%.]+)%s+to%s+([%d%.]+)%s+health"
local PAT_RESTORE_MANA_SINGLE   = "Restores%s+([%d%.]+)%s+mana"
local PAT_RESTORE_MANA_RANGE    = "Restores%s+([%d%.]+)%s+to%s+([%d%.]+)%s+mana"

local function AvgRange(a,b)
  if not a or not b then return nil end
  return (a+b)/2
end

-- Classify by tooltip:
--   food:  Restores X health (and no mana)
--   water: Restores X mana
--   hpotion/mpotion: "Potion" in name AND restores health/mana (range or single)
--   wellFed: "Well Fed" present in any line
local function ClassifyByTooltip(bag, slot)
  CCV_Tip:ClearLines()
  CCV_Tip:SetBagItem(bag, slot)

  local name = TipLine(1)
  local isPotion = (name and string.find(name, "Potion", 1, true)) and true or false

  local restoresHealth, restoresMana = nil, nil
  local wellFed = false

  for i=2,12 do
    local line = TipLine(i)
    if not line then break end

    if not restoresHealth then
      local _,_,a,b = string.find(line, PAT_RESTORE_HEALTH_RANGE)
      if a and b then
        local na, nb = ParseNum(a), ParseNum(b)
        restoresHealth = AvgRange(na, nb)
      else
        local _,_,h = string.find(line, PAT_RESTORE_HEALTH_SINGLE)
        if h then restoresHealth = ParseNum(h) end
      end
    end

    if not restoresMana then
      local _,_,a,b = string.find(line, PAT_RESTORE_MANA_RANGE)
      if a and b then
        local na, nb = ParseNum(a), ParseNum(b)
        restoresMana = AvgRange(na, nb)
      else
        local _,_,m = string.find(line, PAT_RESTORE_MANA_SINGLE)
        if m then restoresMana = ParseNum(m) end
      end
    end

    if string.find(line, "Well Fed", 1, true) then
      wellFed = true
    end
  end

  -- Potions (only if item name contains "Potion" to avoid food/drink false-positives)
  if isPotion then
    if restoresHealth and (not restoresMana or restoresMana==0) then
      return "hpotion", restoresHealth, false
    end
    if restoresMana then
      return "mpotion", restoresMana, false
    end
  end

  -- Food/Drink (for water, mana restoration is the key)
  if restoresMana then
    return "water", restoresMana, false
  end
  if restoresHealth and not restoresMana then
    return "food", restoresHealth, wellFed
  end

  return nil, nil, false
end

-- Bandage detection (keyword; safest for 1.12)
local function LooksLikeBandage(bag, slot)
  CCV_Tip:ClearLines()
  CCV_Tip:SetBagItem(bag, slot)
  local name = TipLine(1)
  if not name then return false end
  return string.find(name, "Bandage", 1, true) and true or false
end

local function GetItemIDFromLink(link)
  if not link then return nil end
  local _,_,id = string.find(link,"item:(%d+)")
  return id and tonumber(id) or nil
end

-- Icon index resolver (macro icon list)
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

local function ScanBags()
  local hasWellFed = PlayerHasWellFed()
  local best = { food={score=-1}, water={score=-1}, bandage={score=-1}, hpotion={score=-1}, mpotion={score=-1} }

  for bag=0,4 do
    local slots = GetContainerNumSlots(bag) or 0
    for slot=1,slots do
      local link = GetContainerItemLink(bag,slot)
      local id = GetItemIDFromLink(link)

      if id and not CCV_Ignore[id] then
        local entry = (CCV_DATA and CCV_DATA.items and CCV_DATA.items[id]) or nil
        local kind, score, wellFed = nil, nil, false

        if entry then
          kind = entry.kind
          score = tonumber(entry.score) or 0
          wellFed = entry.wellFed and true or false
        else
          -- auto classify (food/water/potions)
          kind, score, wellFed = ClassifyByTooltip(bag, slot)
          -- bandages keyword fallback
          if not kind and LooksLikeBandage(bag, slot) then
            kind, score, wellFed = "bandage", 1, false
          end
        end

        if kind and best[kind] and score then
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

function CCV_Use(kind)
  local best = ScanBags()
  local pick = best[kind]
  if not pick or not pick.id then msg("No "..tostring(kind).." found.") return end

  UseContainerItem(pick.bag, pick.slot)

  if kind=="bandage" then
    if UnitExists("target") and UnitIsFriend("player","target") then
      SpellTargetUnit("target")
    else
      SpellTargetUnit("player")
    end
  end
end

-- Turtle wiki macro API:
--   CreateMacro(name, iconIndex, body, local)
--   EditMacro(index, name, iconIndex, body, local)
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
f:SetScript("OnEvent", function() if CCV_Settings.autoUpdate then UpdateMacros() end end)

SLASH_CCV1="/ccv"
SlashCmdList["CCV"]=function(m)
  m = m and string.lower(m) or ""
  if m=="update" then
    UpdateMacros()
    msg("Macros updated.")
  elseif m=="wellfed" then
    msg("Well Fed: "..tostring(PlayerHasWellFed()))
  else
    msg("Commands: /ccv update | /ccv wellfed")
  end
end
