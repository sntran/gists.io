defmodule Cacherl.Cache do
	use GenServer.Behaviour

	defrecord Cache, value: nil, lease_time: :infinity, start_time: nil

	def start_link(value, lease_time) do
		:gen_server.start_link(__MODULE__, [value, lease_time], [])
	end

	def create(value, lease_time // :infinity) do
		Cacherl.Manager.start_child(value, lease_time)
	end
	
	def fetch(pid) do
		:gen_server.call(pid, :fetch)
	end

	def replace(pid, value) do
		:gen_server.cast(pid, {:replace, value})
	end

	def delete(pid) do
		:gen_server.cast(pid, :delete)
	end

	def time_left(pid) do
		:gen_server.call(pid, :time_left)
	end

	def last_updated(pid) do
		:gen_server.call(pid, :last_updated)
	end
	
	def init([value, lease_time]) do
		start_time = get_current_time()
		# Store the data, and set a timeout for this cache.
		# After the lease time, a message will be sent to this process,
		# and handle_info/1 will shut down the process.
		cache = Cache.new(value: value, 
						lease_time: lease_time,
						start_time: start_time)
		{:ok, cache, time_left(start_time, lease_time)}
	end
	
	def handle_call(:fetch, _from, cache = Cache[value: value, 
												lease_time: lease_time, 
												start_time: start_time]) do
		time_left = time_left(start_time, lease_time)
		{:reply, {:ok, value}, cache, time_left}
	end

	def handle_call(:time_left, _, cache = Cache[lease_time: lease_time, 
													start_time: start_time]) do
		time_left = time_left(start_time, lease_time)
		{:reply, {:ok, time_left}, cache, time_left}
	end

	def handle_call(:last_updated, _, cache = Cache[start_time: start_time,
													lease_time: lease_time]) do
		time_left = time_left(start_time, lease_time)
		{:reply, {:ok, start_time}, cache, time_left}
	end
	
	def handle_cast({:replace, value}, cache = Cache[lease_time: lease_time, 
											start_time: start_time]) do
		time_left = time_left(start_time, lease_time)
		{:noreply, cache.value(value), time_left}
		
	end

	def handle_cast(:delete, cache) do
		{:stop, :normal, cache}
	end
	
	def handle_info(:timeout, cache) do
		{:stop, :normal, cache}
	end

	def terminate(_reason, _cache) do
		Cacherl.Store.delete(:erlang.self())
		:ok
	end
	
	defp get_current_time do
		:calendar.local_time() 
		|> :calendar.datetime_to_gregorian_seconds()
	end

	defp time_left(_start_time, :infinity) do
		:infinity
	end
	defp time_left(start_time, lease_time) do
		current_time = get_current_time()
		time_elapsed = current_time - start_time
		case lease_time - time_elapsed do
			time when time <= 0 -> 0
			time -> time * 1000
		end
	end
	
end