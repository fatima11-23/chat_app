defmodule ChatAppWeb.ChatLive do
  use ChatAppWeb, :live_view
  alias Phoenix.PubSub

  @topic "chat_room"
  @avatars ~w(🐱 🐶 🐰 🐵 🐸 🐼 🐷 🦊 🐯 🐨 🐮 🐔 🐧 🦁)

  def mount(_params, _session, socket) do
    if connected?(socket), do: PubSub.subscribe(ChatApp.PubSub, @topic)

    socket =
      socket
      |> assign(:display_name, nil)
      |> assign(:avatar, nil)
      |> assign(:name_form, true)
      |> assign(:message, "")
      |> stream(:messages, [])

    {:ok, socket}
  end

  def handle_event("set_name", %{"name" => name}, socket) do
    avatar = Enum.random(@avatars)

    {:noreply,
     socket
     |> assign(:display_name, name)
     |> assign(:avatar, avatar)
     |> assign(:name_form, false)}
  end

  def handle_event("update_message", %{"message" => msg}, socket) do
    {:noreply, assign(socket, :message, msg)}
  end

  def handle_event("send_message", %{"message" => ""}, socket), do: {:noreply, socket}

  def handle_event("send_message", %{"message" => body}, %{assigns: %{display_name: name, avatar: avatar}} = socket) do
    message = %{
      id: System.unique_integer([:positive]),
      name: name,
      avatar: avatar,
      body: body,
      timestamp: timestamp_now()
    }

    PubSub.broadcast(ChatApp.PubSub, @topic, {:new_message, message})

    {:noreply,
     socket
     |> assign(:message, "")
     |> stream_insert(:messages, message)}
  end

  def handle_info({:new_message, message}, socket) do
    {:noreply, stream_insert(socket, :messages, message)}
  end

  defp timestamp_now do
    DateTime.utc_now() |> Timex.format!("%I:%M %p", :strftime)
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-4">
    <h1 class="text-4xl font-extrabold text-center mb-6 text-pink-500 drop-shadow-lg tracking-wide animate-bounce">
    🎉 Buzz Buddy 🐝
     </h1>

      <%= if @name_form do %>
        <.form for={%{}} as={:form} phx-submit="set_name">
          <input name="name" placeholder="Enter your name"
            class="border p-2 rounded w-full mb-2 focus:outline-none focus:ring-2 focus:ring-blue-400" />
          <button type="submit" class="bg-blue-500 text-white px-4 py-2 rounded w-full">Join Chat</button>
        </.form>
      <% else %>
        <h2 class="text-xl font-bold mb-4 flex items-center gap-2">
          <span class="text-2xl"><%= @avatar %></span>
          Welcome, <%= @display_name %>!
        </h2>

        <div id="chat-box" phx-hook="AutoScroll" class="h-96 overflow-y-auto border p-3 rounded mb-4 bg-white shadow-inner">
          <ol id="messages" phx-update="stream">
            <%= for {id, msg} <- @streams.messages do %>
            <li id={id} class={"mb-2 flex " <> if msg.name == @display_name, do: "justify-end", else: "justify-start"}>
     <div class={"max-w-[75%] px-4 py-2 rounded-lg shadow " <>
    if msg.name == @display_name, do: "bg-blue-600 text-white rounded-br-none", else: "bg-green-100 text-black rounded-bl-none"}>

    <div class="text-sm font-semibold flex items-center gap-1 mb-1">
      <span><%= msg.avatar || "" %></span>
      <%= msg.name %>
    </div>

    <div class="text-base break-words whitespace-pre-wrap">
      <%= msg.body %>
    </div>

    <p class="text-xs text-gray-200 mt-1 text-right"><%= msg.timestamp %></p>
    </div>
     </li>

            <% end %>
          </ol>
        </div>

        <.form for={%{}} as={:form} phx-change="update_message" phx-submit="send_message" class="flex gap-2 items-center">
          <input name="message" value={@message} placeholder="Type your message here..." autocomplete="off"
            phx-debounce="300"
            class="flex-grow border px-4 py-2 rounded-full focus:outline-none focus:ring-2 focus:ring-blue-400" />
          <button type="submit" class="bg-blue-600 text-white px-4 py-2 rounded-full hover:bg-blue-700">Send</button>
        </.form>
      <% end %>
    </div>
    """
  end
end
