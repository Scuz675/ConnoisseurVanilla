-- ConnoisseurVanilla (Turtle WoW 1.12)
-- Simple Build: No Minimap Button, Hardcoded Macro Icons

CCV_Settings = CCV_Settings or { autoUpdate=true }
CCV_Ignore = CCV_Ignore or {}

local function msg(s)
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffCCV|r " .. tostring(s))
end

local CCV_Macros = {
  food    = "Food",
  water   = "Water",
  bandage = "Bandage",
  hpotion = "Health Potion",
  mpotion = "Mana Potion",
}

-- Exact macro icon texture names
local CCV_IconTextureName = {
  bandage = "Spell_Holy_SealOfSacrifice",
  food    = "Spell_Misc_Food",
  water   = "Spell_Misc_Drink",
  hpotion = "Spell_Nature_Strength",
  mpotion = "Spell_Misc_ConjureManaJewel",
}

local CCV_ResolvedIconIndex = {}

local function ResolveIconIndex(kind)
  if CCV_ResolvedIconIndex[kind] then
    return CCV_ResolvedIconIndex[kind]
  end

  local desired = CCV_IconTextureName[kind]
  if not desired then return 1 end

  for i=1,GetNumMacroIcons() do
    local tex = GetMacroIconInfo(i)
    if tex and string.find(tex, desired, 1, true) then
      CCV_ResolvedIconIndex[kind] = i
      return i
    end
  end

  CCV_ResolvedIconIndex[kind] = 1
  return 1
end

local function GetItemIDFromLink(link)
  if not link then return nil end
  local _,_,id = string.find(link, "item:(%d+)")
  return id and tonumber(id) or nil
end

local function ScanBags()
  local best = {
    food    = { id=nil, bag=nil, slot=nil, score=0 },
    water   = { id=nil, bag=nil, slot=nil, score=0 },
    bandage = { id=nil, bag=nil, slot=nil, score=0 },
    hpotion = { id=nil, bag=nil, slot=nil, score=0 },
    mpotion = { id=nil, bag=nil, slot=nil, score=0 },
  }

  for bag=0,4 do
    local slots = GetContainerNumSlots(bag) or 0
    for slot=1,slots do
      local link = GetContainerItemLink(bag, slot)
      local id = GetItemIDFromLink(link)
      if id and not CCV_Ignore[id] and CCV_DATA and CCV_DATA.items[id] then
        local entry = CCV_DATA.items[id]
        local k = entry.kind
        if best[k] and entry.score > best[k].score then
          best[k] = { id=id, bag=bag, slot=slot, score=entry.score }
        end
      end
    end
  end

  return best
end

function CCV_Use(kind)
  local best = ScanBags()
  local pick = best[kind]
  if not pick or not pick.id then
    msg("No " .. tostring(kind) .. " found.")
    return
  end

  UseContainerItem(pick.bag, pick.slot)

  if kind == "bandage" then
    if UnitExists("target") and UnitIsFriend("player","target") then
      SpellTargetUnit("target")
    else
      SpellTargetUnit("player")
    end
  end
end

local function SetMacro(kind, body)
  local name = CCV_Macros[kind]
  local iconIndex = ResolveIconIndex(kind) or 1

  local idx = GetMacroIndexByName(name)
  if idx == 0 then
    CreateMacro(name, iconIndex, body, 1)
    idx = GetMacroIndexByName(name)
  end

  EditMacro(idx, name, iconIndex, body, 1)
end

local function UpdateMacros()
  SetMacro("food",    "/run CCV_Use(\"food\")")
  SetMacro("water",   "/run CCV_Use(\"water\")")
  SetMacro("bandage", "/run CCV_Use(\"bandage\")")
  SetMacro("hpotion", "/run CCV_Use(\"hpotion\")")
  SetMacro("mpotion", "/run CCV_Use(\"mpotion\")")
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE")
f:SetScript("OnEvent", function()
  if CCV_Settings.autoUpdate then
    UpdateMacros()
  end
end)

SLASH_CCV1="/ccv"
SlashCmdList["CCV"] = function(m)
  if m=="update" then
    UpdateMacros()
  else
    msg("Commands: /ccv update")
  end
end
