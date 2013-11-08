defmodule GistsIO.GistsHandler do
	alias :cowboy_req, as: Req
	alias GistsIO.GistClient, as: Gist
	alias GistsIO.Utils
	alias GistsIO.Cache
	require EEx
	require Lager

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
  		max_body_length = :application.get_env(:gistsio, :max_body_length, 8000000)
  		{:ok, body, req} = Req.body_qs(max_body_length, req)
  		title = body["title"]
		filename = "#{title}.md"
        gist_data = Jsonex.decode(body["gist"])
		{teaser, content, files} = Utils.compose_gist(gist_data["data"])
        files = files ++ [{filename, [{"content", content}]}]
  		description = "#{title}\n#{teaser}"
  		{:ok, response} = Gist.create_gist client, description, files
  		gist = Jsonex.decode(response)
  		Cache.update_gist(description, gist)
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

		loggedin = case Session.get("is_loggedin", req) do
			:undefined -> false
			result -> result
		end

		{:ok, html} = if :application.get_env(:gistsio, :use_static_page, false) do
			{page, req} = Req.qs_val("page", req, "1")
			maybe_render_template(username, gists, page, loggedin, client)
		else
			render(username, gists, loggedin, client)
		end
		{html, req, gists}
	end
	
	defp maybe_render_template(username, gists, current_page, loggedin?, client) do
		{dir, html_path} = html_path(username, current_page)
		# Check the time the cache is created
		modified_at = Cache.gists_last_updated(username)
						|> :calendar.gregorian_seconds_to_datetime()
		generated_at = :filelib.last_modified(html_path)
		case modified_at > generated_at do
			true ->
				# The cache is newer than the static file, we render it again.
				Lager.debug "Rendering HTML for #{username}'s gists on page #{current_page}"
				{:ok, html} = render(username, gists, loggedin?, client)
				File.mkdir_p(dir) # Ensure the directory is created
				File.write(html_path, html)
				{:ok, html}
			false ->
				# Cache is older, just serve the static file.
				Lager.debug "Serving static HTML for #{username}'s gists on page #{current_page}"
				File.read(html_path)
		end
	end

	defp render(username, gists, loggedin?, client) do
		pager = lc {type, page} inlist gists["pager"], do: {type, "/#{username}?page=#{page}"}
		gists = gists["entries"]
		entries = Enum.map(gists, &Utils.prep_gist/1)
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
									is_loggedin: loggedin?]
		{:ok, html}
	end

	defp html_path(username, page) do
		{:ok, cwd} = File.cwd()
		dir = :filename.join([cwd, "priv", "static", username])
		{dir, :filename.join([dir, "gists_#{page}.html"])}
	end

	defp is_public_markdown(gist) do
		gist["public"] === :true and Enum.any? gist["files"], &Utils.is_markdown/1
	end
end