/*
Markdown Block
*/

SirTrevor.Blocks.Markdown = (function(){

  var md_template = _.template([
    '<div>',
      '<textarea class="tab-pane active gio-write" required></textarea>',
      '<div class="gio-preview" style="display:hidden"></div>',
    '</div>'
  ].join("\n"));

  var autoAdjust = function($textarea) {
    $textarea.height("auto").height( $textarea[0].scrollHeight );
    return $textarea;
  }

  function insertTextAtCursor(el, text) {
    var val = el.value, endIndex, range;
    if (typeof el.selectionStart != "undefined" && typeof el.selectionEnd != "undefined") {
        endIndex = el.selectionEnd;
        el.value = val.slice(0, el.selectionStart) + text + val.slice(endIndex);
        el.selectionStart = el.selectionEnd = endIndex + text.length;
    } else if (typeof document.selection != "undefined" && typeof document.selection.createRange != "undefined") {
        el.focus();
        range = document.selection.createRange();
        range.collapse(false);
        range.text = text;
        range.select();
    }
  };

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

      this.handlePreview();

      setTimeout(function() {
        // Auto-adjust the height of editor based on content.
        autoAdjust($editor).on('keyup', function() {
          autoAdjust($editor);
        });

        $editor.focus();
      }, 0);
    },

    handlePreview: function() {
      var block = this, 
          $editor = block.$el.find(".gio-write"),
          $preview = block.$el.find(".gio-preview"),
          $el = $("<a>").html('<i class="fa fa-eye"></i>')
                .addClass("st-block-ui-btn st-icon");

      var previousMd = "";
      $el.hover(function() {
        var markdown = $editor.hide().val();
        $preview.show();
        if(markdown == previousMd) return;
        previousMd = markdown;

        marked(markdown, function(err, html) {
          $preview.html(html);
        });
      }, function() {
        $preview.hide();
        $editor.show().focus();
      });
      
      this.$ui.prepend($el);
    },

    toData: function() {
      var block = this, dataObj = {}, 
          text = block.$el.find(".gio-write").val();

      if(text != "")
        dataObj.text = text;
      this.setData(dataObj);
    }
  });
})();