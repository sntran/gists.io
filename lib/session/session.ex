defmodule Session do
	use GenServer.Behaviour
	alias :cowboy_req, as: Req
	alias :erlang, as: E

	defrecord SessionRec, store: nil, state: nil

	def start_link() do
		case :application.get_env(:sessions) do
			# Get the environment for session for the current application.
			# If no config, ignore the creation of this gen_server.
			:undefined -> :ignore
			{:ok, config} -> 
				:gen_server.start_link({:local, __MODULE__}, __MODULE__, config, [])
		end
	end

	def new(req) do
		{existing, req} = Req.cookie("session_id", req)
		session_id = case existing do
			:undefined -> new_id()
			_ -> existing
		end
		req = Req.set_resp_cookie("session_id", session_id, [], req)
		req = Req.set_meta(:session_id, session_id, req)
		:gen_server.call(__MODULE__, {:new, [session_id, req]})
		req
	end

	#-spec set(any(), any(), cowboy_req:req()) -> any().
	def set(key, value, req) do
		:gen_server.call(__MODULE__, {:set, [key, value, req]})
	end

	# @doc Gets a value from the session.
	#-spec get(any(), cowboy_req:req()) -> any().
	def get(key, req) do
		:gen_server.call(__MODULE__, {:get, [key, req]})
	end

	# @doc Deletes a session.
	#-spec delete(cowboy_req:req()) -> any().
	def delete(req) do
		:gen_server.call(__MODULE__, {:delete, [req]})
	end

	## Callbacks
	def init(config) do
		{store, conf} = config[:store] || {Session.ETS, []}
		{:ok, state} = store.init(conf)
		{:ok, SessionRec.new(store: store, state: state)}
	end

	# @doc Delegates the call to the configured session store module.
	def handle_call({f, a}, _from, session = SessionRec[store: m, state: state]) do
		{ret, new_state} = apply(m, f, [state | a])
		{:reply, ret, session.state(new_state)}
	end

	## Internal
	defp new_id() do
		data = E.term_to_binary([E.make_ref(), E.now(), :random.uniform()])
		sha = :binary.decode_unsigned(:crypto.hash(:sha, data))
		E.list_to_binary(:lists.flatten(:io_lib.format("~40.16.0b", [sha])))
	end
end