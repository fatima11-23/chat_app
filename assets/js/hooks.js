let Hooks = {}

Hooks.AutoScroll = {
  mounted() {
    this.scrollToBottom()
  },
  updated() {
    this.scrollToBottom()
  },
  scrollToBottom() {
    // Smooth scroll for better UX
    this.el.scrollTo({
      top: this.el.scrollHeight,
      behavior: 'smooth'
    })
  }
}

Hooks.FileUploader = {
  mounted() {
    const fileInput = this.el.parentElement.querySelector("input[type='file']");
    if (fileInput) {
      this.el.addEventListener("click", () => {
        fileInput.click();
      });
    } else {
      console.error("File input not found inside FileUploader hook");
    }
  }
}

// Mobile-friendly keyboard handling
Hooks.MessageInput = {
  mounted() {
    const input = this.el
    
    // Handle mobile keyboard
    input.addEventListener('focus', () => {
      // Scroll to input on mobile when keyboard opens
      setTimeout(() => {
        input.scrollIntoView({ behavior: 'smooth', block: 'center' })
      }, 300)
    })
    
    // Handle enter key on desktop, but not on mobile
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey && window.innerWidth > 640) {
        e.preventDefault()
        const form = input.closest('form')
        if (form) {
          form.dispatchEvent(new Event('submit', { bubbles: true }))
        }
      }
    })
  }
}

// Better mobile touch handling for room switching
Hooks.RoomSwitcher = {
  mounted() {
    // Add haptic feedback on mobile devices
    this.el.addEventListener('touchstart', () => {
      if ('vibrate' in navigator) {
        navigator.vibrate(50)
      }
    })
  }
}

export default Hooks
