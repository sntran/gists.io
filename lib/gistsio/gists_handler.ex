defmodule GistsIO.GistsHandler do
	alias :cowboy_req, as: Req
	alias GistsIO.GistClient, as: Gist
	alias GistsIO.Utils
	alias GistsIO.Cache
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

	def resource_exists(req, _state) do
		case Req.binding :username, req do
			{:undefined, req} -> {:false, req, :index}
			{username, req} -> 
				client = Session.get("gist_client", req)
				{page, req} = Req.qs_val("page", req, "1")
				page = :erlang.binary_to_integer(page)
				case Cache.get_gists(username, page, client, &is_public_markdown/1) do
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

		pager = lc {type, page} inlist gists["pager"], do: {type, "#{path}?page=#{page}"}
		gists = gists["entries"]
		entries = Enum.map(gists, &Utils.prep_gist/1)

		loggedin = case Session.get("is_loggedin", req) do
			:undefined -> false
			result -> result
		end

		# Render author's info on the sidebar
		{:ok, user} = Cache.get_user username, client
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
end