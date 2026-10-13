defmodule Ortovicino.Repo.Migrations.CreateTables do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :name, :string, null: false
      add :description, :text
      add :category, :string, null: false
      add :exchange, :string, null: false
      add :price, :string
      add :seller, :string, null: false
      add :seller_type, :string, null: false
      add :latitude, :float, null: false
      add :longitude, :float, null: false
      timestamps(type: :utc_datetime)
    end

    create table(:messages) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :author, :string, null: false
      add :body, :text, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:product_id])

    create table(:reviews) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :author, :string, null: false
      add :body, :text, null: false
      add :rating, :integer, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:reviews, [:product_id])
  end
end
