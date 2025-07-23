import { Socket } from "phoenix"
import topbar from "../vendor/topbar"
import { LiveSocket } from "phoenix_live_view"
import Hooks from "./hooks"  // ✅ use hooks defined in hooks.js

// 🔐 CSRF protection
let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")

// 🚀 Initialize LiveSocket with imported Hooks
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken }
})

// 📊 Topbar progress bar during page load or form submit
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", () => topbar.show())
window.addEventListener("phx:page-loading-stop", () => topbar.hide())

// 🔌 Connect LiveView
liveSocket.connect()

// 🧪 Expose liveSocket globally for debug via console
window.liveSocket = liveSocket
