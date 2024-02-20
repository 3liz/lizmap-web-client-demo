// Javascript file to hide buttons which are not necessary for the demonstration
// or to activate a key feature by default in the project
lizMap.events.on({
    'uicreated': function(evt){
        $('#dock').hide();
        $('#button-permaLink').hide();
        $('#button-switcher').hide();
        $('#button-draw').click();
    }
});
