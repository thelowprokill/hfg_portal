defmodule HommSaves.SaveFilesTest do
  use HommSaves.DataCase

  alias HommSaves.SaveFiles
  alias HommSaves.SaveFiles.SaveFile

  # Every test gets its own save root on disk, removed afterwards.
  @moduletag :tmp_dir
  setup %{tmp_dir: tmp_dir} do
    prev = System.get_env("HOMM_SAVES_DIR")
    System.put_env("HOMM_SAVES_DIR", tmp_dir)

    on_exit(fn ->
      if prev, do: System.put_env("HOMM_SAVES_DIR", prev), else: System.delete_env("HOMM_SAVES_DIR")
      File.rm_rf!(tmp_dir)
      # ExUnit's tmp/<module>/ and tmp/ parents: removed once empty
      File.rmdir(Path.dirname(tmp_dir))
      File.rmdir(Path.dirname(Path.dirname(tmp_dir)))
    end)

    :ok
  end

  defp write!(section, rel, body \\ "x") do
    {:ok, ^rel, abs} = SaveFiles.abs_path(section, rel)
    File.mkdir_p!(Path.dirname(abs))
    File.write!(abs, body)
    {:ok, file} = SaveFiles.upsert(section, rel, "pc1")
    {abs, file}
  end

  defp paths(section), do: SaveFile |> where(section: ^section) |> order_by(:path) |> select([f], f.path) |> Repo.all()

  test "root/0 follows HOMM_SAVES_DIR", %{tmp_dir: tmp_dir} do
    assert SaveFiles.root() == tmp_dir
  end

  test "abs_path keeps paths inside the section" do
    root = SaveFiles.root()
    assert {:ok, "AUTOSAVE.GM1", abs} = SaveFiles.abs_path("saves", "/AUTOSAVE.GM1")
    assert abs == Path.join([root, "saves", "AUTOSAVE.GM1"])
    assert {:ok, "Hota Random/a b/111.GM1", _} = SaveFiles.abs_path("templates", "Hota Random\\a b\\111.GM1")

    for bad <- ["../x", "a/../../x", "..", "", "/", nil] do
      assert SaveFiles.abs_path("saves", bad) == :error, "expected #{inspect(bad)} to be rejected"
    end

    assert SaveFiles.abs_path("other", "x.GM1") == :error
  end

  test "abs_path normalizes harmless . and .. segments and repeated or Windows leading slashes" do
    assert {:ok, "a/b.GM1", _} = SaveFiles.abs_path("saves", "a/./b.GM1")
    assert {:ok, "a/c.GM1", _} = SaveFiles.abs_path("saves", "a/b/../c.GM1")
    assert {:ok, "x.GM1", _} = SaveFiles.abs_path("saves", "///x.GM1")
    assert {:ok, "x.GM1", _} = SaveFiles.abs_path("saves", "\\x.GM1")
    assert SaveFiles.abs_path("saves", "\\..\\x") == :error
    assert SaveFiles.abs_path("saves", ".") == :error
    assert SaveFiles.abs_path("saves", "a/..") == :error
    assert SaveFiles.abs_path(:saves, "x.GM1") == :error
    assert SaveFiles.abs_path("saves", ~c"x.GM1") == :error
  end

  test "upsert overwrites per section and changed_since hides the uploader's own files" do
    {:ok, first} = SaveFiles.upsert("saves", "t/111.GM1", "pc1")
    {:ok, again} = SaveFiles.upsert("saves", "t/111.GM1", "pc2")
    {:ok, tmpl}  = SaveFiles.upsert("templates", "t/111.GM1", "pc2")

    assert again.id == first.id
    assert tmpl.id != first.id
    assert DateTime.compare(again.updated_at, first.updated_at) == :gt

    assert [%{machine: "pc2", section: "saves"}] = SaveFiles.changed_since("saves", nil, "pc1")
    assert []                                    = SaveFiles.changed_since("saves", nil, "pc2")
    assert []                                    = SaveFiles.changed_since("saves", again.updated_at, "pc1")
  end

  test "upsert keeps inserted_at, moves updated_at and broadcasts the row" do
    SaveFiles.subscribe()
    {:ok, first} = SaveFiles.upsert("saves", "a.GM1", "pc1")
    assert_receive {[:homm_saves, :save_file, :upserted], %SaveFile{path: "a.GM1", machine: "pc1"}}

    {:ok, again} = SaveFiles.upsert("saves", "a.GM1", "pc2")
    assert_receive {[:homm_saves, :save_file, :upserted], %SaveFile{machine: "pc2"}}
    assert again.inserted_at == first.inserted_at
    assert DateTime.compare(again.updated_at, first.updated_at) == :gt
    assert paths("saves") == ["a.GM1"]
  end

  test "changed_since: strictly after `since`, other machines only, this section only, ordered by path" do
    {:ok, b}   = SaveFiles.upsert("saves", "b.GM1", "pc2")
    {:ok, _}   = SaveFiles.upsert("saves", "a.GM1", "pc2")
    {:ok, _}   = SaveFiles.upsert("saves", "c.GM1", "pc1")
    {:ok, _}   = SaveFiles.upsert("templates", "t.GM1", "pc2")

    assert Enum.map(SaveFiles.changed_since("saves", nil, "pc1"), & &1.path) == ["a.GM1", "b.GM1"]
    # b was the first upload, so everything after it except b itself
    assert Enum.map(SaveFiles.changed_since("saves", b.updated_at, "pc1"), & &1.path) == ["a.GM1"]
    assert Enum.map(SaveFiles.changed_since("templates", nil, "pc1"), & &1.path) == ["t.GM1"]
  end

  test "last_upload is the newest updated_at in the section, nil when empty" do
    assert SaveFiles.last_upload("saves") == nil
    {:ok, _} = SaveFiles.upsert("saves", "a.GM1", "pc1")
    {:ok, b} = SaveFiles.upsert("saves", "b.GM1", "pc1")
    {:ok, _} = SaveFiles.upsert("templates", "t.GM1", "pc1")
    assert SaveFiles.last_upload("saves") == b.updated_at
  end

  test "list pages by the last file seen, so an upload between pages doesn't repeat or skip rows" do
    for n <- 1..5, do: {:ok, _} = SaveFiles.upsert("saves", "#{n}.GM1", "pc1")

    page1 = SaveFiles.list("saves", 2)
    assert Enum.map(page1, & &1.path) == ["5.GM1", "4.GM1"]

    # a new upload goes to the top; with an offset it would push 4.GM1 onto page 2 again
    {:ok, _} = SaveFiles.upsert("saves", "6.GM1", "pc1")

    page2 = SaveFiles.list("saves", 2, List.last(page1))
    assert Enum.map(page2, & &1.path) == ["3.GM1", "2.GM1"]
    assert Enum.map(SaveFiles.list("saves", 2, List.last(page2)), & &1.path) == ["1.GM1"]
  end

  test "list breaks updated_at ties by path, across pages, and stays in its section" do
    at = ~U[2026-01-01 00:00:00.000000Z]
    rows = for p <- ~w(d.GM1 b.GM1 a.GM1 c.GM1), do: %{section: "saves", path: p, machine: "pc1", inserted_at: at, updated_at: at}
    Repo.insert_all(SaveFile, rows)
    {:ok, _} = SaveFiles.upsert("templates", "z.GM1", "pc1")

    page1 = SaveFiles.list("saves", 3)
    assert Enum.map(page1, & &1.path) == ["a.GM1", "b.GM1", "c.GM1"]
    assert Enum.map(SaveFiles.list("saves", 3, List.last(page1)), & &1.path) == ["d.GM1"]
  end

  describe "delete/2" do
    test "removes a file from disk and its row, and broadcasts the normalized path" do
      {abs, _} = write!("saves", "dir/a.GM1")
      {other, _} = write!("saves", "dir/b.GM1")
      SaveFiles.subscribe()

      assert {:ok, 1} = SaveFiles.delete("saves", "\\dir\\a.GM1")
      assert_receive {[:homm_saves, :save_file, :deleted], {"saves", "dir/a.GM1"}}
      refute File.exists?(abs)
      assert File.exists?(other)
      assert paths("saves") == ["dir/b.GM1"]
    end

    test "a folder takes its whole subtree; _ and % in names are literal, not LIKE wildcards" do
      {dir_file, _} = write!("saves", "a_b/1.GM1")
      write!("saves", "a_b/sub/2.GM1")
      {lookalike, _} = write!("saves", "axb/3.GM1")
      write!("saves", "a_bc/4.GM1")
      write!("saves", "100%/5.GM1")
      write!("saves", "100x/6.GM1")
      write!("templates", "a_b/7.GM1")

      assert {:ok, 2} = SaveFiles.delete("saves", "a_b")
      refute File.exists?(Path.dirname(dir_file))
      assert File.exists?(lookalike)
      assert paths("saves") == ["100%/5.GM1", "100x/6.GM1", "a_bc/4.GM1", "axb/3.GM1"]
      assert paths("templates") == ["a_b/7.GM1"]

      assert {:ok, 1} = SaveFiles.delete("saves", "100%")
      assert paths("saves") == ["100x/6.GM1", "a_bc/4.GM1", "axb/3.GM1"]
    end

    test "a path that matches nothing deletes nothing" do
      write!("saves", "a.GM1")
      assert {:ok, 0} = SaveFiles.delete("saves", "missing.GM1")
      assert paths("saves") == ["a.GM1"]
    end

    test "an unsafe path, the section root or an unknown section is refused and touches nothing" do
      {abs, _} = write!("saves", "a.GM1")
      SaveFiles.subscribe()

      for {section, path} <- [{"saves", "../saves"}, {"saves", "/"}, {"saves", "."}, {"other", "a.GM1"}, {"saves", nil}] do
        assert SaveFiles.delete(section, path) == :error
      end

      refute_receive {[:homm_saves, :save_file, :deleted], _}
      assert File.exists?(abs)
      assert paths("saves") == ["a.GM1"]
    end
  end
end
