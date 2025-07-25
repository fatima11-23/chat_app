defmodule ChatAppWeb.ChatLive do
  use ChatAppWeb, :live_view
  alias Phoenix.PubSub
  alias ChatAppWeb.Presence
  alias ChatApp.Chat

  @rooms ["#general", "#tech", "#random"]
  @avatars ~w(🐱 🐶 🐰 🐵 🐸 🐼 🦊 🐯 🐨 🐮 🐔 🐧 🦁)
  @reaction_emojis ~w(👍 ❤️ 😂 😮 😢 👎)

  def mount(_params, _session, socket) do
    socket_id = "user:#{System.unique_integer([:positive])}"

    if connected?(socket) do
      Enum.each(@rooms, &PubSub.subscribe(ChatApp.PubSub, topic_for(&1)))
    end

    messages_map =
      Enum.reduce(@rooms, %{}, fn room, acc ->
        messages =
          Chat.list_recent_messages(room)
          |> Enum.map(&decorate_message(&1, nil))

        Map.put(acc, room, messages)
      end)

    online_users =
      Presence.list("presence:#general")
      |> Map.values()
      |> Enum.map(fn %{metas: [meta | _]} -> meta end)

    socket =
      socket
      |> assign(:socket_id, socket_id)
      |> assign(:display_name, nil)
      |> assign(:avatar, nil)
      |> assign(:message, "")
      |> assign(:current_room, "#general")
      |> assign(:name_form, true)
      |> assign(:rooms, @rooms)
      |> assign(:messages_map, messages_map)
      |> assign(:typing_users, %{})
      |> assign(:dark_mode, false)
      |> assign(:reactions, %{})
      |> assign(:show_reaction_picker, nil)
      |> assign(:online_users, online_users)
      |> stream(:messages, messages_map["#general"])

    {:ok, socket}
  end

  def handle_event("set_name", %{"name" => name}, socket) do
    avatar = Enum.random(@avatars)
    room = socket.assigns.current_room

    Presence.track(self(), "presence:#{room}", socket.assigns.socket_id, %{
      name: name,
      avatar: avatar
    })

    {:noreply,
     socket
     |> assign(:display_name, name)
     |> assign(:avatar, avatar)
     |> assign(:name_form, false)}
  end

  def handle_event("update_message", %{"message" => msg}, socket) do
    room = socket.assigns.current_room
    name = socket.assigns.display_name
    PubSub.broadcast(ChatApp.PubSub, topic_for(room), {:user_typing, name})
    {:noreply, assign(socket, :message, msg)}
  end

  def handle_event("send_message", %{"message" => _}, %{assigns: %{display_name: nil}} = socket) do
    {:noreply, assign(socket, :name_form, true)}
  end

  def handle_event("send_message", %{"message" => ""}, socket), do: {:noreply, socket}

  def handle_event("send_message", %{"message" => body}, socket) do
    %{display_name: name, avatar: avatar, current_room: room} = socket.assigns

    {:ok, saved_msg} =
      Chat.create_message(%{body: body, username: name, room: room})

    message = decorate_message(saved_msg, avatar)

    PubSub.broadcast(ChatApp.PubSub, topic_for(room), {:new_message, message, room})

    updated_msgs = [message | socket.assigns.messages_map[room]]
    new_map = Map.put(socket.assigns.messages_map, room, updated_msgs)

    {:noreply,
     socket
     |> assign(:message, "")
     |> assign(:messages_map, new_map)
     |> stream(:messages, Enum.reverse(updated_msgs), reset: true)}
  end

  def handle_event("switch_room", %{"room" => new_room}, socket) do
    old_room = socket.assigns.current_room

    if socket.assigns.display_name do
      Presence.untrack(self(), "presence:#{old_room}", socket.assigns.socket_id)

      Presence.track(self(), "presence:#{new_room}", socket.assigns.socket_id, %{
        name: socket.assigns.display_name,
        avatar: socket.assigns.avatar
      })
    end

    messages =
      socket.assigns.messages_map[new_room]
      |> Enum.map(&Map.put(&1, :avatar, socket.assigns.avatar))

    online_users =
      Presence.list("presence:#{new_room}")
      |> Map.values()
      |> Enum.map(fn %{metas: [meta | _]} -> meta end)

    {:noreply,
     socket
     |> assign(:current_room, new_room)
     |> assign(:online_users, online_users)
     |> stream(:messages, Enum.reverse(messages), reset: true)}
  end

  def handle_event("toggle_theme", _, socket) do
    {:noreply, assign(socket, :dark_mode, !socket.assigns.dark_mode)}
  end

  def handle_event("react", %{"id" => id, "reaction" => reaction}, socket) do
    updated = Map.update(socket.assigns.reactions, id, [reaction], &[reaction | &1])
    {:noreply, assign(socket, :reactions, updated)}
  end

  def handle_event("toggle_reaction_picker", %{"id" => id}, socket) do
    new_value = if socket.assigns.show_reaction_picker == id, do: nil, else: id
    {:noreply, assign(socket, :show_reaction_picker, new_value)}
  end

  def handle_info({:new_message, message, room}, socket) do
    updated_msgs = [message | socket.assigns.messages_map[room]]
    new_map = Map.put(socket.assigns.messages_map, room, updated_msgs)
    socket = assign(socket, :messages_map, new_map)

    if socket.assigns.current_room == room do
      {:noreply, stream_insert(socket, :messages, message)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:user_typing, name}, socket) do
    typing = Map.put(socket.assigns.typing_users, name, :os.system_time(:millisecond))
    Process.send_after(self(), {:clear_typing, name}, 2000)
    {:noreply, assign(socket, :typing_users, typing)}
  end

  def handle_info({:clear_typing, name}, socket) do
    typing = Map.delete(socket.assigns.typing_users, name)
    {:noreply, assign(socket, :typing_users, typing)}
  end

  def handle_info(%{event: "presence_diff", topic: topic}, socket) do
    room = String.replace_prefix(topic, "presence:", "")

    if room == socket.assigns.current_room do
      users =
        Presence.list("presence:#{room}")
        |> Map.values()
        |> Enum.map(fn %{metas: [meta | _]} -> meta end)

      {:noreply, assign(socket, :online_users, users)}
    else
      {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class={"min-h-screen p-4 transition-all " <> if @dark_mode, do: "bg-gray-900 text-white", else: "bg-gray-50 text-black"}>
      <div class="max-w-2xl mx-auto">
        <h1 class="text-4xl font-extrabold text-center mb-6 animate-pulse text-amber-500 drop-shadow-md">
          🚀 BuzzBody Chat App 🐝
        </h1>

        <button phx-click="toggle_theme" class="mb-4 px-4 py-2 rounded-full bg-gradient-to-r from-purple-500 to-pink-500 text-white shadow hover:scale-105 transition-all">
          Toggle Theme 🌗
        </button>

        <%= if @name_form do %>
          <.form for={%{}} as={:form} phx-submit="set_name">
            <input name="name" placeholder="Enter your name"
              class="border p-2 rounded w-full mb-2 focus:outline-none focus:ring-2 focus:ring-blue-400" />
            <button type="submit" class="bg-gradient-to-r from-pink-500 to-yellow-500 text-white px-4 py-2 rounded w-full font-bold shadow-md hover:scale-105 transition">Join Chat</button>
          </.form>
        <% else %>
          <div class="mb-4">
            <h2 class="text-xl font-bold flex items-center gap-2 mb-2">
              <span class="text-2xl"><%= @avatar %></span> Welcome, <%= @display_name %>!
            </h2>
            <div class="flex gap-2 flex-wrap">
              <%= for room <- @rooms do %>
                <button phx-click="switch_room" phx-value-room={room}
                  class={"px-4 py-2 rounded-full text-sm font-semibold shadow-md hover:scale-105 transition-all " <>
                    if room == @current_room, do: "bg-gradient-to-r from-blue-500 to-indigo-600 text-white", else: "bg-gradient-to-br from-gray-100 to-gray-300 text-gray-800"}>
                  <%= room %>
                </button>
              <% end %>
            </div>
            <div class="text-sm mt-2 text-gray-400">
              👥 Online: <%= Enum.map(@online_users, & &1.name) |> Enum.join(", ") %>
            </div>
          </div>

          <div id="chat-box" phx-hook="AutoScroll" class="h-96 overflow-y-auto border p-3 rounded mb-4 bg-white dark:bg-gray-800 shadow-inner">
            <ol id="messages" phx-update="stream">
              <%= for {id, msg} <- @streams.messages do %>
                <%= render_message(id, msg, @display_name, @reactions[msg.id] || [], @show_reaction_picker) %>
              <% end %>
            </ol>
            <%= if map_size(@typing_users) > 0 do %>
              <p class="text-sm italic mt-2 text-gray-300 dark:text-white animate-pulse">
                <%= Enum.map(@typing_users, fn {name, _} -> name end) |> Enum.join(", ") %> is typing...
              </p>
            <% end %>
          </div>

          <.form for={%{}} as={:form} phx-change="update_message" phx-submit="send_message" class="flex items-center gap-2">
            <input name="message" value={@message} placeholder="Type your message here..." autocomplete="off"
              phx-debounce="300"
              class="flex-grow border px-4 py-2 rounded-full focus:outline-none focus:ring-2 focus:ring-blue-400" />
            <div id="emoji-picker-container" phx-hook="EmojiInput" data-dark={@dark_mode} class="relative">
              <button type="button" id="emoji-trigger" class="text-xl px-2 hover:scale-125 transition">😊</button>
            </div>
            <button type="submit" class="bg-blue-600 text-white px-4 py-2 rounded-full hover:bg-blue-700">Send</button>
          </.form>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_message(id, msg, current_user, reactions, show_reaction_picker) do
    assigns = %{
      id: id,
      msg: msg,
      current_user: current_user,
      reactions: reactions,
      emojis: @reaction_emojis,
      show_reaction_picker: show_reaction_picker
    }

    ~H"""
    <li id={@id} class={"mb-4 flex " <> if @msg.username == @current_user, do: "justify-end", else: "justify-start"}>
      <div class={"max-w-[75%] px-4 py-2 rounded-xl shadow " <>
        if @msg.username == @current_user, do: "bg-blue-600 text-white rounded-br-none", else: "bg-gray-200 text-black rounded-bl-none"}>
        <div class="text-sm font-semibold flex items-center gap-1 mb-1">
          <span><%= @msg.avatar || "" %></span>
          <%= @msg.username %>
        </div>
        <div class="text-base break-words whitespace-pre-wrap">
          <%= @msg.body %>
        </div>
        <div class="text-xs text-right mt-1 text-gray-400 dark:text-gray-300"><%= @msg.timestamp %></div>
        <div class="mt-2 relative">
          <button phx-click="toggle_reaction_picker" phx-value-id={@id} class="text-sm px-2 py-1 bg-yellow-200 text-yellow-900 rounded hover:bg-yellow-300 transition">
            😊 React
          </button>
          <%= if @show_reaction_picker == @id do %>
            <div class="absolute z-10 bg-white dark:bg-gray-700 border p-2 rounded shadow-lg mt-2 flex gap-2">
              <%= for emoji <- @emojis do %>
                <button class="text-xl hover:scale-125 transition" phx-click="react" phx-value-id={@id} phx-value-reaction={emoji}>
                  <%= emoji %>
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
        <div class="flex gap-1 mt-1 text-sm">
          <%= for r <- @reactions do %>
            <span><%= r %></span>
          <% end %>
        </div>
      </div>
    </li>
    """
  end

  defp topic_for(room), do: "chat_room:#{room}"

  defp format_timestamp(ts), do: Timex.format!(ts, "%I:%M %p", :strftime)

  defp decorate_message(msg, fallback_avatar) do
    %{
      id: msg.id,
      body: msg.body,
      username: msg.username,
      room: msg.room,
      timestamp: format_timestamp(msg.inserted_at),
      avatar: fallback_avatar
    }
  end
end
