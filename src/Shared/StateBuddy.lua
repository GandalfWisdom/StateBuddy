local require = require(script.Parent.loader).load(script);
local Maid = require("Maid");

local StateBuddy = {};
StateBuddy.__index = StateBuddy;
StateBuddy.ClassName = "StateBuddy";

function StateBuddy.new()
    local self = {};
    self._maid = Maid.new();


    return setmetatable(self, StateBuddy);
end;

function StateBuddy:Destroy()
    self._maid:DoCleaning();
    setmetatable(self, nil);
end;

return StateBuddy;