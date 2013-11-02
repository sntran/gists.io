
SirTrevor.Blocks.Code = (function(){

  var template = _.template([
    "<textarea name='code' class='form-control gio-code' rows='10'></textarea>"
  ].join("\n"));

  return SirTrevor.Block.extend({

    type: 'code',

    icon_name: '<i class="icon-code"></i>',

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
        var matches = this.$filename[0].value.match(/\.(.*)/);
        if(matches && this.languages[matches[1]]){
            this.editor.setOption("mode", this.languages[matches[1]]);
        };
    },

    editorHTML: function() {
        return template(this);
    },

    loadData: function(data){ 
        this.$code = this.$el.find(".gio-code").val(data.source);
        this.oldname = data.name;
    },

    toData: function(){
        var dataObj = {};

        dataObj.code = this.$el.find(".gio-code")[0].value;
        field = this.$ui.find(".gio-filename")[0];
        dataObj.name = (field)? field.value : this.oldname;
        dataObj.oldname = this.oldname;
        this.setData(dataObj);
    },

    adjustUI: function() {
        var block = this;
        block.embedded = true;
        var $embedder = $("<a title='Embed inline'>").html('<i class="icon-link"></i>')
            .addClass("st-block-ui-btn st-icon");

        $embedder.click(function() {
            block.embedded = !block.embedded;
            if (!block.embedded) {
                $embedder.html('<i class="icon-unlink"></i>');
            } else {
                $embedder.html('<i class="icon-link"></i>');
            }
        });

        this.$ui.prepend($embedder);

        var $fileInput = $('<input name="filename" class="gio-filename st-block-ui-btn" style="width: 10em;" placeholder="filename.ext">');
        this.$ui.prepend($fileInput.val(this.oldname));
    },

    //Called after the block is rendered
    onBlockRender: function() {
        var block = this;
        this.adjustUI(); // do this gives the filename field.
        block.$filename = block.$ui.find(".gio-filename");

        var options = {
            theme: "monokai",
            lineNumbers: true,
            autofocus: true,
            matchBrackets: true,
            autoCloseBrackets: true,
            styleActiveLine: true,
            viewportMargin: Infinity
        };

        var textArea = block.$el.find(".gio-code")[0];
        this.editor = CodeMirror.fromTextArea(textArea,options);

        this.editor.on("drop", function(instance, event) {
            var file = event.dataTransfer.files[0];
            if (!file) return;
            if(confirm('Replace with new file?')) {
                instance.setValue(""); // Clear existing content
                block.$filename[0].value = file.name;
                block.setMode();
            } else {
                event.preventDefault();
            }
        });
        //Attempt to update language mode of editor when filename is changed
        block.$filename.on("propertychange input paste", function(event){
            block.setMode();
        })
        //Sets the language mode of editor based on file extension
        setTimeout(function() { block.setMode();}, 0);
    }
  });
})();