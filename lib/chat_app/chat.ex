defmodule ChatApp.Chat do
  import Ecto.Query, warn: false
  alias ChatApp.Repo
  alias ChatApp.Chat.Message

  # ✅ Save a message to the DB
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  # ✅ Fetch last 50 messages from a room
  def list_recent_messages(room) do
    Message
    |> where([m], m.room == ^room)
    |> order_by(desc: :inserted_at)
    |> limit(50)
    |> Repo.all()
    |> Enum.reverse()
    |> Enum.map(fn msg ->
      %{
        id: msg.id,
        username: msg.username,
        body: msg.body,
        room: msg.room,
        # ✅ Keep it
        inserted_at: msg.inserted_at,
        avatar: nil
      }
    end)
  end
end
