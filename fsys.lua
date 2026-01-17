-- Fsys Module Loader (Clean Version)
-- Server & Client Compatible

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Fsys = {}

-- =========================
-- INTERNAL TABLES
-- =========================
local MODULES = {}
local LOADED = {}
local LOADING = {}
local DEPENDENCIES = {}
local TIMINGS = {}
local LOG = ""

local IS_SERVER = RunService:IsServer()

-- =========================
-- UTILS
-- =========================
local function log(msg, warnToo)
	LOG ..= msg .. "\n"
	if warnToo then
		warn(msg)
	end
end

function Fsys.get_log()
	return LOG
end

local function getCallerName()
	local src = debug.info(3, "s") or "Unknown"
	return src:match("([^/]+)%.lua") or src
end

-- =========================
-- MODULE DISCOVERY
-- =========================
local function scan(folder)
	for _, inst in ipairs(folder:GetDescendants()) do
		if inst:IsA("ModuleScript") then
			MODULES[inst.Name] = inst
		end
	end
end

-- =========================
-- LOADER
-- =========================
function Fsys.load(path)
	local parts = string.split(path, "/")
	local root = table.remove(parts, 1)

	-- dependency tracking
	local caller = getCallerName()
	DEPENDENCIES[caller] = DEPENDENCIES[caller] or {}
	DEPENDENCIES[caller][root] = true

	-- already loaded
	if LOADED[root] then
		return LOADED[root]
	end

	-- loading protection
	while LOADING[root] do
		task.wait()
	end

	LOADING[root] = true

	local module = MODULES[root]
	if not module then
		error(`Fsys: Module "{root}" not found`)
	end

	local start = os.clock()
	local result = require(module)
	TIMINGS[root] = os.clock() - start

	LOADED[root] = result
	LOADING[root] = nil

	log(`[Fsys] Loaded {root} in {math.floor(TIMINGS[root] * 1000)}ms`)

	-- nested path
	for _, key in ipairs(parts) do
		result = result[key]
		if not result then
			error(`Fsys: "{path}" is invalid`)
		end
	end

	return result
end

-- =========================
-- PUBLIC REQUIRE (SAFE)
-- =========================
function Fsys.require(moduleScript)
	local name = moduleScript.Name
	if not LOADED[name] then
		local start = os.clock()
		LOADED[name] = require(moduleScript)
		TIMINGS[name] = os.clock() - start
	end
	return LOADED[name]
end

-- =========================
-- DEBUG
-- =========================
function Fsys.get_dependencies()
	return DEPENDENCIES
end

function Fsys.get_timings()
	return TIMINGS
end

-- =========================
-- INIT
-- =========================
if IS_SERVER then
	scan(ServerScriptService)
end

scan(ReplicatedStorage)

return Fsys
