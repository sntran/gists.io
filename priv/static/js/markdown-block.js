/*
Markdown Block
*/

SirTrevor.Blocks.Markdown = (function(){

  var md_template = _.template([
    '<div>',
      '<textarea class="tab-pane active gio-write"></textarea>',
      '<div class="gio-preview" style="display:hidden"></div>',
    '</div>'
  ].join("\n"));

  var previewer = function($editor, $preview) {
    var $el = $("<a>").html('<i class="icon-eye-open"></i>')
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
      $editor.show().focus();
    });
    return $el;
  }

  var autoAdjust = function($textarea) {
    $textarea.height("auto").height( $textarea[0].scrollHeight );
    return $textarea
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

      this.$el.bind('drop', _.bind(this._handleDrop, this));

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

      dataObj.text = this.$el.find(".gio-write").val();
      this.setData(dataObj);
    },

    _handleDrop: function(e) {
      e.preventDefault();
      e = e.originalEvent;
  
      var $block = this.$el, $el = $(e.target), file = e.dataTransfer.files[0],
          urlAPI = (typeof URL !== "undefined") ? URL : (typeof webkitURL !== "undefined") ? webkitURL : null;

      if (/image/.test(file.type)) {
        var imgText = '<img src="' + urlAPI.createObjectURL(file) + '" />';
        insertTextAtCursor($block.find('.gio-write')[0], imgText);
      }

    }
  });
})();