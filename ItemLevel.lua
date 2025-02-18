
-------------------------------------
-- 物品等級顯示 Author: M
-------------------------------------

local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local LibSchedule = LibStub:GetLibrary("LibSchedule.7000")
local LibItemInfo = LibStub:GetLibrary("LibItemInfo.7000")

local ARMOR = ARMOR or "Armor"
local WEAPON = WEAPON or "Weapon"
local MOUNTS = MOUNTS or "Mount"
local RELICSLOT = RELICSLOT or "Relic"
local ARTIFACT_POWER = ARTIFACT_POWER or "Artifact"
if (GetLocale():sub(1,2) == "zh") then ARTIFACT_POWER = "能量" end

--框架 #category Bag|Bank|Merchant|Trade|GuildBank|Auction|AltEquipment|PaperDoll|Loot
local function GetItemLevelFrame(self, category)
    if (not self.ItemLevelFrame) then
        local fontAdjust = GetLocale():sub(1,2) == "zh" and 0 or -3
        local anchor, w, h = self.IconBorder or self, self:GetSize()
        local ww, hh = anchor:GetSize()
        if (ww == 0 or hh == 0) then
            anchor = self.Icon or self.icon or self
            w, h = anchor:GetSize()
        else
            w, h = min(w, ww), min(h, hh)
        end
        self.ItemLevelFrame = CreateFrame("Frame", nil, self)
        self.ItemLevelFrame:SetScale(max(0.75, h<32 and h/32 or 1))
        self.ItemLevelFrame:SetFrameLevel(self:GetFrameLevel() + 1)
        self.ItemLevelFrame:SetSize(w, h)
        self.ItemLevelFrame:SetPoint("CENTER", anchor, "CENTER", 0, 0)
        self.ItemLevelFrame.slotString = self.ItemLevelFrame:CreateFontString(nil, "OVERLAY")
        self.ItemLevelFrame.slotString:SetFont(STANDARD_TEXT_FONT, 10+fontAdjust, "OUTLINE")
        self.ItemLevelFrame.slotString:SetPoint("BOTTOMRIGHT", 1, 2)
        self.ItemLevelFrame.slotString:SetTextColor(1, 1, 1)
        self.ItemLevelFrame.slotString:SetJustifyH("RIGHT")
        self.ItemLevelFrame.slotString:SetWidth(30)
        self.ItemLevelFrame.slotString:SetHeight(0)
        self.ItemLevelFrame.levelString = self.ItemLevelFrame:CreateFontString(nil, "OVERLAY")
        self.ItemLevelFrame.levelString:SetFont(STANDARD_TEXT_FONT, 14+fontAdjust, "OUTLINE")
        self.ItemLevelFrame.levelString:SetPoint("TOP")
        self.ItemLevelFrame.levelString:SetTextColor(1, 0.82, 0)
        LibEvent:trigger("ITEMLEVEL_FRAME_CREATED", self.ItemLevelFrame, self)
    end
    if (TinyInspectDB and TinyInspectDB.EnableItemLevel) then
        self.ItemLevelFrame:Show()
        LibEvent:trigger("ITEMLEVEL_FRAME_SHOWN", self.ItemLevelFrame, self, category or "")
    else
        self.ItemLevelFrame:Hide()
    end
    if (category) then
        self.ItemLevelCategory = category
    end
    return self.ItemLevelFrame
end

--設置裝等文字
local function SetItemLevelString(self, text, quality, link)
    if (quality and TinyInspectDB and TinyInspectDB.ShowColoredItemLevelString) then
        local r, g, b, hex = C_Item.GetItemQualityColor(quality)
        text = format("|c%s%s|r", hex, text)
    end
    --腐蚀的物品加个标记
    if (TinyInspectDB and TinyInspectDB.ShowCorruptedMark and link and C_Item.IsCorruptedItem(link)) then
        text = text .. "|cffFF3300★|r"
    end
    self:SetText(text)
end

--設置部位文字
local function SetItemSlotString(self, class, equipSlot, link)
    local slotText = ""
    if (TinyInspectDB and TinyInspectDB.ShowItemSlotString) then
        if (equipSlot and string.find(equipSlot, "INVTYPE_")) then
            slotText = _G[equipSlot] or ""
        elseif (class == ARMOR) then
            slotText = class
        elseif (link and C_Item.IsArtifactPowerItem(link)) then
            slotText = ARTIFACT_POWER
        elseif (link and IsArtifactRelicItem(link)) then
            slotText = RELICSLOT
        end
    end
    self:SetText(slotText)
