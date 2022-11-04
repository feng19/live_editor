import Sortable from 'sortablejs';

const Draggable = {
  mounted() {
    const hook = this;
    let id = this.el.id;
    const selector = '#' + id;
    if (id == "artboard") {
      console.log("Add Sortable for", selector);
      new Sortable(this.el, {
        animation: 150,
        delayOnTouchOnly: true,
        group: 'shared',
        draggable: '.draggable',
        ghostClass: 'sortable-ghost',
        chosenClass: 'sortable-chosen',
        onAdd: function (evt) {
          console.log(id, "-onAdd", evt);
          let attributes = evt.item.attributes;
          hook.pushEventTo(selector, 'add_component', {
            group: attributes['phx-value-group'].value,
            name: attributes['phx-value-name'].value,
            index: evt.newIndex
          });
        },
        onUpdate: function (evt) {
          hook.pushEventTo(selector, 'update_sort', {id: evt.item.id, old_index: evt.oldIndex, new_index: evt.newIndex});
        },
        onRemove: function (evt) {
          console.log(id, "-onRemove", evt);
        },
        onChoose: function (evt) {
          hook.pushEventTo(selector, 'select_component', {id: evt.item.id});
        },
      });
    } else {
      let id = this.el.id;
      const selector = '#' + id;
      console.log("Add Sortable for", selector);
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
      });
    }
  },
};

export default Draggable;