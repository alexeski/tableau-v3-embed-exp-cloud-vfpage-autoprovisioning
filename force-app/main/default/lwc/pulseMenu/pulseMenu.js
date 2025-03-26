import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getMetrics from '@salesforce/apex/CATokenGenerator.getMetrics';

export default class PulseMenu extends LightningElement {
    @track metrics;
    // @api label = 'Tableau Dashboards';
    @api label = '';

    connectedCallback() {
        getMetrics()
            .then(data => {
                // transform custom metadata field names to standard tableau field names
                this.metrics = data.map(item => {
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
                console.log('metrics:', JSON.stringify(this.metrics));
            })
            .catch(error => {
                console.error('Error retrieving metrics:', error);
            });
    }

    handleMetricitem1(event) {
        console.log('event.detail:', event.detail);
        const metricId = event.detail;
    
        console.log('this.metrics:', JSON.stringify(this.metrics));
        const selectedMetric = this.metrics.find((metric) => metric.id === metricId);
        console.log('selectedMetric:', JSON.stringify(selectedMetric));
    
        if (selectedMetric) {
            const metricId = selectedMetric.metricId;
            console.log
    
            const e = new CustomEvent('vizitem2', {
                detail: metricId,
                bubbles: true, // Enable bubbles
                composed: true // Bubble beyond the shadow boundary
            });
            this.dispatchEvent(e);
        } else {
            console.log('No metric found with id:', metricId);
        }
    }

}
