defmodule HfgPortalWeb.Helpers.Charts do
  use Phoenix.LiveView

  attr :values, :list, required: true
  attr :keys,   :map,  required: true
  def bnw_chart_bar_tick(assigns) do
    ~H"""
    <div class="w-full flex">
      <div class={"w-2 rounded-l-full #{Map.get(@keys, Enum.at(@values, 0), "bg-red-500")}"}></div> 
      <div class="w-full grid grid-flow-col h-2.5"> 
        <%= for v <- @values do %>
          <div class={"#{Map.get(@keys, v, "bg-red-500")}"}></div>
        <% end %>
      </div>
      <div class={"w-2 rounded-r-full #{Map.get(@keys, Enum.at(@values, -1), "bg-red-500")}"}></div> 
    </div>
    """
  end
 

  @doc """
  Renders a simple multi-series line chart as inline SVG. Hovering shows a
  vertical crosshair at the nearest point plus a tooltip with every series'
  value there (handled client-side by the ChartHover hook - no server
  round-trips on mousemove).

  `series` - list of `%{label: string, color: css_color, values: [number | Decimal]}`
  `x_labels` - list of strings, one per point along the x-axis
  """
  attr :id,            :string, required: true
  attr :series,        :list, required: true
  attr :x_labels,      :list, required: true
  attr :width,         :integer, default: 640
  attr :height,        :integer, default: 220
  attr :max_x_labels,  :integer, default: 10
  def bnw_chart_line(assigns) do
    padding_left   = 64
    padding_right  = 12
    padding_top    = 12
    padding_bottom = 28

    width  = assigns.width
    height = assigns.height
    plot_w = width - padding_left - padding_right
    plot_h = height - padding_top - padding_bottom

    all_values = assigns.series |> Enum.flat_map(& &1.values) |> Enum.map(&chart_to_float/1)

    {raw_min, raw_max} =
      case all_values do
        [] -> {0.0, 1.0}
        _ -> Enum.min_max(all_values)
      end

    span = max(raw_max - raw_min, 1.0)
    min_v = raw_min - span * 0.1
    max_v = raw_max + span * 0.1
    range = max(max_v - min_v, 1.0)

    point_count = length(assigns.x_labels)
    x_step = if point_count > 1, do: plot_w / (point_count - 1), else: 0.0

    to_x = fn i -> padding_left + i * x_step end
    to_y = fn v -> padding_top + plot_h - (v - min_v) / range * plot_h end

    series_lines =
      Enum.map(assigns.series, fn s ->
        points =
          s.values
          |> Enum.with_index()
          |> Enum.map(fn {v, i} ->
            "#{Float.round(to_x.(i), 2)},#{Float.round(to_y.(chart_to_float(v)), 2)}"
          end)
          |> Enum.join(" ")

        %{label: s.label, color: s.color, points: points}
      end)

    tick_step = max(1, ceil(point_count / assigns.max_x_labels))

    x_ticks =
      assigns.x_labels
      |> Enum.with_index()
      |> Enum.filter(fn {_label, i} -> rem(i, tick_step) == 0 or i == point_count - 1 end)
      |> Enum.map(fn {label, i} -> %{x: to_x.(i), label: label} end)

    hover_points =
      assigns.x_labels
      |> Enum.with_index()
      |> Enum.map(fn {label, i} ->
        %{
          x: to_x.(i),
          label: label,
          series:
            Enum.map(assigns.series, fn s ->
              %{label: s.label, color: s.color, value: chart_format_value(Enum.at(s.values, i))}
            end)
        }
      end)

    assigns =
      assigns
      |> assign(:plot_left, padding_left)
      |> assign(:plot_right, width - padding_right)
      |> assign(:plot_top, padding_top)
      |> assign(:plot_bottom, height - padding_bottom)
      |> assign(:zero_y, to_y.(0.0))
      |> assign(:series_lines, series_lines)
      |> assign(:x_ticks, x_ticks)
      |> assign(:hover_points_json, Jason.encode!(hover_points))

    ~H"""
    <div
      id={@id}
      phx-hook="ChartHover"
      class="relative"
      data-points={@hover_points_json}
      data-viewbox-width={@width}
    >
      <div class="chart-tooltip hidden absolute top-0 z-10 pointer-events-none rounded-lg border border-zinc-200 dark:border-zinc-700 bg-white dark:bg-zinc-800 shadow-md p-2 text-xs whitespace-nowrap">
      </div>
      <svg viewBox={"0 0 #{@width} #{@height}"} class="w-full h-auto">
        <line
          x1={@plot_left} y1={@zero_y} x2={@plot_right} y2={@zero_y}
          stroke="currentColor" class="text-zinc-300 dark:text-zinc-600"
          stroke-width="1" stroke-dasharray="4 2"
        />
        <%= for s <- @series_lines do %>
          <polyline points={s.points} fill="none" stroke={s.color} stroke-width="2" stroke-linejoin="round" stroke-linecap="round" />
        <% end %>
        <%= for t <- @x_ticks do %>
          <text x={t.x} y={@height - 6} font-size="10" text-anchor="middle" class="fill-zinc-400">
            <%= t.label %>
          </text>
        <% end %>
        <line
          class="chart-crosshair hidden text-zinc-400 dark:text-zinc-500"
          x1={@plot_left} y1={@plot_top} x2={@plot_left} y2={@plot_bottom}
          stroke="currentColor"
          stroke-width="1"
        />
      </svg>
      <div class="flex flex-wrap gap-x-4 gap-y-1 justify-center pt-2 text-xs text-zinc-500">
        <%= for s <- @series_lines do %>
          <span class="inline-flex items-center gap-1.5">
            <span class="w-2.5 h-2.5 rounded-full" style={"background-color: #{s.color}"}></span>
            <%= s.label %>
          </span>
        <% end %>
      </div>
    </div>
    """
  end

  defp chart_to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp chart_to_float(n) when is_number(n), do: n * 1.0

  defp chart_format_value(%Decimal{} = d), do: "$#{d}"
  defp chart_format_value(n) when is_number(n), do: "$#{n}"
  defp chart_format_value(nil), do: "—"

  # this does not work yet.
  def bnw_chart_metabase(assigns) do
    # this is not working for some reason.
    # The python version works fine.
    #
    secret_key = "20bee8ab6d36bd3eda0fe751f187e74f5869dd61488dc2c843557bfa064727a4"
    site_url   = "http://10.1.2.18:3000"
    exp        = :os.system_time(:seconds) + (10 * 60)

    payload = %{
      "exp"      => exp, 
      "params"   => %{"sensor" => "bd-medcooler-1"}, 
      "resource" => %{dashboard: 2}
    }

    token =
    JOSE.JWK.from(%{"k" => secret_key, "kty" => "oct"})
    |> IO.inspect()
    |> JOSE.JWT.sign(%{"alg" => "HS256"}, payload)
    |> IO.inspect()
    |> JOSE.JWS.compact()
    |> elem(1)

    IO.puts "{{{{{{{{{{{{{{{{{{{{{{{{{{ token }}}}}}}}}}}}}}}}}}}}}}}}}}"
    IO.inspect token
    IO.puts "{{{{{{{{{{{{{{{{{{{{{{{{{{ token }}}}}}}}}}}}}}}}}}}}}}}}}}"

    #token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3MTU5Njc0NTUsInBhcmFtcyI6e30sInJlc291cmNlIjp7ImRhc2hib2FyZCI6Mn19.FY111W51Uovo6qet1vfpDHLZ_Nts0x7-NPwOYHlQr0A"

    assigns =
      assigns
      |> assign(:site_url, site_url)
      |> assign(:token,    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3MTU5NzYzODcsInBhcmFtcyI6eyJzZW5zb3IiOlsiYmQtbWVkY29vbGVyLTEiXX0sInJlc291cmNlIjp7ImRhc2hib2FyZCI6Mn19.eOfhXQ1_Epjz1zCXyjsQaGyByYWPsUc2janvNmIf7PU")
    
    ~H"""
      <div>
        <iframe class="w-1/2 h-[500px]" src={"#{@site_url}/embed/dashboard/#{@token}#bordered=true&titled=true"}></iframe>

      </div>
    """
  end


  # make the compiler happy
  def render(assigns), do: ~H"<div>render</div>"
end


