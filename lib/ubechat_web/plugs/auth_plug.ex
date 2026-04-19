defmodule UbechatWeb.AuthPlug do
  @moduledoc """
  Plug that authenticates requests via Bearer JWT token.

  Assigns `current_user` to the conn on success.
  On failure, halts with 401 JSON response.

  Usage in router:
    plug UbechatWeb.AuthPlug
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Ubechat.Auth.Token
  alias Ubechat.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- extract_token(conn),
         {:ok, user_id} <- Token.user_id_from_token(token),
         %Ubechat.Accounts.User{} = user <- Accounts.get_user(user_id) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized"})
        |> halt()
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, String.trim(token)}
      _ -> {:error, :missing_token}
    end
  end
end
