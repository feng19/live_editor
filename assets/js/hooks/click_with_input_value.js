const ClickWithInputValue = {
  mounted() {
    let event = this.el.dataset.event;
    let input_id = this.el.dataset.target;
    let input = document.querySelector('#' + input_id);
    this.el.addEventListener("click", e => {
      this.pushEvent(event, {value: input.value});
    });
  }
}
export default ClickWithInputValue;