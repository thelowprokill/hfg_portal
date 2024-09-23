defmodule BnwPortalWeb.Home.DataManagement.ChangeGroup do
  use BnwPortalWeb, :live_component

  alias BnwPortal.DataManagementGroups

  defp save(socket) do
    %{
      changeset: changeset,
    } = socket.assigns

    changeset = DataManagementGroups.change(changeset.data, changeset.changes)
    |> Map.put(:action, :update)

    if changeset.valid? do
      case DataManagementGroups.create_or_update(changeset.data, changeset.params) do
        {:ok, _} ->
          send(self(), {:cancel})
          res(socket)

        {:error, %Ecto.Changeset{} = changeset} ->
          assign(socket, changeset: changeset) |> res()
      end
    else
      assign(socket, changeset: changeset) |> res()
    end
  end

  @impl true
  def update(assigns, socket) do
    %{modal: modal} = assigns
    socket
    |> assign(assigns)
    |> assign(:changeset, modal.changeset)
    |> res(:ok)
  end

  @impl true
  def handle_event("validate", %{"data_management_group" => params}, socket) do
    %{
      changeset: changeset,
    } = socket.assigns

    changeset =
      changeset.data
      |> DataManagementGroups.change(params)
      |> Map.put(:action, :update)

    socket =
      socket
      |> assign(:changeset, changeset)
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"data_management_group" => params}, socket) do
    %{
      changeset: changeset,
    } = socket.assigns

    changeset = DataManagementGroups.change(changeset.data, params)
    |> Map.put(:action, :update)

    if changeset.valid? do
      case DataManagementGroups.create_or_update(changeset.data, params) do
        {:ok, _} ->
          send(self(), {:cancel})
          {:noreply, socket}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, changeset: changeset)}
      end
    else
      {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_event("save", _, socket), do: socket |> save()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__ |> to_string())
    {:noreply, socket}
  end

end

