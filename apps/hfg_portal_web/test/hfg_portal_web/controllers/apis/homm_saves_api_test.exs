defmodule HfgPortalWeb.Apis.HommSavesApiTest do
  use HfgPortalWeb.ApiCase

  alias HommSaves.SaveFiles

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp} do
    old = System.get_env("HOMM_SAVES_DIR")
    root = Path.join(tmp, "root")
    File.mkdir_p!(root)
    System.put_env("HOMM_SAVES_DIR", root)

    on_exit(fn ->
      if old, do: System.put_env("HOMM_SAVES_DIR", old), else: System.delete_env("HOMM_SAVES_DIR")
    end)

    user = api_user(%{homm_saves: "Edit"})
    %{root: root, jwt: token(user)}
  end

  defp call(conn, jwt, method, route, query, body \\ nil),
    do: api(conn, method, jwt, Map.merge(%{"scope" => "homm_saves", "route" => route}, query), body)

  defp upload(tmp, content) do
    path = Path.join(tmp, "upload-#{System.unique_integer([:positive])}")
    File.write!(path, content)
    %{"file" => %Plug.Upload{path: path, filename: "x.GM1", content_type: "application/octet-stream"}}
  end

  defp put_file(conn, jwt, tmp, query, content \\ "save-data"),
    do: call(conn, jwt, "PUT", "file", Map.merge(%{"machine" => "pc1"}, query), upload(tmp, content))

  # every file under the temp dir except our uploads' sources
  defp files_on_disk(tmp) do
    Path.wildcard(Path.join(tmp, "**/*"), match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, tmp))
    |> Enum.reject(&String.starts_with?(&1, "upload-"))
    |> Enum.sort()
  end

  describe "auth and validation" do
    test "users without Edit/Admin are refused on every route", %{conn: conn} do
      for user <- [api_user(), api_user(%{homm_saves: "None"}), api_user(%{homm_saves: "View"})],
          {method, route} <- [{"GET", "changes"}, {"GET", "file"}, {"PUT", "file"}, {"DELETE", "file"}] do
        assert %{"error" => "Unauthorized"} = conn |> call(token(user), method, route, %{"machine" => "pc1", "path" => "a"}) |> json_response(401)
      end
    end

    test "Admin is allowed", %{conn: conn} do
      admin = token(api_user(%{homm_saves: "Admin"}))
      assert conn |> call(admin, "GET", "changes", %{"machine" => "pc1"}) |> data() == []
    end

    test "unknown route, wrong method or no route is 404", %{conn: conn, jwt: jwt} do
      assert %{"error" => "Route not found"} = conn |> call(jwt, "GET", "nope", %{"machine" => "m"}) |> json_response(404)
      assert %{"error" => "Route not found"} = conn |> call(jwt, "PUT", "changes", %{"machine" => "m"}) |> json_response(404)
      assert %{"error" => "Route not found"} = conn |> api("GET", jwt, %{"scope" => "homm_saves"}) |> json_response(404)
    end

    test "machine is required and section must be known", %{conn: conn, jwt: jwt} do
      for m <- [nil, "", "  "] do
        q = if m, do: %{"machine" => m}, else: %{}
        assert %{"error" => "machine is required"} = conn |> call(jwt, "GET", "changes", q) |> json_response(400)
      end

      for s <- ["other", "../saves", ""] do
        assert %{"error" => "section must be one of: saves, templates"} =
                 conn |> call(jwt, "GET", "changes", %{"machine" => "m", "section" => s}) |> json_response(400)
      end
    end
  end

  describe "PUT file" do
    test "stores the upload under root/section/path and records it", %{conn: conn, jwt: jwt, tmp_dir: tmp, root: root} do
      assert %{"section" => "saves", "path" => "Heroes/a b.GM1", "updated_at" => _} =
               conn |> put_file(jwt, tmp, %{"path" => "\\Heroes\\a b.GM1"}) |> data()

      assert File.read!(Path.join([root, "saves", "Heroes", "a b.GM1"])) == "save-data"
      assert [%{machine: "pc1", path: "Heroes/a b.GM1"}] = SaveFiles.changed_since("saves", nil, "other")

      assert %{"section" => "templates"} = conn |> put_file(jwt, tmp, %{"path" => "t.rmg", "section" => "templates"}) |> data()
      assert File.exists?(Path.join([root, "templates", "t.rmg"]))
    end

    test "overwrites an existing file and takes the new machine", %{conn: conn, jwt: jwt, tmp_dir: tmp, root: root} do
      put_file(conn, jwt, tmp, %{"path" => "a.GM1"}, "v1")
      conn |> call(jwt, "PUT", "file", %{"machine" => "pc2", "path" => "a.GM1"}, upload(tmp, "v2")) |> data()

      assert File.read!(Path.join([root, "saves", "a.GM1"])) == "v2"
      assert [%{machine: "pc2"}] = SaveFiles.changed_since("saves", nil, "pc1")
    end

    test "without a file upload is a 400", %{conn: conn, jwt: jwt} do
      assert %{"error" => "file upload is required"} = conn |> call(jwt, "PUT", "file", %{"machine" => "pc1", "path" => "a.GM1"}) |> json_response(400)
      assert %{"error" => "file upload is required"} = conn |> call(jwt, "PUT", "file", %{"machine" => "pc1", "path" => "a.GM1", "file" => "plain text"}) |> json_response(400)
    end

    test "path traversal is refused and nothing is written", %{conn: conn, jwt: jwt, tmp_dir: tmp} do
      for bad <- ["../evil.GM1", "../../evil.GM1", "a/../../evil.GM1", "..\\..\\evil.GM1", "a\\..\\..\\..\\evil.GM1", "..", ".", "", "/", "\\"] do
        assert %{"error" => "invalid path"} = conn |> put_file(jwt, tmp, %{"path" => bad}) |> json_response(400), "#{inspect(bad)} accepted"
      end

      assert %{"error" => "invalid path"} = conn |> call(jwt, "PUT", "file", %{"machine" => "pc1"}, upload(tmp, "x")) |> json_response(400)

      assert files_on_disk(tmp) == []
      assert SaveFiles.changed_since("saves", nil, "other") == []
    end

    test "an absolute path is confined to the section", %{conn: conn, jwt: jwt, tmp_dir: tmp, root: root} do
      assert %{"path" => "etc/evil.GM1"} = conn |> put_file(jwt, tmp, %{"path" => "/etc/evil.GM1"}) |> data()
      assert File.exists?(Path.join([root, "saves", "etc", "evil.GM1"]))
      refute File.exists?("/etc/evil.GM1")
    end

    test "a path that walks back into the section is normalised", %{conn: conn, jwt: jwt, tmp_dir: tmp, root: root} do
      assert %{"path" => "b.GM1"} = conn |> put_file(jwt, tmp, %{"path" => "a/../b.GM1"}) |> data()
      assert File.exists?(Path.join([root, "saves", "b.GM1"]))
    end
  end

  describe "GET file" do
    test "downloads the file as an attachment", %{conn: conn, jwt: jwt, tmp_dir: tmp} do
      put_file(conn, jwt, tmp, %{"path" => "dir/my save.GM1"}, <<0, 1, 2, 255>>)

      conn = call(conn, jwt, "GET", "file", %{"machine" => "pc2", "path" => "dir/my save.GM1"})
      assert response(conn, 200) == <<0, 1, 2, 255>>
      assert [disposition] = get_resp_header(conn, "content-disposition")
      assert disposition =~ "attachment"
      assert disposition =~ "my%20save.GM1"
    end

    test "a missing file or a folder is a 404", %{conn: conn, jwt: jwt, tmp_dir: tmp} do
      put_file(conn, jwt, tmp, %{"path" => "dir/a.GM1"})

      for p <- ["nope.GM1", "dir"] do
        assert %{"error" => "file not found"} = conn |> call(jwt, "GET", "file", %{"machine" => "m", "path" => p}) |> json_response(404)
      end
    end

    test "path traversal can't read outside the section", %{conn: conn, jwt: jwt, tmp_dir: tmp, root: root} do
      File.write!(Path.join(tmp, "secret.txt"), "secret")
      File.mkdir_p!(Path.join(root, "templates"))
      File.write!(Path.join([root, "templates", "t.rmg"]), "template")

      for bad <- ["../../secret.txt", "../templates/t.rmg", "..\\templates\\t.rmg", "a/../../templates/t.rmg", "", nil] do
        q = if bad, do: %{"machine" => "m", "path" => bad}, else: %{"machine" => "m"}
        assert %{"error" => "invalid path"} = conn |> call(jwt, "GET", "file", q) |> json_response(400), "#{inspect(bad)} accepted"
      end

      # an absolute path stays inside the section, so the real file isn't found
      assert %{"error" => "file not found"} = conn |> call(jwt, "GET", "file", %{"machine" => "m", "path" => Path.join(tmp, "secret.txt")}) |> json_response(404)
    end
  end

  describe "GET changes" do
    test "lists files other machines changed, optionally since a time", %{conn: conn, jwt: jwt, tmp_dir: tmp} do
      put_file(conn, jwt, tmp, %{"path" => "mine.GM1"})
      conn |> call(jwt, "PUT", "file", %{"machine" => "pc2", "path" => "theirs.GM1"}, upload(tmp, "x")) |> data()
      conn |> call(jwt, "PUT", "file", %{"machine" => "pc2", "path" => "tmpl.rmg", "section" => "templates"}, upload(tmp, "x")) |> data()

      assert [%{"path" => "theirs.GM1", "machine" => "pc2", "section" => "saves", "updated_at" => at}] =
               conn |> call(jwt, "GET", "changes", %{"machine" => "pc1"}) |> data()

      assert [%{"path" => "tmpl.rmg"}] = conn |> call(jwt, "GET", "changes", %{"machine" => "pc1", "section" => "templates"}) |> data()
      assert conn |> call(jwt, "GET", "changes", %{"machine" => "pc1", "since" => at}) |> data() == []
      assert [_] = conn |> call(jwt, "GET", "changes", %{"machine" => "pc1", "since" => "2000-01-01T00:00:00Z"}) |> data()
      assert [_] = conn |> call(jwt, "GET", "changes", %{"machine" => "pc1", "since" => ""}) |> data()
    end

    test "a bad since is a 400", %{conn: conn, jwt: jwt} do
      for s <- ["yesterday", "2026-01-01"] do
        assert %{"error" => "since must be ISO8601" <> _} = conn |> call(jwt, "GET", "changes", %{"machine" => "m", "since" => s}) |> json_response(400)
      end
    end
  end

  describe "DELETE file" do
    test "deletes a file, or a folder with everything under it", %{conn: conn, jwt: jwt, tmp_dir: tmp, root: root} do
      for p <- ["one.GM1", "Game_1/a.GM1", "Game_1/sub/b.GM1", "GameX1/c.GM1"], do: put_file(conn, jwt, tmp, %{"path" => p})

      assert %{"section" => "saves", "path" => "one.GM1", "deleted" => 1} =
               conn |> call(jwt, "DELETE", "file", %{"machine" => "pc1", "path" => "one.GM1"}) |> data()

      # "_" in the folder name must not act as a LIKE wildcard and take GameX1 with it
      assert %{"deleted" => 2} = conn |> call(jwt, "DELETE", "file", %{"machine" => "pc1", "path" => "Game_1"}) |> data()

      assert files_on_disk(tmp) == ["root/saves/GameX1/c.GM1"]
      refute File.exists?(Path.join([root, "saves", "Game_1"]))
      assert [%{path: "GameX1/c.GM1"}] = SaveFiles.changed_since("saves", nil, "other")
    end

    test "deleting something that isn't there is ok with 0 deleted", %{conn: conn, jwt: jwt} do
      assert %{"deleted" => 0} = conn |> call(jwt, "DELETE", "file", %{"machine" => "pc1", "path" => "ghost.GM1"}) |> data()
    end

    test "path traversal can't delete outside the section, nor the section itself", %{conn: conn, jwt: jwt, tmp_dir: tmp, root: root} do
      put_file(conn, jwt, tmp, %{"path" => "keep.GM1"})
      put_file(conn, jwt, tmp, %{"path" => "t.rmg", "section" => "templates"})
      File.write!(Path.join(tmp, "outside.txt"), "x")

      for bad <- ["..", "../templates", "..\\templates", "../../outside.txt", "a/../..", ".", "", "/"] do
        assert %{"error" => "invalid path"} = conn |> call(jwt, "DELETE", "file", %{"machine" => "m", "path" => bad}) |> json_response(400), "#{inspect(bad)} accepted"
      end

      assert File.exists?(Path.join(tmp, "outside.txt"))
      assert File.exists?(Path.join([root, "saves", "keep.GM1"]))
      assert File.exists?(Path.join([root, "templates", "t.rmg"]))
    end
  end
end
