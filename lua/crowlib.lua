--- Crow standard library

local _crow = {}
local _c = _crow -- alias


--- Library loader
--
local function closelibs()
    -- set whole list of libs to nil to close them
    -- TODO does this free the RAM used by 'dofile'?
    Input  = nil
    Output = nil
    asl    = nil
    asllib = nil
    metro  = nil
    ii     = nil
    cal    = nil
    midi   = nil
end

function _crow.libs( lib )
    if lib == nil then
        -- load all
        Input  = dofile('lua/input.lua')
        Output = dofile('lua/output.lua')
        asl    = dofile('lua/asl.lua')
        asllib = dofile('lua/asllib.lua')
        metro  = dofile('lua/metro.lua')
        ii     = dofile('lua/ii.lua')
        cal    = dofile('lua/calibrate.lua')
        --midi   = dofile('lua/midi.lua')
    elseif type(lib) == 'table' then
        -- load the list 
    else
        if lib == 'close' then closelibs() end
        -- assume string & load single library
    end
end

-- open all libs by default
_crow.libs()

function _crow.reset()
    for n=1,2 do input[n].mode = 'none' end
    for n=1,4 do
        output[n].slew = 0
        output[n].volts = 0
    end
    metro.free_all()
end

--- Communication functions
-- these will be called from norns (or the REPL)
-- they return values wrapped in strings that can be used in Lua directly
-- via dostring

--TODO tell should be in c-fns table, not _crow table?
function _crow.tell( event_name, ... )
    tell( event_name, ... )
end

function get_out( channel )
    _c.tell( 'output', channel, get_state( channel ))
end
function get_cv( channel )
    _c.tell( 'stream', channel, io_get_input( channel ))
end



--- Input
input = {1,2}
for chan = 1, #input do
    input[chan] = Input.new( chan )
end

--- Output
output = {1,2,3,4}
for chan = 1, #output do
    output[chan] = Output.new( chan )
end


--- asl
function toward_handler( id ) end -- do nothing if asl not active
-- if defined, make sure active before setting up actions and banging
if asl then
    toward_handler = function( id )
        output[id].asl:step()
    end
end
-- special wrapper should really be in the ASL lib itself?
function LL_toward( id, d, t, s )
    while type(d) == 'function' do d = d() end
    while type(t) == 'function' do t = t() end
    while type(s) == 'function' do s = s() end
    go_toward( id, d, t, s )
end

function LL_get_state( id )
    return get_state(id)
end


--- ii
-- pullups on by default
ii.pullup(true)

--- follower default actions
ii.self.output = function(chan,val)
    output[chan].volts = val
end

ii.self.slew = function(chan,slew)
    output[chan].slew = slew/1000 -- ms
end


--- True Random Number Generator
-- redefine library function to use stm native rng
math.random = function(a,b)
    if a == nil then return random_float()
    elseif b == nil then return random_int(1,a)
    else return random_int(a,b)
    end
end


--- Syntax extensions
function closure_if_table( f )
    local _f = f
    return function( ... )
            if ... == nil then
                return _f()
            elseif type( ... ) == 'table' then
                local args = ...
                debug_usart('table')
                return function() return _f( table.unpack(args) ) end
            else return _f( ... ) end
        end
end
-- these functions are overloaded with the table->closure functionality
wrapped_fns = { 'math.random'
              , 'math.min'
              , 'math.max'
              }
-- this hack is required to change the identifier (eg math.random) itself(?)
for _,fn in ipairs( wrapped_fns ) do
    load( string.format('%s=closure_if_table(%s)',fn,fn))()
    -- below is original version that didn't work. nb: wrapped_fns was fns not strs
    -- fn = closure_if_table( fn ) -- this *doesn't* redirect the identifier
end

--- Delay execution of a function
-- dynamically assigns metros (clashes with indexed metro syntax)
function delay(action, time, repeats)
    local r = repeats or 1
    local d = {}
    function devent(c)
        if c > 1 then
            action(c-1) -- make the action aware of current iteration
            if c > r then
                metro.free(d.id)
                d = nil
            end
        end
    end
    d = metro.init(devent, time)
    if d then d:start() end
    return d
end

-- empty init function in case userscript doesn't define it
function init() end

-- cleanup all unused lua objects before releasing to the userscript
-- call twice to ensure all finalizers are caught
collectgarbage()
collectgarbage()

return _crow
