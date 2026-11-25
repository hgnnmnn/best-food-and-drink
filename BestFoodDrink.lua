-- Best Food & Drink
-- Zeigt das beste Essen (Gesundheit) und Trinken (Mana) aus den Taschen als Buttons.
-- Shift + Linksklick ziehen = verschieben. /bfd fuer Optionen.

local ADDON = "BestFoodDrink"

---------------------------------------------------------------------------
-- Lokalisierung (Fallback: Englisch)
---------------------------------------------------------------------------
local TEXTS = {
    enUS = {
        food = "Food", drink = "Drink", auto = "Automatic (best item)", mage = "Mage",
        hint = "Alt + Click: choose item | Shift + Drag: move",
        locked = "locked.", unlocked = "unlocked (Shift + Drag).",
    },
    deDE = {
        food = "Essen", drink = "Trinken", auto = "Automatisch (bestes Item)", mage = "Magier",
        hint = "Alt + Klick: Item wählen | Shift + Ziehen: verschieben",
        locked = "gesperrt.", unlocked = "entsperrt (Shift + Ziehen).",
    },
    frFR = {
        food = "Nourriture", drink = "Boisson", auto = "Automatique (meilleur objet)", mage = "Mage",
        hint = "Alt + Clic : choisir l'objet | Maj + Glisser : déplacer",
        locked = "verrouillé.", unlocked = "déverrouillé (Maj + Glisser).",
    },
    esES = {
        food = "Comida", drink = "Bebida", auto = "Automático (mejor objeto)", mage = "Mago",
        hint = "Alt + Clic: elegir objeto | Mayús + Arrastrar: mover",
        locked = "bloqueado.", unlocked = "desbloqueado (Mayús + Arrastrar).",
    },
}
TEXTS.esMX = TEXTS.esES
local L = TEXTS[GetLocale()] or TEXTS.enUS

local defaults = { locked = false, scale = 1, size = 40, point = "CENTER", x = 0, y = -150 }
local db

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------
local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetItemCooldownFn = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
local GetItemInfoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemCountFn = (C_Item and C_Item.GetItemCount) or GetItemCount

local function SlotItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local i = C_Container.GetContainerItemInfo(bag, slot)
        if i then return i.itemID, i.hyperlink end
    elseif GetContainerItemInfo then
        local _, _, _, _, _, _, link = GetContainerItemInfo(bag, slot)
        if link then return tonumber(link:match("item:(%d+)")), link end
    end
end

local tip = CreateFrame("GameTooltip", "BFDScanTip", UIParent, "GameTooltipTemplate")
tip:SetOwner(UIParent, "ANCHOR_NONE")

local healthWords = { "health", "gesundheit", "vie", "salud", "life", "saude", "saúde", "salute" }
local manaWords = { "mana", "maná" }

-- Entfernt Tausendertrenner ("2,600", "2.600", "2 600"), sonst wird nur "600" gelesen.
local function StripSeparators(text)
    for _ = 1, 2 do
        text = text:gsub("(%d)[,%.](%d%d%d)", "%1%2")
        text = text:gsub("(%d)\194\160(%d%d%d)", "%1%2")
        text = text:gsub("(%d)\226\128\175(%d%d%d)", "%1%2")
    end
    return text
end

local function FindValue(text, words)
    text = StripSeparators(text)
    local best = 0
    for _, w in ipairs(words) do
        local n = text:match("(%d+)[^%d]*" .. w)
        if n and tonumber(n) > best then best = tonumber(n) end
    end
    return best
end

-- Liest Gesundheits-/Manawert aus dem Tooltip (sprachunabhaengig soweit moeglich).
local function ParseTooltip(link)
    tip:ClearLines()
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:SetHyperlink(link)
    local health, mana, conjured = 0, 0, false
    for i = 2, tip:NumLines() do
        local fs = _G["BFDScanTipTextLeft" .. i]
        local t = fs and fs:GetText()
        if t and ITEM_CONJURED and t == ITEM_CONJURED then conjured = true end
        if t and t:find("%d") then
            local low = t:lower()
            local h = FindValue(low, healthWords)
            local m = FindValue(low, manaWords)
            if h > health then health = h end
            if m > mana then mana = m end
        end
    end
    return health, mana, conjured
end

