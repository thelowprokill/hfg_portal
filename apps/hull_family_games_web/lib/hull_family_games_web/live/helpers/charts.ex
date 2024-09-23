defmodule HullFamilyGamesWeb.Helpers.Charts do
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


