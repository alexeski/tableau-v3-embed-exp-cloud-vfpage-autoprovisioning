import { LightningElement, api } from 'lwc';

export default class VizItem extends LightningElement {


    // gives you access to variable called view defined in the parent component
    @api view;

    handleVizItem(event) {
        console.log('click event fired!');
        console.log("viewId: " + this.view.id);
        const e = new CustomEvent('vizitem1', {
            detail: this.view.id,
            bubbles: true, // Enable bubbling
            composed: true // Allow the event to bubble beyond the shadow boundary
        });
        this.dispatchEvent(e);
    }
    
}