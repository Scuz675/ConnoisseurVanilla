-- Data_Vanilla.lua
-- Optional overrides for classification/scoring.
-- If an item is listed here, it will be used instead of tooltip auto-detection.
-- Fields: kind=food|water|bandage|hpotion|mpotion, score=number, wellFed=true/false, reqLevel=number, conjured=true/false

CCV_DATA = {
  items = {
    -- Example Well Fed food:
    -- [40001] = { kind="food", score=2550, wellFed=true },

    -- Example force-classify custom potion:
    -- [99999] = { kind="hpotion", score=700 },
  }
}
