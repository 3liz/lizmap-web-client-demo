// Javascript file to hide buttons which are not necessary for the demonstration
// or to activate a key feature by default in the project
lizMap.events.on({
    'uicreated':function(evt){
        var newbt = '<span style="text-align: right;"><button style="margin: 5px;" class="btn btn-mini btn-info" id="dv-locate-clear">Annuler le filtre</button></span>';
        $('#locate div.menu-content').after(newbt);
        $('#dv-locate-clear').click(function(){
            $('#locate-clear').click();
            lizMap.map.zoomToExtent(lizMap.map.initialExtent);
        });
        $('li.dataviz a').click()
    }
});
