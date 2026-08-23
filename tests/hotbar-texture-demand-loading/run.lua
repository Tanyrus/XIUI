package.path = table.concat({
    './XIUI/?.lua',
    './XIUI/?/init.lua',
    package.path,
}, ';');

local nativeLoadPaths = {};
local failedNativePaths = {};
local nativeFailuresRemaining = {};
local d3dDeviceAvailable = true;
local d3dDeviceRequestCount = 0;

local fakeFfi = {
    C = {
        D3DFMT_A8R8G8B8 = 21,
        D3DPOOL_MANAGED = 1,
        S_OK = 0,
    },
};

fakeFfi.C.D3DXCreateTextureFromFileExA = function(
    _, filePath, _, _, _, _, _, _, _, _, _, _, _, texturePointer)
    table.insert(nativeLoadPaths, filePath);
    local failuresRemaining = nativeFailuresRemaining[filePath] or 0;
    if failuresRemaining > 0 then
        nativeFailuresRemaining[filePath] = failuresRemaining - 1;
        return 1;
    end
    if failedNativePaths[filePath] then
        return 1;
    end
    texturePointer[0] = { filePath = filePath };
    return fakeFfi.C.S_OK;
end

fakeFfi.new = function(typeName, value)
    if typeName == 'IDirect3DTexture8*[1]' then
        return { [0] = nil };
    end
    return value;
end

fakeFfi.cast = function(_, value)
    return value;
end

fakeFfi.cdef = function() end;

package.preload['ffi'] = function()
    return fakeFfi;
end

package.preload['d3d8'] = function()
    return {
        gc_safe_release = function(texture)
            return texture;
        end,
    };
end

package.preload['libs.pngencoder'] = function()
    return {};
end

package.preload['handlers.helpers'] = function()
    return true;
end

package.preload['common'] = function()
    return true;
end

_G.T = function(value)
    return value or {};
end

_G.GetD3D8Device = function()
    d3dDeviceRequestCount = d3dDeviceRequestCount + 1;
    return d3dDeviceAvailable and {} or nil;
end

_G.AshitaCore = {
    GetInstallPath = function()
        return 'C:\\Ashita\\';
    end,
};

_G.ashita = {
    events = {
        register = function() end,
        unregister = function() end,
    },
    fs = {
        get_directory = function(path)
            if path:find('\\spells\\', 1, true) then
                return { '00001.png', '00002.png' };
            end
            if path:find('\\abilities\\', 1, true) then
                return { '00528.png', '00529.png' };
            end
            return {};
        end,
    },
};

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format('%s: expected %s, got %s', message, tostring(expected), tostring(actual)), 2);
    end
end

local tests = {};
local textures = require('modules.hotbar.textures');

local function LoadHotbarModule(display, actions, crossbar)
    display.ClearIconCache = display.ClearIconCache or function() end;
    display.UpdateVisuals = display.UpdateVisuals or function() end;
    actions = actions or { ClearNoIconCache = function() end };
    crossbar = crossbar or {};
    package.loaded['modules.hotbar.init'] = nil;
    package.loaded['libs.dragdrop'] = {
        Update = function() end,
        Render = function() end,
        WasDroppedOutside = function() return false; end,
    };
    package.loaded['libs.imtext'] = {
        SetConfigFromSettings = function() end,
        Reset = function() end,
    };
    package.loaded['modules.hotbar.data'] = { NUM_BARS = 6 };
    package.loaded['modules.hotbar.display'] = display;
    package.loaded['modules.hotbar.actions'] = actions;
    package.loaded['modules.hotbar.macropalette'] = { DrawPalette = function() end };
    package.loaded['modules.hotbar.crossbar'] = crossbar;
    package.loaded['modules.hotbar.controller'] = {
        Initialize = function() end,
        SetSlotActivateCallback = function() end,
        SetBlockingEnabled = function() end,
    };
    package.loaded['modules.hotbar.textures'] = textures;
    package.loaded['config.hotbar'] = { DrawKeybindModal = function() end };
    package.loaded['config.palettemanager'] = { Draw = function() end };
    package.loaded['modules.hotbar.slotrenderer'] = {
        BeginFrame = function() end,
        ClearAllCache = function() end,
    };
    package.loaded['modules.hotbar.petpalette'] = {};
    package.loaded['modules.hotbar.palette'] = {};
    package.loaded['libs.ffxi.macros'] = {
        hide_macro_bar = function() end,
        show_macro_bar = function() end,
        set_controller_hold_to_show = function() end,
    };

    local hotbar = require('modules.hotbar.init');
    hotbar.initialized = true;
    return hotbar;
