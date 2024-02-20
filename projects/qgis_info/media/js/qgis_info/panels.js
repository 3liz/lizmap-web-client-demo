// Javascript file to hide buttons which are not necessary for the demonstration
// or to activate a key feature by default in the project
lizMap.events.on({
    'uicreated': function(evt){
        $('#dock').hide();
        $('#button-permaLink').hide();
        $('#button-switcher').hide();
    },

    'layersadded': function(e) {
        var html = '';
        html+= '<div class="modal-header"><a class="close" data-dismiss="modal">X</a><h3>Time manager</h3></div>';
        html+= '<div class="modal-body">';
        html+= $('#metadata').html();
        html+= '<br>';

        html+= '<br>';
        html+= '</div>';
        html+= '<div class="modal-footer"><button type="button" class="btn btn-default" data-dismiss="modal">Ok</button></div>';
        $('#lizmap-modal').html(html).modal('show');
    }
});
