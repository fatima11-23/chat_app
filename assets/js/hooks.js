import { createPicker } from 'picmo'

let Hooks = {}

// ✅ Auto-scroll to latest message
Hooks.AutoScroll = {
  mounted() {
    this.scrollToBottom()
  },
  updated() {
    this.scrollToBottom()
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

// ✅ Emoji Picker with PicMo (reliable per LiveView mount)
Hooks.EmojiInput = {
  mounted() {
    const input = this.el.closest("form").querySelector("input[name='message']")
    const trigger = this.el.querySelector("#emoji-trigger")

    // Attach the picker to the hook root
    this.picker = createPicker({
      rootElement: this.el,
      autoHide: true,
      showSearch: false,
      showPreview: false,
      emojiSize: "1.5rem",
      theme: this.el.dataset.dark === "true" ? "dark" : "light"
    })

    trigger.addEventListener("click", (e) => {
      e.preventDefault()
      this.picker.toggle()
    })

    this.picker.addEventListener("emoji:select", (selection) => {
      input.value += selection.emoji
      input.focus()
      input.dispatchEvent(new Event("input", { bubbles: true }))
    })
  },

  destroyed() {
    this.picker?.destroy()
  }
}

export default Hooks