---------------------------------------------------------------------------
-- Bag-Scan
---------------------------------------------------------------------------
local cache = {}      -- itemID -> {health, mana, minLevel}
local needsRetry = false

local function Evaluate(itemID, link)
    local c = cache[itemID]
    if c then return c end
    local _, _, _, _, minLevel, _, _, _, _, _, _, classID, subClassID = GetItemInfoFn(link)
    if not classID then needsRetry = true return nil end
    if classID ~= 0 or subClassID ~= 5 then -- nur "Verbrauchbar: Essen & Trinken"
        c = { health = 0, mana = 0, minLevel = 0, conjured = false }
    else
        local h, m, conj = ParseTooltip(link)
        if h == 0 and m == 0 then needsRetry = true; return nil end
        c = { health = h, mana = m, minLevel = minLevel or 0, conjured = conj }
    end
    cache[itemID] = c
    return c
end

-- Vom Magier herbeigezauberte Items haben Vorrang, danach zaehlt der Wert.
local function Better(conjured, value, cur)
    if not cur then return true end
    if conjured ~= cur.conjured then return conjured end
    return value > cur.value
end

local lists = { food = {}, drink = {} }

local function SortEntries(a, b)
    if a.conjured ~= b.conjured then return a.conjured end
    return a.value > b.value
end