end

--部分裝備無法一次讀取
local function SetItemLevelScheduled(button, ItemLevelFrame, link)
    if (not string.match(link, "item:(%d+):")) then return end
    LibSchedule:AddTask({
        identity  = link,
        elasped   = 1,
        expired   = GetTime() + 5,
        frame     = ItemLevelFrame,
        button    = button,
        onExecute = function(self)
            local count, level, _, _, quality, _, _, class, _, _, equipSlot = LibItemInfo:GetItemInfo(self.identity)
            if (count == 0) then
                SetItemLevelString(self.frame.levelString, level > 0 and level or "", quality)
                SetItemSlotString(self.frame.slotString, class, equipSlot, link)
                self.button.OrigItemLink = link
                self.button.OrigItemLevel = (level and level > 0) and level or ""
                self.button.OrigItemQuality = quality
                self.button.OrigItemClass = class
                self.button.OrigItemEquipSlot = equipSlot
                return true
            end
        end
    })
end

--設置物品等級
local function SetItemLevel(self, link, category)
    if (not self) then return end
    local frame = GetItemLevelFrame(self, category)
    if (self.OrigItemLink == link) then
        SetItemLevelString(frame.levelString, self.OrigItemLevel, self.OrigItemQuality, link)
        SetItemSlotString(frame.slotString, self.OrigItemClass, self.OrigItemEquipSlot, self.OrigItemLink)
    else
        local level = ""
        local _, count, quality, class, subclass, equipSlot
        if link then
            local linkType, id = string.match(link, "|H(%a+):(%d+):.-|h.-|h")
            if linkType == "item" then
                _, _, quality, _, _, class, subclass, _, equipSlot = C_Item.GetItemInfo(link)
                -- 除了装备和圣物外,其它不显示装等
                if ((equipSlot and string.find(equipSlot, "INVTYPE_"))
                    or (subclass and string.find(subclass, RELICSLOT))) then
                    count, level = LibItemInfo:GetItemInfo(link, nil, true)
                else
                    count = 0
                    level = ""
                end
                -- 坐骑
                if (subclass and subclass == MOUNTS) then
                    class = subclass
                end
                if (count > 0) then
                    SetItemLevelString(frame.levelString, "...")
                    return SetItemLevelScheduled(self, frame, link)
                else
                    if (tonumber(level) == 0) then level = "" end
                    SetItemLevelString(frame.levelString, level, quality, link)
                    SetItemSlotString(frame.slotString, class, equipSlot, link)
                end
            elseif linkType == "keystone" then
                -- 钥石
                quality = select(3, C_Item.GetItemInfo(id))
                level = strmatch(link, "|Hkeystone:%d+:%d+:(%d+):.-|h.-|h")
                SetItemLevelString(frame.levelString, level, quality)
                SetItemSlotString(frame.slotString)
            elseif linkType == "battlepet" then
                -- 宠物
                level, quality = strmatch(link, "|Hbattlepet:%d+:(%d+):(%d+):.-|h.-|h")
                SetItemLevelString(frame.levelString, level, quality)
                SetItemSlotString(frame.slotString)
            end
        else
            SetItemLevelString(frame.levelString, "")
            SetItemSlotString(frame.slotString)
        end
        self.OrigItemLink = link
        self.OrigItemLevel = level
        self.OrigItemQuality = quality
        self.OrigItemClass = class
        self.OrigItemEquipSlot = equipSlot
    end
end

-- Gem
local socketWatchList = {
	["BLUE"] = true,
	["RED"] = true,
	["YELLOW"] = true,
	["COGWHEEL"] = true,
	["HYDRAULIC"] = true,
	["META"] = true,
	["PRISMATIC"] = true,
	["PUNCHCARDBLUE"] = true,
	["PUNCHCARDRED"] = true,
	["PUNCHCARDYELLOW"] = true,
	["DOMINATION"] = true,
	["PRIMORDIAL"] = true,
}

local function GetSocketTexture(socket, count)
	return strrep("|TInterface\\ItemSocketingFrame\\UI-EmptySocket-"..socket..":0|t", count)
