--!strict
local require: any = require(script.Parent.loader).load(script) :: any;
local Maid: any = require("Maid");

local StateBuddy = {};
StateBuddy.__index = StateBuddy;
StateBuddy.ClassName = "StateBuddy";

local id_increment: number = 0;
local current_states: {[string]: string} = {};
--[=[
    A state machine utility class that handles transitions between named states.

    @prop _maid Maid -- Used to manage cleanup.
    @prop _states table<string, StateDefinition> -- All defined states, keyed by name.
    @prop _current_state string? -- The name of the current active state.
    @prop _duration number -- Duration tracker for the current state (if applicable).

]=]

export type StateCallback = (...any) -> string? | boolean?;
export type State = { Name: string, Duration: number?, Enter: StateCallback?, Started: StateCallback?, Completed: StateCallback? };
export type StateBuddy = typeof(setmetatable(
    {} :: {
        _maid: Maid.Maid,
        Name: string,
        _states: { [string]: State },
        state_index_table: { [number]: string },
        _current_state: string,
        _duration: number?,
        _start_time: number,
    },
   {} :: typeof({ __index = StateBuddy })
));

--[=[
    Constructs a new StateBuddy object
    @return StateBuddy
]=]
function StateBuddy.new(object_name: string?): StateBuddy
    local self: StateBuddy = setmetatable({} :: any, StateBuddy);
    self._maid = Maid.new();
    if (object_name == nil) then id_increment += 1; end;
    self.Name = object_name or "StateBuddy"..tostring(id_increment);
    self._states = {};
    self.state_index_table = {};
    self._current_state = "";
    self._duration = 0;

    current_states[self.Name] = self._current_state; --Updates global state table
    return self;
end;

--[=[
    Creates a new state.
    @param state_name string -- Name of the state to be added.
    @param duration number -- The time the state will last. Set this to 0 to last indefinitely.
    @param enter StateCallback -- The function that checks if state can be entered into.
    @param started StateCallback -- The function that runs when state is successfully entered.
    @param completed StateCallback -- The function that runs when state ends. If duration is set, make sure this function returns a string value of the next state.
]=]
function StateBuddy.AddState(self: StateBuddy, state_name: string, duration: number, enter: StateCallback?, started: StateCallback?, completed: StateCallback?): ()
    local is_first_state: boolean = false;
    if (next(self._states) == nil) then is_first_state = true; end;

    self._states[state_name] = {
        Name = state_name;
        Duration = duration;
        Enter = enter;
        Started = started;
        Completed = completed;
    };

    table.insert(self.state_index_table, state_name); -- Adds state to index table, allowing the conversion of state as a number to a state name.
    if (is_first_state == true) then self:ChangeState(state_name); end; -- If it is the first state added, set it as the default state.
end;

--[=[
    Changes state.
    @param state string -- State to change in to.
]=]
function StateBuddy.ChangeState(self: StateBuddy, new_state: string | number, ...: any): ()
    local new_state_string: string;
    if (typeof(new_state) == "number") then 
        new_state_string = self:GetStateFromNumber(new_state);
    else
        new_state_string = new_state;
    end;
    
    if (self._current_state == new_state_string) then return; end; --Guard Clause. Returns if attempting to change to state that the state machine is already in.

    local next_state: State = self._states[new_state_string];
    if not (next_state) then return; end; --Guard Clause. Returns if next_state does not exist.

    local can_enter: boolean? | string? = false;
    if (next_state.Enter) then can_enter = next_state.Enter(...); end;
    if not (can_enter) then return; end; --Enter guard clause.

    local old_state: State? = self._states[self._current_state or ""];
    if (old_state) and (old_state.Completed) then old_state.Completed(...) end; --Run completed function if it exists.

    self._current_state = new_state_string;
    self._duration = next_state.Duration;
    self._start_time = workspace:GetServerTimeNow();
    if (next_state.Started) then next_state.Started(...); end;

    current_states[self.Name] = self._current_state; --Updates global state table
end;

--[=[
    Updates state machine. Used only when state has a duration above 0.
]=]
function StateBuddy.Update(self: StateBuddy): ()
    if not (self._current_state) or (self._current_state == "") then return; end;
    local state_current: State = self._states[self._current_state];
    if (state_current.Duration == 0) or (state_current.Duration == nil) then return; end; --Guard clause. If duration is 0 or nil, return.

    local time_now: number = workspace:GetServerTimeNow();
    if (time_now - self._start_time >= state_current.Duration) then
        assert(state_current.Completed, "No completed function present! Make sure functions with a duration value have a completed function!");
        assert(typeof(state_current.Completed()) == "string", "Returned value from .Completed() function is not a string!");
        
        self:ChangeState(state_current.Completed() :: string);
    end;
end;

--[=[
    Gets the current global state of an object name.
    @param buddy_name string -- The name of the StateBuddy object to check.
    @return string?
]=]
function StateBuddy.GetBuddyState(buddy_name: string): string?
    if not (current_states[buddy_name]) then return; end;
    return current_states[buddy_name];
end;

--[=[
    Gets the state as a string when given a number. Used for packing bits in replication systems. 
    @param number number -- State index as a number.
    @return string -- Returns the state as a string.
]=]
function StateBuddy.GetStateFromNumber(self: StateBuddy, number: number): string
    return self.state_index_table[number] or "Idle";
end;
--[=[
    Gets the state as a number when given a state name string. Used for packing bits in replication systems. 
    @param state_name string -- State name as a string.
    @return number -- Returns the state as a number.
]=]
function StateBuddy.GetIndexFromName(self: StateBuddy, state_name: string): number
    local state_index: number = 0;
    for index, name in ipairs(self.state_index_table) do
        if (state_name == name) then state_index = index; break; end;
    end;
    return state_index;
end;

--[=[
    Cleans up the class object and sets the metatable to nil
]=]
function StateBuddy.Destroy(self: StateBuddy): ()
    current_states[self.Name] = nil;
    id_increment -= 1;
    self._maid:DoCleaning();
    setmetatable(self :: any, nil);
end;

return StateBuddy;