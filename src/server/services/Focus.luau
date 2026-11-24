--!strict
-- Focus meter and temptations for trainers during Party Night (design doc: party pressure).
-- Focus is the player's "Focus" attribute (0-100). At 0 the player gives in to the party.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Night = require(ReplicatedStorage.Shared.Night)

type Pending = { kind: Night.TemptationKind, deadline: number, tapsLeft: number }
type State = {
	focus: number,
	nextTemptation: number,
	bassUntil: number,
	pending: { [number]: Pending },
}

local Focus = {}

-- Extra seconds allowed for an answer to travel from the client.
Focus.answerGrace = 0.3

-- Called once when a trainer's focus reaches 0.
function Focus.onBroken(_player: Player) end

local states: { [Player]: State } = {}
local nextId = 0

local remotes = ReplicatedStorage:WaitForChild("RhythmRemotes")
local temptationEvent = Instance.new("RemoteEvent")
temptationEvent.Name = "Temptation" -- server -> client: id, kind, window (seconds)
temptationEvent.Parent = remotes
local answerEvent = Instance.new("RemoteEvent")
answerEvent.Name = "TemptationAnswer" -- client -> server: id
answerEvent.Parent = remotes

local function setFocus(player: Player, state: State, value: number)
	if state.focus <= 0 then
		return
	end
	state.focus = math.max(0, value)
	player:SetAttribute("Focus", state.focus)
	if state.focus == 0 then
		states[player] = nil
		Focus.onBroken(player)
	end
end

-- Drain focus from outside (partier abilities). Returns how much was actually taken.
function Focus.drain(player: Player, amount: number): number
	local state = states[player]
	if not state then
		return 0
	end
	local before = state.focus
	setFocus(player, state, state.focus - amount)
	return before - math.max(0, before - amount)
end

function Focus.begin(player: Player, now: number)
	states[player] = {
		focus = Night.focusStart,
		nextTemptation = now + Night.temptationGap(0),
		bassUntil = 0,
		pending = {},
	}
	player:SetAttribute("Focus", Night.focusStart)
end

function Focus.finish(player: Player)
	states[player] = nil
end

function Focus.isTrainer(player: Player): boolean
	return states[player] ~= nil
end

function Focus.onGrade(player: Player, grade: string)
	local state = states[player]
	if state and grade == "Miss" then
		local bass = os.clock() < state.bassUntil
		setFocus(player, state, state.focus - Night.missDrain * (if bass then 2 else 1))
	end
end

-- Called about once a second by the round; sends each trainer's next temptation when it's due.
function Focus.tick(now: number, progress: number)
	for player, state in states do
		if now < state.nextTemptation then
			continue
		end
		state.nextTemptation = now + Night.temptationGap(progress) * (0.75 + math.random() * 0.5)
		local kind = Night.temptationOrder[math.random(1, #Night.temptationOrder)]
		local spec = Night.temptations[kind]
		nextId += 1
		local id = nextId
		temptationEvent:FireClient(player, id, kind, spec.window)
		if kind == "BassDrop" then
			state.bassUntil = os.clock() + spec.window
			continue
		end
		state.pending[id] =
			{ kind = kind, deadline = os.clock() + spec.window, tapsLeft = spec.taps }
		task.delay(spec.window + Focus.answerGrace, function()
			local current = states[player]
			local pending = current and current.pending[id]
			if current and pending then
				current.pending[id] = nil
				setFocus(player, current, current.focus - spec.drain)
			end
		end)
	end
end

answerEvent.OnServerEvent:Connect(function(player: Player, id: unknown)
	local state = states[player]
	local pending = state and typeof(id) == "number" and state.pending[id]
	if not state or not pending or os.clock() > pending.deadline + Focus.answerGrace then
		return
	end
	pending.tapsLeft -= 1
	if pending.tapsLeft <= 0 then
		state.pending[id :: number] = nil
	end
end)

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

return Focus
