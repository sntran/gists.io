defmodule GistsIO.Cache do
	alias GistsIO.GistClient, as: Gist

	def get_gists(gister, username, page) do
		cache = Cacherl.match({:gist, :'$1', username}, fn([id]) -> 
			{:gist, id, username} 
		end)

		case cache do
			[] ->
				# No gists cache for this user
				fetch = Gist.fetch_gists(gister, username, [{"page", page}])
				case fetch do
					{:ok, gists} ->
						# Able to fetch from GitHub, cache them
						Enum.each(gists, fn(gist) ->
							key = {:gist, gist["id"], username}
							Cacherl.insert(key, gist)
						end)
						{:ok, gists}
					{:error, error} -> {:error, error}
				end
			gists -> {:ok, gists}
		end
	end

	def get_gist(gister, gist_id) do
		cache = Cacherl.match({:gist, gist_id, :'$1'}, fn([username]) ->
			{:gist, gist_id, username}
		end)

		case cache do
			[] ->
				fetch = Gist.fetch_gist(gister, gist_id)
				case fetch do
					{:ok, gist} ->
						username = gist["user"]["login"]
						key = {:gist, gist_id, username}
						Cacherl.insert(key, gist)
						{:ok, gist}
					{:error, error} -> {:error, error}
				end
			[gist] -> {:ok, gist}
		end
	end

	def get_user(gister, username) do
		cache = Cacherl.lookup({:user, username})
		case cache do
			{:error, :not_found} ->
				{:ok, user} = Gist.fetch_user gister, username
			{:ok, user} -> 
				Cacherl.insert({:user, username}, user)
				{:ok, user}
		end
	end
end