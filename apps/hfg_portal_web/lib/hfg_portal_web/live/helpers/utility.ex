defmodule HfgPortalWeb.Helpers.Utility do
  use Phoenix.LiveView


  def res(socket, response \\ :noreply, temp_assigns \\ nil)
  def res(socket, response, temp_assigns) when not is_nil(temp_assigns), do: {response, socket, temporary_assigns: temp_assigns}
  def res(socket, response, _), do: {response, socket}

  def stack_push(stack, item), do: [item | stack]
  def stack_pop([]),     do: []
  def stack_pop(stack) , do: stack |> Enum.drop(1)
  def stack_tail([]),    do: nil
  def stack_tail(stack), do: stack |> Enum.at(0)

  def get_month_name(month, starting_month \\ 1, offset \\ 1) do 
    months = %{
      adjust_starting_month( 1, starting_month, offset) => "January",
      adjust_starting_month( 2, starting_month, offset) => "February",
      adjust_starting_month( 3, starting_month, offset) => "March",
      adjust_starting_month( 4, starting_month, offset) => "April",
      adjust_starting_month( 5, starting_month, offset) => "May",
      adjust_starting_month( 6, starting_month, offset) => "June",
      adjust_starting_month( 7, starting_month, offset) => "July",
      adjust_starting_month( 8, starting_month, offset) => "August",
      adjust_starting_month( 9, starting_month, offset) => "September",
      adjust_starting_month(10, starting_month, offset) => "October",
      adjust_starting_month(11, starting_month, offset) => "November",
      adjust_starting_month(12, starting_month, offset) => "December"
    }
    Map.get(months, month)
  end

  def get_drop_down_value(list, keys) do
    keys
    |> Enum.reduce(list, fn x, item ->
      cond do
        is_nil(item)     -> nil
        is_integer(item) -> item
        is_binary(item)  -> item
        true -> Map.get(item, x)
      end
    end)
  end

  defp adjust_starting_month(month_number, starting_month, offset) do
    month_number - (starting_month - offset)
    |> case do
      val when val < offset -> val + 12
        val -> val
    end
  end

  def push_changes(socket, type \\ :nav)
  def push_changes(socket, :nav),   do: push_navigate(socket, to: Enum.reduce(socket.assigns.session, "/?", fn {k, v}, acc -> acc <> "#{k}=#{v}&" end))
  def push_changes(socket, :patch), do: push_patch(   socket, to: Enum.reduce(socket.assigns.session, "/?", fn {k, v}, acc -> acc <> "#{k}=#{v}&" end))

  # make the compiler happy
  def render(assigns), do: ~H"<div>render</div>"
end


