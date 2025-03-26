import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getViews from '@salesforce/apex/CATokenGenerator.getViews';

export default class VizMenu extends NavigationMixin(LightningElement) {
    @track views;
    // @api label = 'Tableau Dashboards';
    @api label = '';

    connectedCallback() {
        getViews()
            .then(data => {
                // transform custom metadata field names to standard tableau field names
                this.views = data.map(item => {
                    console.log('vizMenu - connectedCallBack - item:',item)
                    return {
                        ...item,
                        contentUrl: item.contentUrl__c,
                        name: item.viewName__c,
                        id: item.Id,
                        contentUrl__c: undefined,
                        viewName__c: undefined,
                        Id: undefined
                    };
                });
                console.log('Views:', JSON.stringify(this.views));
            })
            .catch(error => {
                console.error('Error retrieving views:', error);
            });
    }

    handleVizItem1(event) {
        console.log('event.detail:', event.detail);
        const viewId = event.detail;
    
        console.log('this.views:', this.views);
        const selectedView = this.views.find((view) => view.id === viewId);
    
        if (selectedView) {
            console.log('selectedView:', selectedView);
            const contentUrl = selectedView.contentUrl;
    
            const e = new CustomEvent('vizitem2', {
                detail: contentUrl,
                bubbles: true, // Enable bubbles
                composed: true // Bubble beyond the shadow boundary
            });
            this.dispatchEvent(e);
        } else {
            console.log('No view found with id:', viewId);
        }
    }

}
