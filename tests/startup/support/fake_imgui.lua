local M = {};

local constant_names = {
    'ImGuiChildFlags_None',
    'ImGuiCol_Border',
    'ImGuiCol_BorderShadow',
    'ImGuiCol_Button',
    'ImGuiCol_ButtonActive',
    'ImGuiCol_ButtonHovered',
    'ImGuiCol_CheckMark',
    'ImGuiCol_ChildBg',
    'ImGuiCol_FrameBg',
    'ImGuiCol_FrameBgActive',
    'ImGuiCol_FrameBgHovered',
    'ImGuiCol_Header',
    'ImGuiCol_HeaderActive',
    'ImGuiCol_HeaderHovered',
    'ImGuiCol_PopupBg',
    'ImGuiCol_ResizeGrip',
    'ImGuiCol_ResizeGripActive',
    'ImGuiCol_ResizeGripHovered',
    'ImGuiCol_ScrollbarBg',
    'ImGuiCol_ScrollbarGrab',
    'ImGuiCol_ScrollbarGrabActive',
    'ImGuiCol_ScrollbarGrabHovered',
    'ImGuiCol_Separator',
    'ImGuiCol_Text',
    'ImGuiCol_TextDisabled',
    'ImGuiCol_TitleBg',
    'ImGuiCol_TitleBgActive',
    'ImGuiCol_WindowBg',
    'ImGuiColorEditFlags_AlphaBar',
    'ImGuiColorEditFlags_AlphaPreviewHalf',
    'ImGuiColorEditFlags_NoInputs',
    'ImGuiComboFlags_HeightLargest',
    'ImGuiComboFlags_None',
    'ImGuiCond_Always',
    'ImGuiCond_Appearing',
    'ImGuiCond_FirstUseEver',
    'ImGuiCond_Once',
    'ImGuiHoveredFlags_AllowWhenBlockedByActiveItem',
    'ImGuiHoveredFlags_AllowWhenBlockedByPopup',
    'ImGuiHoveredFlags_AllowWhenOverlapped',
    'ImGuiInputTextFlags_EnterReturnsTrue',
    'ImGuiMouseCursor_Hand',
    'ImGuiSelectableFlags_Disabled',
    'ImGuiSliderFlags_AlwaysClamp',
    'ImGuiStyleVar_Alpha',
    'ImGuiStyleVar_ChildRounding',
    'ImGuiStyleVar_FrameBorderSize',
    'ImGuiStyleVar_FramePadding',
    'ImGuiStyleVar_FrameRounding',
    'ImGuiStyleVar_GrabRounding',
    'ImGuiStyleVar_ItemSpacing',
    'ImGuiStyleVar_PopupRounding',
    'ImGuiStyleVar_ScrollbarRounding',
    'ImGuiStyleVar_WindowBorderSize',
    'ImGuiStyleVar_WindowPadding',
    'ImGuiStyleVar_WindowRounding',
    'ImGuiStyleVar_WindowTitleAlign',
    'ImGuiTreeNodeFlags_DefaultOpen',
    'ImGuiWindowFlags_AlwaysAutoResize',
    'ImGuiWindowFlags_AlwaysVerticalScrollbar',
    'ImGuiWindowFlags_NoBackground',
    'ImGuiWindowFlags_NoBringToFrontOnFocus',
    'ImGuiWindowFlags_NoCollapse',
    'ImGuiWindowFlags_NoDecoration',
    'ImGuiWindowFlags_NoFocusOnAppearing',
    'ImGuiWindowFlags_NoMove',
    'ImGuiWindowFlags_NoNav',
    'ImGuiWindowFlags_NoResize',
    'ImGuiWindowFlags_NoSavedSettings',
    'ImGuiWindowFlags_NoScrollWithMouse',
    'ImGuiWindowFlags_NoScrollbar',
    'ImGuiWindowFlags_NoTitleBar',
    'ImGuiWindowFlags_None',
    'ImDrawCornerFlags_None',
    'ImDrawCornerFlags_TopLeft',
    'ImDrawCornerFlags_TopRight',
    'ImDrawCornerFlags_BotLeft',
    'ImDrawCornerFlags_BotRight',
    'ImDrawCornerFlags_Top',
    'ImDrawCornerFlags_Bot',
    'ImDrawCornerFlags_Left',
    'ImDrawCornerFlags_Right',
    'ImDrawCornerFlags_All',
};

function M.install()
    local previous = {};
    for index, name in ipairs(constant_names) do
        previous[name] = rawget(_G, name);
        _G[name] = index;
    end
    previous.ImGuiChildFlags_Borders = rawget(_G, 'ImGuiChildFlags_Borders');
    _G.ImGuiChildFlags_Borders = nil;

    local imgui = {
        AddFontFromFileTTF = function()
            return nil;
        end,
        BeginChild = function()
            return true;
        end,
        BeginDisabled = function()
        end,
        EndDisabled = function()
        end,
        GetColorU32 = function()
            return 0;
        end,
        GetFont = function()
            return { FontSize = 13 };
        end,
        GetIO = function()
            return {
                DisplaySize = { x = 1920, y = 1080 },
                FontGlobalScale = 1,
                Fonts = {
                    AddFontFromFileTTF = function()
                        return nil;
                    end,
                    Build = function()
                        return true;
                    end,
                },
            };
        end,
        GetStyle = function()
            return { Alpha = 1 };
        end,
        GetTextLineHeight = function()
            return 13;
        end,
        PopStyleVar = function()
        end,
        PushStyleVar = function()
        end,
    };

    return imgui, function()
        for _, name in ipairs(constant_names) do
            _G[name] = previous[name];
        end
        _G.ImGuiChildFlags_Borders = previous.ImGuiChildFlags_Borders;
    end;
end

return M;
