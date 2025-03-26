// SDO with BlackTab enabled:
// Username: bking@DF23SDOTabNativeLWC.demo
// Pswd: Summer2023
// Domain: DF23SDOTabNativeLWC
// URL: https://df23sdotabnativelwc.my.salesforce.com


// Load the Tableau Embed v3 API in the head markup
// https://help.salesforce.com/s/articleView?id=sf.community_builder_page_head.htm&type=5
// You can use Head Markup in Builder -> Settigngs -> Advanced -> Edit Head Markup
// <script defer type="module" src="https://us-west-2b.online.tableau.com/javascripts/api/tableau.embedding.3.latest.js"></script>


import {
    LightningElement,
    wire,
    track
} from 'lwc';
import generateJWT from '@salesforce/apex/CATokenGenerator.generateJWT';
import getUserDetails from '@salesforce/apex/CATokenGenerator.getUserDetails';
// import getViews from '@salesforce/apex/CATokenGenerator.getViews';
import getTableauEnvConfig from '@salesforce/apex/CATokenGenerator.getTableauEnvConfig';
import getMetrics from '@salesforce/apex/CATokenGenerator.getMetrics';
import { loadScript } from 'lightning/platformResourceLoader';

export default class PulseEmbedSidebar extends LightningElement {


    // Sidebar stuff
    @track isOpen = false;
    @track isTextVisible = false;

    get svgColor() {
        /* menu text color for SVG */
        return '#C23335';
    }

    get divClass1() {
        return `sidebar-override stage-left slds-grid slds-size--2-of-12 slds-theme--alt-inverse slds-p-vertical--x-small slds-p-horizontal--medium js-nav-toggle ${this.isOpen ? 'open' : ''}`;
    }

    get divClass2() {
        return `sidebar-override stage-left slds-size--2-of-12 slds-shrink-none slds-scrollable--y slds-theme--alt-inverse slds-p-around--small ${this.isOpen ? 'open' : ''}`;
    }

    handleSidebarClick(event) {
        this.isOpen = !this.isOpen;
        this.isTextVisible = !this.isTextVisible;

    }

    handleVizItem2(event) {
        console.log('vizitem2 event fired!');
        console.log('event.detail: ' + JSON.stringify(event.detail));
        this.metricId = event.detail;
        // TODO: Actually, this might be the timeout issue - investigate - may need to call initMetric everytime
        // This is cool. Instead of calling initMetric, we just update the src property on the Tableau web component which is more performant. Need to implement this in CDAPP
        
        
        this.tableauContainer.src = this.metricUrl;
        console.log('this.metricUrl: ' + this.metricUrl);
    }

    @track jwt;
    @track userDetails;

    viz;
    sheet;
    targetSheet;
    tokenType = 'SSO';
    views;
  
    // server = 'https://us-west-2b.online.tableau.com';
    // site = 'eacloud';
    server;
    site;
    path = '/t/';
    workbook = 'UAFSuperstore';
    view = 'Overview';
    params = '?:embed=y';
    baseUrl;
    SCRIPT_PATH;
    SCRIPT_PATH_ALT;
    
