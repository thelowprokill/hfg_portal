defmodule HfgPortalWeb.Helpers.PrintUnhandled do
  def print_unhandled(event, params, location) do
    IO.puts ""
    IO.puts ""
    IO.puts ""
    IO.puts "{{{{{{{{{{{{{{{{{{{ unhandled event }}}}}}}}}}}}}}}}}}}"
    IO.inspect event
    IO.inspect params
    IO.inspect location |> to_string()
    IO.puts "{{{{{{{{{{{{{{{{{{{ unhandled event }}}}}}}}}}}}}}}}}}}"
    IO.puts ""
    IO.puts ""
    IO.puts ""
  end

  def print_unhandled(info, location) do
    IO.puts ""
    IO.puts ""
    IO.puts ""
    IO.puts "{{{{{{{{{{{{{{{{{{{ unhandled info }}}}}}}}}}}}}}}}}}}"
    IO.inspect info
    IO.inspect location |> to_string()
    IO.puts "{{{{{{{{{{{{{{{{{{{ unhandled info }}}}}}}}}}}}}}}}}}}"
    IO.puts ""
    IO.puts ""
    IO.puts ""
  end

  def print_event(event, params, location) do
    IO.puts ""
    IO.puts ""
    IO.puts ""
    IO.puts "{{{{{{{{{{{{{{{{{{{ Event }}}}}}}}}}}}}}}}}}}"
    IO.inspect location |> to_string()
    IO.inspect event
    IO.inspect params
    IO.puts "{{{{{{{{{{{{{{{{{{{ Event }}}}}}}}}}}}}}}}}}}"
    IO.puts ""
    IO.puts ""
    IO.puts ""
  end
end
