# 🚀 BuzzBody Chat App 🐝

A modern, real-time chat application built with Phoenix LiveView featuring responsive design optimized for both desktop and mobile experiences.

## ✨ Features

### 💬 Real-time Chat
- **Instant messaging** with Phoenix PubSub
- **Multiple chat rooms** (#general, #tech, #random)
- **Live typing indicators** to see when others are typing
- **Message persistence** with database storage
- **User presence tracking** with online/offline status

### 📱 Responsive Design
- **Desktop Full-Screen Mode**: Utilizes entire browser window with sidebar navigation
- **Mobile-Optimized Layout**: Compact, touch-friendly interface
- **Adaptive UI Elements**: Different layouts and sizing for desktop vs mobile
- **Smart Room Navigation**: Sidebar on desktop, horizontal buttons on mobile

### 🎨 Modern UI/UX
- **Dark/Light Theme Toggle** with smooth transitions
- **Avatar Selection** from 10 carefully chosen emojis
- **Gradient Styling** with modern design elements
- **Smooth Animations** and hover effects
- **Custom Scrollbars** and optimized typography

### 📎 File Sharing
- **Multi-file Upload** support (up to 5 files, 10MB each)
- **Image Preview** with click-to-view functionality
- **File Type Support**: Images (jpg, png, gif), documents (pdf, txt, doc), media (mp4, mp3, wav)
- **Progress Indicators** during file uploads
- **Drag & Drop** file attachment

### 🔧 Technical Features
- **Phoenix LiveView** for real-time updates without JavaScript complexity
- **Tailwind CSS** with mobile-first responsive design
- **Database Persistence** for chat history
- **File Upload Handling** with secure storage
- **Cross-browser Compatibility** with modern web standards

## 🚀 Getting Started

### Prerequisites
- **Elixir** 1.14+ and **Erlang** 24+
- **Phoenix** 1.7+
- **PostgreSQL** database
- **Node.js** 18+ for asset compilation

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd chat_app
   ```

2. **Install dependencies**
   ```bash
   mix setup
   ```
   This command will:
   - Install Elixir dependencies with `mix deps.get`
   - Create and migrate the database with `mix ecto.setup`
   - Install Node.js dependencies with `npm install` (inside assets directory)

3. **Start the Phoenix server**
   ```bash
   mix phx.server
   ```
   Or run it inside IEx for interactive development:
   ```bash
   iex -S mix phx.server
   ```

4. **Visit the application**
   Open your browser and navigate to [`localhost:4000`](http://localhost:4000)

## 🖥️ Desktop Experience

The desktop version provides a full-screen chat experience:
- **Sidebar Navigation**: Persistent left sidebar with rooms and online users
- **Full Window Usage**: Utilizes entire browser window for maximum screen real estate
- **Fixed Input Area**: Chat input pinned to bottom for easy access
- **Larger UI Elements**: Spacious design with comfortable padding and fonts
- **Enhanced Features**: Full placeholder text, detailed file information

## 📱 Mobile Experience

The mobile version is optimized for touch devices:
- **Compact Layout**: Centered, mobile-optimized container design
- **Touch-Friendly Elements**: Appropriately sized buttons and inputs
- **Vertical Stack Layout**: Traditional mobile chat interface
- **Mobile-Specific UI**: Emoji buttons, shortened text, optimized spacing
- **Keyboard-Aware**: Smart scrolling when mobile keyboard appears

## 🎯 Usage

1. **Enter Your Name**: Choose a display name and select an avatar
2. **Join Conversations**: Switch between different chat rooms
3. **Send Messages**: Type and send real-time messages
4. **Share Files**: Attach images, documents, or media files
5. **See Who's Online**: View active users in current room
6. **Customize Experience**: Toggle between light and dark themes

## 🏗️ Project Structure

```
chat_app/
├── lib/
│   ├── chat_app/               # Core application logic
│   │   ├── chat.ex            # Chat context
│   │   └── chat/
│   │       └── message.ex     # Message schema
│   └── chat_app_web/          # Web interface
│       ├── live/
│       │   └── chat_live.ex   # Main LiveView module
│       ├── components/        # Reusable components
│       └── channels/          # Real-time features
├── assets/                    # Frontend assets
│   ├── css/
│   │   └── app.css           # Tailwind CSS with custom styles
│   ├── js/
│   │   ├── app.js            # Main JavaScript
│   │   └── hooks.js          # LiveView hooks
│   └── tailwind.config.js    # Tailwind configuration
├── priv/
│   ├── repo/migrations/      # Database migrations
│   └── static/uploads/       # File upload storage
└── README.md
```

## 🛠️ Development

### Database Operations
```bash
# Create and migrate database
mix ecto.setup

# Run migrations
mix ecto.migrate

# Reset database
mix ecto.reset
```

### Asset Compilation
```bash
# Watch and compile assets during development
cd assets && npm run watch

# Build assets for production
cd assets && npm run deploy
```

### Testing
```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover
```

## 🚀 Deployment

Ready to run in production? Check the [Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

### Environment Variables
Set these environment variables for production:
- `DATABASE_URL`: PostgreSQL connection string
- `SECRET_KEY_BASE`: Phoenix secret key
- `PHX_HOST`: Your domain name

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 Learn More About Phoenix

- **Official website**: https://www.phoenixframework.org/
- **Guides**: https://hexdocs.pm/phoenix/overview.html
- **Documentation**: https://hexdocs.pm/phoenix
- **Forum**: https://elixirforum.com/c/phoenix-forum
- **Source**: https://github.com/phoenixframework/phoenix

## 💡 Features Roadmap

- [ ] Message reactions and emoji responses
- [ ] Private messaging between users
- [ ] Message search and filtering
- [ ] User authentication and profiles
- [ ] Push notifications
- [ ] Voice/video calling integration
- [ ] Message encryption
- [ ] Custom room creation
- [ ] Admin moderation tools
- [ ] Mobile app (React Native/Flutter)

---

**Built with ❤️ using Phoenix LiveView, Tailwind CSS, and modern web technologies.**