end

local function IsItemHasGem(link)
	local text = ""
	local stats = C_Item.GetItemStats(link)
	if stats then
		for stat, count in pairs(stats) do
			local socket = strmatch(stat, "EMPTY_SOCKET_(%S+)")
			if socket and socketWatchList[socket] then
				if socket == "PRIMORDIAL" then socket = "META" end -- primordial texture is missing, use meta instead, needs review
				text = text..GetSocketTexture(socket, count)
			end
		end
	end
	return text
end

--[[ All ]]
hooksecurefunc("SetItemButtonQuality", function(self, quality, itemIDOrLink, suppressOverlays, isBound)
    if (self.ItemLevelCategory or self.isBag) then return end
    local frame = GetItemLevelFrame(self)
    if (TinyInspectDB and not TinyInspectDB.EnableItemLevelOther) then
        return frame:Hide()
    end
    if (itemIDOrLink) then
        local link
        --Artifact
        if (IsArtifactRelicItem(itemIDOrLink) or C_Item.IsArtifactPowerItem(itemIDOrLink)) then
            SetItemLevel(self)
        --QuestInfo
        elseif (self.type and self.objectType == "item") then
            if (QuestInfoFrame and QuestInfoFrame.questLog) then
                link = LibItemInfo:GetQuestItemlink(self.type, self:GetID())
            else
                link = GetQuestItemLink(self.type, self:GetID())
            end
            if (not link) then
                link = select(2, C_Item.GetItemInfo(itemIDOrLink))
            end
            SetItemLevel(self, link)
        --EncounterJournal
        elseif (self.encounterID and self.link) then
            local itemInfo = C_EncounterJournal.GetLootInfoByIndex(self.index)
            SetItemLevel(self, itemInfo.link or self.link)
        --EmbeddedItemTooltip
        elseif (self.Tooltip) then
            link = select(2, self.Tooltip:GetItem())
            SetItemLevel(self, link)
        --(Bank)
        elseif (tonumber(itemIDOrLink) and self.hasItem) then
            link = C_Container.GetContainerItemLink(self:GetParent():GetID(), self:GetID())
            SetItemLevel(self, link)
        else
            SetItemLevel(self, itemIDOrLink)
        end
    else
        SetItemLevelString(frame.levelString, "")
        SetItemSlotString(frame.slotString)
    end
end)

-- Bag & Bank
local function SetContainerItemLevel(self)
    local category = self:IsBankBag() and "Bank" or "Bag"
    for _, button in self:EnumerateValidItems() do
        SetItemLevel(button, C_Container.GetContainerItemLink(button:GetBagID(), button:GetID()), category)
    end
end

for i = 1, NUM_CONTAINER_FRAMES do
    local ContainerFrame = _G["ContainerFrame"..i]
    if ContainerFrame and ContainerFrame.UpdateItems then
        hooksecurefunc(ContainerFrame, "UpdateItems", SetContainerItemLevel)
    end
end

if ContainerFrameCombinedBags then
    hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", SetContainerItemLevel)
end

-- Bank
if BankFrameItemButton_Update then
    hooksecurefunc("BankFrameItemButton_Update", function(self)
        if self.isBag then return end
        SetItemLevel(self, C_Container.GetContainerItemLink(self:GetParent():GetID(), self:GetID()), "Bank")
    end)
end

-- Warband Bank
if BankPanelItemButtonMixin then
    hooksecurefunc(BankPanelItemButtonMixin, "Refresh", function(self)
        SetItemLevel(self, self.itemInfo and self.itemInfo.hyperlink, "Bank")
    end)
end

-- Merchant
if MerchantFrameItem_UpdateQuality then
    hooksecurefunc("MerchantFrameItem_UpdateQuality", function(self, link)
        SetItemLevel(self.ItemButton, link, "Merchant")
    end)
end

-- ALT
if (EquipmentFlyout_DisplayButton) then
    hooksecurefunc("EquipmentFlyout_DisplayButton", function(button)
        local location = button.location
        if (not location) then return end
        local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(location)
        if (not player and not bank and not bags and not voidStorage) then return end
        if (voidStorage) then
            SetItemLevel(button, nil, "AltEquipment")
        elseif (bags) then
            local link = C_Container.GetContainerItemLink(bag, slot)
            SetItemLevel(button, link, "AltEquipment")
        else
            local link = GetInventoryItemLink("player", slot)
            SetItemLevel(button, link, "AltEquipment")
        end
    end)
