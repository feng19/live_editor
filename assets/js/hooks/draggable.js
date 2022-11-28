import Sortable from 'sortablejs';

let create_workspace_sortable = function (hook) {
  return new Sortable(hook.el, {
    animation: 150,
    delayOnTouchOnly: true,
    group: {
      name: 'workspace',
      pull: 'clone',
      put: 'add'
    },
    draggable: '.draggable',
    ghostClass: 'sortable-ghost',
    chosenClass: 'sortable-chosen',
    onAdd: function (evt) {
      let attributes = evt.item.attributes;
      hook.pushEvent('add_component', {
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
}

let create_component_add_panel_sortable = function (hook) {
  let id = hook.el.id;
  let left = document.getElementById('ld-left');
  let right_bar = document.getElementById('ld-right-bar');
  return new Sortable(hook.el, {
    animation: 150,
    sort: false,
    delayOnTouchOnly: true,
    group: {
      name: 'add',
      pull: 'clone',
      put: false // Do not allow items to be put into this list
    },
    draggable: '.draggable',
    ghostClass: 'sortable-ghost',
    chosenClass: 'sortable-chosen',
    onStart: function (evt) {
      hook.open_panel = left._x_dataStack[0].open_panel;
      hook.right_tab = right_bar._x_dataStack[0].tab;
      left._x_dataStack[0].open_panel = false;
      right_bar._x_dataStack[0].tab = 'children';
    },
    onEnd: function (evt) {
      left._x_dataStack[0].open_panel = hook.open_panel;
      right_bar._x_dataStack[0].tab = hook.right_tab;
    },
  });
}

const Draggable = {
  sortable: null,
  open_panel: false,
  right_tab: null,
  mounted() {
    let id = this.el.id;
    if (id == "artboard") {
      this.sortable = create_workspace_sortable(this);
    } else {
      this.sortable = create_component_add_panel_sortable(this);
    }
  },
  destroyed() {
    if (this.sortable) {
      this.sortable.destroy();
    }
  },
};

export default Draggable;