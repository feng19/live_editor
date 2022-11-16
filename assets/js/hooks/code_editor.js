import {CodeJar} from 'codejar';
import {withLineNumbers} from 'codejar/linenumbers';

const CodeEditor = {
  jat: null,
  pos: null,
  mounted() {
    let id = this.el.dataset.id;
    let lang = this.el.dataset.lang;
    let editor_id = this.el.dataset.editor;
    const highlight = (editor) => {
      const code = editor.textContent.trim();
      if (code !== "") {
        this.pushEvent("format_code", {id: id, lang: lang, code: code}, (reply, ref) => {
          editor.innerHTML = reply.code;
          if(this.pos){ this.jar.restore(this.pos); }
        });
      }
    }

    let options = {
      tab: ' '.repeat(2)
    }

    this.jar = CodeJar(
      document.querySelector('#' + editor_id),
      withLineNumbers(highlight),
      options
    );
    this.jar.updateCode(this.el.value);

    this.jar.onUpdate(code => {
      this.pos = this.jar.save();
      code = code.trim();
      old = this.el.value.trim();
      if (code != old) {
        this.pushEvent("code_changed", {id: id, lang: lang, code: code});
      }
    });
  },
  updated() {
    if (this.jar.toString() !== this.el.value) {
      this.pos = this.jar.save();
      this.jar.updateCode(this.el.value);
      if(this.pos){ this.jar.restore(this.pos); }
    }
  },
  destroyed() {
    this.jar.destroy();
  }
};

export default CodeEditor;