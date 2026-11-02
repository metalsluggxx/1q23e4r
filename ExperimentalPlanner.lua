local _, addon = ...
local CF = addon.CF
local P = {}
CF.ExperimentalPlanner = P

-- Pure planning on addon-owned, readable numbers. No client APIs or widgets.
local function copyRows(rows)
    local result = {}
    for i, row in ipairs(rows) do
        local r = {key=row.key, order=row.order or i, effects={}}
        for _, effect in ipairs(row.effects) do
            local e = {}
            for k,v in pairs(effect) do e[k]=v end
            r.effects[#r.effects+1]=e
        end
        result[#result+1]=r
    end
    return result
end

local function readyAt(e, now)
    -- No observation is not evidence of absence. Unknown effects must not
    -- compete with known timers or cause an immediate refresh on activation.
    if not e.expiresAt then return nil end
    return e.expiresAt - math.max(0,e.castTime or 0)
end

local function before(a,b)
    if not b then return true end
    if a.priority ~= b.priority then return a.priority < b.priority end
    if math.abs(a.ready-b.ready) > 0.05 then return a.ready < b.ready end
    if a.order ~= b.order then return a.order < b.order end
    return a.effectKey < b.effectKey
end

function P.Plan(rows, now, count, gcd)
    local model = copyRows(rows)
    local result, clock = {}, now
    gcd = math.max(0.5,gcd or 1.5)
    for step=1,(count or 2) do
        local due, future, earliest
        for _,row in ipairs(model) do
            for _,e in ipairs(row.effects) do
                local ready=readyAt(e,clock)
                local c={targetKey=row.key,effectKey=e.key,priority=e.priority,
                    order=row.order,ready=ready,effect=e,confidence=e.confidence or "unobserved",
                    expiresAt=e.expiresAt}
                if ready and ready <= clock + 0.001 then
                    if before(c,due) then due=c end
                elseif ready and (not earliest or ready < earliest-0.001
                    or (math.abs(ready-earliest)<=0.001 and before(c,future))) then
                    earliest,future=ready,c
                end
            end
        end
        local selected=due or future
        if not selected then break end
        local e=selected.effect
        local start=math.max(clock,selected.ready)
        local castTime=math.max(0,e.castTime or 0)
        selected.startAt=start
        selected.appliesAt=start+castTime
        selected.actionEnd=start+math.max(gcd,castTime)
        selected.spellID=e.spellID
        selected.name=e.name
        selected.duration=e.duration
        selected.effect=nil
        result[#result+1]=selected
        -- A simulated action only changes the simulation, never the live model.
        e.expiresAt=selected.appliesAt+e.duration
        e.confidence="simulated"
        clock=selected.actionEnd
    end
    return result
end

function P.RowPlan(row,globalPlan,now,gcd)
    local r=copyRows({row})[1]
    local result,clock={},now
    for i,action in ipairs(globalPlan) do
        clock=math.max(clock,action.actionEnd)
        if action.targetKey==r.key then
            local item={}
            for k,v in pairs(action) do item[k]=v end
            item.globalIndex=i
            result[#result+1]=item
            for _,e in ipairs(r.effects) do
                if e.key==action.effectKey then
                    e.expiresAt=action.appliesAt+action.duration
                    e.confidence="simulated"
                end
            end
        end
    end
    -- Continue this row after the two global actions. This avoids displaying
    -- an unmarked action at an earlier time than the blue action in its row.
    for _,action in ipairs(P.Plan({r},clock,math.max(0,2-#result),gcd)) do
        result[#result+1]=action
    end
    return result
end
