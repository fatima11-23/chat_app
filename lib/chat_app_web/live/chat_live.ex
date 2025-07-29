defmodule ChatAppWeb.ChatLive do
  use ChatAppWeb, :live_view
  alias Phoenix.PubSub
  alias ChatAppWeb.Presence
  alias ChatApp.Chat

  @rooms ["#general", "#tech", "#random"]
  @avatars ~w(
    👩 👨 🧑 👵 👴
    👨‍💻 👩‍💻 🧑‍🎓 👨‍🎨 👩‍🚀
  )


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
  |> assign(:avatars, @avatars)
  |> assign(:show_reaction_picker, nil)
  |> assign(:online_users, online_users)
  |> assign(:uploaded_files, [])
  |> allow_upload(:files,
  accept: ~w(.jpg .jpeg .png .gif .pdf .txt .doc .docx .mp4 .mp3 .wav),
  max_entries: 5,
  max_file_size: 10_000_000) # 10MB
  |> stream(:messages, messages_map["#general"])

  {:ok, socket}
  end

  def handle_event("set_name", %{"name" => name, "avatar" => avatar}, socket) do
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

  def handle_event("send_message", %{"message" => body}, socket) do
    # Check if we have either a message or files to upload
    has_files = length(socket.assigns.uploads.files.entries) > 0
    has_message = String.trim(body) != ""

    # Don't send if there's neither message nor files
    if not has_message and not has_files do
      {:noreply, socket}
    else
      %{display_name: name, avatar: avatar, current_room: room} = socket.assigns

      # Handle file uploads
      uploaded_file_urls =
        consume_uploaded_entries(socket, :files, fn %{path: path}, entry ->
          filename = "#{System.unique_integer([:positive])}_#{entry.client_name}"
          dest_path = Path.join(["priv", "static", "uploads", filename])

          File.mkdir_p!(Path.dirname(dest_path))
          File.cp!(path, dest_path)

          {:ok, "/uploads/#{filename}"}
        end)

      # Create message content
      message_body =
        case {String.trim(body), uploaded_file_urls} do
          {"", []} -> ""
          {text, []} -> text
          {"", files} -> "📎 Shared #{length(files)} file(s)"
          {text, files} -> "#{text}\n📎 Shared #{length(files)} file(s)"
        end

      attachment_string =
        case uploaded_file_urls do
          [] -> nil
          list -> Enum.join(list, ",")
        end

      case Chat.create_message(%{
             body: message_body,
             username: name,
             room: room,
             attachment_url: attachment_string
           }) do
        {:ok, saved_msg} ->
          message = decorate_message(saved_msg, avatar)

          PubSub.broadcast(ChatApp.PubSub, topic_for(room), {:new_message, message, room})

          updated_msgs = [message | socket.assigns.messages_map[room]]
          new_map = Map.put(socket.assigns.messages_map, room, updated_msgs)

          {:noreply,
           socket
           |> assign(:message, "")
           |> assign(:uploaded_files, [])  # Clear uploaded files after sending
           |> assign(:messages_map, new_map)
           |> stream(:messages, Enum.reverse(updated_msgs), reset: true)}

        {:error, changeset} ->
          IO.inspect(changeset, label: "Failed to insert message")
          {:noreply, socket}
      end
    end
  end



  def handle_event("validate_upload", _params, socket) do
  {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
  {:noreply, cancel_upload(socket, :files, ref)}
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
  <div class={"chat-container transition-all " <> if @dark_mode, do: "bg-gray-900 text-white", else: "bg-gray-50 text-black"}>
  <!-- Mobile: centered container, Desktop: full width -->
  <div class="max-w-sm mx-auto px-1 sm:max-w-none sm:mx-0 sm:px-0 sm:h-full sm:flex sm:flex-col">
  <header class="chat-header">
    <div class="flex justify-between items-center p-1 sm:p-0">
      <h1 class="main-title flex-1">
        🚀 BuzzBody Chat App 🐝
      </h1>
      <button phx-click="toggle_theme" class="theme-toggle ml-2">
        Toggle Theme 🌗
      </button>
    </div>
  </header>

  <%= if @name_form do %>
  <.form for={%{}} as={:form} phx-submit="set_name">
  <input name="name" placeholder="Enter your name"
    class={"border p-2 sm:p-3 rounded-lg w-full mb-2 sm:mb-4 focus:outline-none focus:ring-2 focus:ring-blue-400 transition-all text-sm sm:text-base " <>
         if @dark_mode, do: "bg-gray-800 text-white placeholder-gray-400", else: "bg-white text-black placeholder-gray-600"} />

  <div class="mb-2 sm:mb-4">
    <p class="mb-1 sm:mb-2 text-xs sm:text-base text-gray-600 dark:text-gray-300 font-semibold">Choose your avatar:</p>
    <div class="avatar-grid">
  <%= for avatar <- @avatars do %>
      <label title={avatar}>
        <input type="radio" name="avatar" value={avatar} class="hidden peer" required />
        <div class="avatar-option">
          <%= avatar %>
        </div>
      </label>
  <% end %>
  </div>
  </div>

    <button type="submit"
      class="bg-gradient-to-r from-pink-500 to-yellow-500 text-white px-3 py-2 sm:px-4 sm:py-3 rounded-lg w-full font-bold shadow-md hover:scale-105 transition text-sm sm:text-base">
      Join Chat
    </button>
  </.form>

  <% else %>
  <!-- Mobile: traditional layout, Desktop: full screen with sidebar -->
  <div class="block sm:hidden mb-2">
    <!-- Mobile layout - compact -->
    <h2 class="text-sm font-bold flex items-center gap-1 mb-1">
      <span class="text-base"><%= @avatar %></span> 
      <span class="truncate text-xs">Welcome, <%= @display_name %>!</span>
    </h2>
    <div class="flex gap-1 flex-wrap mb-1">
      <%= for room <- @rooms do %>
        <button phx-click="switch_room" phx-value-room={room} id={"room-btn-#{String.replace(room, "#", "")}"}  phx-hook="RoomSwitcher"
          class={"room-button " <>
          if room == @current_room, do: "bg-gradient-to-r from-blue-500 to-indigo-600 text-white", else: "bg-gradient-to-br from-gray-100 to-gray-300 text-gray-800 dark:from-gray-600 dark:to-gray-700 dark:text-white"}>
          <%= room %>
        </button>
      <% end %>
    </div>
    <div class="online-users">
      👥 Online: <%= Enum.map(@online_users, & &1.name) |> Enum.join(", ") %>
    </div>
  </div>

  <!-- Desktop: Full screen layout -->
  <div class="hidden sm:flex sm:flex-1 sm:overflow-hidden">
    <!-- Sidebar -->
    <div class="chat-sidebar">
      <div class="mb-4">
        <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
          <span class="text-xl"><%= @avatar %></span> 
          <span>Welcome, <%= @display_name %>!</span>
        </h2>
        
        <div class="mb-6">
          <h3 class="text-sm font-semibold mb-3 text-gray-600 dark:text-gray-400">Rooms</h3>
          <div class="space-y-2">
            <%= for room <- @rooms do %>
              <button phx-click="switch_room" phx-value-room={room} id={"desktop-room-btn-#{String.replace(room, "#", "")}"}  phx-hook="RoomSwitcher"
                class={"w-full text-left px-3 py-2 rounded text-sm font-medium transition-all " <>
                if room == @current_room, do: "bg-blue-600 text-white shadow", else: "hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-300"}>
                <%= room %>
              </button>
            <% end %>
          </div>
        </div>
        
        <div>
          <h3 class="text-sm font-semibold mb-3 text-gray-600 dark:text-gray-400">Online Users</h3>
          <div class="space-y-2">
            <%= for user <- @online_users do %>
              <div class="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                <div class="w-2 h-2 bg-green-500 rounded-full"></div>
                <%= user.name %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Main chat area -->
    <div class="chat-main">
      <div id="chat-box" phx-hook="AutoScroll" class="chat-box">
        <ol id="messages" phx-update="stream">
          <%= for {id, msg} <- @streams.messages do %>
            <%= render_message(id, msg, @display_name, @reactions[msg.id] || [], @show_reaction_picker) %>
          <% end %>
        </ol>
        <%= if map_size(@typing_users) > 0 do %>
          <p class="typing-indicator">
            <%= Enum.map(@typing_users, fn {name, _} -> name end) |> Enum.join(", ") %> is typing...
          </p>
        <% end %>
      </div>
      
      <!-- Desktop input area -->
      <div class="chat-input-area">
        <.form for={%{}} as={:form} phx-change="update_message" phx-submit="send_message" class="space-y-3">
          <div class="flex items-center gap-2">
            <div id="desktop-upload-btn" phx-hook="FileUploader" class="cursor-pointer bg-gray-200 dark:bg-gray-700 px-3 py-2 rounded text-sm hover:bg-gray-300 dark:hover:bg-gray-600 transition-colors">
              📎 Attach Files
            </div>
            <.live_file_input upload={@uploads.files} id="desktop-hidden-file-input" class="hidden" />
          </div>

          <%= if length(@uploads.files.entries) > 0 do %>
            <div class="flex flex-wrap gap-1 p-2 bg-blue-50 dark:bg-blue-900 rounded">
              <%= for entry <- @uploads.files.entries do %>
                <div class="bg-blue-100 dark:bg-blue-800 px-2 py-1 rounded-full text-xs flex items-center gap-1">
                  <span><%= entry.client_name %></span>
                  <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} class="text-red-500 hover:text-red-700 ml-1">×</button>
                </div>
              <% end %>
            </div>
          <% end %>

          <%= for entry <- @uploads.files.entries do %>
            <div class="w-full bg-gray-200 rounded-full h-2">
              <div class="bg-blue-600 h-2 rounded-full transition-all" style={"width: #{entry.progress}%"}></div>
            </div>
          <% end %>

          <%= for err <- upload_errors(@uploads.files) do %>
            <p class="text-red-500 text-sm">
              <%= error_to_string(err) %>
            </p>
          <% end %>

          <div class="flex items-center gap-2">
            <input
              id="desktop-message-input"
              name="message"
              value={@message}
              placeholder="Type your message here..."
              autocomplete="off"
              phx-debounce="300"
              phx-hook="MessageInput"
              class="flex-grow border px-4 py-3 rounded-full focus:outline-none focus:ring-2 focus:ring-blue-400 text-base"
            />
            <button type="submit" class="bg-blue-600 text-white px-6 py-3 rounded-full hover:bg-blue-700 text-base transition-colors flex-shrink-0">
              Send
            </button>
          </div>
        </.form>
      </div>
    </div>
  </div>

  <!-- Mobile chat area -->  
  <div class="block sm:hidden">
    <div id="mobile-chat-box" phx-hook="AutoScroll" class="chat-box">
      <ol id="mobile-messages" phx-update="stream">
        <%= for {id, msg} <- @streams.messages do %>
          <%= render_message(id, msg, @display_name, @reactions[msg.id] || [], @show_reaction_picker) %>
        <% end %>
      </ol>
      <%= if map_size(@typing_users) > 0 do %>
        <p class="typing-indicator">
          <%= Enum.map(@typing_users, fn {name, _} -> name end) |> Enum.join(", ") %> is typing...
        </p>
      <% end %>
    </div>

    <.form for={%{}} as={:form} phx-change="update_message" phx-submit="send_message" class="space-y-1">
      <div class="flex items-center gap-1">
        <div id="mobile-upload-btn" phx-hook="FileUploader" class="cursor-pointer bg-gray-200 dark:bg-gray-700 px-2 py-1 rounded text-xs hover:bg-gray-300 dark:hover:bg-gray-600 transition-colors">
          📎
        </div>
        <.live_file_input upload={@uploads.files} id="mobile-hidden-file-input" class="hidden" />
      </div>

      <%= if length(@uploads.files.entries) > 0 do %>
        <div class="flex flex-wrap gap-1 p-2 bg-blue-50 dark:bg-blue-900 rounded">
          <%= for entry <- @uploads.files.entries do %>
            <div class="bg-blue-100 dark:bg-blue-800 px-2 py-1 rounded-full text-xs flex items-center gap-1">
              <span class="truncate max-w-20"><%= entry.client_name %></span>
              <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} class="text-red-500 hover:text-red-700 ml-1">×</button>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= for entry <- @uploads.files.entries do %>
        <div class="w-full bg-gray-200 rounded-full h-2">
          <div class="bg-blue-600 h-2 rounded-full transition-all" style={"width: #{entry.progress}%"}></div>
        </div>
      <% end %>

      <%= for err <- upload_errors(@uploads.files) do %>
        <p class="text-red-500 text-sm">
          <%= error_to_string(err) %>
        </p>
      <% end %>

      <div class="flex items-center gap-1">
        <input
          id="mobile-message-input"
          name="message"
          value={@message}
          placeholder="Type here..."
          autocomplete="off"
          phx-debounce="300"
          phx-hook="MessageInput"
          class="message-input"
        />
        <button type="submit" class="bg-blue-600 text-white px-2 py-2 rounded-full hover:bg-blue-700 text-xs transition-colors flex-shrink-0">
          📤
        </button>
      </div>
    </.form>
  </div>

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
  show_reaction_picker: show_reaction_picker
  }

  ~H"""
  <li id={@id} class={"mb-3 sm:mb-4 flex message-slide-in " <> if @msg.username == @current_user, do: "justify-end", else: "justify-start"}>
    <div class={"message-bubble " <>
    if @msg.username == @current_user, do: "bg-blue-600 text-white rounded-br-none", else: "bg-gray-200 dark:bg-gray-700 text-black dark:text-white rounded-bl-none"}>
      <div class="text-xs sm:text-sm font-semibold flex items-center gap-1 mb-1">
        <span class="text-sm sm:text-base"><%= @msg.avatar || "" %></span>
        <span class="truncate"><%= @msg.username %></span>
      </div>
      <div class="text-sm sm:text-base break-words whitespace-pre-wrap leading-relaxed">
        <%= @msg.body %>
      </div>

      <!-- File attachments -->
      <%= if Map.get(@msg, :file_urls, []) != [] do %>
        <div class="mt-2 space-y-1">
          <%= for file_url <- @msg.file_urls do %>
            <div class="file-attachment">
              <%= if is_image?(file_url) do %>
                <img src={file_url} alt="Shared image" class="file-preview" onclick={"window.open('#{file_url}', '_blank')"} />
              <% else %>
                <a href={file_url} target="_blank" class={"flex items-center gap-2 underline " <> if @msg.username == @current_user, do: "text-blue-200 hover:text-blue-100", else: "text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"}>
                  📄 <span class="truncate"><%= Path.basename(file_url) %></span>
                </a>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>

      <div class="text-xs text-right mt-1 opacity-70"><%= @msg.timestamp %></div>
    </div>
  </li>
  """
  end

  defp topic_for(room), do: "chat_room:#{room}"

  defp format_timestamp(ts), do: Timex.format!(ts, "%I:%M %p", :strftime)

  defp decorate_message(msg, fallback_avatar) do
    # Handle attachment_url properly - it might be nil or a string
    attachment_url = case Map.get(msg, :attachment_url) do
      nil -> ""
      url when is_binary(url) -> url
      _ -> ""
    end

    file_urls = case attachment_url do
      "" -> []
      urls when is_binary(urls) and urls != "" ->
        urls
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
      _ -> []
    end

    %{
      id: msg.id,
      body: msg.body,
      username: msg.username,
      room: msg.room,
      timestamp: format_timestamp(msg.inserted_at),
      avatar: fallback_avatar,
      file_urls: file_urls
    }
  end



  defp is_image?(file_url) do
  ext = Path.extname(file_url) |> String.downcase()
  ext in [".jpg", ".jpeg", ".png", ".gif"]
  end
  defp error_to_string(:too_large), do: "File too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "File type not supported"
  defp error_to_string(:too_many_files), do: "Too many files (max 5)"
  defp error_to_string(_), do: "Upload error"

  end
