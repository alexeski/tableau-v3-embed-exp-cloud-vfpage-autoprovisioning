import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

export default class SendMessageToVF extends LightningElement {
    @wire(CurrentPageReference)
    pageRef;

    sendMessage() {
        // Find the iframe containing the Tableau visualization
        const iframes = document.querySelectorAll('iframe');
        
        for (let i = 0; i < iframes.length; i++) {
            const iframe = iframes[i];
            
            try {
                // Try to find tableau-viz inside the iframe
                if (iframe.contentWindow && iframe.contentDocument) {
                    const tableauVizInIframe = iframe.contentDocument.querySelector('tableau-viz');
                    if (tableauVizInIframe) {
                        this.sendFilterToTableau(iframe);
                        return;
                    }
                }
            } catch (e) {
                // Cross-origin restrictions might prevent accessing iframe content
                // Try to identify the iframe by its ID or src attribute
                if (iframe.id && iframe.id.includes('vfFrameId')) {
                    this.sendFilterToTableau(iframe);
                    return;
                }
                
                if (iframe.src && (iframe.src.includes('tableau') || 
                                  iframe.src.includes('visualforce') || 
                                  iframe.src.includes('apex/tableau_visualforce_autoprovisioning'))) {
                    this.sendFilterToTableau(iframe);
                    return;
                }
            }
        }
        
        console.error('No Tableau visualization iframe found');
    }
    
    sendFilterToTableau(iframe) {
        iframe.contentWindow.postMessage({
            type: 'applyFilter',
            sheetName: 'Claims Over Time',
            filterValues: ['Corporate'],
            filterField: 'Patient Class'
        }, '*');
    }

    connectedCallback() {
        window.addEventListener('message', this.handleMessage.bind(this));
    }

    disconnectedCallback() {
        window.removeEventListener('message', this.handleMessage.bind(this));
    }

    handleMessage(event) {
        if (event.data && event.data.type === 'filterApplied') {
            console.log('Filter application result:', event.data.success ? 'Success' : 'Failed');
            if (!event.data.success) {
                console.error('Error:', event.data.error);
            }
        }
    }
}