end

-- GuildNews
local GuildNewsItemCache = {}
if GuildNewsButton_SetText then
    hooksecurefunc("GuildNewsButton_SetText", function(button, text_color, text, text1, text2, ...)
        if (not TinyInspectDB or
            not TinyInspectDB.EnableItemLevel or
            not TinyInspectDB.EnableItemLevelGuildNews) then
            return
        end

        if (text2 and type(text2) == "string") then
            local link = string.match(text2, "|H(item:%d+:.-)|h.-|h")
            if (link) then
                local level = GuildNewsItemCache[link] or select(2, LibItemInfo:GetItemInfo(link))
                if (level > 0) then
                    GuildNewsItemCache[link] = level
                    text2 = text2:gsub("(%|Hitem:%d+:.-%|h%[)(.-)(%]%|h)", "%1"..level..":%2%3"..IsItemHasGem(link))
                    button.text:SetFormattedText(text, text1, text2, ...)
                end
            end
        end
    end)
end

-------------------
--   PaperDoll  --
-------------------

local function SetPaperDollItemLevel(self, unit)
    if (not self) then return end
    local id = self:GetID()
    local frame = GetItemLevelFrame(self, "PaperDoll")
    if (unit and GetInventoryItemTexture(unit, id)) then
        local _, level, _, link, quality, _, _, class, _, _, equipSlot = LibItemInfo:GetUnitItemInfo(unit, id)
        SetItemLevelString(frame.levelString, level > 0 and level or "", quality, link)
        SetItemSlotString(frame.slotString, class, equipSlot)
        if (id == 16 or id == 17) then
            local _, mlevel, _, _, mquality = LibItemInfo:GetUnitItemInfo(unit, 16)
            local _, olevel, _, _, oquality = LibItemInfo:GetUnitItemInfo(unit, 17)
            if (mlevel > 0 and olevel > 0 and (mquality == 6 or oquality == 6)) then
                SetItemLevelString(frame.levelString, max(mlevel,olevel), mquality or oquality, link)
            end
        end
    else
        SetItemLevelString(frame.levelString, "")
        SetItemSlotString(frame.slotString)
    end
    if (unit == "player") then
        SetItemSlotString(frame.slotString)
    end
end

local EquipmentSlots = {
    [1] = "Head",
    [2] = "Neck",
    [3] = "Shoulder",
    [5] = "Chest",
    [6] = "Waist",
    [7] = "Legs",
    [8] = "Feet",
    [9] = "Wrist",
    [10] = "Hands",
    [11] = "Finger0",
    [12] = "Finger1",
    [13] = "Trinket0",
    [14] = "Trinket1",
    [15] = "Back",
    [16] = "MainHand",
    [17] = "SecondaryHand"
}

PaperDollFrame:HookScript("OnShow", function()
    for _, slot in pairs(EquipmentSlots) do
        SetPaperDollItemLevel(_G["Character"..slot.."Slot"], "player")
    end
end)

LibEvent:attachEvent("PLAYER_EQUIPMENT_CHANGED", function(_, slotID)
    if CharacterFrame:IsShown() and EquipmentSlots[slotID] then
        SetPaperDollItemLevel(_G["Character"..EquipmentSlots[slotID].."Slot"], "player")
    end
end)

LibEvent:attachTrigger("UNIT_INSPECT_READY", function(self, data)
    if (InspectFrame and InspectFrame.unit and UnitGUID(InspectFrame.unit) == data.guid) then
        for _, slot in pairs(EquipmentSlots) do
            SetPaperDollItemLevel(_G["Inspect"..slot.."Slot"], InspectFrame.unit)
        end
    end
end)

LibEvent:attachEvent("ADDON_LOADED", function(self, addonName)
    if (addonName == "Blizzard_InspectUI") then
        hooksecurefunc(InspectFrame, "Hide", function()
            for _, slot in pairs(EquipmentSlots) do
                SetPaperDollItemLevel(_G["Inspect"..slot.."Slot"])
            end
        end)
    end
end)

----------------------
--  Chat ItemLevel  --
----------------------

