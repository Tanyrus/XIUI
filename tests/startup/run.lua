local ORIGINAL_PACKAGE_PATH = package.path;
package.path = 'tests/startup/?.lua;tests/startup/?/init.lua;XIUI/?.lua;XIUI/?/init.lua;' .. package.path;

local host = require('support.host');

local function expect_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format('%s: expected %s, got %s', message, tostring(expected), tostring(actual)), 2);
    end
end

local function expect_type(actual, expected, message)
    expect_equal(type(actual), expected, message);
end

local tests = {
    {
        name = 'real addon graph registers the load callback',
        run = function()
            host.with_environment({ winmm_available = false }, function(environment)
                environment.load_addon();
                expect_type(environment.get_event('load', 'load_cb'), 'function', 'registered load callback');
            end);
        end,
    },
};

local failed = 0;
for _, test in ipairs(tests) do
    local ok, err = xpcall(test.run, debug.traceback);
    if ok then
        io.write('PASS ', test.name, '\n');
    else
        failed = failed + 1;
        io.stderr:write('FAIL ', test.name, '\n', tostring(err), '\n');
    end
end

package.path = ORIGINAL_PACKAGE_PATH;
if failed ~= 0 then
    error(string.format('%d startup test(s) failed', failed));
end
io.write(string.format('%d startup tests passed\n', #tests));
