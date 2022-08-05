lizMap.events.on({
    'uicreated':function(evt){
        var html = '<button id="toggleLight" class="btn btn-warning">Switch the lights on !</button>';

        $('#map-content').append(html);
        $('#toggleLight')
        .css('position', 'absolute')
        .css('top', '30px')
        .css('z-index', '1000')
        .css('margin-left', 'calc(50% - 80px)')
        ;
        $('#toggleLight').click(function(){
            $('#layer-lampadaires button.checkbox[value="lampadaires"]').click();
            var btnText = getBtnText();
            $(this).text(btnText);
        });

        function getBtnText(){
            var btnText = 'Switch the lights on !';
            if( $('#layer-lampadaires button.checkbox[value="lampadaires"]').hasClass('checked') )
                btnText = 'Switch the lights off !';
            return btnText;
        }
    }
});
