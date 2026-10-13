defmodule Ortovicino.Repo.Migrations.SecurityUpgrade do
  use Ecto.Migration
  def change do
    create table(:users) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :kind, :string, null: false, default: "privato"
      timestamps(type: :utc_datetime)
    end
    create unique_index(:users, [:email])
    create table(:sessions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token_hash, :binary, null: false
      add :csrf_hash, :binary, null: false
      add :expires_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime, updated_at: false)
    end
    create unique_index(:sessions, [:token_hash])
    create table(:conversations) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :buyer_id, references(:users, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end
    create unique_index(:conversations, [:product_id, :buyer_id])
    alter table(:products) do
      add :owner_id, references(:users, on_delete: :nilify_all)
    end
    # Remove old PUBLIC chat/reviews schema: this upgrade is a clean dev migration.
    drop table(:messages)
    drop table(:reviews)
    create table(:messages) do
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :sender_id, references(:users, on_delete: :delete_all), null: false
      add :body, :text, null: false
      timestamps(type: :utc_datetime, updated_at: false)
    end
    create index(:messages, [:conversation_id, :id])
    create table(:reviews) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :author_id, references(:users, on_delete: :delete_all), null: false
      add :body, :text, null: false
      add :rating, :integer, null: false
      timestamps(type: :utc_datetime)
    end
    create unique_index(:reviews, [:product_id, :author_id])
  end
end
