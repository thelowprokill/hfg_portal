defmodule BnwPortalWeb.Home.DataManagement.ChangeItem do
  use BnwPortalWeb, :live_component

  alias BnwPortal.DataManagementItems

  defp save(socket) do
    %{
      changeset: changeset,
    } = socket.assigns

    changeset = DataManagementItems.change(changeset.data, changeset.changes)
    |> Map.put(:action, :update)

    if changeset.valid? do
      case DataManagementItems.create_or_update(changeset.data, changeset.changes) do
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
  def handle_event("validate", %{"data_management_item" => params}, socket) do
    %{
      changeset: changeset,
    } = socket.assigns

    changeset =
      changeset.data
      |> DataManagementItems.change(params)
      |> Map.put(:action, :update)

    socket
    |> assign(:changeset, changeset)
    |> res()
  end

  @impl true
  def handle_event("save", _, socket), do: socket |> save()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__ |> to_string())
    {:noreply, socket}
  end

end
