-- Please do not modify, change, or repost without the owner's permission. Thank you.

-- BeastZ Audio Player -- BeamMP server relay plugin.
--
-- Rebroadcasts short playback-state pings between synced clients so that
-- each player's driving music can be heard (positionally, on the receiving
-- client) by everyone else. Holds no playback state of its own: every
-- message is a stateless validate-then-fan-out. Install by placing this
-- BAP/ folder inside Resources/Server/ on the BeamMP server.

local PLUGIN_NAME    = "BAP"
local PLUGIN_VERSION = "1.0"
local EVENT_NAME      = "bap"      -- shared with the client; do not change independently

local PAYLOAD_BYTE_LIMIT = 2000    -- a real "state" payload is well under 100 bytes
local EVENTS_PER_SECOND  = 10      -- per-connection ceiling
local KNOWN_ACTIONS = { state = true, syncreq = true }

--------------------------------------------------------------------------
-- Relay: tracks which connections have completed the BAP handshake
-- (onPlayerJoin) and fans a message out to every other synced connection.
--------------------------------------------------------------------------
local Relay = { synced = {} }

function Relay:markSynced(playerId)
    self.synced[playerId] = true
end

function Relay:markLeft(playerId)
    self.synced[playerId] = nil
end

function Relay:isSynced(playerId)
    return self.synced[playerId] == true
end

function Relay:fanOut(senderId, eventName, wireData)
    local senderNum = tonumber(senderId)
    for pid in pairs(MP.GetPlayers() or {}) do
        if pid ~= senderNum and self:isSynced(pid) then
            MP.TriggerClientEvent(pid, eventName, wireData)
        end
    end
end

--------------------------------------------------------------------------
-- Throttle: a fixed 1-second window per player, reset lazily the first
-- time a message arrives after the previous window has elapsed (no timer
-- needed).
--------------------------------------------------------------------------
local Throttle = { windows = {} }

function Throttle:allow(playerId)
    local now = os.time()
    local w = self.windows[playerId]
    if not w or now > w.expiresAt then
        self.windows[playerId] = { seen = 1, expiresAt = now + 1 }
        return true
    end
    w.seen = w.seen + 1
    return w.seen <= EVENTS_PER_SECOND
end

--------------------------------------------------------------------------
-- Wire format: "<vehicleIndex>|<action>|<payload>"
-- Pure validation, no side effects, so it can be reasoned about (and
-- unit-exercised) independently of the relay/throttle state above.
--------------------------------------------------------------------------
local function parseEnvelope(raw)
    if type(raw) ~= "string" or raw == "" then
        return nil, "empty payload"
    end
    if #raw > PAYLOAD_BYTE_LIMIT then
        return nil, "oversized payload (" .. #raw .. " bytes)"
    end
    local vehicleIndex, action, payload = raw:match("^([^|]*)|([^|]*)|(.*)$")
    if not vehicleIndex then
        return nil, "malformed envelope"
    end
    -- Fixed reason string only -- never echoes the attacker-supplied action
    -- text back into the server log (see PHASE3_REPORT.md).
    if not KNOWN_ACTIONS[action] then
        return nil, "unknown action"
    end
    if tonumber(vehicleIndex) == nil then
        return nil, "non-numeric vehicle index"
    end
    return vehicleIndex, action, payload
end

--------------------------------------------------------------------------
-- BeamMP event handlers
--------------------------------------------------------------------------
function onBap(senderId, raw)
    -- Throttle applies to every incoming event, valid or not -- checking it
    -- before parseEnvelope() closes a gap where a flood of malformed
    -- payloads bypassed the per-connection rate limit entirely (each one
    -- still cheap individually, but unbounded in volume and each producing
    -- a log line; see PHASE3_REPORT.md).
    if not Throttle:allow(tonumber(senderId) or -1) then
        return -- drop silently; logging every throttle hit would itself be noisy
    end

    local vehicleIndex, actionOrReason = parseEnvelope(raw)
    if not vehicleIndex then
        print(("[%s] dropped event from %s: %s"):format(PLUGIN_NAME, tostring(senderId), tostring(actionOrReason)))
        return
    end

    Relay:fanOut(senderId, EVENT_NAME, tostring(senderId) .. "|" .. raw)
end

function onPlayerJoin(playerId)
    Relay:markSynced(playerId)
    print(("[%s] player %s synced"):format(PLUGIN_NAME, tostring(playerId)))
end

function onPlayerDisconnect(playerId)
    Relay:markLeft(playerId)
end

function onInit()
    print(("[%s v%s] starting"):format(PLUGIN_NAME, PLUGIN_VERSION))

    -- BeamMP silently ignores MP.RegisterEvent calls made outside onInit(),
    -- so every registration this plugin needs must happen here.
    MP.RegisterEvent(EVENT_NAME, "onBap")
    MP.RegisterEvent("onPlayerJoin", "onPlayerJoin")
    MP.RegisterEvent("onPlayerDisconnect", "onPlayerDisconnect")

    -- Pick up anyone already connected when the plugin (re)loads.
    for playerId in pairs(MP.GetPlayers() or {}) do
        onPlayerJoin(playerId)
    end

    print(("[%s] ready, relaying '%s' events"):format(PLUGIN_NAME, EVENT_NAME))
end

onInit()