local Caches = {}

local function ChatItemLevel(Hyperlink)
    if (Caches[Hyperlink]) then
        return Caches[Hyperlink]
    end
    local link = string.match(Hyperlink, "|H(.-)|h")
    local count, level, name, _, quality, _, _, class, subclass, _, equipSlot = LibItemInfo:GetItemInfo(link)
    if (tonumber(level) and level > 0) then
        if (equipSlot == "INVTYPE_CLOAK" or equipSlot == "INVTYPE_TRINKET" or equipSlot == "INVTYPE_FINGER" or equipSlot == "INVTYPE_NECK") then
            level = format("%s(%s)", level, _G[equipSlot] or equipSlot)
        elseif (equipSlot and string.find(equipSlot, "INVTYPE_")) then
            level = format("%s(%s-%s)", level, subclass or "", _G[equipSlot] or equipSlot)
        elseif (class == ARMOR) then
            level = format("%s(%s-%s)", level, subclass or "", class)
        elseif (subclass and string.find(subclass, RELICSLOT)) then
            level = format("%s(%s)", level, RELICSLOT)
        else
            level = nil
        end
        if (level) then
            local gem = IsItemHasGem(link)
            if (quality == 6 and class == WEAPON) then gem = "" end
            Hyperlink = Hyperlink:gsub("|h%[(.-)%]|h", "|h["..level..":"..name.."]|h"..gem)
        end
        Caches[Hyperlink] = Hyperlink
    elseif (subclass and subclass == MOUNTS) then
        Hyperlink = Hyperlink:gsub("|h%[(.-)%]|h", "|h[("..subclass..")%1]|h")
        Caches[Hyperlink] = Hyperlink
    elseif (count == 0) then
        Caches[Hyperlink] = Hyperlink
    end
    return Hyperlink
end

local function filter(self, event, msg, ...)
    if (TinyInspectDB and TinyInspectDB.EnableItemLevel and TinyInspectDB.EnableItemLevelChat) then
        msg = msg:gsub("(|Hitem:%d+:.-|h.-|h)", ChatItemLevel)
    end
    return false, msg, ...
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BATTLEGROUND", filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", filter)

-- 位置設置
LibEvent:attachTrigger("ITEMLEVEL_FRAME_SHOWN", function(self, frame, parent, category)
    if (TinyInspectDB and not TinyInspectDB["EnableItemLevel"..category]) then
        return frame:Hide()
    end
    if (TinyInspectDB and TinyInspectDB.PaperDollItemLevelOutsideString) then
        return
    end
    local anchorPoint = TinyInspectDB and TinyInspectDB.ItemLevelAnchorPoint
    if (frame.anchorPoint ~= anchorPoint) then
        frame.anchorPoint = anchorPoint
        frame.levelString:ClearAllPoints()
        frame.levelString:SetPoint(anchorPoint or "TOP")
    end
end)

-- OutsideString For PaperDoll ItemLevel
LibEvent:attachTrigger("ITEMLEVEL_FRAME_CREATED", function(self, frame, parent)
    if (TinyInspectDB and TinyInspectDB.PaperDollItemLevelOutsideString) then
        local name = parent:GetName()
        if (name and string.match(name, "^[IC].+Slot$")) then
            local id = parent:GetID()
            frame:ClearAllPoints()
            frame.levelString:ClearAllPoints()
            if (id <= 5 or id == 9 or id == 15 or id == 19) then
                frame:SetPoint("LEFT", parent, "RIGHT", 7, -1)
                frame.levelString:SetPoint("TOPLEFT")
                frame.levelString:SetJustifyH("LEFT")
            elseif (id == 17) then
                frame:SetPoint("LEFT", parent, "RIGHT", 5, 1)
                frame.levelString:SetPoint("TOPLEFT")
                frame.levelString:SetJustifyH("LEFT")
            elseif (id == 16) then
                frame:SetPoint("RIGHT", parent, "LEFT", -5, 1)
                frame.levelString:SetPoint("TOPRIGHT")
                frame.levelString:SetJustifyH("RIGHT")
            else
                frame:SetPoint("RIGHT", parent, "LEFT", -7, -1)
                frame.levelString:SetPoint("TOPRIGHT")
                frame.levelString:SetJustifyH("RIGHT")
            end
        end
    end
end)
