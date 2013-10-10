defmodule GistsIO.Cache do
	alias GistsIO.GistClient, as: Gist
	require Lager
	@per_page :application.get_env(:gistsio, :gists_per_page, 30)

	def get_gists(username, page, gister, filter // fn(_) -> true end) do
		key = {:user, username, "gists"}
		cache = Cacherl.lookup(key)
		paged_gists = (case cache do
			{:error, :not_found} ->
				gists = do_fetch_gists(username, gister)
				Cacherl.insert(key, gists)
				gists
			{:ok, gists} -> gists
		end |> Enum.filter(filter)
			|> Enum.slice((page-1) * @per_page, @per_page)) || []
		
		{:ok, paged_gists}
	end

	defp do_fetch_gists(username, gister) do
		do_fetch_gists(username, gister, 1, [])
	end
	defp do_fetch_gists(_username, _gister, nil, acc) do acc end
	defp do_fetch_gists(username, gister, page, acc) do
		case Gist.fetch_gists(gister, username, [{"page", page}]) do 
			{:ok, [{"entries", gists}, {"pager", nil}]} ->
				# Only one page on GitHub
				do_fetch_gists(username, gister, nil, acc++gists)
			{:ok, [{"entries", gists}, {"pager", pager}]} ->
				pager = map_pager(pager)
				cond do
				pager["last"] === nil ->
					# We are at the last page
					do_fetch_gists(username, gister, nil, acc++gists)
				true ->
					do_fetch_gists(username, gister, page+1, acc ++ gists)
				end
			{:error, _} ->
				do_fetch_gists(username, gister, page+1, acc)
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
		cache = Cacherl.lookup({:comments, gist_id})
		case cache do
			{:error, :not_found} ->
				Lager.debug "No cached comments for gist #{gist_id}. Fetching from service."
				fetch = Gist.fetch_comments(gister, gist_id)
				case fetch do
					{:ok, comments} ->
						Cacherl.insert({:comments, gist_id}, comments)
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

	# Convert the pager header from GitHub to a format suitable to display.
	# It takes a binary string of format
	# "<h../gists?page=3>; rel=\"next\", 
    #  <h.../gists?page=6>; rel=\"last\"; 
    #  <h.../?page=1; rel=\"first\";
    #  <h.../?page=2; rel=\"prev\""
    # split it by the comma, and try to get the page query string and the
    # rel to indicate the type.
	defp map_pager(binary_pager, prefix // "") when is_binary(binary_pager) do
		map_pager(:binary.split(binary_pager, ", "), prefix)
	end
    defp map_pager(nil, _) do [] end
	defp map_pager([], _) do [] end
	defp map_pager([page | rest], prefix) do
		{pos, len} = :binary.match(page, "page=")
		page_number = :binary.part(page, pos + len, 1)
		{pos, len} = :binary.match(page, "rel=\"")
		type = :binary.part(page, pos+len, 4)
		pager = {type, "#{prefix}?page=#{page_number}"}
		[pager | map_pager(rest, prefix)]
	end
	
end