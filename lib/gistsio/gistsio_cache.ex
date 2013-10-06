defmodule GistsIO.Cache do
	alias GistsIO.GistClient, as: Gist
	require Lager

	def get_gists(username, page, gister) do
		cache = Cacherl.match({:gist, :'$1', username}, fn([id]) -> 
			{:gist, id, username} 
		end)

		case cache do
			[] ->
				Lager.debug "No cached data for user #{username}'s gists. Fetching from service."
				fetch = Gist.fetch_gists(gister, username, [{"page", page}])
				case fetch do
					{:ok, gists} ->
						# Able to fetch from GitHub, cache them
						Enum.each(gists, fn(gist) ->
							key = {:gist, gist["id"], username}
							Cacherl.insert(key, gist)
						end)
						{:ok, gists}
					{:error, error} ->
						Lager.error "Failed to fetch gists for user #{username} from service with #{error}."
						{:error, error}
				end
			gists -> {:ok, gists}
		end
	end

	def get_gist(gist_id, gister) do
		cache = Cacherl.match({:gist, gist_id, :'$1'}, fn([username]) ->
			{:gist, gist_id, username}
		end)

		gist = Enum.at(cache, 0)
		if gist !== nil and gist["history"] do
			Lager.debug "Fetching full data for gist #{gist_id} from cache."
			{:ok, gist}
		else
				# Either no gist found, or the gist is not full - no history data,
				# in which case, it was cached by gists_handler, then we fetch
				# the full gist and cache again.
				Lager.debug "No full cache for gist #{gist_id}. Fetching from service."
				fetch = Gist.fetch_gist(gister, gist_id)
				case fetch do
					{:ok, gist} ->
						username = gist["user"]["login"]
						key = {:gist, gist_id, username}
						Cacherl.insert(key, gist)
						{:ok, gist}
					{:error, error} -> 
						Lager.error "Failed to fetch gist #{gist_id} from service with error #{error}."
						{:error, error}
				end
		end
	end

	def get_comments(gist_id, gister) do
		cache = Cacherl.lookup({:gist, gist_id, "comments"})
		case cache do
			{:error, :not_found} ->
				Lager.debug "No cached comments for gist #{gist_id}. Fetching from service."
				fetch = Gist.fetch_comments(gister, gist_id)
				case fetch do
					{:ok, comments} ->
						Cacherl.insert({:gist, gist_id, "comments"}, comments)
						{:ok, comments}
					{:error, error} ->
						Lager.error "Failed to fetch comments for gist #{gist_id} from service with error #{error}."
						{:error, error}
				end
			{:ok, comments} ->
				Lager.debug "Fetching comments for gist #{gist_id} from cache."
				{:ok, comments}
		end
	end
	
	def get_user(username, gister) do
		cache = Cacherl.lookup({:user, username})
		case cache do
			{:error, :not_found} ->
				Lager.debug "No cached info for user #{username}. Fetching from service."
				fetch = Gist.fetch_user gister, username
				case fetch do
					{:ok, user} ->
						Cacherl.insert({:user, username}, user)
						{:ok, user}
					{:error, error} ->
						Lager.error "Failed to fetch info for user #{username} from service with error #{error}."
						{:error, error}
				end
			{:ok, user} ->
				Lager.debug "Fetching info for user #{username} from cache."
				{:ok, user}
		end
	end

	def get_html(markdown, gister) do
		cache = Cacherl.lookup({:html, markdown})
		case cache do
			{:error, :not_found} ->
				Lager.debug "No cached html for markdown: `#{markdown}`. Calling service to render."
				fetch = Gist.render gister, markdown
				case fetch do
					{:ok, html} ->
						Cacherl.insert({:html, markdown}, html)
						{:ok, html}
					{:error, error} ->
						Lager.error "Failed to render html for markdown: `#{markdown}` from service with error #{error}."
						{:error, error}
				end
			{:ok, html} ->
				Lager.debug "Fetching rendered html for markdown: `#{markdown} from cache."
				{:ok, html}
		end
	end
	
end