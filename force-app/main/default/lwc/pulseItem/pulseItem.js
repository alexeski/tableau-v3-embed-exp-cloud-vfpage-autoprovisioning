import { LightningElement, api } from 'lwc';

export default class PulseItem extends LightningElement {


    // gives you access to variable called metric defined in the parent component
    @api metric;

    handleMetricItem(event) {
        console.log('click event fired!');
        console.log("metricId: " + this.metric.id);
        const e = new CustomEvent('metricitem1', {
            detail: this.metric.id,
            bubbles: true, // Enable bubbling
            composed: true // Allow the event to bubble beyond the shadow boundary
        });
        this.dispatchEvent(e);
    }
    
}