end

local function LoadActions()
    package.loaded['modules.hotbar.actions'] = nil;
    package.loaded['modules.hotbar.data'] = { jobId = 1 };
    package.loaded['modules.hotbar.database.horizonspells'] = {
        { en = 'Carbuncle', id = 1 },
        { en = 'Cure', id = 2 },
    };
    package.loaded['modules.hotbar.textures'] = textures;
    package.loaded['modules.hotbar.actiondb'] = {
        GetAbilityId = function() return nil; end,
    };
    package.loaded['modules.hotbar.playerdata'] = {};
    package.loaded['modules.hotbar.recast'] = {
        CHARGE_TIMER = {
            STRATAGEM = 1,
            READY = 2,
            QUICK_DRAW = 3,
        },
        GetStratagemCharges = function() return 0; end,
        GetReadyCharges = function() return 0; end,
        GetQuickDrawCharges = function() return 0; end,
    };
    package.loaded['libs.texturemanager'] = {
        ResolveCustomIconPath = function() return nil; end,
    };
    package.loaded['libs.ffxi.macros'] = {
        is_debug_enabled = function() return false; end,
    };
    package.loaded['modules.hotbar.palette'] = {};
    package.loaded['libs.target'] = nil;
    package.preload['libs.target'] = function()
        return {
            GetSubTargetActive = function() return false; end,
            HasMainTarget = function() return false; end,
        };
    end;
    return require('modules.hotbar.actions');
end

