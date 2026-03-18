local _, ns = ...

local T = {}
ns.T = T

local issecretvalue = issecretvalue
local issecrettable = issecrettable
local canaccessvalue = canaccessvalue
local ShouldUnitIdentityBeSecret = C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret

do
    function T:IsSecretUnit(unit)
        return ShouldUnitIdentityBeSecret and ShouldUnitIdentityBeSecret(unit)
    end

    function T:NotSecretUnit(unit)
        return not ShouldUnitIdentityBeSecret or not ShouldUnitIdentityBeSecret(unit)
    end

    function T:IsSecretValue(value)
        return issecretvalue and issecretvalue(value)
    end

    function T:IsSecretTable(object)
        return issecrettable and issecrettable(object)
    end

    function T:NotSecretValue(value)
        return not issecretvalue or not issecretvalue(value)
    end

    function T:NotSecretTable(object)
        return not issecrettable or not issecrettable(object)
    end

    function T:CanAccessValue(value)
        return not canaccessvalue or canaccessvalue(value)
    end

    function T:CanNotAccessValue(value)
        return canaccessvalue and not canaccessvalue(value)
    end

    function T:HasSecretValues(object)
        return object.HasSecretValues and object:HasSecretValues()
    end

    function T:NoSecretValues(object)
        return not object.HasSecretValues or not object:HasSecretValues()
    end

    function T:UnitExists(unit)
        if T:IsSecretUnit(unit) then return end
        return unit and UnitExists(unit)
    end

    function T:UnitGUID(unit)
        if T:IsSecretUnit(unit) then return end
        local success, guid = pcall(UnitGUID, unit)
        return success and guid
    end
end

do
    function T:SendChatMessage(...)
        if C_ChatInfo.InChatMessagingLockdown() then return end
        return C_ChatInfo.SendChatMessage(...)
    end

    function T:SendAddonMessage(...)
        if C_ChatInfo.InChatMessagingLockdown() then return end
        return C_ChatInfo.SendAddonMessage(...)
    end
end