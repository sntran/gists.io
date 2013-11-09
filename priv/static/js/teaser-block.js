SirTrevor.Blocks.Teaser = (function(){

    return SirTrevor.Blocks.Text.extend({
        title: "Teaser",
        type: "teaser",
        icon_name: '<i class="icon-ellipsis-horizontal"></i>',
        editorHTML: '<div class="st-text-block" contenteditable="true"></div>',
    

        onBlockRender: function() {
            SirTrevor.Blocks.Text.prototype.onBlockRender.call(this);

            var editorID = this.instanceID, $el = this.$el;
            $el.prepend("<h3>Teaser</h3>");

            this.on("removeBlock", function() {
                $(".st-block-controls__top").show();
            });

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
                $(".st-block-controls__top").hide(); // No top "Add" button
                $el.find(".st-block-ui-btn--reorder").remove(); // Not draggable
                $el.find(".st-block-positioner").remove();
            }, 0);
        }

    })
})();