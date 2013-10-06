defmodule Session.ETS do
	alias :cowboy_req, as: Req
	defrecord State, tid: nil, conf: []

	def init(conf) do
		tid = :ets.new(__MODULE__, [:set, :private])
		{:ok, State.new(tid: tid, conf: conf)}
	end

	def new(state, session_id, _req) do
		:ets.insert_new(state.tid, {session_id, []})
		{:ok, state}
	end

	def set(state, key, value, req) do
		{session_id, _} = Req.meta(:session_id, req)
		session = case :ets.lookup(state.tid, session_id) do
			[{^session_id, existing}] -> existing
			[] -> []
		end
		new_session = List.keystore(session, key, 0, {key, value})
		:true = :ets.insert(state.tid, {session_id, new_session})
		{:ok, state}
	end
	
	def get(state, key, req) do
		{session_id, _} = Req.meta(:session_id, req)
		value = case :ets.lookup(state.tid, session_id) do
			[] -> :undefined
			[{_, session}] -> :proplists.get_value(key, session)
		end
		{value, state}
	end
	
	def delete(state, req) do
		{session_id, _} = Req.meta(:session_id, req)
		:true = :ets.delete(state.tid, session_id)
		{:ok, state}
	end
	
end