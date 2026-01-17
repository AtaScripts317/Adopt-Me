-- TimerModule.lua

local Timer = {}

-- Active sessions
local sessions = {}
local paused = {}

----------------------------------------------------
-- Internal helpers
----------------------------------------------------

local function addTime(timerType, key, delta)
	for _, session in pairs(sessions) do
		if not paused[session] then
			session[timerType][key] = (session[timerType][key] or 0) + delta
		end
	end
end

----------------------------------------------------
-- Session control
----------------------------------------------------

function Timer.createSession(name)
	sessions[name] = {
		primary = {},
		misc = {}
	}
end

function Timer.removeSession(name)
	sessions[name] = nil
	paused[name] = nil
end

function Timer.pauseSession(name)
	paused[name] = true
end

function Timer.resumeSession(name)
	paused[name] = nil
end

----------------------------------------------------
-- Primary timers
----------------------------------------------------

function Timer.startTimer(key)
	local start = os.clock()
	return function()
		addTime("primary", key, os.clock() - start)
	end
end

function Timer.logTimer(key, value)
	addTime("primary", key, value)
end

function Timer.getPrimary(name)
	return sessions[name] and sessions[name].primary or {}
end

----------------------------------------------------
-- Consecutive timers
----------------------------------------------------

local function consecutive(timerType)
	local lastKey
	local lastTime

	return function(nextKey)
		if lastKey and lastTime then
			addTime(timerType, lastKey, os.clock() - lastTime)
		end
		lastKey = nextKey
		lastTime = os.clock()
	end,
	function()
		if lastKey and lastTime then
			addTime(timerType, lastKey, os.clock() - lastTime)
		end
	end
end

function Timer.newPrimaryConsecutive()
	return consecutive("primary")
end

function Timer.newMiscConsecutive()
	return consecutive("misc")
end

----------------------------------------------------
-- Misc timers
----------------------------------------------------

function Timer.logMisc(key, value)
	addTime("misc", key, value)
end

function Timer.getMisc(name)
	return sessions[name] and sessions[name].misc or {}
end

----------------------------------------------------
-- Formatting
----------------------------------------------------

local function formatTimers(tbl, minValue, sortByValue)
	local list = {}

	for k, v in pairs(tbl) do
		if not minValue or v >= minValue then
			table.insert(list, { key = k, value = v })
		end
	end

	table.sort(list, function(a, b)
		if sortByValue then
			return a.value > b.value
		end
		return a.key < b.key
	end)

	local out = {}
	for _, item in ipairs(list) do
		table.insert(out, string.format("%-30s : %7.3f", item.key, item.value))
	end

	return table.concat(out, "\n")
end

function Timer.getPrimaryString(name)
	return formatTimers(Timer.getPrimary(name))
end

function Timer.getMiscString(name, minValue, sortByValue)
	return formatTimers(Timer.getMisc(name), minValue, sortByValue)
end

----------------------------------------------------
-- Thread tracking (safe)
----------------------------------------------------

function Timer.trackThread(prefix, includeLine, thread)
	thread = thread or coroutine.running()
	local running = true
	local bucket = {}

	task.spawn(function()
		while running and coroutine.status(thread) ~= "dead" do
			local src, line = debug.info(thread, 1, "sl")
			local key = includeLine
				and string.format("%s_%s_%d", prefix, src, line)
				or string.format("%s_%s", prefix, src)

			bucket[key] = (bucket[key] or 0) + task.wait()
		end
	end)

	return function()
		running = false
		for k, v in pairs(bucket) do
			Timer.logMisc(k, v)
		end
	end
end

return Timer
