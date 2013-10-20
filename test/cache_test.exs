defmodule GistTest do
    use ExUnit.Case, async: true
    alias GistsIO.Cache, as: Cache

    @gist_id "5180107"
    @username "sntran"
    @unchanged_file [
        {"filename", "filename with space and different attrs order"},
        {"content", "Some content"},
        {"language", "Erlang"}
    ]
    @key {:gist, @gist_id, @username}

    setup do
        old_description = "Old Description"
        gist = get_gist(old_description)
        Cacherl.insert(@key, gist)
        {:ok, cache} = Cacherl.lookup(@key)
        assert cache === gist
        {:ok, gist: gist}
    end

    test "update a description in existing gist", meta do
        gist = meta[:gist]
        old_description = gist["description"]
        new_description = "New Description"
        Cache.update_gist(new_description, gist)
        {:ok, cache} = Cacherl.lookup(@key)
        refute cache["description"] === old_description
        assert cache["description"] === new_description
    end

    test "update a file content in existing gist", meta do
        gist = meta[:gist]
        description = gist["description"]
        old_file = gist["files"]["file1"]
        old_file_content = old_file["content"]
        new_file_content = "New File Content"
        new_files = [
            {"file1", [{"filename", "file1"}, {"content", new_file_content}]}
        ]
        Cache.update_gist(description, new_files, gist)
        {:ok, cache} = Cacherl.lookup(@key)
        updated_file = cache["files"]["file1"]
        refute updated_file["content"] === old_file_content
        assert updated_file["content"] === new_file_content

    end

    test "rename a file with new content in existing gist", meta do
        gist = meta[:gist]
        new_description = "New Description"
        new_file_content = "New File Content"
        new_file_name = "new name"
        new_files = [
            {"file1", [{"filename", new_file_name}, {"content", new_file_content}]}
        ]

        Cache.update_gist(new_description, new_files, gist)
        {:ok, cache} = Cacherl.lookup(@key)
        refute cache === gist
        assert cache["id"] === @gist_id
        assert cache["user"]["login"] === @username
        assert cache["description"] === new_description
        files = cache["files"]
        assert files["filename with space and different attrs order"] === @unchanged_file
        assert files["file1"] === nil
        new_file = files[new_file_name]
        refute new_file === nil
        assert new_file["filename"] === new_file_name
        assert new_file["language"] === "Markdown"
        assert new_file["content"] === new_file_content
    end

    test "update a cached gist should have start time reset", meta do
        gist = meta[:gist]
        start_time = Cacherl.last_updated(@key)
        :timer.sleep(1000)
        new_description = "New Description"
        Cache.update_gist(new_description, gist)
        refute Cacherl.last_updated(@key) === start_time
    end

    test "adding a new gist should insert it into cache", meta do
        Cacherl.delete(@key)
        assert Cacherl.lookup(@key) === {:error, :not_found}

        gist = meta[:gist]
        Cache.update_gist(gist["description"], gist)
        {:ok, cache} = Cacherl.lookup(@key)
        assert cache["id"] === gist["id"]
        assert cache["description"] === gist["description"]
    end

    test "adding a new gist also updates gists list's cache", meta do
        existing_gist = meta[:gist]
        key = {:user, @username, "gists"}
        # This is not actually true, since the data structure from GitHub
        # for gists listing is simpler, but for the sake of testing...
        Cacherl.insert(key, [existing_gist])
        {:ok, cache} = Cacherl.lookup(key)
        assert Enum.count(cache) === 1

        description = "Another gist's description"
        new_gist = get_gist("#{@gist_id}_123", description)
        Cache.update_gist(description, new_gist)
        {:ok, cache} = Cacherl.lookup(key)
        assert Enum.count(cache) === 2
        cached_new_gist = Enum.at(cache, 0)
        cached_old_gist = Enum.at(cache, 1)
        assert cached_new_gist["id"] === new_gist["id"]
        assert cached_new_gist["description"] === new_gist["description"]
        assert cached_old_gist["id"] === existing_gist["id"]
        assert cached_old_gist["description"] === existing_gist["description"]
    end

    test "updating a gist's description also updates gists list's cache", meta do
        gist = meta[:gist]
        key = {:user, @username, "gists"}
        # This is not actually true, since the data structure from GitHub
        # for gists listing is simpler, but for the sake of testing...
        Cacherl.insert(key, [gist])
        new_description = "New description"
        Cache.update_gist(new_description, gist)
        {:ok, cache} = Cacherl.lookup(key)
        assert Enum.count(cache) === 1
        updated_gist = Enum.at(cache, 0)
        # The only thing we use for gists listing is the description.
        refute updated_gist["description"] === gist["description"]
        assert updated_gist["description"] === new_description
    end

    test "updating gists list's cache should reset its start time", meta do
        gist = meta[:gist]
        key = {:user, @username, "gists"}
        # This is not actually true, since the data structure from GitHub
        # for gists listing is simpler, but for the sake of testing...
        Cacherl.insert(key, [gist])
        start_time = Cacherl.last_updated(key)
        :timer.sleep(1000)
        new_description = "New description"
        Cache.update_gist(new_description, gist)
        {:ok, cache} = Cacherl.lookup(key)
        refute Cacherl.last_updated(key) === start_time
    end

    test "removing a gist should clear its cache", meta do
        gist = meta[:gist]
        # `setup/0` ensures we have the gist in cache
        Cache.remove_gist(@username, @gist_id)
        assert Cacherl.lookup(@key) === {:error, :not_found}
    end

    test "removing a gist should also clear its comments' cache" do
        comments_key = {:comments, @gist_id}
        refute Cacherl.lookup(comments_key) === {:error, :not_found}
        Cache.remove_gist(@username, @gist_id)
        assert Cacherl.lookup(comments_key) === {:error, :not_found}
    end

    defp get_gist(id // @gist_id, description) do
        [
            {"id", id},
            {"description", description},
            {"user", [
                {"login", @username}
            ]},
            {"files", [
                {"file1", [
                    {"filename", "file1"},
                    {"language", "Markdown"},
                    {"content", "Conway's Game of Life in Erlang, in 2 hours, with 0 Erlang experience."}
                ]},
                {"filename with space and different attrs order", @unchanged_file}
            ]}
        ]
    end
end

defmodule CommentsTest do
    use ExUnit.Case, async: true
    alias GistsIO.Cache, as: Cache

    @gist_id "5180107"
    @username "sntran"

    @key {:comments, @gist_id}

    test "posting new comment" do
        comments = lc id inlist [1,2,3], do: get_comment(id)
        Cacherl.insert(@key, comments)
        new_comment = get_comment(4)
        Cache.add_comment(new_comment, @gist_id)
        {:ok, cache} = Cacherl.lookup(@key)
        assert cache === comments ++ [new_comment]
    end

    defp get_comment(id, username // @username) do
        [
            {"id", id},
            {"user", [
                {"login", username}
            ]},
            {"body", "Comment #{id}"}
        ]
    end
end
