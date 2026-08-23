package.path = table.concat({
    './XIUI/?.lua',
    './XIUI/?/init.lua',
    package.path,
}, ';');

local nativeLoadPaths = {};
local failedNativePaths = {};

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
    return {};
end

_G.AshitaCore = {
    GetInstallPath = function()
        return 'C:\\Ashita\\';
    end,
};

_G.ashita = {
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

local function LoadHotbarModule(display)
    display.ClearIconCache = display.ClearIconCache or function() end;
    package.loaded['modules.hotbar.init'] = nil;
    package.loaded['libs.dragdrop'] = {
        Update = function() end,
        Render = function() end,
        WasDroppedOutside = function() return false; end,
    };
    package.loaded['libs.imtext'] = {
        SetConfigFromSettings = function() end,
    };
    package.loaded['modules.hotbar.data'] = { NUM_BARS = 6 };
    package.loaded['modules.hotbar.display'] = display;
    package.loaded['modules.hotbar.actions'] = { ClearNoIconCache = function() end };
    package.loaded['modules.hotbar.macropalette'] = { DrawPalette = function() end };
    package.loaded['modules.hotbar.crossbar'] = {};
    package.loaded['modules.hotbar.controller'] = {};
    package.loaded['modules.hotbar.textures'] = textures;
    package.loaded['config.hotbar'] = { DrawKeybindModal = function() end };
    package.loaded['config.palettemanager'] = { Draw = function() end };
    package.loaded['modules.hotbar.slotrenderer'] = { BeginFrame = function() end };
    package.loaded['modules.hotbar.petpalette'] = {};
    package.loaded['modules.hotbar.palette'] = {};
    package.loaded['libs.ffxi.macros'] = {};

    local hotbar = require('modules.hotbar.init');
    hotbar.initialized = true;
    return hotbar;
end

tests[#tests + 1] = {
    name = 'initialization does not create native textures',
    run = function()
        textures:Initialize();

        assertEqual(#nativeLoadPaths, 0, 'native texture load count');
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
    name = 'failed texture loads are not retried every frame',
    run = function()
        local failedPath = 'C:\\Ashita\\addons\\XIUI\\assets\\hotbar\\abilities\\00529.png';
        failedNativePaths[failedPath] = true;

        assertEqual(textures:Get('abilities00529'), nil, 'failed texture before processing');
        textures:ProcessPendingLoads(1);
        assertEqual(textures:Get('abilities00529'), nil, 'failed texture after processing');
        textures:ProcessPendingLoads(1);

        assertEqual(#nativeLoadPaths, 1, 'native loads after repeated failed request');
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
    name = 'disabled Hotbar does not process requested textures',
    run = function()
        textures:Get('spells00001');
        local hotbar = LoadHotbarModule({
            DrawWindow = function()
                error('disabled Hotbar attempted to draw');
            end,
            HideWindow = function() end,
        });
        gConfig = { hotbarEnabled = false, hotbarCrossbar = { mode = 'hotbar' } };

        hotbar.DrawWindow({});

        assertEqual(#nativeLoadPaths, 0, 'native loads while Hotbar is disabled');
    end,
};

local passed = 0;
for _, test in ipairs(tests) do
    textures:Release();
    nativeLoadPaths = {};
    failedNativePaths = {};
    textures:Initialize();
    local ok, err = pcall(test.run);
    if not ok then
        io.stderr:write(string.format('FAIL %s\n%s\n', test.name, err));
        os.exit(1);
    end
    passed = passed + 1;
    print('PASS ' .. test.name);
end

print(string.format('%d Hotbar texture demand-loading tests passed', passed));
