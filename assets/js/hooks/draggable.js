import Sortable from 'sortablejs';

const Draggable = {
  sortable: null,
  open_panel: false,
  mounted() {
    const hook = this;
    let id = this.el.id;
    const selector = '#' + id;
    if (id == "artboard") {
      // console.log("Add Sortable for", selector);
      sortable = new Sortable(this.el, {
        animation: 150,
        delayOnTouchOnly: true,
        group: 'shared',
        draggable: '.draggable',
        ghostClass: 'sortable-ghost',
        chosenClass: 'sortable-chosen',
        onAdd: function (evt) {
          // console.log(id, "-onAdd", evt);
          let attributes = evt.item.attributes;
          hook.pushEventTo(selector, 'add_component', {
            group: attributes['phx-value-group'].value,
            name: attributes['phx-value-name'].value,
            index: evt.newIndex
          });
        },
        onUpdate: function (evt) {
          hook.pushEvent('update_sort', {id: evt.item.id, old_index: evt.oldIndex, new_index: evt.newIndex});
        },
        //onRemove: function (evt) {
        //  console.log(id, "-onRemove", evt);
        //},
        onChoose: function (evt) {
          hook.pushEvent('select_component', {id: evt.item.id});
        },
      });
    } else {
      let id = this.el.id;
      const selector = '#' + id;
      let left = document.getElementById('ld-left');
      // console.log("Add Sortable for", selector);
      new Sortable(this.el, {
        animation: 150,
        sort: false,
        delayOnTouchOnly: true,
        group: {
          name: 'shared',
          pull: 'clone',
          put: false // Do not allow items to be put into this list
        },
        draggable: '.draggable',
        ghostClass: 'sortable-ghost',
        chosenClass: 'sortable-chosen',
        onStart: function (evt) {
          this.open_panel = left._x_dataStack[0].open_panel;
          left._x_dataStack[0].open_panel = false;
        },
        onEnd: function (evt) {
          left._x_dataStack[0].open_panel = this.open_panel;
        },
      });
    }
  },
  destroyed() {
    if (this.sortable) {
      this.sortable.destroy();
    }
  },
};

export default Draggable;