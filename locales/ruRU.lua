
-- Thanks to BLizzatron

local _, ns = ...

if (GetLocale() ~= "ruRU") then return end

ns.L = {
    ShowItemBorder              = "Показать рамку предмета",
    EnableItemLevel             = "Включить ур. предмета",
    ShowColoredItemLevelString  = "Показать цветную, строку уровня предмета",
    ShowItemSlotString          = "Показать строку слота элемента",
    ShowInspectAngularBorder    = "Показать угловую границу осмотра",
    ShowInspectColoredLabel     = "Показать окрашенный, ярлычок осмотра",
    ShowCharacterItemSheet      = "Показать список предметов персонажа",
    ShowInspectItemSheet        = "Показать окрашенный предметов персонажа",
    ShowOwnFrameWhenInspecting  = "Показывать собственную рамку, при осмотре",
    ShowItemStats               = "Показать характеристики преметов",
    DisplayPercentageStats      = "Отображение по процентам характеристик",
    EnablePartyItemLevel        = "Включить уровень предметов группы",
    SendPartyItemLevelToSelf    = "Отправить ур. предметов группы для себя",
    SendPartyItemLevelToParty   = "Отправить ур. предметов, для группы",
    ShowPartySpecialization     = "Показать специализацию группы",
    EnableRaidItemLevel         = "Включить уровень предметов рейда",
    EnableMouseItemLevel        = "Включить уровень предметов по мыши",
    EnableMouseSpecialization   = "Включить специализацию по мыши",
    EnableMouseWeaponLevel      = "Включить уровень оружия по мыши",
    Bag                         = "Сумка",
    Bank                        = "Банк",
    Merchant                    = "Торговец",
    Trade                       = "Обмен",
    Auction                     = "Аукцион",
    AltEquipment                = "ALT экипировка",
    GuildBank                   = "Банк гильдии",
    GuildNews                   = "Новости гильдии",
    PaperDoll                   = "Окно персонажа",
    Chat                        = "Чат",
    --Loot                        = "",
    ShowGemAndEnchant           = "Show Gem And Enchant",
}

BINDING_NAME_InspectRaidFrame = "рамку"