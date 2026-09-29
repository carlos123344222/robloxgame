--!strict
-- Minimal pure-Luau signal. Handlers run synchronously in connection order.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, handler: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	DisconnectAll: (self: Signal) -> (),
}

type Node = { Handler: (...any) -> (), Connection: Connection }

local Signal = {}
Signal.__index = Signal

type SignalImpl = Signal & { _nodes: { Node } }

function Signal.new(): Signal
	local self = setmetatable({ _nodes = {} }, Signal)
	return (self :: any) :: Signal
end

function Signal.Connect(self: SignalImpl, handler: (...any) -> ()): Connection
	local nodes = self._nodes
	local connection: Connection
	connection = {
		Connected = true,
		Disconnect = function(conn: Connection)
			if not conn.Connected then
				return
			end
			conn.Connected = false
			for i, node in nodes do
				if node.Connection == conn then
					table.remove(nodes, i)
					break
				end
			end
		end,
	}
	table.insert(nodes, { Handler = handler, Connection = connection })
	return connection
end

function Signal.Fire(self: SignalImpl, ...: any)
	-- Snapshot so handlers may disconnect (or connect) while we iterate.
	local snapshot = table.clone(self._nodes)
	for _, node in snapshot do
		if node.Connection.Connected then
			local ok, err = pcall(node.Handler :: (...any) -> any, ...)
			if not ok then
				warn("[Signal] handler error: " .. tostring(err))
			end
		end
	end
end

function Signal.DisconnectAll(self: SignalImpl)
	for _, node in table.clone(self._nodes) do
		node.Connection:Disconnect()
	end
end

return Signal
