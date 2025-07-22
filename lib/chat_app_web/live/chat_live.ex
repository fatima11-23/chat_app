defmodule ChatAppWeb.ChatLive do
  use ChatAppWeb, :live_view
  alias Phoenix.PubSub

  @topic "chat_room"

  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(ChatApp.PubSub, @topic)
    end

    {:ok,
     socket
     |> assign(display_name: nil, name_form: true, message: "")
     |> stream(:messages, [])}
  end

  def handle_event("set_name", %{"name" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply, put_flash(socket, :error, "Display name can't be empty")}
    else
      {:noreply, assign(socket, display_name: name, name_form: false)}
    end
  end

  def handle_event("send_message", %{"message" => msg}, socket) do
    msg = String.trim(msg)

    if msg == "" do
      {:noreply, socket}
    else
      message = %{
        id: System.unique_integer([:positive]), # required for stream!
        name: socket.assigns.display_name,
        body: msg,
        timestamp: Timex.format!(Timex.now(), "{h12}:{m} {AM}")
      }

      PubSub.broadcast(ChatApp.PubSub, @topic, {:new_message, message})
      {:noreply, assign(socket, message: "")}
    end
  end

  def handle_info({:new_message, message}, socket) do
    {:noreply, stream_insert(socket, :messages, message)}
  end

  def render(assigns) do
    IO.inspect(assigns)
    ~H"""
    <div class="min-h-screen bg-gray-100 flex items-center justify-center px-4">
      <div class="bg-white shadow-lg rounded-lg p-6 w-full max-w-md space-y-4">

        <%= if @name_form do %>
          <h2 class="text-xl font-semibold mb-4 text-center">Enter Display Name</h2>
          <.form for={%{}} as={:name} phx-submit="set_name" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Display Name</label>
              <input name="name" class="border border-gray-300 rounded px-3 py-2 w-full focus:outline-none focus:ring-2 focus:ring-blue-400" />
            </div>
            <button type="submit" class="w-full bg-blue-600 text-white py-2 rounded hover:bg-blue-700 transition">Join Chat</button>
          </.form>
          <%= if @flash[:error] do %>
            <div class="mt-4 text-red-600 text-sm text-center">
              <%= @flash[:error] %>
            </div>
          <% end %>

        <% else %>
          <h2 class="text-lg text-center text-green-600 font-bold">Welcome, <%= @display_name %>! 🎉</h2>

          <div id="messages" phx-hook="AutoScroll" phx-update="stream" phx-stream="messages"
               class="h-64 overflow-y-auto border rounded p-2 bg-gray-50 space-y-2 scroll-smooth">
            <%= for {id, msg} <- @streams.messages do %>
              <div id={id} class={
                if msg.name == @display_name,
                  do: "text-right",
                  else: "text-left"
              }>
                <div class={
                  if msg.name == @display_name,
                    do: "inline-block bg-green-100 text-green-900 px-3 py-2 rounded-lg",
                    else: "inline-block bg-gray-200 text-gray-800 px-3 py-2 rounded-lg"
                }>
                  <p class="text-sm font-semibold"><%= msg.name %></p>
                  <p><%= msg.body %></p>
                  <p class="text-xs text-gray-600"><%= msg.timestamp %></p>
                </div>
              </div>
            <% end %>
          </div>

          <.form for={%{}} as={:form} phx-submit="send_message" class="mt-4 flex space-x-2">
            <input name="message" value={@message} placeholder="Type a message..." autocomplete="off"
              class="flex-grow border px-3 py-2 rounded focus:outline-none focus:ring-2 focus:ring-blue-400" />
            <button type="submit" class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600 transition">Send</button>
          </.form>
        <% end %>

      </div>
    </div>
    """
  end
end
