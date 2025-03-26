import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class CustomToast extends NavigationMixin(LightningElement) {
    @api title;
    @api message;
    @api variant;

    get toastClasses() {
        return `slds-notify slds-notify_toast slds-theme_${this.variant} toast-background-color`;
    }

    // navigateToPulseEmbedSidebar() {
    //     console.log('UPDATED:  navigateToPulseEmbedSidebar called in customToast component!');
    //     this[NavigationMixin.Navigate]({
    //         type: 'standard__component',
    //         attributes: {
    //             componentName: 'c__pulseEmbedSidebar'
    //         }
    //     });
    // }

    handleNavigate() {
        console.log('UPDATED:  handleNavigate called in customToast component!');
        this.dispatchEvent(new CustomEvent('navigatetopulse', {
            bubbles: true,
            composed: true
        }));
    }

    // navigateToPulseEmbedSidebar() {
    //     console.log('navigateToPulseEmbedSidebar called in customToast component!');
    //     try {
    //         this[NavigationMixin.Navigate]({
    //             type: 'standard__component',
    //             attributes: {
    //                 componentName: 'c__pulseEmbedSidebar'
    //             }
    //         });
    //     } catch (error) {
    //         console.error('Navigation Error:', error);
    //     }
    // }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}