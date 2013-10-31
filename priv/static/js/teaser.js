SirTrevor.Blocks.Teaser = (function(){

    var md_template = _.template([
        '<h3>Teaser</h3>',
        '<ul class="nav nav-tabs" id="myTab">',
            '<li class="active"><a href="#write" data-toggle="tab">Write</a></li>',
            '<li><a href="#preview" data-toggle="tab">Preview</a></li>',
        '</ul>',

        '<div class="tab-content">',
            '<div class="tab-pane active" id="write" contenteditable="true"></div>',
            '<div class="tab-pane" id="preview"></div>',
        '</div>',
    ].join("\n"));



    return SirTrevor.Blocks.Markdown.extend({

        type: "teaser",

        editorHTML: function() {
            return md_template(this);
        }

    })
})();