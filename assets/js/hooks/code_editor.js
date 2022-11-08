import {CodeJar} from 'codejar';
import {withLineNumbers} from 'codejar/linenumbers';

let jat;
let pos;

const CodeEditor = {
  mounted() {
    let id = this.el.dataset.id;
    let lang = this.el.dataset.lang;
    let editor_id = this.el.dataset.editor;
    const highlight = (editor) => {
      const code = editor.textContent.trim();
      if (code !== "") {
        this.pushEvent("format_code", {id: id, lang: lang, code: code}, (reply, ref) => {
          editor.innerHTML = reply.code;
          if(pos){ jar.restore(pos); }
        });
      }
    }

    let options = {
      tab: ' '.repeat(2)
    }

    jar = CodeJar(
      document.querySelector('#' + editor_id),
      withLineNumbers(highlight),
      options
    );
    jar.updateCode(this.el.value);

    jar.onUpdate(code => {
      pos = jar.save();
      code = code.trim();
      old = this.el.value.trim();
      if (code != old) {
        this.pushEvent("code_changed", {id: id, lang: lang, code: code});
      }
    });
  },
  updated() {
    if (jar.toString() !== this.el.value) {
      pos = jar.save();
      jar.updateCode(this.el.value);
      if(pos){ jar.restore(pos); }
    }
  }
};

export default CodeEditor;