-- Liefert (Essen, Trinken, Essen manuell?, Trinken manuell?)
local function Scan()
    local food, drink, manualFood, manualDrink
    local fl, dl, seenF, seenD = {}, {}, {}, {}
    local level = UnitLevel("player")
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (GetNumSlots(bag) or 0) do
            local id, link = SlotItem(bag, slot)
            if id and link then
                local c = Evaluate(id, link)
                if c and c.minLevel <= level then
                    if c.health > 0 then
                        local e = { id = id, link = link, value = c.health, conjured = c.conjured }
                        if not seenF[id] then seenF[id] = true; fl[#fl + 1] = e end
                        if Better(c.conjured, c.health, food) then food = e end
                        if id == db.manualFood then manualFood = e end
                    end
                    if c.mana > 0 then
                        local e = { id = id, link = link, value = c.mana, conjured = c.conjured }
                        if not seenD[id] then seenD[id] = true; dl[#dl + 1] = e end
                        if Better(c.conjured, c.mana, drink) then drink = e end
                        if id == db.manualDrink then manualDrink = e end
                    end
                end
            end
        end
    end
    table.sort(fl, SortEntries)
    table.sort(dl, SortEntries)
    lists.food, lists.drink = fl, dl
    return manualFood or food, manualDrink or drink, manualFood ~= nil, manualDrink ~= nil
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
local buttons = {}
local pending = false
local Refresh

---------------------------------------------------------------------------
-- Dropdown-Menue (Alt + Klick)
---------------------------------------------------------------------------
local menu = CreateFrame("Frame", "BFDMenu", UIParent)
menu:SetFrameStrata("DIALOG")
menu:EnableMouse(true)
menu:Hide()
menu.bg = menu:CreateTexture(nil, "BACKGROUND")
menu.bg:SetAllPoints()
menu.bg:SetColorTexture(0.05, 0.05, 0.08, 0.95)
menu.edge = menu:CreateTexture(nil, "BACKGROUND", nil, -1)
menu.edge:SetPoint("TOPLEFT", -1, 1)
menu.edge:SetPoint("BOTTOMRIGHT", 1, -1)
menu.edge:SetColorTexture(0.6, 0.5, 0.2, 1)
menu.rows = {}
tinsert(UISpecialFrames, "BFDMenu")

local ROW_H, MENU_W = 24, 280

local function GetRow(i)
    local r = menu.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, menu)
    r:SetSize(MENU_W - 8, ROW_H)
    r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ROW_H)
    r:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight", "ADD")
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ROW_H - 4, ROW_H - 4)
    r.icon:SetPoint("LEFT", 2, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.text:SetJustifyH("LEFT")
    r.count = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.count:SetPoint("RIGHT", -4, 0)
    r:SetScript("OnClick", function(self)
        db[menu.key] = self.itemID -- nil = automatisch
        menu:Hide()
        Refresh()
    end)
    menu.rows[i] = r
    return r
end

local function IsOver(frame)
    if frame.IsMouseOver then return frame:IsMouseOver() end
    if MouseIsOver then return MouseIsOver(frame) end
    return true
end

menu:SetScript("OnUpdate", function(self, elapsed)
    if IsOver(self) or (self.anchor and IsOver(self.anchor)) then
        self.idle = 0
    else
        self.idle = (self.idle or 0) + elapsed
        if self.idle > 0.6 then self:Hide() end
    end
end)

local function ShowMenu(kind, anchor)
    if menu:IsShown() and menu.anchor == anchor then menu:Hide() return end
    menu.key = (kind == "food") and "manualFood" or "manualDrink"
    menu.anchor = anchor
    menu.idle = 0
    local entries = lists[kind]
    local current = db[menu.key]

    local r = GetRow(1)
    r.itemID = nil
    r.icon:SetTexture("Interface/Icons/INV_Misc_Gear_01")
    r.text:SetText(current and L.auto or "|cff33ff99" .. L.auto .. "|r")
    r.count:SetText("")
    r:Show()

    for i, e in ipairs(entries) do
        local row = GetRow(i + 1)
        row.itemID = e.id
        row.icon:SetTexture(GetItemIcon and GetItemIcon(e.id) or select(10, GetItemInfoFn(e.id)))
        local mark = (current == e.id) and "|cff33ff99>|r " or ""
        row.text:SetText(mark .. e.link .. " |cffaaaaaa" .. e.value .. "|r" .. (e.conjured and " |cff66ccff" .. L.mage .. "|r" or ""))
        row.count:SetText(GetItemCountFn(e.id) or "")
        row:Show()
    end
    for i = #entries + 2, #menu.rows do menu.rows[i]:Hide() end

    menu:SetSize(MENU_W, 8 + (#entries + 1) * ROW_H)
    menu:ClearAllPoints()
    menu:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 6)
    menu:SetScale(anchor:GetEffectiveScale() / UIParent:GetEffectiveScale())
    menu:Show()
end

local function Move(btn)
    if db.locked or InCombatLockdown() then return false end
    return IsShiftKeyDown()
end

local function MakeButton(name, kind)
    local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    b:SetMovable(true)
    b:SetClampedToScreen(true)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("useOnKeyDown", false)
    b.kind = kind
    b:RegisterForDrag("LeftButton")
    b:SetAttribute("type", "macro")
    -- Alt + Klick: nichts benutzen, stattdessen Dropdown oeffnen
    for _, n in ipairs({ "1", "2" }) do
        b:SetAttribute("alt-type" .. n, "macro")
        b:SetAttribute("alt-macrotext" .. n, "")
    end
    b:HookScript("OnClick", function(self, _, down)
        if not down and IsAltKeyDown() then ShowMenu(self.kind, self) end
    end)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    b.border = b:CreateTexture(nil, "BACKGROUND")
    b.border:SetPoint("TOPLEFT", -2, 2)
    b.border:SetPoint("BOTTOMRIGHT", 2, -2)
    b.border:SetColorTexture(0, 0, 0, 0.8)

    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)

    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)

    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints()

    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    b:SetScript("OnDragStart", function(self)
        if Move(self) then self.isMoving = true; self:StartMoving() end
    end)
    b:SetScript("OnDragStop", function(self)
        if not self.isMoving then return end
        self.isMoving = false
        self:StopMovingOrSizing()
        local p, _, _, x, y = self:GetPoint()
        db.point, db.x, db.y = p, x, y
        buttons.drink:ClearAllPoints()
        buttons.drink:SetPoint("LEFT", buttons.food, "RIGHT", 8, 0)
    end)
    b:SetScript("OnEnter", function(self)
        if self.link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            GameTooltip:AddLine(L.hint, 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function ApplyLayout()
    for _, b in pairs(buttons) do
        b:SetSize(db.size, db.size)
        b:SetScale(db.scale)
    end
    buttons.food:ClearAllPoints()
    buttons.food:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    buttons.drink:ClearAllPoints()
    buttons.drink:SetPoint("LEFT", buttons.food, "RIGHT", 8, 0)
end

local function SetButton(b, entry, label, manual)
    b.label:SetText(label)
    if manual then b.border:SetColorTexture(0.2, 0.8, 0.4, 0.9) else b.border:SetColorTexture(0, 0, 0, 0.8) end
    if entry then
        b.link = entry.link
        b.itemID = entry.id
        b.icon:SetTexture(GetItemIcon and GetItemIcon(entry.id) or select(10, GetItemInfoFn(entry.id)))
        b.icon:SetDesaturated(false)
        b:SetAttribute("macrotext", "/use item:" .. entry.id)
        b.count:SetText(GetItemCountFn(entry.id) or "")
    else
        b.link, b.itemID = nil, nil
        b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        b.icon:SetDesaturated(true)
        b:SetAttribute("macrotext", "")
        b.count:SetText("")
        b.cd:Clear()
    end
end

local function UpdateCooldowns()
    for _, b in pairs(buttons) do
        if b.itemID and GetItemCooldownFn then
            local start, dur = GetItemCooldownFn(b.itemID)
            if start and dur and dur > 0 then b.cd:SetCooldown(start, dur) else b.cd:Clear() end
        end
    end
end

function Refresh()
    if InCombatLockdown() then pending = true return end
    pending = false
    needsRetry = false
    local food, drink, mf, md = Scan()
    SetButton(buttons.food, food, L.food, mf)
    SetButton(buttons.drink, drink, L.drink, md)
    UpdateCooldowns()
    if needsRetry then C_Timer.After(1.5, Refresh) end
end

local timer
local function RefreshSoon()
    if timer then return end
    timer = true
    C_Timer.After(0.2, function() timer = nil; Refresh() end)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        BestFoodDrinkDB = BestFoodDrinkDB or {}
        db = BestFoodDrinkDB
        for k, v in pairs(defaults) do if db[k] == nil then db[k] = v end end

        buttons.food = MakeButton("BFDFoodButton", "food")
        buttons.drink = MakeButton("BFDDrinkButton", "drink")
        ApplyLayout()

        for _, e in ipairs({ "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD",
            "GET_ITEM_INFO_RECEIVED", "PLAYER_REGEN_ENABLED" }) do
            pcall(f.RegisterEvent, f, e)
        end
        pcall(f.RegisterEvent, f, "BAG_UPDATE_COOLDOWN")
        f:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then Refresh() end
    elseif event == "BAG_UPDATE_COOLDOWN" then
        UpdateCooldowns()
    elseif db then
        RefreshSoon()
    end
end)

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
SLASH_BESTFOODDRINK1 = "/bfd"
SlashCmdList["BESTFOODDRINK"] = function(msg)
    msg = (msg or ""):lower()
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    if cmd == "lock" then
        db.locked = true; print("|cff33ff99BFD|r: " .. L.locked)
    elseif cmd == "unlock" then
        db.locked = false; print("|cff33ff99BFD|r: " .. L.unlocked)
    elseif cmd == "scale" and tonumber(arg) then
        db.scale = math.max(0.5, math.min(3, tonumber(arg)))
        if not InCombatLockdown() then ApplyLayout() end
    elseif cmd == "size" and tonumber(arg) then
        db.size = math.max(20, math.min(100, tonumber(arg)))
        if not InCombatLockdown() then ApplyLayout() end
    elseif cmd == "auto" then
        db.manualFood, db.manualDrink = nil, nil
        Refresh()
    elseif cmd == "reset" then
        db.manualFood, db.manualDrink = nil, nil
        for k, v in pairs(defaults) do db[k] = v end
        if not InCombatLockdown() then ApplyLayout() end
    elseif cmd == "refresh" then
        wipe(cache); Refresh()
    elseif cmd == "debug" then
        local level = UnitLevel("player")
        for bag = 0, (NUM_BAG_SLOTS or 4) do
            for slot = 1, (GetNumSlots(bag) or 0) do
                local id, link = SlotItem(bag, slot)
                if id and link then
                    local _, _, _, _, minLevel, _, _, _, _, _, _, classID, subClassID = GetItemInfoFn(link)
                    if classID == 0 and subClassID == 5 then
                        local h, m, conj = ParseTooltip(link)
                        print(("|cff33ff99BFD|r %s class=%s/%s minLvl=%s (you %s) health=%d mana=%d conjured=%s"):format(
                            link, tostring(classID), tostring(subClassID), tostring(minLevel), level, h, m, tostring(conj)))
                    end
                end
            end
        end
    else
        print("|cff33ff99BFD|r: /bfd lock | unlock | scale <0.5-3> | size <20-100> | auto | reset | refresh | debug")
    end
end
