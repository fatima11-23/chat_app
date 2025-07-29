let Hooks = {}

Hooks.AutoScroll = {
  mounted() {
    this.el.scrollTop = this.el.scrollHeight
  },
  updated() {
    this.el.scrollTop = this.el.scrollHeight
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

export default Hooks
