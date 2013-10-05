defmodule GistsIO.GistsHandler do
	alias :cowboy_req, as: Req
	alias GistsIO.GistClient, as: Gist
	alias GistsIO.Utils, as: Utils
	require EEx

	def init(_transport, _req, []) do
		{:upgrade, :protocol, :cowboy_rest}
	end

	def allowed_methods(req, state) do
		{["GET", "POST"], req, state}
	end

	def content_types_provided(req, state) do
		{[
			{"text/html", :gists_html}
		], req, state}
	end

	def resource_exists(req, state) do
		case Req.binding :username, req do
			{:undefined, req} -> {:false, req, :index}
			{username, req} -> 
				client = Session.get("gist_client", req)
				{page, req} = Req.qs_val("page", req, "1")
				case get_gists(client, username, page) do
					{:error, _} ->
						{:false, req, username}
					{:ok, gists} ->
						{:true, req, gists}
				end
		end
	end

	def content_types_accepted(req, state) do
  		{[
  			{{"application", "x-www-form-urlencoded", []}, :gists_post}
  		], req, state}
  	end

  	def gists_post(req, gist) do
  		client = Session.get("gist_client", req)
  		{:ok, body, req} = Req.body_qs(req)
  		teaser = body["teaser"]
  		title = body["title"]
  		description = "#{title}\n#{teaser}"
  		{files, contents} = extract_files(body)
  		Gist.create_gist client, description, files, contents
        prev_path = Session.get("previous_path", req)
        # Cowboy set status code to be 201 instead of 3xx
        # Browser does not redirect, so we have to set the
        # Refresh header
        req = Req.set_resp_header("Refresh", "0; url=#{prev_path}", req)
  		{{true,prev_path}, req, gist}
  	end

	def gists_html(req, gists) do
		client = Session.get("gist_client", req)
		{username, req} = Req.binding(:username, req)
		{path, req} = Req.path(req)

		# pager = gists["pager"]
		# gists = gists["entries"]
		# pager = map_pager(pager, path)
		pager = []

		{user, entries} = Enum.reduce(gists, {nil, []}, fn(gist, {user, acc}) ->
			cond do # `cond` allows any expression, not just guards
				!is_public_markdown(gist) -> {user, acc}
			  	user === nil ->
					{gist["user"], [Utils.prep_gist(gist) | acc]}
			  	true ->
			  		{user, [Utils.prep_gist(gist) | acc]}
			end
		end)

		loggedin = case Session.get("is_loggedin", req) do
			:undefined -> false
			result -> result
		end

		# Render author's info on the sidebar
		{:ok, user} = get_user client, username
		sidebar_html = [:code.priv_dir(:gistsio), "templates", "sidebar.html.eex"]
				|> Path.join
				|> EEx.eval_file [user: user]

		gists_html = [:code.priv_dir(:gistsio), "templates", "gists.html.eex"]
				|> Path.join
				|> EEx.eval_file [entries: entries, pager: pager]

		html = [:code.priv_dir(:gistsio), "templates", "base.html.eex"]
				|> Path.join
				|> EEx.eval_file [content: gists_html, 
									title: "#{user["login"]}'s gists",
									sidebar: sidebar_html,
									is_loggedin: loggedin]

		{html, req, gists}
	end

	defp get_gists(gister, username, page) do
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
					{:error, Error} -> {:error, Error}
				end
			gists -> {:ok, gists}
		end
	end

	defp get_user(gister, username) do
		cache = Cacherl.lookup({:user, username})
		case cache do
			{:error, :not_found} ->
				{:ok, user} = Gist.fetch_user gister, username
			{:ok, user} -> 
				Cacherl.insert({:user, username}, user)
				{:ok, user}
		end
	end

	defp is_public_markdown(gist) do
		gist["public"] === :true and Enum.any? gist["files"], &Utils.is_markdown/1
	end

	# Takes form data from gist form and extracts
	# lists for the file names and contents
	defp extract_files(data) do
		title = data["title"]
		files = ["#{Regex.replace(%r/ /, title, "_")}.md"]
		contents = [[{"content",data["content"]}]]
		extract_files(data,files,contents)
	end
	defp extract_files([field|[]], files, contents) do
		case field do
			{"filename", file} ->
				{files ++ [file], contents}
			{"file", content} ->
				{files, contents ++ [[{"content",content}]]}
			{_,_} ->
				{files,contents}
		end
	end
	defp extract_files([field|data], files, contents) do
		case field do
			{"filename", file} ->
				extract_files(data, files ++ [file], contents)
			{"file", content} ->
				extract_files(data, files, contents ++ [[{"content",content}]])
			{_,_} ->
				extract_files(data, files, contents)
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
    defp map_pager(nil, _) do [] end
	defp map_pager(binary_pager, prefix) when is_binary(binary_pager) do
		map_pager(:binary.split(binary_pager, ", "), prefix)
	end
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