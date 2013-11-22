SirTrevor.BlockMixins.Embeddable = {
  
  mixinName: "Embeddable",

  initializeEmbeddable: function() {
    var block = this;
    if(block.embedded == null)
        block.embedded = true;
    var $embedder = $("<a class='linkbtn' title='Embed inline'>").addClass("st-block-ui-btn st-icon");
    var editorID = this.instanceID;
    $embedder.html('<i class="fa fa-link"></i>');

    $embedder.click(function() {
      var editorInstance = _.findWhere(SirTrevor.instances, {"ID": editorID});
      block.embedded = !block.embedded;
      if (!block.embedded) {
        $embedder.html('<i class="fa fa-unlink"></i>');
        editorInstance.changeBlockPosition(block.$el,editorInstance.blocks.length);
      } else {
        $embedder.html('<i class="fa fa-link"></i>');
      }
    });

    this.$ui.prepend($embedder);

  },
  //Returns the name of the file:
  //If embedded it returns the orginal name
  //If nonembedded it returns the name minus the underscores
  loadNonEmbedded: function(name) {
    var matches = name.match(/__(.+)__/);
    if(matches && matches[1]){
      var $embedder = this.$ui.find(".linkbtn");
      $embedder.html('<i class="icon-unlink"></i>');
      this.embedded = false;
      return matches[1]
    }
    return name
  }

};