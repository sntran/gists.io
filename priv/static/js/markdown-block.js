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

    images: {}, // Image map between filename and its base64.

    editorHTML: function() {
      return md_template(this);
    },

    loadData: function(data){
      // Convert base64 to regular filename and cache the base64.
      var text = this.toRegularImages(data.text);
      this.$el.find('.gio-write').html(text);
    },

    onBlockRender: function() {
      var $editor = this.$el.find(".gio-write");
      var $preview = this.$el.find(".gio-preview");

      this.$el.bind('drop', _.bind(this._handleDrop, this));

      this.handlePreview();

      setTimeout(function() {
        // Auto-adjust the height of editor based on content.
        autoAdjust($editor).on('keyup', function() {
          autoAdjust($editor);
        });
      }, 0);
    },

    handlePreview: function() {
      var block = this, 
          $editor = block.$el.find(".gio-write"),
          $preview = block.$el.find(".gio-preview"),
          $el = $("<a>").html('<i class="icon-eye-open"></i>')
                .addClass("st-block-ui-btn st-icon");

      var previousMd = "";
      $el.hover(function() {
        var markdown = $editor.hide().val();
        $preview.show();
        if(markdown == previousMd) return;
        previousMd = markdown;

        marked(markdown, function(err, html) {
          html = block.toBase64Img(html);
          $preview.html(html);
        });
      }, function() {
        $preview.hide();
        $editor.show().focus();
      });
      
      this.$ui.prepend($el);
    },

    toBase64Img: function(filename) {
      var block = this;
      return filename.replace(/(<img src=")(.+)("\s?\/>)/g, function(match, p1, p2, p3) {
        return p1 + block.images[p2] + '" alt="' + p2 + p3;
      });
    },

    toRegularImages: function(textWithBase64Images) {
      var block = this;
      return textWithBase64Images.replace(/(<img src=")(data:image\/.+;base64.+)(" alt=")(.+)("\s?\/>)/g, function(match, p1, p2, p3, p4, p5) {
        block.images[p4] = p2;
        return p1 + p4 + p5;
      });
    },

    toData: function() {
      var block = this, dataObj = {}, 
          text = this.$el.find(".gio-write").val();
      // Convert regular image's filename source to base64.
      dataObj.text = this.toBase64Img(text);
      this.setData(dataObj);
    },

    _handleDrop: function(e) {
      e.preventDefault();
      e = e.originalEvent;
  
      var block = this, $block = block.$el, $el = $(e.target), 
          file = e.dataTransfer.files[0],
          urlAPI = (typeof URL !== "undefined") ? URL : (typeof webkitURL !== "undefined") ? webkitURL : null;

      if (/image/.test(file.type)) {
        block.loading();
        var fileReader = new FileReader();
        fileReader.onload = function(e) {
          // var url = urlAPI.createObjectURL(file);
          var url = file.name;
          var imgText = '<img src="' + url + '" />';
          insertTextAtCursor($block.find('.gio-write')[0], imgText);
          // Cache the file's base64.
          block.images[url] = e.target.result;
          block.ready();
        }
        fileReader.readAsDataURL(file);
      }
    }
  });
})();