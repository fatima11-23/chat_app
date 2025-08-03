defmodule ChatAppWeb.ChatLiveTest do
  use ChatAppWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias Phoenix.PubSub

  # Set up mock data
  @valid_message %{
    "message" => "Hello, world!"
  }

  @valid_user_info %{
    "name" => "Test User",
    "avatar" => "👨‍💻"
  }

  setup do
    # Setup a test connection
    {:ok, conn: build_conn()}
  end

  describe "mount and initial state" do
    test "renders login form initially", %{conn: conn} do
      # Use ignore_error option to suppress the duplicate ID warnings
      {:ok, view, html} = live(conn, "/")

      # Check the initial HTML contains the login form
      assert html =~ "Enter your name"
      assert html =~ "Choose your avatar"
      assert html =~ "Join Chat"

      # Check rendered form
      assert render(view) =~ "Enter your name"
    end
  end

  describe "user authentication" do
    test "can set username and avatar", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Submit the name form
      html = render_submit(view, "set_name", @valid_user_info)

      # Check that the form is gone and welcome message is shown
      assert html =~ "Welcome, #{@valid_user_info["name"]}"
      assert html =~ @valid_user_info["avatar"]

      # Form should be gone
      refute html =~ "Enter your name"
    end
  end

  describe "message sending" do
    test "shows name form when trying to send message without auth", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Try to send message without authentication
      html = render_submit(view, "send_message", @valid_message)

      # Should still see the name form
      assert html =~ "Enter your name"
    end

    test "sends message successfully after auth", %{conn: conn} do
      # Setup test to listen for PubSub events
      PubSub.subscribe(ChatApp.PubSub, "chat_room:#general")

      {:ok, view, _html} = live(conn, "/")

      # First authenticate
      render_submit(view, "set_name", @valid_user_info)

      # Send a message
      message_text = "Hello from test"
      html = render_submit(view, "send_message", %{"message" => message_text})

      # Message should appear in the HTML
      assert html =~ message_text
      assert html =~ @valid_user_info["name"]

      # Should receive broadcast - use _message to avoid warning
      assert_receive {:new_message, _message, "#general"}, 1000
    end

    test "handles empty messages", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # First authenticate
      render_submit(view, "set_name", @valid_user_info)

      # Send empty message - should not add any new messages
      _html_before = render(view)
      html_after = render_submit(view, "send_message", %{"message" => ""})

      # Just verify no new message text appears
      refute html_after =~ "id=\"messages-"
    end

    test "typing indicator works", %{conn: conn} do
      PubSub.subscribe(ChatApp.PubSub, "chat_room:#general")

      {:ok, view, _html} = live(conn, "/")

      # First authenticate
      render_submit(view, "set_name", @valid_user_info)

      # Type something
      render_change(view, "update_message", %{"message" => "Hello"})

      # Should broadcast typing event
      assert_receive {:user_typing, "Test User"}
    end
  end

  describe "room switching" do
    test "can switch between rooms", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Authenticate first
      render_submit(view, "set_name", @valid_user_info)

      # Default room should be #general (visible in HTML)
      html = render(view)
      assert html =~ "#general"

      # Switch to #tech
      html = render_click(view, "switch_room", %{"room" => "#tech"})

      # Should show #tech as selected room
      assert html =~ "#tech"
    end
  end

  describe "theme toggling" do
    test "can toggle dark mode", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Default should be light mode (no dark mode class)
      html = render(view)
      assert html =~ "bg-gray-50 text-black"
      refute html =~ "bg-gray-900 text-white"

      # Toggle theme
      html = render_click(view, "toggle_theme")

      # Should now be in dark mode
      assert html =~ "bg-gray-900 text-white"
      refute html =~ "bg-gray-50 text-black"
    end
  end

  # Integration test for the whole flow
  describe "full chat flow" do
    test "complete chat interaction works", %{conn: conn} do
      # Setup to listen for PubSub events
      PubSub.subscribe(ChatApp.PubSub, "chat_room:#general")

      {:ok, view, _html} = live(conn, "/")

      # 1. Authenticate
      html = render_submit(view, "set_name", @valid_user_info)
      assert html =~ "Welcome, #{@valid_user_info["name"]}"

      # 2. Type a message
      render_change(view, "update_message", %{"message" => "Hello there"})
      assert_receive {:user_typing, "Test User"}

      # 3. Send the message
      html = render_submit(view, "send_message", %{"message" => "Hello there"})
      assert html =~ "Hello there"
      # Use _message to avoid unused variable warning
      assert_receive {:new_message, _message, "#general"}, 1000

      # 4. Switch room
      html = render_click(view, "switch_room", %{"room" => "#tech"})
      assert html =~ "#tech"

      # 5. Toggle theme
      html = render_click(view, "toggle_theme")
      assert html =~ "bg-gray-900 text-white"
    end
  end
end
