/*
Markdown Block
*/

SirTrevor.Blocks.Markdown = (function(){

  var md_template = _.template([
    '<div class="container">',
      '<textarea class="tab-pane active gio-write"></textarea>',
      '<div class="gio-preview" style="display:hidden"></div>',
    '</div>'
  ].join("\n"));

  var previewer = function($editor, $preview) {
    var $el = $("<a>").html("preview")
                .addClass("st-block-ui-btn st-icon");

    var previousMd = "";
    $el.hover(function() {
      var markdown = $editor.hide().val();
      caret = $editor[0].selectionStart;
      $preview.show();
      if(markdown == previousMd) return;
      previousMd = markdown;
      html = marked(markdown);
      $preview.html(html);
    }, function() {
      $preview.hide();
      $editor.show();
    });
    return $el;
  }

  var autoAdjust = function($textarea) {
    $textarea.height("auto").height( $textarea[0].scrollHeight );
    return $textarea
  }

  return SirTrevor.Block.extend({

    type: "markdown",
    icon_name: 'text',

    editorHTML: function() {
      return md_template(this);
    },

    loadData: function(data){
      this.$el.find('.gio-write').html(data.text);
    },

    onBlockRender: function() {
      var $editor = this.$el.find(".gio-write");
      var $preview = this.$el.find(".gio-preview");

      this.$ui.prepend(previewer($editor, $preview));

      setTimeout(function() {
        // Auto-adjust the height of editor based on content.
        autoAdjust($editor).on('keyup', function() {
          autoAdjust($editor);
        });
      }, 0);
    },

    toData: function() {
      var dataObj = {};

      dataObj.text = this.$el.find(".gio-write").html();
      this.setData(dataObj);
    }
  });
})();