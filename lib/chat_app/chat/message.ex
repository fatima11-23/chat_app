defmodule ChatApp.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :body, :string
    field :username, :string
    field :room, :string
    field :attachment_url, :string  # Make sure this line exists

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body, :username, :room, :attachment_url])  # Include attachment_url here
    |> validate_required([:username, :room])  # body is not required if we have attachments
  end
end
