-- Señal mínima (Connect / Fire / Once) para comunicar módulos sin crear dependencias circulares.

export type Connection = { Disconnect: (self: Connection) -> (), Connected: boolean }
export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> Connection,
	Once: (self: Signal, fn: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	_handlers: { [any]: (...any) -> () },
}

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if self.Connected then
		self.Connected = false
		self._signal._handlers[self] = nil
	end
end

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal) :: any
end

function Signal:Connect(fn: (...any) -> ())
	local connection = setmetatable({ Connected = true, _signal = self }, Connection)
	self._handlers[connection] = fn
	return connection
end

function Signal:Once(fn: (...any) -> ())
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...: any)
	for connection, fn in self._handlers do
		if connection.Connected then
			task.spawn(fn, ...)
		end
	end
end

return Signal
