SirTrevor.Blocks.Teaser = (function(){

    return SirTrevor.Blocks.Text.extend({

        type: "teaser",
        icon_name: '<i class="icon-ellipsis-horizontal"></i>',

        onBlockRender: function() {
            SirTrevor.Blocks.Text.prototype.onBlockRender.call(this);

            var editorID = this.instanceID, $el = this.$el;
            $el.prepend("<h3>Teaser</h3>");
            
            setTimeout(function() {
                var editorInstance = _.findWhere(SirTrevor.instances, {"ID": editorID});
                SirTrevor.EventBus.on(editorID + ":blocks:change_position", function($block, selectedPosition, beforeOrAfter) {
                    if ($block.is($el)) {
                        editorInstance.changeBlockPosition($el, 1);
                    } else if (selectedPosition == "1") {
                        editorInstance.changeBlockPosition($block, 2)
                    }
                });
                editorInstance.changeBlockPosition($el, 1);
            }, 0);
        }

    })
})();