tests[#tests + 1] = {
    name = 'initialization does not create native textures',
    run = function()
        textures:Initialize();

        assertEqual(#nativeLoadPaths, 0, 'native texture load count');
    end,
};

tests[#tests + 1] = {
    name = 'one D3D device lookup serves a non-empty texture batch',
    run = function()
        textures:ProcessPendingLoads(8);
        assertEqual(d3dDeviceRequestCount, 0, 'device lookups for an empty queue');

        textures:Get('spells00001');
        textures:Get('spells00002');
        textures:ProcessPendingLoads(2);

        assertEqual(d3dDeviceRequestCount, 1, 'device lookups for one texture batch');
    end,
};

tests[#tests + 1] = {
    name = 'requested textures load within the supplied frame budget',
    run = function()
        assertEqual(textures:Get('spells00001'), nil, 'first texture before processing');
        assertEqual(textures:Get('spells00002'), nil, 'second texture before processing');

        textures:ProcessPendingLoads(1);

        assertEqual(#nativeLoadPaths, 1, 'native loads after first frame');
        assert(textures:Get('spells00001'), 'first requested texture was not cached');
        assertEqual(textures:Get('spells00002'), nil, 'second texture exceeded first-frame budget');

        textures:ProcessPendingLoads(1);

        assertEqual(#nativeLoadPaths, 2, 'native loads after second frame');
        assert(textures:Get('spells00002'), 'second requested texture was not cached');
        assertEqual(nativeLoadPaths[1], 'C:\\Ashita\\addons\\XIUI\\assets\\hotbar\\\\spells\\00001.png', 'first loaded path');
        assertEqual(nativeLoadPaths[2], 'C:\\Ashita\\addons\\XIUI\\assets\\hotbar\\\\spells\\00002.png', 'second loaded path');
    end,
};

tests[#tests + 1] = {
    name = 'availability checks do not queue texture loads',
    run = function()
        assertEqual(textures:Has('abilities00528'), true, 'known ability availability');

        textures:ProcessPendingLoads(8);

        assertEqual(#nativeLoadPaths, 0, 'native loads after availability check');
    end,
};

tests[#tests + 1] = {
    name = 'duplicate requests share one native texture load',
    run = function()
        textures:Get('spells00001');
        textures:Get('spells00001');

        textures:ProcessPendingLoads(8);

        assertEqual(#nativeLoadPaths, 1, 'native loads for duplicate requests');
    end,
};

tests[#tests + 1] = {
    name = 'requests added after an exact budget are not discarded',
    run = function()
        textures:Get('spells00001');
        textures:ProcessPendingLoads(1);
        textures:Get('spells00002');
        textures:ProcessPendingLoads(1);

        assertEqual(#nativeLoadPaths, 2, 'native loads across consecutive frames');
        assert(textures:Get('spells00002'), 'second-frame texture was not cached');
    end,
};

tests[#tests + 1] = {
    name = 'transient native failures recover within the retry limit',
    run = function()
        local failedPath = 'C:\\Ashita\\addons\\XIUI\\assets\\hotbar\\abilities\\00529.png';
        nativeFailuresRemaining[failedPath] = 2;

        assertEqual(textures:Get('abilities00529'), nil, 'texture before processing');
        textures:ProcessPendingLoads(1);
        textures:ProcessPendingLoads(1);
        textures:ProcessPendingLoads(1);

        assertEqual(#nativeLoadPaths, 3, 'native attempts before recovery');
        assert(textures:Get('abilities00529'), 'texture did not recover after transient failures');
    end,
};

tests[#tests + 1] = {
    name = 'permanent native failures stop after the retry limit',
    run = function()
        local failedPath = 'C:\\Ashita\\addons\\XIUI\\assets\\hotbar\\abilities\\00529.png';
        failedNativePaths[failedPath] = true;

        textures:Get('abilities00529');
        for _ = 1, 5 do
            textures:ProcessPendingLoads(1);
        end

        assertEqual(#nativeLoadPaths, 3, 'native attempts for a permanent failure');
        assertEqual(select(2, textures:Get('abilities00529')), 'failed', 'terminal texture state');
    end,
};

tests[#tests + 1] = {
    name = 'requests wait for a temporarily unavailable D3D device',
    run = function()
        textures:Get('spells00001');
        d3dDeviceAvailable = false;

        local loadedCount, resolvedCount = 0, 0;
        for _ = 1, 5 do
            loadedCount, resolvedCount = textures:ProcessPendingLoads(1);
        end
        assertEqual(loadedCount, 0, 'loads without a D3D device');
        assertEqual(resolvedCount, 0, 'resolved requests without a D3D device');
        assertEqual(#nativeLoadPaths, 0, 'native calls without a D3D device');

        d3dDeviceAvailable = true;
        textures:ProcessPendingLoads(1);

        assertEqual(#nativeLoadPaths, 1, 'native calls after the device returned');
        assert(textures:Get('spells00001'), 'request did not resume after the device returned');
    end,
};

tests[#tests + 1] = {
    name = 'changing a request scope discards only obsolete scoped work',
    run = function()
        textures:SetRequestScope('icon_picker', 'page:1');
        textures:Get('spells00001', 'icon_picker');
        textures:Get('abilities00528');

        textures:SetRequestScope('icon_picker', 'page:2');
        textures:Get('spells00002', 'icon_picker');
        textures:ProcessPendingLoads(8);

        assertEqual(#nativeLoadPaths, 2, 'loads after changing picker scope');
        assertEqual(nativeLoadPaths[1], 'C:\\Ashita\\addons\\XIUI\\assets\\hotbar\\abilities\\00528.png', 'persistent request path');
        assertEqual(nativeLoadPaths[2], 'C:\\Ashita\\addons\\XIUI\\assets\\hotbar\\\\spells\\00002.png', 'current picker request path');
    end,
};

tests[#tests + 1] = {
    name = 'pending preferred icons do not queue lower-priority fallbacks',
    run = function()
        local actions = LoadActions();

        local icon, _, iconState = actions.GetBindIcon({ actionType = 'ma', action = 'Carbuncle' });
        assertEqual(icon, nil, 'pending preferred icon');
        if iconState ~= textures.State.PENDING then
            textures:Get('spells00001');
        end
        textures:ProcessPendingLoads(8);

        assertEqual(#nativeLoadPaths, 1, 'native loads for one preferred icon');
        assert(nativeLoadPaths[1]:find('SMN\\Carbuncle.png', 1, true), 'preferred summon path');
    end,
};

tests[#tests + 1] = {
    name = 'pending icons are not stored in the action negative cache',
    run = function()
        local actions = LoadActions();

        assertEqual(actions.GetBindIcon({ actionType = 'ma', action = 'Cure' }), nil, 'pending native spell icon');
        textures:ProcessPendingLoads(1);

        assert(actions.GetBindIcon({ actionType = 'ma', action = 'Cure' }), 'loaded icon remained negative-cached');
    end,
};

tests[#tests + 1] = {
    name = 'terminal preferred-icon failures resolve to native fallbacks',
    run = function()
        local preferredPath = 'C:\\Ashita\\addons\\XIUI\\assets\\hotbar\\SMN\\Carbuncle.png';
        failedNativePaths[preferredPath] = true;
        local actions = LoadActions();
        local iconCacheSet = false;
        local cachedIcon = nil;
        local display = {
            DrawWindow = function()
                if not iconCacheSet then
                    cachedIcon = actions.GetBindIcon({ actionType = 'ma', action = 'Carbuncle' });
                    iconCacheSet = true;
                end
            end,
            HideWindow = function() end,
            ClearIconCache = function()
                iconCacheSet = false;
            end,
        };
        local hotbar = LoadHotbarModule(display, actions);
        gConfig = { hotbarEnabled = true, hotbarCrossbar = { mode = 'hotbar' } };

        for _ = 1, 5 do
            hotbar.DrawWindow({});
        end

        assert(cachedIcon, 'native fallback did not replace the failed preferred icon');
        assertEqual(#nativeLoadPaths, 4, 'preferred attempts plus one native fallback');
        assert(nativeLoadPaths[4]:find('spells\\00001.png', 1, true), 'native fallback path');
    end,
};

tests[#tests + 1] = {
    name = 'ability catalog enumeration does not request native textures',
    run = function()
        local abilityCatalog = require('modules.hotbar.abilitycatalog');
        local abilities = {
            [528] = { Id = 528, Type = 1, Name = { 'Mighty Strikes' } },
            [529] = { Id = 529, Type = 3, Name = { 'Fast Blade' } },
        };
        local resourceManager = {
            GetAbilityById = function(_, id)
                return abilities[id];
            end,
        };
        local playerdata = {
            IsGarbageSpellName = function() return false; end,
        };

        local catalog = abilityCatalog.GetAll(resourceManager, textures, playerdata);
        textures:ProcessPendingLoads(8);

        assertEqual(#catalog, 1, 'ability catalog size');
        assertEqual(catalog[1].name, 'Mighty Strikes', 'catalog ability name');
        assertEqual(catalog[1].iconKey, 'abilities00528', 'catalog icon key');
        assertEqual(#nativeLoadPaths, 0, 'native loads during ability enumeration');
    end,
};

tests[#tests + 1] = {
    name = 'Hotbar frames load requested textures incrementally',
    run = function()
        local requestedKeys = {
            'spells00001', 'spells00002', 'abilities00528', 'abilities00529',
            'controller_UP', 'controller_DOWN', 'summon_Carbuncle',
            'trust_ajido-marujido', 'cmd_attack', 'ui_refresh',
        };
        local display = {
            DrawWindow = function()
                for _, key in ipairs(requestedKeys) do
                    textures:Get(key);
                end
            end,
            HideWindow = function() end,
        };
        local hotbar = LoadHotbarModule(display);
        gConfig = { hotbarEnabled = true, hotbarCrossbar = { mode = 'hotbar' } };

        hotbar.DrawWindow({});
        assertEqual(#nativeLoadPaths, 0, 'native loads on request frame');

        hotbar.DrawWindow({});
        assertEqual(#nativeLoadPaths, 8, 'native loads on first processing frame');

        hotbar.DrawWindow({});
        assertEqual(#nativeLoadPaths, 10, 'native loads on second processing frame');
    end,
};

tests[#tests + 1] = {
    name = 'newly loaded textures invalidate cached text fallbacks',
    run = function()
        local iconCacheSet = false;
        local cachedIcon = nil;
        local display = {
            DrawWindow = function()
                if not iconCacheSet then
                    cachedIcon = textures:Get('spells00001');
                    iconCacheSet = true;
                end
            end,
            HideWindow = function() end,
            ClearIconCache = function()
                iconCacheSet = false;
            end,
        };
        local hotbar = LoadHotbarModule(display);
        gConfig = { hotbarEnabled = true, hotbarCrossbar = { mode = 'hotbar' } };

        hotbar.DrawWindow({});
        assertEqual(cachedIcon, nil, 'icon on request frame');

        hotbar.DrawWindow({});

        assert(cachedIcon, 'loaded icon did not replace cached text fallback');
    end,
};

tests[#tests + 1] = {
    name = 'newly loaded textures invalidate cached crossbar fallbacks',
    run = function()
        local iconCacheSet = false;
        local cachedIcon = nil;
        local crossbar = {
            Initialize = function() end,
            DrawWindow = function()
                if not iconCacheSet then
                    cachedIcon = textures:Get('spells00001');
                    iconCacheSet = true;
                end
            end,
            ClearIconCache = function()
                iconCacheSet = false;
            end,
            SetHidden = function() end,
        };
        local hotbar = LoadHotbarModule({
            DrawWindow = function() end,
            HideWindow = function() end,
        }, nil, crossbar);
        gConfig = {
            hotbarEnabled = true,
            hotbarGlobal = {},
            hotbarCrossbar = { mode = 'crossbar' },
        };
        gAdjustedSettings = { crossbarSettings = {} };
        hotbar.UpdateVisuals({});

        hotbar.DrawWindow({});
        assertEqual(cachedIcon, nil, 'crossbar icon on request frame');

        hotbar.DrawWindow({});

        assert(cachedIcon, 'loaded icon did not replace cached crossbar fallback');
    end,
};

tests[#tests + 1] = {
    name = 'disabled Hotbar does not initialize its texture catalog',
    run = function()
        textures:Release();
        local hotbar = LoadHotbarModule({
            DrawWindow = function()
                error('disabled Hotbar attempted to draw');
            end,
            HideWindow = function() end,
        });
        gConfig = { hotbarEnabled = false, hotbarCrossbar = { mode = 'hotbar' } };

        hotbar.DrawWindow({});

        assertEqual(textures.Cache, nil, 'texture catalog while Hotbar is disabled');
        assertEqual(#nativeLoadPaths, 0, 'native loads while Hotbar is disabled');
    end,
};

local passed = 0;
local failed = 0;
for _, test in ipairs(tests) do
    textures:Release();
    nativeLoadPaths = {};
    failedNativePaths = {};
    nativeFailuresRemaining = {};
    d3dDeviceAvailable = true;
    d3dDeviceRequestCount = 0;
    textures:Initialize();
    local ok, err = pcall(test.run);
    if not ok then
        io.stderr:write(string.format('FAIL %s\n%s\n', test.name, err));
        failed = failed + 1;
    else
        passed = passed + 1;
        print('PASS ' .. test.name);
    end
end

if failed > 0 then
    error(string.format('%d Hotbar texture demand-loading test(s) failed', failed));
end
print(string.format('%d Hotbar texture demand-loading tests passed', passed));
