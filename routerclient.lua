-- RouterClient (Clean Version)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Fsys = require(ReplicatedStorage:WaitForChild("Fsys"))
local load = Fsys.load

local SimpleEvents = load("SimpleEvents")
local LoadTimers = require(game.ReplicatedFirst.Load.LoadTimers)

local RouterClient = {}

-- cache: decodedName -> RemoteEvent
local remoteCache = {}

-- cipher vars
local cryptNum
local charset
local charsetIndex

-- build charset once
local function initCharset()
	if charset then return end

	charset = {}
	charsetIndex = {}

	-- A-Z
	for i = 65, 90 do
		table.insert(charset, i)
		charsetIndex[i] = #charset
	end

	-- a-z
	for i = 97, 122 do
		table.insert(charset, i)
		charsetIndex[i] = #charset
	end

	-- /
	table.insert(charset, 47)
	charsetIndex[47] = #charset
end

-- decode encrypted remote name
local function decode(name)
	initCharset()

	local bytes = { string.byte(name, 1, #name) }

	for i, byte in ipairs(bytes) do
		local index = charsetIndex[byte]
		local decodedIndex =
			(index - i - cryptNum - 1 + #charset) % #charset + 1

		bytes[i] = charset[decodedIndex]
	end

	return string.char(unpack(bytes))
end

-- wait until remote is cached
local function getRemote(name)
	while not remoteCache[name] do
		task.wait(0.2)
	end
	return remoteCache[name]
end

-- public api
function RouterClient.get(name)
	return getRemote(name)
end

function RouterClient.get_event(name)
	return getRemote(name)
end

-- init
function RouterClient.init()
	local startTimer, endTimer = LoadTimers.new_misc_consecutive_timers()
	startTimer("router_client_init_wait")

	-- get crypt info from server
	local RemoteInfo = ReplicatedStorage:WaitForChild("RemoteInfo")
	local info = HttpService:JSONDecode(RemoteInfo.Value)

	cryptNum = info.crypt_num

	RemoteInfo.Value = ""
	RemoteInfo:Destroy()

	startTimer("router_client_init")

	-- non-encrypted remotes
	local nonCipher = {}
	for _, name in ipairs(info.noncipher_remotes) do
		nonCipher[name] = true
	end

	-- listen API folder
	SimpleEvents
		.get("ChildAddedPlusExisting", ReplicatedStorage:WaitForChild("API"))
		:connect(function(remote)
			if nonCipher[remote.Name] then
				remoteCache[remote.Name] = remote
			else
				local decoded = decode(remote.Name)
				remoteCache[decoded] = remote
			end
		end)

	endTimer()
end

RouterClient.init()
return RouterClient
