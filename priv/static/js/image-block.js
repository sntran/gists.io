SirTrevor.Blocks.Image = (function(){

    return SirTrevor.Block.extend({
        type: "image",
        icon_name: 'image',

        droppable: true,
        uploadable: true,

        loadData: function(data){
            // Create our image tag
            this.$editor.html($('<img>', { src: data.source , alt: data.name}));
        },

        toData: function() {
            var $img = this.$editor.find("img"),
            data = {
                source: $img.attr("src"),
                name: $img.attr("alt")
            };
            this.setData(data);
        },
      
        onBlockRender: function(){
            this.$editor.css("textAlign", "center");
            /* Setup the upload button */
            this.$inputs.find('button').bind('click', function(ev){ ev.preventDefault(); });
            this.$inputs.find('input').on('change', _.bind(function(ev){
                this.onDrop(ev.currentTarget);
            }, this));
        },
      
        onDrop: function(transferData){
            var file = transferData.files[0];
      
            // Handle one upload at a time
            if (/image/.test(file.type)) {
                this.loading();
                var block = this;
                // Show this image on here
                block.$inputs.hide();
                var fileReader = new FileReader();
                fileReader.onload = function(e) {
                    // var url = urlAPI.createObjectURL(file);
                    var url = file.name;
                    var data = {
                        name: file.name,
                        source: e.target.result
                    };
                    block.$editor.html($('<img>', { src: data.source, alt: file.name })).show();
                    block.setData(data);
                    block.ready();
                }
                fileReader.readAsDataURL(file);
            }
        }

    })
})();