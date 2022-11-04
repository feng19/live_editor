const ContentEditable = {
  mounted() {
    let id = this.el.id.substr(5);
    this.el.addEventListener("input", e => {
      let content = this.el.innerText.trim();
      this.pushEvent("slot_changed", {id: id, content: content})
    })
  }
};

export default ContentEditable;