defmodule Cacherl do
	alias Cacherl.Cache
	alias Cacherl.Store
	@default_lease_time 60*60*24

	@moduledoc """
	The main APIs for the cache system. It provides an interface
	to manipulate the cache without knowing the inner working.
	"""

	@doc """
	Inserts a {key, value} pair into the cache, setting an expiry
	if set. If the cache exists, update it; otherwise, create a
	new cache, and keep track of its pid in the store.
	"""
	def insert(key, value, lease_time \\ @default_lease_time) do
		case Store.lookup(key) do
			{:ok, pid} ->
				Cache.replace(pid, value)
			{:error, _} ->
				{:ok, pid} = Cache.create(value, lease_time)
				Store.insert(key, pid)
		end
	end

	@doc """
	Looks up the value for the key in the cache.

	Acquires the pid of the key from the store, and fetch the value
	from it. Since the cache may expires, which throws exception,
	the function is wrapped in a try... catch.
	"""
	def lookup(key) do
		try do
			{:ok, pid} = Store.lookup(key)
			{:ok, _value} = Cache.fetch(pid)
		rescue
			_ -> {:error, :not_found}
		end
	end

	@doc """
	Looks up for a range of values base on a matcher on the key.

	This is mostly used when the key is any composite data types
	such as list or tuple to keep track a cache for each property
	of a target. For example, we may have a cache for each of the
	user's email and we store with the key `{username, category}`.
	We can then use this to lookup all the emails in a certain
	category.

	This function takes a matcher based on ETS's spec, and since
	the store is a KVS, the matcher needs to apply on the key only
	because the user does not need to know the `pid`. It takes as
	second argument a function that is called on each match. The
	return value of that function will be used as the key to look
	up in a reduce, which returns only found values.

	## Example

		caches = range_lookup({username, :'$1'}, fn([cat]) ->
			# Since we only match one variable, the argument for
			# the `fn` is a list of one element.
			{username, cat}
		end)

	"""
	def match(key_pattern, key_generator) do
		case Store.match({key_pattern, :'_'}) do
			[] -> []
			result -> 
				Enum.reduce(result, [], fn(match, acc) ->
					key = key_generator.(match)
					case Cacherl.lookup(key) do
						{:ok, value} -> [value | acc]
						_ -> acc
					end
				end)
		end
	end

	def keys() do
		Store.match({:'$1', :'_'})
		|> Enum.map(fn([key]) -> key end)
	end

	def last_updated(key) do
		case Store.lookup(key) do
			{:ok, pid} ->
				{:ok, last_updated} = Cache.last_updated(pid)
				last_updated
			{:error, _} -> 0
		end
	end
	
	@doc """
	Delete the cache associated with the provided key.
	"""
	def delete(key) do
		case Store.lookup(key) do
			{:ok, pid} ->
				Cache.delete(pid)
				Store.delete(pid)
			{:error, _reason} ->
				:ok
		end
	end
end