import Sortable from 'sortablejs';

const ChildrenDraggable = {
  sortable: null,
  mounted() {
    let hook = this;
    let id = hook.el.id;
    this.sortable = new Sortable(hook.el, {
      animation: 150,
      delayOnTouchOnly: true,
      fallbackOnBody: true,
      swapThreshold: 0.65,
      group: {
        name: 'children',
        pull: false,
        put: 'add'
      },
      draggable: '.draggable',
      // filter: '.filtered',
      ghostClass: 'sortable-ghost',
      chosenClass: 'sortable-chosen',
      onAdd: function (evt) {
        if (evt.from.dataset.group == 'add') {
          let attributes = evt.item.attributes;
          hook.pushEvent('add_component', {
            group: attributes['phx-value-group'].value,
            name: attributes['phx-value-name'].value,
            to: evt.to.dataset.group,
            index: evt.newIndex
          });
        }
      },
      onEnd: function (evt) {
        let from = evt.from.dataset.group;
        let to = evt.to.dataset.group;
        let old_index = evt.oldIndex;
        let new_index = evt.newIndex;
        if (! (from == to && old_index == new_index)) {
          console.log("update_sort");
          hook.pushEvent('update_sort', {
            id: evt.item.dataset.id,
            from: from,
            to: to,
            old_index: old_index,
            new_index: new_index
          });
        }
      },
    });
  },
  destroyed() {
    if (this.sortable) {
      this.sortable.destroy();
    }
  },
};

export default ChildrenDraggable;