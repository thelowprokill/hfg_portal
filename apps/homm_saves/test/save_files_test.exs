defmodule HommSaves.SaveFilesTest do
  use HommSaves.DataCase

  alias HommSaves.SaveFiles

  test "abs_path keeps paths inside the root" do
    root = SaveFiles.root()
    assert {:ok, "AUTOSAVE.GM1", abs} = SaveFiles.abs_path("/AUTOSAVE.GM1")
    assert abs == Path.join(root, "AUTOSAVE.GM1")
    assert {:ok, "Hota Random/a b/111.GM1", _} = SaveFiles.abs_path("Hota Random\\a b\\111.GM1")

    for bad <- ["../x", "a/../../x", "..", "", "/", nil] do
      assert SaveFiles.abs_path(bad) == :error, "expected #{inspect(bad)} to be rejected"
    end
  end

  test "upsert overwrites and changed_since hides the uploader's own files" do
    {:ok, first} = SaveFiles.upsert("Hota Random/t/111.GM1", "pc1")
    {:ok, again} = SaveFiles.upsert("Hota Random/t/111.GM1", "pc2")

    assert again.id == first.id
    assert DateTime.compare(again.updated_at, first.updated_at) == :gt

    assert [%{machine: "pc2"}] = SaveFiles.changed_since(nil, "pc1")
    assert []                  = SaveFiles.changed_since(nil, "pc2")
    assert []                  = SaveFiles.changed_since(again.updated_at, "pc1")
  end
end
