defmodule Ortovicino.Repo.Migrations.PublicSecurity do
  use Ecto.Migration
  def change do
    alter table(:users) do
      add :verified_at, :utc_datetime
      add :suspended_at, :utc_datetime
    end
    create table(:email_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token_hash, :binary, null: false
      add :purpose, :string, null: false
      add :expires_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime, updated_at: false)
    end
    create unique_index(:email_tokens, [:token_hash])
    create index(:email_tokens, [:user_id, :purpose])
    create table(:reports) do
      add :reporter_id, references(:users, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :target_id, :integer, null: false
      add :reason, :text, null: false
      add :status, :string, null: false, default: "aperta"
      timestamps(type: :utc_datetime)
    end
    create index(:reports, [:status, :inserted_at])
  end
end