    connectedCallback() {
        // First Apex call getUserDetails
        // Get the current domain dynamically
        this.baseUrl = window.location.origin;
        // this.baseUrl = "https://us-west-2b.online.tableau.com"
        console.log('Current Domain: ' + this.baseUrl);

        // this.SCRIPT_PATH = '/js/tableau/tableau.embedding.3.9.0-pre.21.min.js';
        this.SCRIPT_PATH = '/js/tableau/tableau.embedding.3.10.0.min.js';
        this.SCRIPT_PATH_ALT = '/sfsites/c' + this.SCRIPT_PATH;

        // Load the Tableau Embed v3 API script
        loadScript(this, this.baseUrl + this.SCRIPT_PATH)
            .then(() => {
                console.log('Tableau Embed v3 API script loaded successfully.');
            })
            .catch(() => {
                console.log('Tableau Embed v3 API script failed to load using ' + this.SCRIPT_PATH + ' - now trying ' + this.SCRIPT_PATH_ALT);
                return loadScript(this, this.baseUrl + this.SCRIPT_PATH_ALT);
            })
            .then(() => {
                // This will execute after either the initial loadScript (success or fail)
                return getTableauEnvConfig();
            })
            .then(result => {
                // Handle the result from the second call
                console.log('tabEnv: ' + JSON.stringify(result));
                this.server = result[0].TableauCloud__c; // https://10ax.online.tableau.com
                this.site = result[0].SiteName__c; // rcgsepulse
                
                
                // Third Apex call getViews
                return getUserDetails();
            })
            .then(result => {
                // Handle the result from the first call
                this.userDetails = result;
                console.log('userDetails: ' + JSON.stringify(this.userDetails));
    
                // Second Apex call generateJWT
                return generateJWT({ tokenType: this.tokenType });
            })
            .then(result => {
                // Handle the result from the second call
                this.jwt = result;
                console.log('JWT: ' + this.jwt);
                console.log('Link to decode JWT: ' + 'https://jwt.io/#debugger-io?token=' + this.jwt);
                
                // Third Apex call getMetrics
                return getMetrics();
            })
            .then(result => {
                // Handle the result from the thrid call
                // Normalize the view properties to those found in REST API response (name, metricUrl, etc.)
                this.metrics = result.map(item => {
                    return {
                        ...item,
                        metricId: item.metricId__c,
                        name: item.metricName__c,
                        id: item.Id,
                        metricId__c: undefined,
                        metricName__c: undefined,
                        Id: undefined
                    };
                });
                console.log('Metrics:', JSON.stringify(this.metrics));
                // load view at index 0 on first page load
                // TODO: improve to index off of name instead of index int
                this.metricId = this.metrics[0].metricId;
                console.log('this.metricId @ index 0: ' + this.metricId);
                this.initMetric(); // Init viz after all the apex calls
                // this.addEventListener('customclick', this.handleCustomClick.bind(this));
            })
            .catch(error => {
                // Handle error
                console.log("error: " + JSON.stringify(error));
            });
    }

    get tableauContainer() {
        return this.template.querySelector('.tableau-target-div');
    }

    get metricUrl() {
        let metricUrl;
        
        if (this.metricId) {
            // https://online.tableau.com/site/mysite/pulse/metrics/metric-id
            

            console.log("this.metricId: " + this.metricId);
            metricUrl = this.server + '/site/' + this.site + '/pulse/metrics/' + this.metricId;
         
        }
        else {
            console.log('ERROR: No metricId found in local stoarge');
            metricUrl = this.server + '/site/' + this.site + '/pulse/metrics/' + this.metricId;
            
            
        }
        console.log("metricUrl: " + metricUrl);
        return metricUrl;
    }

    // In the initMetric1() method, we create the viz object from the HTML element (container), and then use the viz object to programatically configure the embedded viz.
    // This approach requires the <tableau-viz> web component to be included in the HTML
    initMetric() {
        console.log("initMetric called!");
        const container = this.tableauContainer;
        console.log('container: ' + JSON.stringify(container));

        if (container) {

            console.log('container: ' + JSON.stringify(container));
            console.log('this.jwt: ' + this.jwt);

            // this is not working!
            console.log('this.metricUrl: ' + this.metricUrl);

            // set viz properties
            container.height = '1000px';
            container.width = '100%';
            container.token = this.jwt;
            container.src = this.metricUrl;
            // container.src = 'https://10ax.online.tableau.com/pulse/site/rcgsepulse/metrics/5bd858fa-40e1-4ecc-bf61-c0f037a168e2';
            // container.debug = true;
            // container.toolbar = 'top';
            // container.toolbar = 'hidden';

            console.log('container.token: ' + container.token);
            console.log('container.src: ' + container.src);

            // let tableauMetricElement = this.template.querySelector('[data-id="tableauMetric"]');
            
            // Listen for the 'firstinteractive' event, which is fired when the viz has finished loading
            // Pulse web component does not have event listener functionality as of Feb 2024
            // tableauMetricElement.addEventListener('firstinteractive', (onFirstInteractiveEvent) => {
            //     console.log('viz loaded!');
            //     console.log('target: ' + onFirstInteractiveEvent.target);
            //     this.viz = onFirstInteractiveEvent.target;
            //     this.sheet = this.viz.workbook.activeSheet;
            //     console.log("sheet name: " + this.sheet.name);
            //     console.log('sheetType: ' + this.sheet.sheetType);

            //     this.targetSheet = this.sheet.worksheets.find(ws => ws.name == "Sale Map");
            //     console.log("targetSheet: " + this.targetSheet);
            // });

        }
    }

}