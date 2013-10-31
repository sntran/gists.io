/*
Markdown Block
*/

SirTrevor.Blocks.Markdown = (function(){

  var md_template = _.template([

    '<ul class="nav nav-tabs" id="myTab">',
      '<li class="active"><a data-toggle="tab" class="tab-write">Write</a></li>',
      '<li><a data-toggle="tab" class="tab-preview">Preview</a></li>',
    '</ul>',

    '<div class="tab-content">',
      '<div class="tab-pane active gio-write" contenteditable="true"></div>',
      '<div class="tab-pane gio-preview"></div>',
    '</div>',
  ].join("\n"));


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
      var block = this;
      var editorID = block.blockID.replace(/st-block-/,"gio-write-");
      var previewID = block.blockID.replace(/st-block-/,"gio-preview-");
      var $editor = block.$el.find(".gio-write");
      var $preview = block.$el.find(".gio-preview");
      $editor[0].id = editorID;
      $preview[0].id = previewID;
      block.$el.find(".tab-write")[0].href = "#"+editorID;
      block.$el.find(".tab-preview")[0].href = "#"+previewID;

      setTimeout(function() {
        $('#myTab a').click(function (e) {
          e.preventDefault();
          $(this).tab('show');
        })

        var previousMd = "";
        block.$el.find('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
          if ($(e.target).attr("href") === "#"+previewID) {
            var markdown = $editor.html();
            if(markdown == previousMd) return;
            previousMd = markdown;
            html = marked(markdown);
            $preview.html(html);
          };
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