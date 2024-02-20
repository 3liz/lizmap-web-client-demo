// Javascript file to hide buttons which are not necessary for the demonstration
// or to activate a key feature by default in the project
lizMap.events.on({
    'uicreated': () => {
        function waitForElm(selector) {
            return new Promise(resolve => {
                if (document.querySelector(selector)) {
                    return resolve(document.querySelector(selector));
                }

                const observer = new MutationObserver(mutations => {
                    if (document.querySelector(selector)) {
                        resolve(document.querySelector(selector));
                        observer.disconnect();
                    }
                });

                observer.observe(document.body, {
                    childList: true,
                    subtree: true
                });
            });
        }

        waitForElm('#button-pgrouting').then((elm) => {
            elm.click();
            $('#button-switcher').hide();
            $('#button-permaLink').hide();
        });
    }
});
