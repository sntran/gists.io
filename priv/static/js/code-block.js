
SirTrevor.Blocks.Code = (function(){

  var template = _.template([
    "<textarea class='form-control gio-code' rows='10'></textarea>"
  ].join("\n"));

  return SirTrevor.Block.extend({

    type: 'code',

    embeddable: true,
    is_initialized: false,

    icon_name: '<i class="icon-code"></i>',

    //List of languages that the editor supports
    languages: {
        "js": "javascript",
        "erl": "erlang",
        "py": "python",
        "coffee": "coffeescript"
    },

    oldname: "",

    initialize_mixins: function() {
        this.withMixin(SirTrevor.BlockMixins.Embeddable);
        this.is_initialized = true;
    },

    //Pulls out the file extension and checks the list of supported languages
    //If language is supported the language of the editor is adjusted
    setMode: function() {
        var matches = this.$filename.val().match(/\.(.*)/);
        if(matches && this.languages[matches[1]]){
            this.editor.setOption("mode", this.languages[matches[1]]);
        };
    },

    editorHTML: function() {
        return template(this);
    },

    loadData: function(data){
        this.initialize_mixins();
        data.name = this.loadNonEmbedded(data.name);
        this.$code = this.$el.find(".gio-code").val(data.source);
        this.oldname = data.name;
    },

    toData: function(){
        var dataObj = {}, source = "";
        if(this.editor)
            source = this.editor.getValue();
        field = this.$ui.find(".gio-filename")[0];
        var name = (field)? field.value : this.oldname;
        dataObj = {source: source, name: name, embedded: this.embedded, oldname: this.oldname};
        if(!_.isEmpty(dataObj)) {
            this.setData(dataObj);
        }
    },

    adjustUI: function() {     
        if(!this.is_initialized)
            this.initialize_mixins();
        var $fileInput = $('<input class="gio-filename st-block-ui-btn" style="width: 10em;" placeholder="filename.ext" required>');
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
        setTimeout(function() { 
            block.setMode(); 
            block.editor.refresh();
        }, 0);
    }
  });
})();