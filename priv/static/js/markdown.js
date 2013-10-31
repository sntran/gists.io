/*
Markdown Block
*/

SirTrevor.Blocks.Markdown = (function(){

  var md_template = _.template([

    '<ul class="nav nav-tabs" id="myTab">',
      '<li class="active"><a href="#write" data-toggle="tab">Write</a></li>',
      '<li><a href="#preview" data-toggle="tab">Preview</a></li>',
    '</ul>',

    '<div class="tab-content">',
      '<div class="tab-pane active" id="write" contenteditable="true"></div>',
      '<div class="tab-pane" id="preview"></div>',
    '</div>',
  ].join("\n"));


  return SirTrevor.Block.extend({

    type: "markdown",

    editorHTML: function() {
      return md_template(this);
    },

    loadData: function(data){
      this.$('#write').html(data.text);
    },

    onBlockRender: function() {
      setTimeout(function() {
        $('#myTab a').click(function (e) {
          e.preventDefault();
          $(this).tab('show');
        })
      }, 0);

      var previousMd = "";
      setTimeout(function () {
        $('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
          var $editor = $("#write");
          var $preview = $("#preview");
          if ($(e.target).attr("href") === "#preview") {
            var markdown = $editor.html();
            if(markdown == previousMd) return;
            previousMd = markdown;
            html = marked(markdown);
            $preview.html(html);
          };
        });
      });
    },

    toData: function() {
      var dataObj = {};

      dataObj.text = $("#write").html();
      this.setData(dataObj);
    }
  });
})();