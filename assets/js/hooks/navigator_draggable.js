import Sortable from 'sortablejs';

const NavigatorDraggable = {
  sortable: null,
  mounted() {
    let hook = this;
    let id = hook.el.id;
    this.sortable = new Sortable(hook.el, {
      animation: 150,
      delayOnTouchOnly: true,
      fallbackOnBody: true,
      swapThreshold: 0.65,
      group: 'navigator',
      draggable: '.draggable',
      // filter: '.filtered',
      ghostClass: 'sortable-ghost',
      chosenClass: 'sortable-chosen',
      onEnd: function (evt) {
        let from = evt.from.dataset.group;
        let to = evt.to.dataset.group;
        if (from == 'root' && to == 'root') {
          hook.pushEvent('update_sort', {
            id: evt.item.dataset.id,
            old_index: evt.oldIndex,
            new_index: evt.newIndex
          });
        } else {
          hook.pushEvent('update_sort', {
            id: evt.item.dataset.id,
            from: from,
            to: to,
            old_index: evt.oldIndex,
            new_index: evt.newIndex
          });
        }
      },
      onChoose: function (evt) {
        console.log('select_component', evt);
        hook.pushEvent('select_component', {id: evt.item.dataset.id});
      },
    });
  },
  destroyed() {
    if (this.sortable) {
      this.sortable.destroy();
    }
  },
};

export default NavigatorDraggable;