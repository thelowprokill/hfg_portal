defmodule HommSaves.Repo.Migrations.AddSectionToSaveFiles do
  use Ecto.Migration

  @sections ["saves", "templates"]

  def up do
    alter table(:save_files) do
      add :section, :string, null: false, default: "saves"
    end

    drop unique_index(:save_files, [:path])
    create unique_index(:save_files, [:section, :path])

    flush()

    # Existing files were stored at <root>/<path>; they all become saves at <root>/saves/<path>.
    root = HommSaves.SaveFiles.root()
    dest = Path.join(root, "saves")

    if File.dir?(root) do
      File.mkdir_p!(dest)

      for entry <- File.ls!(root), entry not in @sections do
        File.rename!(Path.join(root, entry), Path.join(dest, entry))
      end
    end
  end

  def down do
    root = HommSaves.SaveFiles.root()
    src  = Path.join(root, "saves")

    if File.dir?(src) do
      for entry <- File.ls!(src), do: File.rename!(Path.join(src, entry), Path.join(root, entry))
      File.rmdir(src)
    end

    schema = Application.get_env(:homm_saves, HommSaves.Repo)[:migration_default_prefix]
    execute "DELETE FROM \"#{schema}\".save_files WHERE section <> 'saves'"
    drop unique_index(:save_files, [:section, :path])
    create unique_index(:save_files, [:path])

    alter table(:save_files) do
      remove :section
    end
  end
end
