
SirTrevor.Blocks.Code = (function(){

  var template = _.template([
    "<label for='filename'>File Name:</label>",
    "<input type='text' name='filename' id='filename' class='form-control'>",
    "<textarea name='code' id='code' class='form-control' rows='10'></textarea>"
  ].join("\n"));

  return SirTrevor.Block.extend({

    type: 'code',

    icon_name: 'text',

    //List of languages that the editor supports
    languages: {
        "js": "javascript",
        "erl": "erlang",
        "py": "python",
        "coffee": "coffeescript"
    },

    //Pulls out the file extension and checks the list of supported languages
    //If language is supported the language of the editor is adjusted
    setMode: function() {
        var matches = this.$("#filename")[0].value.match(/\.(.*)/);
        if(matches && this.languages[matches[1]]){
            this.editor.setOption("mode", this.languages[matches[1]]);
        };
    },

    editorHTML: function() {
        return template(this);
    },

    loadData: function(data){
        this.$("#code")[0].value = data.source;
        this.$("#filename")[0].value = data.name;
        this.oldname = data.name;
    },

    toData: function(){
        var dataObj = {};

        dataObj.code = this.$("#code")[0].value;
        dataObj.name = this.$("#filename")[0].value;
        dataObj.oldname = this.oldname;
        this.setData(dataObj);
    },

    //Called after the block is rendered
    onBlockRender: function() {
        var block = this;

        var options = {
            theme: "monokai",
            lineNumbers: true,
            autofocus: true,
            matchBrackets: true,
            autoCloseBrackets: true,
            styleActiveLine: true
        };

        var textArea = this.$("#code")[0];
        this.editor = CodeMirror.fromTextArea(textArea,options);

        this.editor.on("drop", function(instance, event) {
            var file = event.dataTransfer.files[0];
            if (!file) return;
            if(confirm('Replace with new file?')) {
                instance.setValue(""); // Clear existing content
                this.$("#filename")[0].value = file.name;
                block.setMode();
            } else {
                event.preventDefault();
            }
        });
        //Attempt to update language mode of editor when filename is changed
        this.$("#filename").on("propertychange input paste", function(event){
            block.setMode();
        })
        //Sets the language mode of editor based on file extension
        setTimeout(function() { block.setMode();}, 0);
    }
  });
})();