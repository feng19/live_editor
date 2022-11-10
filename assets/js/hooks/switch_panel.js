const SwitchPanel = {
  mounted() {
    let parent_class = this.el.dataset.pclass;
    let targetPanel = document.querySelector('#' + this.el.dataset.target);
    this.el.addEventListener("click", e => {
      active = document.querySelector(parent_class+'.active')
      if (active && active.id != targetPanel.id) {
        active.classList.add('hidden');
        active.classList.remove('active');
      }
      targetPanel.classList.toggle('hidden');
      targetPanel.classList.add('active');
    });
  }
}
export default SwitchPanel;