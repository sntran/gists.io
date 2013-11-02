defmodule GistsIO.Cache do
	alias GistsIO.GistClient, as: Gist
	require Lager

	def get_gists(username, page, gister, filter // fn(_) -> true end) do
		key = {:user, username, "gists"}
		per_page = :application.get_env(:gistsio, :gists_per_page, 50)
		cache = Cacherl.lookup(key)
		filtered_gists = case cache do
			{:error, :not_found} ->
				# gists = do_fetch_gists(username, gister)
				{:ok, [{"entries", gists}, {"pager", nil}]} = Gist.fetch_gists(gister, username)
				Cacherl.insert(key, gists)
				gists
			{:ok, gists} -> gists
		end |> Enum.filter(filter)

		paged_gists = Enum.slice(filtered_gists, (page-1) * per_page, per_page) || []
		
		total_page = div(Enum.count(filtered_gists), per_page+1) + 1
		pager = make_pager(page, total_page)
		return = [{"entries", paged_gists}, {"pager", pager}]
		{:ok, return}
	end

	@doc """
	Sequentially fetch all the gists of a user.

	GitHub allows maximum 100 gists per page, and provides pagination details
	in the response header. @see `GistsIO.GistClient.fetch_gists/3.

	This function recursively fetches each page, looking into the pagination
	details, and if there is next page, perform fetch again.

	This is the api. It calls do_fetch_gists/4.
	"""
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
				Lager.error "Error fetching gists for #{username}."
				do_fetch_gists(username, gister, nil, acc)
		end
	end

	@doc """
	Build the suitable pager based on filtered and paged gists.
	"""
	defp make_pager(1, 1) do [] end # single page
	defp make_pager(1, last) do
		# first page of more than one page
		[{"next", 2}, {"last", last}]
	end
	defp make_pager(current, current) do
		# last page
		[{"previous", current-1}, {"first", 1}]
	end
	defp make_pager(current, total) when current > total do [] end # out of range
	defp make_pager(current, total) do
		# any page in between
		[{"previous", current-1}, {"first", 1}, {"next", current+1}, {"last", total}]
	end

	def gists_last_updated(username) do
		key = {:user, username, "gists"}
		Cacherl.last_updated(key)
	end

	def get_gist(gist_id, gister) do
		cache = Cacherl.match({:gist, gist_id, :'$1'}, fn([username]) ->
			# We need to perform a match because there is case where no 
			# username is provided.
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

	@doc """
	Update a cached gist.

	Always overwriting the description. For files, it takes a list
	of file "diff"'s using the format of GitHub's PATCH file's body.
	It will use this "diff" to filter out to-delete files and map
	the changed data to each file.

	It then deletes the old cache and create a new one with updated
	data so that the html calls on the handlers can check for changes.

	@arguments:
	description = binary()
	files = [file]
	file = [{oldname, [{"filename", newname},{"content", content}]}]
	oldname = newname = content = binary()
	"""
	def update_gist(description, files // [], gist) do
		gist_id = gist["id"]
		username = gist["user"]["login"]
		updated_gist = ListDict.put(gist, "description", description)
		current_files = gist["files"]
		updated_gist = if files !== [] do
			new_files = Enum.filter_map(current_files, fn({name, attrs}) ->
				# Keep the file not in the list of files to update
				# or not indicated to be deleted - null value.
				file_to_update = files[name]
				file_to_update === nil or file_to_update !== "null"
			end, fn({name, attrs}) ->
				file_to_update = files[name]
				if (file_to_update !== nil) do
					# We want to update this file
					newname = file_to_update["filename"]
					content = file_to_update["content"]
					new_attrs = ListDict.put(attrs, "filename", newname)
					|> ListDict.put("content", content)
					{newname, new_attrs}
				else
					# Just return the old file.
					{name, attrs}
				end
			end)
			ListDict.put(updated_gist, "files", new_files)
		else
			updated_gist
		end

		gist_key = {:gist, gist_id, username}
		Cacherl.delete(gist_key) # Remove the cache so we can reset the start and lease time
		Cacherl.insert(gist_key, updated_gist)

		gists_key = {:user, username, "gists"}
		case Cacherl.lookup(gists_key) do
			{:ok, cache} ->
				idx = Enum.find_index(cache, &(&1["id"] === updated_gist["id"]))
				new_cache = if (idx === nil) do
					[updated_gist | cache]
				else
					changed_gist = Enum.at(cache, idx)
								|> ListDict.put("description", updated_gist["description"])
					List.replace_at(cache, idx, changed_gist)
				end
				Cacherl.delete(gists_key) # Remove the cache so we can reset the start and lease time
				Cacherl.insert(gists_key, new_cache)
			{:error, :not_found} -> :ok
		end
	end

	def remove_gist(username, gist_id) do
		# Clear the gist's cache.
		gist_key = {:gist, gist_id, username}
		Cacherl.delete(gist_key)
		# Clear associated comments' cache.
		comments_key = {:comments, gist_id}
		Cacherl.delete(comments_key)
		# Remove it from gists list's cache.
		gists_key = {:user, username, "gists"}
		case Cacherl.lookup(gists_key) do
			{:ok, cache} ->
				new_cache = Enum.reject(cache, &(&1["id"] === gist_id))
				Cacherl.delete(gists_key) # Remove the cache so we can reset the start and lease time
				Cacherl.insert(gists_key, new_cache)
			{:error, :not_found} -> :ok
		end
	end

	def gist_last_updated(username, gist_id) do
		key = {:gist, gist_id, username}
		Cacherl.last_updated(key)
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

	def add_comment(comment, gist_id) do
		key = {:comments, gist_id}
		{:ok, cache} = Cacherl.lookup(key)
		Cacherl.insert(key, cache ++ [comment])
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