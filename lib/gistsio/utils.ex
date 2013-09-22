defmodule GistsIO.Utils do
	def is_markdown({_name, attrs}) do
		attrs["language"] === "Markdown"
	end

	def prep_gist(gist) do
		{_name, entry} = Enum.at gist["files"], 0
		description = gist["description"]
		{title, teaser} = if description !== "" do
			[title] = Regex.run %r/.*$/m, description
			size = Kernel.byte_size(title)
			<<title :: [size(size), binary], teaser :: binary>> = description
			{title, teaser}
		else
			{entry["filename"], ""}
		end
		gist = ListDict.put(gist, "title", title)
				|> ListDict.put("teaser", teaser)
		
	end
	
end