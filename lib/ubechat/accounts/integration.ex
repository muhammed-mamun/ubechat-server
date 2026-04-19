defmodule Ubechat.Accounts.Integration do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_integrations" do
    field :provider, :string
    field :access_token, :string
    field :refresh_token, :string
    field :expires_at, :utc_datetime

    belongs_to :user, Ubechat.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [:provider, :access_token, :refresh_token, :expires_at, :user_id])
    |> validate_required([:provider, :access_token, :user_id])
    |> unique_constraint([:user_id, :provider])
  end
end
