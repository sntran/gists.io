SirTrevor.Blocks.Teaser = (function(){

    var md_template = _.template([
        '<h3>Teaser</h3>',
        '<ul class="nav nav-tabs" id="myTab">',
            '<li class="active"><a data-toggle="tab" class="tab-write">Write</a></li>',
            '<li><a data-toggle="tab" class="tab-preview">Preview</a></li>',
        '</ul>',

        '<div class="tab-content">',
            '<div class="tab-pane active gio-write" contenteditable="true"></div>',
            '<div class="tab-pane gio-preview"></div>',
        '</div>',
    ].join("\n"));
    
    return SirTrevor.Blocks.Markdown.extend({

        type: "teaser",

        editorHTML: function() {
            return md_template(this);
        },

        onBlockRender: function() {
            var editorID = this.instanceID, $el = this.$el,
                editorInstance = _.findWhere(SirTrevor.instances, {"ID": editorID});
            SirTrevor.EventBus.on(editorID + ":blocks:change_position", function($block, selectedPosition, beforeOrAfter) {
                if ($block.is($el)) {
                    editorInstance.changeBlockPosition($el, 1);
                } else if (selectedPosition == "1") {
                    editorInstance.changeBlockPosition($block, 2)
                }
            });

            setTimeout(function() {
                editorInstance.changeBlockPosition($el, 1);
            }, 0);
        }

    })
})();