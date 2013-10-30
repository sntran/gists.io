
SirTrevor.Blocks.File = (function(){

  var template = _.template([
    "<label for='filename'>File Name:</label>",
    "<input type='text' name='filename' id='filename' class='form-control'>",
    "<textarea name='file' id='file' class='form-control' rows='10'></textarea>"
  ].join("\n"));

  return SirTrevor.Block.extend({

    type: 'file',

    icon_name: 'text',

    languages: {
        "js": "javascript",
        "erl": "erlang",
        "py": "python",
        "coffee": "coffeescript"
    },


    setMode: function() {
        var matches = this.$("#filename")[0].value.match(/\.(.*)/)
        if(matches && this.languages[matches[1]]){
            this.editor.setOption("mode", this.languages[matches[1]])
        }
    },

    editorHTML: function() {
        return template(this);
    },

    loadData: function(data){
        this.$("#file")[0].value = data.text;
        this.$("#filename")[0].value = data.name;
    },

    onBlockRender: function() {
        var block = this;

        var options = {
            theme: "monokai",
            lineNumbers: true,
            autofocus: true
        };

        var textArea = this.$("#file")[0];
        this.editor = CodeMirror.fromTextArea(textArea,options);
        this.$("#filename").on("propertychange input paste", function(event){
            block.setMode();
        })
        block.setMode();
    }
  });
})();