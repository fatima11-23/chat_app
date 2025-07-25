defmodule ChatApp.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :body, :string
    field :username, :string
    field :room, :string

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body, :username, :room])
    |> validate_required([:body, :username, :room])
  end
end
