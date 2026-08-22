local M = {};

function M.new()
    return {
        device = nil,
        texture = { image = nil },
        gc_safe_release = function(value)
            return value;
        end,
    };
end

return M;
