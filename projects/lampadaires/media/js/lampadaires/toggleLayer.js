// JavaScript to add the custom button in the center of the map
// and to toggle ON or OFF the layer
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
        // LWC ≥ 3.7
        let checkbox = lizMap.mainLizmap.state.rootMapGroup.getMapLayerByName('lampadaires');

        $('#toggleLight').click(function(){
            // LWC ≤ 3.6
            $('#layer-lampadaires button.checkbox[value="lampadaires"]').click();
            // LWC ≥ 3.7
            checkbox.checked = !checkbox.checked;
            var btnText = getBtnText();
            $(this).text(btnText);
        });

        function getBtnText(){
            var btnText = 'Switch the lights on !';
            if( $('#layer-lampadaires button.checkbox[value="lampadaires"]').hasClass('checked') ) {
                // LWC ≤ 3.6
                btnText = 'Switch the lights off !';
            }
            if( checkbox.checked ) {
                // LWC ≥ 3.7
                btnText = 'Switch the lights off !';
            }
            return btnText;
        }
    }
});
