defmodule UbechatWeb.UserController do
  use UbechatWeb, :controller

  alias Ubechat.Accounts

  @doc """
  Lists all registered users.
  """
  def index(conn, _params) do
    users = Accounts.list_users()

    json(conn, %{
      users:
        Enum.map(users, fn user ->
          %{
            id: user.id,
            display_name: user.display_name,
            avatar_url: user.avatar_url,
            has_public_key: not is_nil(user.public_key)
          }
        end)
    })
  end
end
