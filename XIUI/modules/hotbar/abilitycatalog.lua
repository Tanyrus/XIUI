local ABILITY_ID_MIN = 0x200;
local ABILITY_ID_MAX = 0x600;
local NON_MENU_ABILITY_TYPES = {
    [3] = true,
    [4] = true,
    [20] = true,
};

local M = {};

function M.GetAll(resourceManager, textures, playerdata)
    local abilities = {};
    if not resourceManager then
        return abilities;
    end

    local seenNames = {};
    for id = ABILITY_ID_MIN, ABILITY_ID_MAX do
        local ability = resourceManager:GetAbilityById(id);
        if ability and ability.Name and ability.Name[1] and ability.Name[1] ~= '' then
            local name = ability.Name[1];
            local stem = ability.Id and ability.Id ~= 0 and string.format('%05d', ability.Id) or nil;
            local iconKey = stem and ('abilities' .. stem);
            if not NON_MENU_ABILITY_TYPES[ability.Type or 0]
                and not seenNames[name]
                and not playerdata.IsGarbageSpellName(name)
                and iconKey
                and textures:Has(iconKey) then
                seenNames[name] = true;
                abilities[#abilities + 1] = {
                    id = stem,
                    name = name,
                    iconKey = iconKey,
                };
            end
        end
    end

    table.sort(abilities, function(a, b)
        return a.name:lower() < b.name:lower();
    end);
    return abilities;
end

return M;
