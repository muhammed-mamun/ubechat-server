defmodule Ubechat.Repo.Migrations.CreateUserIntegrations do
  use Ecto.Migration

  def change do
    create table(:user_integrations) do
      add :provider, :string, null: false
      add :access_token, :text, null: false
      add :refresh_token, :text
      add :expires_at, :utc_datetime

      add :user_id, references(:users, on_delete: :delete_all, type: :id), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_integrations, [:user_id, :provider])
  end
end
